// POST /functions/v1/notify-feedback   login required
//   body: {}  — or multipart with feedbackId + file0..file2 (screenshots)
//
// 1. With files: stores them in the private feedback-attachments bucket
//    ("<user id>/<feedback id>/<n>.<ext>") on the caller's own, recent
//    feedback row and records the paths in app_feedback.attachments.
// 2. Emails new in-app feedback (public.app_feedback rows with no
//    notified_at) to the KidsPool team, with 30-day links to attachments,
//    then marks them notified. The app calls this right after
//    submit_app_feedback; anything missed is sent with the next call.
//
// Secrets (Supabase → Edge Functions → Secrets):
//   RESEND_API_KEY     required. Without it nothing is sent ({skipped}).
//   FEEDBACK_EMAIL_TO  optional, default ebountibusiness@gmail.com
//                      (comma-separated for several people).
//   FEEDBACK_EMAIL_FROM optional, default "KidsPool Feedback
//                      <onboarding@resend.dev>". The resend.dev sender only
//                      delivers to the Resend account's own email; use a
//                      verified domain to send anywhere else.
//
// Deploy: supabase functions deploy notify-feedback --no-verify-jwt
import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const TO = (Deno.env.get("FEEDBACK_EMAIL_TO") ?? "ebountibusiness@gmail.com")
  .split(",").map((s) => s.trim()).filter(Boolean);
const FROM = Deno.env.get("FEEDBACK_EMAIL_FROM") ??
  "KidsPool Feedback <onboarding@resend.dev>";
const BATCH = 20;
const BUCKET = "feedback-attachments";
const MAX_FILES = 3;
const MAX_BYTES = 2 * 1024 * 1024;
const TYPES: Record<string, string> = {
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/heic": "heic",
};
const LINK_SECONDS = 30 * 24 * 60 * 60;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });

