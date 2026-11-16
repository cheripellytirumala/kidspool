// POST /functions/v1/delete-account   body: {}   login required
//
// Permanently deletes the signed-in user's account (App Store 5.1.1(v),
// Google Play account deletion):
//   1. refuses while one of their rides is under way (started, not done);
//   2. removes their files: everything under "<user id>/" in the
//      identity-documents, driver-documents, kid-photos and
//      feedback-attachments buckets;
//   3. deletes the auth user. That cascades to profiles and everything
//      linked to it (kids, addresses, rides they asked for, chats, groups
//      membership, tokens …). Group messages they sent stay without a
//      sender; rides they drove keep the record with no driver.
// Reports about them (user_reports) are kept for safety reviews.
//
// Deploy: supabase functions deploy delete-account --no-verify-jwt
// (the user is checked from the Authorization header below).
import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const BUCKETS = ["identity-documents", "driver-documents", "kid-photos", "feedback-attachments"];

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

const admin = () =>
  createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

/** Every file path under `prefix/` in a bucket (folders walked). */
async function listAll(
  db: ReturnType<typeof admin>,
  bucket: string,
  prefix: string,
): Promise<string[]> {
  const out: string[] = [];
  const queue = [prefix];
  while (queue.length) {
    const dir = queue.shift()!;
    for (let offset = 0; ; offset += 100) {
      const { data, error } = await db.storage.from(bucket).list(dir, { limit: 100, offset });
      if (error || !data?.length) break;
      for (const item of data) {
        const path = `${dir}/${item.name}`;
        // Folders have no id.
        if (item.id) out.push(path);
        else queue.push(path);
      }
      if (data.length < 100) break;
    }
  }
  return out;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  const header = req.headers.get("Authorization") ?? "";
  const token = header.startsWith("Bearer ") ? header.slice(7).trim() : "";
  if (!token) return json(401, { error: "not_authenticated" });

  const db = admin();
  const { data: auth, error: authError } = await db.auth.getUser(token);
  if (authError || !auth.user) return json(401, { error: "not_authenticated" });
  const uid = auth.user.id;

  // 1. Not in the middle of a ride.
  const { count, error: rideError } = await db
    .from("ride_requests")
    .select("id", { count: "exact", head: true })
    .or(`parent_id.eq.${uid},driver_id.eq.${uid}`)
    .not("started_at", "is", null)
    .is("completed_at", null)
    .is("cancelled_at", null);
  if (rideError) return json(500, { error: "check_failed" });
  if ((count ?? 0) > 0) {
    return json(409, {
      error: "ride_in_progress",
      message: "Finish or cancel your ride in progress before deleting your account.",
    });
  }

  // 2. Files.
  for (const bucket of BUCKETS) {
    const files = await listAll(db, bucket, uid);
    for (let i = 0; i < files.length; i += 100) {
      const { error } = await db.storage.from(bucket).remove(files.slice(i, i + 100));
      if (error) return json(500, { error: "files_not_deleted", bucket });
    }
  }

  // 3. The account (cascades through public.profiles).
  const { error } = await db.auth.admin.deleteUser(uid);
  if (error) return json(500, { error: "delete_failed" });

  return json(200, { status: "deleted" });
});
