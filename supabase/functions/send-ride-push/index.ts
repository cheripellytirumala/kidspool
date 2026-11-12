// send-ride-push — S19 "Ride started" / S20 "Arrived" pushes to the parent.
//
// Called by a Supabase Database Webhook on `public.ride_requests` UPDATE
// (payload `{type, table, record, old_record}`), with the header
// `x-webhook-secret: <RIDE_PUSH_WEBHOOK_SECRET>`.
//
//   started_at   null → set   ⇒ S19  kind `ride_started`
//   completed_at null → set   ⇒ S20  kind `ride_arrived`
//   anything else             ⇒ 200 {skipped}
//
// Title / body copy matches get_my_notifications
// (docs/backend/2026-11-05_get_my_notifications.sql), so the push, the in-app
// banner and the Notifications list read the same.
//
// Sends through FCM HTTP v1 to every token in `public.push_tokens` for
// `record.parent_id` and deletes tokens FCM reports as no longer valid.
//
// Secrets / env:
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY   (provided by Supabase)
//   FCM_SERVICE_ACCOUNT        Firebase service-account JSON (whole file)
//   RIDE_PUSH_WEBHOOK_SECRET   shared with the Database Webhook header
//
// Deploy: supabase functions deploy send-ride-push --no-verify-jwt
// Setup:  docs/backend/2026-11-10_push_setup.md

import { createClient } from "npm:@supabase/supabase-js@2";

type Row = Record<string, unknown>;

interface WebhookPayload {
  type?: string;
  table?: string;
  schema?: string;
  record?: Row | null;
  old_record?: Row | null;
}

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
  token_uri?: string;
}

type RideKind = "ride_started" | "ride_arrived";

const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
const GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token";
/** Android channel created by the app (NotificationsApiConstants). */
const ANDROID_CHANNEL_ID = "ride_alerts";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

const isSet = (value: unknown) => value !== null && value !== undefined && value !== "";

// ---------------------------------------------------------------- entry point

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const secret = Deno.env.get("RIDE_PUSH_WEBHOOK_SECRET") ?? "";
  if (!secret || !safeEqual(req.headers.get("x-webhook-secret") ?? "", secret)) {
    return json({ error: "unauthorized" }, 401);
  }

  let payload: WebhookPayload;
  try {
    payload = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  const record = payload.record ?? null;
  const old = payload.old_record ?? null;
  if (payload.type !== "UPDATE" || payload.table !== "ride_requests" || !record || !old) {
    return json({ skipped: "not_a_ride_request_update" });
  }

  const kind = rideEvent(record, old);
  if (!kind) return json({ skipped: "no_ride_event" });

  const requestId = String(record.id ?? "");
  const parentId = record.parent_id ? String(record.parent_id) : "";
  if (!requestId || !parentId) return json({ skipped: "missing_ids" });

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );

  const { data: tokenRows, error: tokenError } = await supabase
    .from("push_tokens")
    .select("token")
    .eq("user_id", parentId);
  if (tokenError) {
    console.error("push_tokens lookup failed", tokenError);
    return json({ error: "token_lookup_failed" }, 500);
  }
  const tokens: string[] = ((tokenRows ?? []) as Row[]).map((r) => String(r.token));
  if (tokens.length === 0) return json({ skipped: "no_tokens", kind, requestId });

  let copy: { title: string; body: string };
  try {
    copy = await buildCopy(supabase, kind, record);
  } catch (error) {
    console.error("copy lookup failed", error);
    return json({ error: "copy_lookup_failed" }, 500);
  }

  let account: ServiceAccount;
  try {
    account = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT") ?? "");
  } catch {
    console.error("FCM_SERVICE_ACCOUNT is missing or not JSON");
    return json({ error: "fcm_not_configured" }, 500);
  }

  let accessToken: string;
  try {
    accessToken = await googleAccessToken(account);
  } catch (error) {
    console.error("Google OAuth failed", error);
    return json({ error: "fcm_auth_failed" }, 500);
  }

  const alertId = `${kind}:${requestId}`;
  const results = await Promise.all(
    tokens.map((token) =>
      sendToToken(account.project_id, accessToken, token, kind, requestId, alertId, copy)
    ),
  );

  const stale = results.filter((r) => r.stale).map((r) => r.token);
  if (stale.length > 0) {
    const { error } = await supabase.from("push_tokens").delete().in("token", stale);
    if (error) console.error("stale token cleanup failed", error);
  }

  return json({
    kind,
    requestId,
    sent: results.filter((r) => r.ok).length,
    failed: results.filter((r) => !r.ok).length,
    removed: stale.length,
  });
});

