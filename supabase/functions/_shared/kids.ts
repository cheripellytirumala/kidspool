// Shared validation for add-kid / update-kid
import { json } from "./otp.ts";

export const KID_PHOTO_BUCKET = "kid-photos";
export const MAX_KIDS = 10;

const NAME_RE = /^[\p{L}][\p{L} .'-]{0,49}$/u;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const PHONE_RE = /^\+\d{8,15}$/;

export const isUuid = (v: string) => UUID_RE.test(v);

export const clean = (v: FormDataEntryValue | null) =>
  v === null ? null : String(v).trim().replace(/\s+/g, " ");

type Result<T> = { value?: T; error?: Response };
const bad = (field: string, error = "invalid_field", message?: string) =>
  ({ error: json(400, { error, field, ...(message ? { message } : {}) }) });

export const checkName = (v: string, field: string): Result<string> =>
  NAME_RE.test(v) ? { value: v } : bad(field);

export const checkDob = (v: string): Result<string> => {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(v)) return bad("dateOfBirth", "invalid_field", "YYYY-MM-DD");
  const d = new Date(v + "T00:00:00Z");
  if (isNaN(d.getTime()) || d.toISOString().slice(0, 10) !== v) return bad("dateOfBirth");
  const now = new Date();
  if (d > now) return bad("dateOfBirth", "invalid_field", "date is in the future");
  const minDate = new Date(Date.UTC(now.getUTCFullYear() - 19, now.getUTCMonth(), now.getUTCDate()));
  if (d < minDate) return bad("dateOfBirth", "invalid_field", "child must be under 19");
  return { value: v };
};

export const checkGrade = (v: string): Result<string> =>
  v.length <= 20 ? { value: v } : bad("grade");

export const checkNotes = (v: string): Result<string> =>
  v.length <= 500 ? { value: v } : bad("healthNotes", "invalid_field", "max 500 characters");

export const checkContactName = (v: string): Result<string> =>
  v.length <= 80 ? { value: v } : bad("emergencyContactName");

export const checkPhone = (v: string): Result<string> => {
  const p = v.replace(/[\s\-()]/g, "");
  return PHONE_RE.test(p) ? { value: p } : bad("emergencyContactPhone", "invalid_field", "use +<country><number>");
};

// "true"/"false" (also 1/0, yes/no). Empty = not sent.
export const checkBool = (v: string | null, field: string): Result<boolean | null> => {
  if (v === null || v === "") return { value: null };
  const t = v.toLowerCase();
  if (["true", "1", "yes"].includes(t)) return { value: true };
  if (["false", "0", "no"].includes(t)) return { value: false };
  return bad(field, "invalid_field", "true or false");
};