const esc = (v: unknown) =>
  String(v ?? "").replace(/[&<>"']/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]!)
  );

const KIND: Record<string, string> = {
  problem: "🐞 Problem",
  idea: "💡 Improvement idea",
  praise: "💚 Praise",
  other: "💬 Other",
};

type Row = {
  id: string;
  user_id: string | null;
  kind: string;
  area: string | null;
  message: string;
  rating: number | null;
  app_version: string | null;
  platform: string | null;
  os_version: string | null;
  created_at: string;
  attachments: string[] | null;
};

/** Saves the uploaded screenshots on the caller's feedback row. */
async function storeAttachments(
  db: ReturnType<typeof createClient>,
  uid: string,
  form: FormData,
): Promise<Response | null> {
  const feedbackId = String(form.get("feedbackId") ?? "");
  if (!/^[0-9a-f-]{36}$/i.test(feedbackId)) return json(400, { error: "invalid_feedback" });
  const { data: row } = await db.from("app_feedback")
    .select("id, user_id, attachments, created_at").eq("id", feedbackId).maybeSingle();
  // Only the sender, within 15 minutes, once.
  if (!row || row.user_id !== uid) return json(404, { error: "feedback_not_found" });
  if (Date.now() - new Date(row.created_at).getTime() > 15 * 60 * 1000) {
    return json(409, { error: "too_late" });
  }
  if ((row.attachments ?? []).length) return json(409, { error: "already_attached" });

  const files = [...form.entries()]
    .filter(([k, v]) => /^file\d$/.test(k) && v instanceof File)
    .map(([, v]) => v as File)
    .slice(0, MAX_FILES);
  const paths: string[] = [];
  for (const [i, f] of files.entries()) {
    const ext = TYPES[f.type] ?? (/\.png$/i.test(f.name) ? "png" : /\.jpe?g$/i.test(f.name) ? "jpg" : "");
    if (!ext) return json(400, { error: "invalid_file_type" });
    if (f.size > MAX_BYTES) return json(400, { error: "file_too_large" });
    const path = `${uid}/${feedbackId}/${i}.${ext}`;
    const { error } = await db.storage.from(BUCKET).upload(path, f, {
      contentType: f.type || (ext === "png" ? "image/png" : "image/jpeg"),
      upsert: true,
    });
    if (error) return json(500, { error: "upload_failed" });
    paths.push(path);
  }
  if (paths.length) {
    await db.from("app_feedback").update({ attachments: paths }).eq("id", feedbackId);
  }
  return null;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  // Only signed-in app users can trigger it (it only sends existing rows).
  const header = req.headers.get("Authorization") ?? "";
  const token = header.startsWith("Bearer ") ? header.slice(7).trim() : "";
  if (!token) return json(401, { error: "not_authenticated" });
  const db = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: auth, error: authError } = await db.auth.getUser(token);
  if (authError || !auth.user) return json(401, { error: "not_authenticated" });

  // Screenshots first, so they're kept even when email isn't set up.
  let attached = 0;
  if ((req.headers.get("content-type") ?? "").includes("multipart/form-data")) {
    let form: FormData;
    try {
      form = await req.formData();
    } catch {
      return json(400, { error: "invalid_body" });
    }
    const failed = await storeAttachments(db, auth.user.id, form);
    if (failed) return failed;
    attached = [...form.keys()].filter((k) => /^file\d$/.test(k)).length;
  }

  if (!RESEND_API_KEY) return json(200, { skipped: "no_email_provider", attached });

  const { data, error } = await db
    .from("app_feedback")
    .select("id, user_id, kind, area, message, rating, app_version, platform, os_version, created_at, attachments")
    .is("notified_at", null)
    .order("created_at", { ascending: true })
    .limit(BATCH);
  if (error) return json(500, { error: "read_failed" });
  const rows = (data ?? []) as Row[];
  if (!rows.length) return json(200, { sent: 0 });

  // First names only (no phone numbers in email).
  const ids = [...new Set(rows.map((r) => r.user_id).filter(Boolean))] as string[];
  const names = new Map<string, string>();
  if (ids.length) {
    const { data: people } = await db.from("profiles").select("id, first_name, last_name").in("id", ids);
    for (const p of people ?? []) {
      names.set(p.id, [p.first_name, p.last_name ? `${String(p.last_name)[0]}.` : ""].filter(Boolean).join(" "));
    }
  }

  const sentIds: string[] = [];
  for (const r of rows) {
    const who = (r.user_id && names.get(r.user_id)) || "A KidsPool user";
    const stars = r.rating ? "★".repeat(r.rating) + "☆".repeat(5 - r.rating) : "—";
    const kind = KIND[r.kind] ?? r.kind;
    // Private bucket: 30-day signed links.
    const links: string[] = [];
    for (const path of r.attachments ?? []) {
      const { data: signed } = await db.storage.from(BUCKET).createSignedUrl(path, LINK_SECONDS);
      if (signed?.signedUrl) links.push(signed.signedUrl);
    }
    const shots = links.length
      ? `<p style="margin:12px 0 4px"><strong>Attachments (${links.length})</strong> · links work for 30 days</p>` +
        links.map((u, i) =>
          `<a href="${esc(u)}"><img src="${esc(u)}" alt="Attachment ${i + 1}" style="max-width:180px;max-height:320px;border-radius:10px;margin:4px 6px 4px 0;border:1px solid #e6e6e6"></a>`
        ).join("")
      : "";
    const subject = `[KidsPool feedback] ${kind}${r.area ? ` · ${r.area}` : ""}: ${r.message.replace(/\s+/g, " ").slice(0, 60)}`;
    const html = `
      <div style="font-family:-apple-system,Segoe UI,Roboto,Arial,sans-serif;font-size:15px;line-height:1.5;color:#0f0f0f">
        <h2 style="margin:0 0 8px">${esc(kind)}</h2>
        <p style="white-space:pre-wrap;background:#f2f2f2;border-left:5px solid #c7ff2e;border-radius:10px;padding:12px 14px">${esc(r.message)}</p>
        <table style="font-size:14px;color:#5c5c5c">
          <tr><td>From</td><td>${esc(who)}</td></tr>
          <tr><td>Area</td><td>${esc(r.area ?? "—")}</td></tr>
          <tr><td>Rating</td><td>${esc(stars)}</td></tr>
          <tr><td>App</td><td>${esc(r.app_version ?? "?")} · ${esc(r.platform ?? "?")} · ${esc(r.os_version ?? "")}</td></tr>
          <tr><td>When</td><td>${esc(new Date(r.created_at).toUTCString())}</td></tr>
          <tr><td>ID</td><td>${esc(r.id)}</td></tr>
        </table>
        ${shots}
        <p style="font-size:13px;color:#808080">Stored in public.app_feedback. Update status / team_notes there.</p>
      </div>`;
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${RESEND_API_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify({ from: FROM, to: TO, subject, html }),
    });
    if (!res.ok) {
      const detail = await res.text();
      console.error("resend_failed", res.status, detail.slice(0, 300));
      // Stop here; the rest stay un-notified and go out next time.
      break;
    }
    sentIds.push(r.id);
  }

  if (sentIds.length) {
    await db.from("app_feedback").update({ notified_at: new Date().toISOString() }).in("id", sentIds);
  }
  return json(200, { sent: sentIds.length, pending: rows.length - sentIds.length, attached });
});