// ---------------------------------------------------------------- event + copy

/** S19 / S20 from the timestamps that just changed; null otherwise. */
function rideEvent(record: Row, old: Row): RideKind | null {
  // Both in one update (unusual): the ride is over, say it arrived.
  if (!isSet(old.completed_at) && isSet(record.completed_at)) return "ride_arrived";
  if (!isSet(old.started_at) && isSet(record.started_at)) return "ride_started";
  return null;
}

/** Same wording as get_my_notifications (first names only). */
async function buildCopy(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  kind: RideKind,
  record: Row,
): Promise<{ title: string; body: string }> {
  const requestId = String(record.id);

  const [kidsRes, schoolRes, driverRes] = await Promise.all([
    supabase
      .from("ride_request_kids")
      .select("kids(first_name)")
      .eq("request_id", requestId),
    record.school_id
      ? supabase.from("schools").select("name").eq("id", record.school_id).maybeSingle()
      : Promise.resolve({ data: null, error: null }),
    record.driver_id
      ? supabase
        .from("profiles")
        .select("first_name, full_name")
        .eq("id", record.driver_id)
        .maybeSingle()
      : Promise.resolve({ data: null, error: null }),
  ]);
  for (const res of [kidsRes, schoolRes, driverRes]) {
    if (res.error) throw res.error;
  }

  const kidNames = ((kidsRes.data ?? []) as Row[])
    .map((row) => {
      const kid = row.kids as Row | Row[] | null;
      const first = Array.isArray(kid) ? kid[0]?.first_name : kid?.first_name;
      return typeof first === "string" ? first.trim() : "";
    })
    .filter((name) => name.length > 0)
    .sort((a, b) => (a < b ? -1 : a > b ? 1 : 0));
  const kids = kidNames.length > 0 ? kidNames.join(" & ") : "your kids";

  const schoolName = (schoolRes.data as Row | null)?.name;
  const school = typeof schoolName === "string" && schoolName.trim() ? schoolName : "school";

  const driver = driverRes.data as Row | null;
  const firstName = typeof driver?.first_name === "string" ? driver.first_name.trim() : "";
  const fullFirst = typeof driver?.full_name === "string"
    ? driver.full_name.trim().split(" ")[0]
    : "";
  const driverName = firstName || fullFirst || "Your Ride Partner";

  if (kind === "ride_started") {
    return {
      title: "Ride started 🚗",
      body: `${driverName} is on the way to pick up ${kids}.`,
    };
  }
  const tz = typeof record.time_zone === "string" && record.time_zone ? record.time_zone : "UTC";
  return {
    title: `${kids} reached ${school} ✅`,
    body: `${driverName}’s car arrived at ${clockTime(String(record.completed_at), tz)}.`,
  };
}

/** `FMHH12:MI AM` in the ride's time zone, e.g. "8:05 AM". */
function clockTime(iso: string, timeZone: string): string {
  const date = new Date(iso);
  const format = (zone: string) =>
    new Intl.DateTimeFormat("en-US", {
      hour: "numeric",
      minute: "2-digit",
      hour12: true,
      timeZone: zone,
    }).format(date);
  let text: string;
  try {
    text = format(timeZone);
  } catch {
    text = format("UTC");
  }
  // Newer ICU puts a narrow no-break space before AM/PM.
  return text.replace(/ | /g, " ");
}

// ---------------------------------------------------------------- FCM HTTP v1

interface SendResult {
  token: string;
  ok: boolean;
  /** FCM says the token is gone: delete it. */
  stale: boolean;
}

