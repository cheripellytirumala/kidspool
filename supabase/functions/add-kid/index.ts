// POST /functions/v1/add-kid   (multipart/form-data, login required, parents whose ID is in review or approved)
// Required: firstName, dateOfBirth (YYYY-MM-DD)
// Optional: lastName, grade, schoolId (can be set later with update-kid), schoolIdCard (file),
//           needsBooster (true/false, default false), needsCarSeat (true/false, default false),
//           gender (male/female/other), healthNotes, emergencyContactName + emergencyContactPhone, photo (file)
import { adminClient, corsHeaders, json } from "../_shared/otp.ts";
import { getAuthUser } from "../_shared/auth.ts";
import { readImage } from "../_shared/images.ts";
import {
  checkBool, checkContactName, checkDob, checkGender, checkGrade, checkName, checkNotes, checkPhone, clean, isUuid,
  KID_PHOTO_BUCKET, MAX_KIDS,
} from "../_shared/kids.ts";

// Parents can add kids as soon as their ID is submitted (in review) or approved.
const ALLOWED_ONBOARDING = ["approved", "pending_review"];

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

  const db = adminClient();

  const { data: profile } = await db.from("profiles").select("role, onboarding_status").eq("id", user.id).maybeSingle();
  if (!profile) return json(404, { error: "profile_not_found" });
  if (profile.role !== "parent") return json(403, { error: "not_a_parent" });
  if (!ALLOWED_ONBOARDING.includes(profile.onboarding_status)) return json(403, { error: "not_approved" });

  const { count } = await db.from("kids").select("id", { count: "exact", head: true }).eq("parent_id", user.id);
  if ((count ?? 0) >= MAX_KIDS) return json(409, { error: "kid_limit_reached", max: MAX_KIDS });

  // Required
  const firstName = clean(form.get("firstName")) ?? "";
  const dob = clean(form.get("dateOfBirth")) ?? "";
  if (!firstName) return json(400, { error: "missing_field", field: "firstName" });
  if (!dob) return json(400, { error: "missing_field", field: "dateOfBirth" });

  const fn = checkName(firstName, "firstName"); if (fn.error) return fn.error;
  const d = checkDob(dob); if (d.error) return d.error;

  // School: optional here, chosen later on "Where do your kids go?" (update-kid).
  const schoolId = clean(form.get("schoolId")) || null;
  if (schoolId) {
    if (!isUuid(schoolId)) return json(400, { error: "invalid_field", field: "schoolId" });
    const { data: school } = await db.from("schools").select("id, name, is_active").eq("id", schoolId).maybeSingle();
    if (!school || !school.is_active) return json(400, { error: "invalid_field", field: "schoolId" });
  }

  // Optional
  const lastName = clean(form.get("lastName")) || null;
  if (lastName) { const r = checkName(lastName, "lastName"); if (r.error) return r.error; }
  const grade = clean(form.get("grade")) || null;
  if (grade) { const r = checkGrade(grade); if (r.error) return r.error; }
  const g = checkGender(clean(form.get("gender"))); if (g.error) return g.error;
  const gender = g.value ?? null;
  const healthNotes = clean(form.get("healthNotes")) || null;
  if (healthNotes) { const r = checkNotes(healthNotes); if (r.error) return r.error; }
  const nb = checkBool(clean(form.get("needsBooster")), "needsBooster"); if (nb.error) return nb.error;
  const needsBooster = nb.value ?? false;
  const nc = checkBool(clean(form.get("needsCarSeat")), "needsCarSeat"); if (nc.error) return nc.error;
  const needsCarSeat = nc.value ?? false;

  const ecName = clean(form.get("emergencyContactName")) || null;
  const ecPhoneRaw = clean(form.get("emergencyContactPhone")) || null;
  let ecPhone: string | null = null;
  if (!!ecName !== !!ecPhoneRaw) {
    return json(400, { error: "missing_field", field: ecName ? "emergencyContactPhone" : "emergencyContactName" });
  }
  if (ecName) { const r = checkContactName(ecName); if (r.error) return r.error; }
  if (ecPhoneRaw) { const r = checkPhone(ecPhoneRaw); if (r.error) return r.error; ecPhone = r.value!; }

  const photo = await readImage(form, "photo", false);
  if (photo.error) return photo.error;
  const idCard = await readImage(form, "schoolIdCard", false);
  if (idCard.error) return idCard.error;

  const { data: kid, error: insErr } = await db.from("kids").insert({
    parent_id: user.id,
    first_name: firstName,
    last_name: lastName,
    date_of_birth: dob,
    grade,
    gender,
    school_id: schoolId,
    health_notes: healthNotes,
    needs_booster: needsBooster,
    needs_car_seat: needsCarSeat,
    emergency_contact_name: ecName,
    emergency_contact_phone: ecPhone,
  }).select("id").single();
  if (insErr || !kid) return json(500, { error: "save_failed" });

  const bucket = db.storage.from(KID_PHOTO_BUCKET);
  const uploaded: string[] = [];
  const fail = async (field: string) => {
    if (uploaded.length) await bucket.remove(uploaded);
    await db.from("kids").delete().eq("id", kid.id);
    return json(500, { error: "upload_failed", field });
  };

  // School ID card (optional)
  let idCardPath: string | null = null;
  if (idCard.file) {
    idCardPath = `${user.id}/${kid.id}_school_id.${idCard.file.kind.ext}`;
    const { error } = await bucket.upload(idCardPath, idCard.file.bytes, { contentType: idCard.file.kind.mime, upsert: true });
    if (error) return await fail("schoolIdCard");
    uploaded.push(idCardPath);
  }

  // Photo (optional)
  let photoPath: string | null = null;
  if (photo.file) {
    photoPath = `${user.id}/${kid.id}.${photo.file.kind.ext}`;
    const { error } = await bucket.upload(photoPath, photo.file.bytes, { contentType: photo.file.kind.mime, upsert: true });
    if (error) return await fail("photo");
    uploaded.push(photoPath);
  }

  if (photoPath || idCardPath) {
    const { error: pathErr } = await db.from("kids")
      .update({ photo_path: photoPath, school_id_card_path: idCardPath }).eq("id", kid.id);
    if (pathErr) return await fail(photoPath ? "photo" : "schoolIdCard");
  }

  return json(200, { status: "saved", kidId: kid.id, needsBooster, needsCarSeat, photoPath, schoolIdCardPath: idCardPath });
});
