// Resolve the logged-in user from the Authorization header.
import { adminClient } from "./otp.ts";

export const getAuthUser = async (req: Request) => {
  const header = req.headers.get("Authorization") ?? "";
  const token = header.startsWith("Bearer ") ? header.slice(7).trim() : "";
  if (!token) return null;
  const { data, error } = await adminClient().auth.getUser(token);
  if (error || !data.user) return null;
  return data.user;
};
