// Shared image checks: max 1 MB, JPEG / PNG by real file content
import { json } from "./otp.ts";

export const MAX_IMAGE_BYTES = 1024 * 1024;

export type ImageKind = { mime: "image/jpeg" | "image/png"; ext: "jpg" | "png" };
export type CheckedImage = { field: string; bytes: Uint8Array; kind: ImageKind };

export const detectImage = (bytes: Uint8Array): ImageKind | null => {
  if (bytes.length > 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) {
    return { mime: "image/jpeg", ext: "jpg" };
  }
  if (
    bytes.length > 8 && bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e &&
    bytes[3] === 0x47 && bytes[4] === 0x0d && bytes[5] === 0x0a && bytes[6] === 0x1a && bytes[7] === 0x0a
  ) {
    return { mime: "image/png", ext: "png" };
  }
  return null;
};

export const readImage = async (
  form: FormData,
  field: string,
  required: boolean,
): Promise<{ error?: Response; file?: CheckedImage | null }> => {
  const value = form.get(field);
  if (value === null || value === "") {
    return required ? { error: json(400, { error: "missing_field", field }) } : { file: null };
  }
  if (!(value instanceof File)) return { error: json(400, { error: "invalid_file_type", field }) };
  if (value.size > MAX_IMAGE_BYTES) {
    return { error: json(413, { error: "file_too_large", field, maxBytes: MAX_IMAGE_BYTES }) };
  }
  const bytes = new Uint8Array(await value.arrayBuffer());
  if (bytes.length === 0) return { error: json(400, { error: "missing_field", field }) };
  const kind = detectImage(bytes);
  if (!kind) return { error: json(400, { error: "invalid_file_type", field }) };
  return { file: { field, bytes, kind } };
};
