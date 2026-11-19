// POST /functions/v1/save-vehicle   multipart/form-data, login required
//
// "Your vehicle" (sign-up after the driver's license, and Profile):
//   model        "Honda Odyssey"            required, ≤ 50
//   year         2021                        optional, 1980 … next year
//   color        "White"                     optional, ≤ 20
//   plateNumber  "7KDP 392"                  required, 2–12 letters/digits
//   carSeats     5                           all seats incl. the driver, 2–9
//   kidSeats     3                           seats free for kids, 1 … carSeats−1
//   boosterSeat  true / false
//   vehiclePhoto JPEG / PNG ≤ 1 MB           optional (keeps the saved one)
// Saves one car per parent (public.vehicles) and returns it.
import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const BUCKET = "driver-documents";
const MAX_BYTES = 1024 * 1024;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

const kindOf = (b: Uint8Array) =>
  b.length > 3 && b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff
    ? { mime: "image/jpeg", ext: "jpg" }
    : b.length > 8 && b[0] === 0x89 && b[1] === 0x50 && b[2] === 0x4e && b[3] === 0x47
    ? { mime: "image/png", ext: "png" }
    : null;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  const header = req.headers.get("Authorization") ?? "";
  const token = header.startsWith("Bearer ") ? header.slice(7).trim() : "";
  if (!token) return json(401, { error: "not_authenticated" });
  const db = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: auth, error: authError } = await db.auth.getUser(token);
  if (authError || !auth.user) return json(401, { error: "not_authenticated" });
  const uid = auth.user.id;

  let form: FormData;
  try {
    form = await req.formData();
  } catch {
    return json(400, { error: "invalid_body" });
  }
  const text = (k: string) => String(form.get(k) ?? "").trim().replace(/\s+/g, " ");

  const model = text("model");
  const color = text("color");
  const plate = text("plateNumber").toUpperCase();
  const yearRaw = text("year");
  const carSeats = Number(text("carSeats"));
  const kidSeats = Number(text("kidSeats"));
  const booster = ["true", "1"].includes(text("boosterSeat").toLowerCase());

  if (!model) return json(400, { error: "missing_field", field: "model" });
  if (model.length > 50) return json(400, { error: "invalid_field", field: "model" });
  if (color.length > 20) return json(400, { error: "invalid_field", field: "color" });
  if (!/^[A-Z0-9 -]{2,12}$/.test(plate)) return json(400, { error: "invalid_field", field: "plateNumber" });
  let year: number | null = null;
  if (yearRaw) {
    year = Number(yearRaw);
    const max = new Date().getFullYear() + 1;
    if (!Number.isInteger(year) || year < 1980 || year > max) {
      return json(400, { error: "invalid_field", field: "year" });
    }
  }
  if (!Number.isInteger(carSeats) || carSeats < 2 || carSeats > 9) {
    return json(400, { error: "invalid_field", field: "carSeats" });
  }
  if (!Number.isInteger(kidSeats) || kidSeats < 1 || kidSeats > carSeats - 1 || kidSeats > 8) {
    return json(400, { error: "invalid_field", field: "kidSeats" });
  }

  // Optional photo: replaces the saved one.
  let photoPath: string | undefined;
  const photo = form.get("vehiclePhoto");
  if (photo instanceof File && photo.size > 0) {
    if (photo.size > MAX_BYTES) return json(413, { error: "file_too_large", field: "vehiclePhoto" });
    const bytes = new Uint8Array(await photo.arrayBuffer());
    const kind = kindOf(bytes);
    if (!kind) return json(400, { error: "invalid_file_type", field: "vehiclePhoto" });
    photoPath = `${uid}/vehiclePhoto.${kind.ext}`;
    const { error } = await db.storage.from(BUCKET).upload(photoPath, bytes, {
      contentType: kind.mime,
      upsert: true,
    });
    if (error) return json(500, { error: "upload_failed", field: "vehiclePhoto" });
  }

  const row: Record<string, unknown> = {
    owner_id: uid,
    model,
    color: color || null,
    year,
    plate_number: plate,
    car_seats: carSeats,
    kid_seats: kidSeats,
    has_booster: booster,
    updated_at: new Date().toISOString(),
  };
  if (photoPath) row.photo_path = photoPath;
  const { data, error } = await db.from("vehicles")
    .upsert(row, { onConflict: "owner_id" })
    .select("model, color, year, plate_number, car_seats, kid_seats, has_booster, photo_path")
    .single();
  if (error) return json(500, { error: "save_failed" });

  return json(200, {
    model: data.model,
    color: data.color,
    year: data.year,
    plateNumber: data.plate_number,
    carSeats: data.car_seats,
    kidSeats: data.kid_seats,
    hasBooster: data.has_booster,
    hasPhoto: !!data.photo_path,
  });
});