async function sendToToken(
  projectId: string,
  accessToken: string,
  token: string,
  kind: RideKind,
  requestId: string,
  alertId: string,
  copy: { title: string; body: string },
): Promise<SendResult> {
  const message = {
    message: {
      token,
      notification: { title: copy.title, body: copy.body },
      // Read by the app on tap (RideAlertPayload.fromData).
      data: { kind, requestId },
      android: {
        priority: "HIGH",
        notification: {
          channel_id: ANDROID_CHANNEL_ID,
          sound: "default",
          // Same (tag, id 0) as the app's local notification for this event,
          // so the two replace each other.
          tag: alertId,
        },
      },
      apns: {
        headers: {
          "apns-priority": "10",
          // Same identifier as the app's local notification for this event.
          "apns-collapse-id": String(notificationId(alertId)),
        },
        payload: { aps: { sound: "default" } },
      },
    },
  };

  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(message),
    },
  );
  if (res.ok) return { token, ok: true, stale: false };
  if (res.status === 401) cachedToken = null; // retried on the next event

  const body = await res.json().catch(() => ({}));
  const error = (body as { error?: Row }).error ?? {};
  const status = String(error.status ?? "");
  const details = Array.isArray(error.details) ? (error.details as Row[]) : [];
  const errorCode = details.map((d) => String(d.errorCode ?? "")).find((c) => c) ?? "";
  const messageText = String(error.message ?? "");
  // UNREGISTERED: app uninstalled / token rotated. INVALID_ARGUMENT only
  // when it's about the token itself (not a payload bug, which would
  // otherwise wipe every token).
  const stale = errorCode === "UNREGISTERED" ||
    status === "NOT_FOUND" ||
    ((errorCode === "INVALID_ARGUMENT" || status === "INVALID_ARGUMENT") &&
      /registration token/i.test(messageText));
  console.error("FCM send failed", res.status, status, errorCode, messageText);
  return { token, ok: false, stale };
}

/**
 * Same 31-bit FNV-1a hash as RideAlertNotificationId.of in the app
 * (lib/ride_tracking/core/utils/ride_alert_payload.dart).
 */
function notificationId(alertId: string): number {
  let hash = 0x811c9dc5;
  for (let i = 0; i < alertId.length; i++) {
    hash = Math.imul(hash ^ alertId.charCodeAt(i), 0x01000193) >>> 0;
  }
  return hash & 0x7fffffff;
}

// ---------------------------------------------------------------- Google OAuth

let cachedToken: { value: string; expiresAt: number } | null = null;

/** OAuth access token for FCM, from a service-account JWT (RS256). */
async function googleAccessToken(account: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expiresAt - 60 > now) return cachedToken.value;

  const tokenUri = account.token_uri ?? GOOGLE_TOKEN_URL;
  const header = { alg: "RS256", typ: "JWT" };
  const claims = {
    iss: account.client_email,
    scope: FCM_SCOPE,
    aud: tokenUri,
    iat: now,
    exp: now + 3600,
  };
  const unsigned = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(claims))}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToDer(account.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  const assertion = `${unsigned}.${base64url(new Uint8Array(signature))}`;

  const res = await fetch(tokenUri, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!res.ok) {
    throw new Error(`Google token exchange failed: ${res.status} ${await res.text()}`);
  }
  const data = await res.json() as { access_token: string; expires_in?: number };
  cachedToken = { value: data.access_token, expiresAt: now + (data.expires_in ?? 3600) };
  return data.access_token;
}

function pemToDer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\\n/g, "")
    .replace(/\s+/g, "");
  const bytes = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
  return bytes.buffer;
}

function base64url(input: string | Uint8Array): string {
  const bytes = typeof input === "string" ? new TextEncoder().encode(input) : input;
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

/** Length-safe string comparison for the webhook secret. */
function safeEqual(a: string, b: string): boolean {
  const x = new TextEncoder().encode(a);
  const y = new TextEncoder().encode(b);
  let diff = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) {
    diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  }
  return diff === 0;
}
