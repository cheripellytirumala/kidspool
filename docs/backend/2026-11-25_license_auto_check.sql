-- Server switch for the app's automatic driving-licence checks (V3 "Is
-- this you?" screen): name read from the photo, not expired, 18+, and the
-- typed first or last name on the licence.
--
--   app_settings.license_auto_check = 1  → checks on (default; as before)
--   app_settings.license_auto_check = 0  → checks off: the app shows what
--                                          it read, never blocks Continue
--
-- Change it in Supabase → Table Editor → app_settings. Apps pick it up the
-- next time the licence screen opens. Either way a person on the review
-- team still checks every licence before a driver is approved.
--
-- get_app_flags() → {licenseAutoCheck: bool}: the flags the app may read
-- (app_settings itself stays closed to app users). Idempotent.

insert into public.app_settings (key, value, description)
values ('license_auto_check', 1,
        '1 = the app checks the driving licence (name, expiry, 18+) before '
        'it can be sent; 0 = no automatic checks, review team only.')
on conflict (key) do nothing;

create or replace function public.get_app_flags()
returns jsonb
language sql
stable
security definer
set search_path to ''
as $$
  select jsonb_build_object(
    'licenseAutoCheck',
    coalesce((select s.value from public.app_settings s
               where s.key = 'license_auto_check'), 1) >= 1
  );
$$;

revoke all on function public.get_app_flags() from public, anon;
grant execute on function public.get_app_flags() to authenticated, service_role;

-- 2026-11-25: switched off on request (review team checks only). Not part
-- of re-running this file; set it in app_settings to change it again:
--   update public.app_settings set value = 0 where key = 'license_auto_check';
