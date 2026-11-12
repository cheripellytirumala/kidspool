-- S19 / S20 push: device tokens for Firebase Cloud Messaging.
--
-- The app (lib/notifications/core/services/ride_notifications.dart) calls
--   register_push_token(token, platform)   on Home, and when FCM rotates it
--   unregister_push_token(token)           on sign-out
-- The `send-ride-push` Edge Function (supabase/functions/send-ride-push),
-- triggered by a Database Webhook on ride_requests UPDATE, reads the parent's
-- tokens with the service role and deletes the ones FCM reports as invalid.
--
-- No client grants on the table: it is only reachable through the two
-- SECURITY DEFINER functions below, which act on auth.uid() only.
-- A token belongs to one user at a time: registering it again (another
-- account signed in on the same phone) moves it to the caller.
--
-- Safe to re-run. Apply in Supabase → SQL editor, project cojraqxramlirnepncrd.
-- Setup steps: docs/backend/2026-11-10_push_setup.md.

begin;

create table if not exists public.push_tokens (
  token      text primary key check (char_length(token) between 1 and 4096),
  user_id    uuid not null references public.profiles (id) on delete cascade,
  platform   text not null check (platform in ('ios', 'android')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists push_tokens_user_id_idx on public.push_tokens (user_id);

alter table public.push_tokens enable row level security;

-- No policies and no grants: clients can't read or write rows directly.
revoke all on public.push_tokens from public, anon, authenticated;

-- register_push_token(token, platform): upsert this device's token for the
-- caller (reassigning it if another account had it).
create or replace function public.register_push_token(token text, platform text)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $fn$
#variable_conflict use_column
declare
  v_uid      uuid := auth.uid();
  v_token    text := nullif(btrim(register_push_token.token), '');
  v_platform text := lower(btrim(coalesce(register_push_token.platform, '')));
begin
  if v_uid is null then raise sqlstate 'PT401' using message = 'not_authenticated'; end if;
  if v_token is null then raise sqlstate 'PT400' using message = 'invalid_token'; end if;
  if v_platform not in ('ios', 'android') then
    raise sqlstate 'PT400' using message = 'invalid_platform';
  end if;

  insert into public.push_tokens as pt (token, user_id, platform)
  values (v_token, v_uid, v_platform)
  on conflict (token) do update
     set user_id    = excluded.user_id,
         platform   = excluded.platform,
         updated_at = now();
end;
$fn$;

-- unregister_push_token(token): forget this device's token (sign-out).
-- Deletes only the caller's own row; unknown tokens are a no-op.
create or replace function public.unregister_push_token(token text)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $fn$
#variable_conflict use_column
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then raise sqlstate 'PT401' using message = 'not_authenticated'; end if;

  delete from public.push_tokens pt
   where pt.token = unregister_push_token.token
     and pt.user_id = v_uid;
end;
$fn$;

revoke all on function public.register_push_token(text, text) from public, anon;
revoke all on function public.unregister_push_token(text) from public, anon;
grant execute on function public.register_push_token(text, text) to authenticated;
grant execute on function public.unregister_push_token(text) to authenticated;

commit;

notify pgrst, 'reload schema';
