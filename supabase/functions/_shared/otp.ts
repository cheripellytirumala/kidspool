// Shared helpers for request-otp and verify-otp
import { createClient } from "npm:@supabase/supabase-js@2";

export const OTP_LENGTH = 6;
export const OTP_TTL_SECONDS = 300;        // 5 minutes
export const RESEND_AFTER_SECONDS = 30;    // must match the app's resend timer
export const MAX_WRONG_ATTEMPTS = 5;

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

export const isDemoMode = () =>
  (Deno.env.get("OTP_DEMO_MODE") ?? "false").toLowerCase() === "true";

// Admin client: bypasses RLS. Never exposed to the app.
export const adminClient = () =>
  createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

// Public client: used only to sign the user in and get a normal session.
export const publicClient = () =>
  createClient(SUPABASE_URL, ANON_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export const json = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

// Allowed countries: US (+1, 10 digits) and India (+91, 10 digits starting 6-9)
const PHONE_RULES: RegExp[] = [
  /^\+1\d{10}$/,
  /^\+91[6-9]\d{9}$/,
];

export const normalizePhone = (value: unknown): string | null => {
  if (typeof value !== "string") return null;
  const phone = value.replace(/[\s\-()]/g, "");
  return PHONE_RULES.some((re) => re.test(phone)) ? phone : null;
};

export const generateOtp = (): string => {
  // Unbiased 6-digit code from a secure random source
  const max = 10 ** OTP_LENGTH;
  const limit = Math.floor(0xffffffff / max) * max;
  const buf = new Uint32Array(1);
  do {
    crypto.getRandomValues(buf);
  } while (buf[0] >= limit);
  return (buf[0] % max).toString().padStart(OTP_LENGTH, "0");
};

// HMAC-SHA256 of phone + code, keyed with the service role key
export const hashOtp = async (phone: string, otp: string): Promise<string> => {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(SERVICE_ROLE_KEY),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(`${phone}:${otp}`));
  return Array.from(new Uint8Array(sig)).map((b) => b.toString(16).padStart(2, "0")).join("");
};

export const safeEqual = (a: string, b: string): boolean => {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
};

export const randomPassword = (): string => {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return btoa(String.fromCharCode(...bytes)).replace(/[+/=]/g, "").slice(0, 40) + "Aa1!";
};

// Placeholder for the real SMS sender (MSG91 / Twilio …) — configured later.
// Returns false when no sender is configured.
export const sendSms = async (_phone: string, _otp: string): Promise<boolean> => {
  return false;
};
