// POST /functions/v1/update-kid   (multipart/form-data, login required)
// Required: kidId. Send only the fields you want to change.
// needsBooster=true/false changes the booster flag; needsCarSeat=true/false the car seat flag.
// gender=male/female/other sets the gender (empty clears it).
// To clear an optional field send it empty (lastName, grade, healthNotes,
// emergencyContactName + emergencyContactPhone). removePhoto=true deletes the photo.
// schoolIdCard (file) replaces the school ID card photo (it cannot be removed).
import { adminClient, corsHeaders, json } from "../_shared/otp.ts";
import { getAuthUser } from "../_shared/auth.ts";
import { readImage } from "../_shared/images.ts";
import {
  checkBool, checkContactName, checkDob, checkGender, checkGrade, checkName, checkNotes, checkPhone, clean, isUuid,
  KID_PHOTO_BUCKET,
} from "../_shared/kids.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  const user = await getAuthUser(req);
  if (!user) return json(401, { error: "not_authenticated" });

  let form: FormData;
  try {
    form = await req.formData();
  } catch {
    return json(400, { error: "invalid_body", message: "Send multipart/form-data" });
  }

  const kidId = clean(form.get("kidId")) ?? "";
  if (!kidId) return json(400, { error: "missing_field", field: "kidId" });
  if (!isUuid(kidId)) return json(400, { error: "invalid_field", field: "kidId" });

  const db = adminClient();
  const { data: kid } = await db.from("kids")
    .select("id, photo_path, school_id_card_path, emergency_contact_name, emergency_contact_phone")
    .eq("id", kidId).eq("parent_id", user.id).maybeSingle();
  if (!kid) return json(404, { error: "kid_not_found" });

  const updates: Record<string, unknown> = {};
  const has = (f: string) => form.has(f);

  if (has("firstName")) {
    const v = clean(form.get("firstName")) ?? "";
    if (!v) return json(400, { error: "missing_field", field: "firstName" });
    const r = checkName(v, "firstName"); if (r.error) return r.error;
    updates.first_name = v;
  }
  if (has("lastName")) {
    const v = clean(form.get("lastName")) || null;
    if (v) { const r = checkName(v, "lastName"); if (r.error) return r.error; }
    updates.last_name = v;
  }
  if (has("dateOfBirth")) {
    const v = clean(form.get("dateOfBirth")) ?? "";
    const r = checkDob(v); if (r.error) return r.error;
    updates.date_of_birth = v;
  }
  if (has("grade")) {
    const v = clean(form.get("grade")) || null;
    if (v) { const r = checkGrade(v); if (r.error) return r.error; }
    updates.grade = v;
  }
  if (has("schoolId")) {
    const v = clean(form.get("schoolId")) ?? "";
    if (!isUuid(v)) return json(400, { error: "invalid_field", field: "schoolId" });
    const { data: school } = await db.from("schools").select("is_active").eq("id", v).maybeSingle();
    if (!school || !school.is_active) return json(400, { error: "invalid_field", field: "schoolId" });
    updates.school_id = v;
  }
  if (has("gender")) {
    const r = checkGender(clean(form.get("gender"))); if (r.error) return r.error;
    updates.gender = r.value ?? null;
  }
  if (has("healthNotes")) {
    const v = clean(form.get("healthNotes")) || null;
    if (v) { const r = checkNotes(v); if (r.error) return r.error; }
    updates.health_notes = v;
  }
  if (has("needsBooster")) {
    const r = checkBool(clean(form.get("needsBooster")), "needsBooster"); if (r.error) return r.error;
    if (r.value === null) return json(400, { error: "invalid_field", field: "needsBooster", message: "true or false" });
    updates.needs_booster = r.value;
  }
  if (has("needsCarSeat")) {
    const r = checkBool(clean(form.get("needsCarSeat")), "needsCarSeat"); if (r.error) return r.error;
    if (r.value === null) return json(400, { error: "invalid_field", field: "needsCarSeat", message: "true or false" });
    updates.needs_car_seat = r.value;
  }
  if (has("emergencyContactName") || has("emergencyContactPhone")) {
    const name = has("emergencyContactName") ? (clean(form.get("emergencyContactName")) || null) : kid.emergency_contact_name;
    const phoneRaw = has("emergencyContactPhone") ? (clean(form.get("emergencyContactPhone")) || null) : kid.emergency_contact_phone;
    if (!!name !== !!phoneRaw) {
      return json(400, { error: "missing_field", field: name ? "emergencyContactPhone" : "emergencyContactName" });
    }
    let phone: string | null = null;
    if (name) { const r = checkContactName(name); if (r.error) return r.error; }
    if (phoneRaw) { const r = checkPhone(phoneRaw); if (r.error) return r.error; phone = r.value!; }
    updates.emergency_contact_name = name;
    updates.emergency_contact_phone = phone;
  }

  const removePhoto = (clean(form.get("removePhoto")) ?? "").toLowerCase() === "true";
  const photo = await readImage(form, "photo", false);
  if (photo.error) return photo.error;

  const bucket = db.storage.from(KID_PHOTO_BUCKET);
  if (photo.file) {
    const newPath = `${user.id}/${kid.id}.${photo.file.kind.ext}`;
    const { error } = await bucket.upload(newPath, photo.file.bytes, { contentType: photo.file.kind.mime, upsert: true });
    if (error) return json(500, { error: "upload_failed", field: "photo" });
    if (kid.photo_path && kid.photo_path !== newPath) await bucket.remove([kid.photo_path]);
    updates.photo_path = newPath;
  } else if (removePhoto && kid.photo_path) {
    await bucket.remove([kid.photo_path]);
    updates.photo_path = null;
  }

  const idCard = await readImage(form, "schoolIdCard", false);
  if (idCard.error) return idCard.error;
  if (idCard.file) {
    const newPath = `${user.id}/${kid.id}_school_id.${idCard.file.kind.ext}`;
    const { error } = await bucket.upload(newPath, idCard.file.bytes, { contentType: idCard.file.kind.mime, upsert: true });
    if (error) return json(500, { error: "upload_failed", field: "schoolIdCard" });
    if (kid.school_id_card_path && kid.school_id_card_path !== newPath) await bucket.remove([kid.school_id_card_path]);
    updates.school_id_card_path = newPath;
  }

  if (Object.keys(updates).length === 0) return json(400, { error: "nothing_to_update" });

  const { error } = await db.from("kids").update(updates).eq("id", kid.id);
  if (error) return json(500, { error: "save_failed" });

  return json(200, { status: "updated", kidId: kid.id });
});
