-- No waiting for manual review: a parent is cleared for rides as soon as
-- the app has scanned and sent their ID.
--
--   * Driver's license  → approved to ask for AND give rides
--                         (onboarding_status + driver_status = approved).
--   * Other photo ID    → approved to ask for rides (state ID, passport,
--                         green card: parents who only need rides).
--   * Every parent already waiting is approved the same way, now.
--   * Matching no longer needs a saved car: the app has no car step, so
--     a driver without one gets requests (seats / booster are only checked
--     when a car is saved).
--   * Matching radius: 1 → 3 miles (1609 m → 4828 m) from the pick-up.
--
-- The app reads the license on the device (name check) before sending;
-- the server trusts that and stops holding accounts in "pending review".
-- A "rejected" account stays rejected.
--
-- Replaces 2026-11-11_test_drivers_and_3mi_radius.sql (not needed).
-- NOTE: dev, staging and production share project cojraqxramlirnepncrd,
-- so this applies to every parent. Safe to re-run.

begin;

-- 1. New submissions are approved on the spot. --------------------------
create or replace function public.record_identity_submission(
  p_user_id uuid, p_first_name text, p_last_name text, p_id_type text,
  p_selfie_path text, p_id_front_path text, p_id_back_path text)
returns text
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_status    public.onboarding_status;
  v_is_driver boolean := p_id_type = 'drivers_license';
begin
  select p.onboarding_status into v_status
  from public.profiles p
  where p.id = p_user_id
  for update;

  if not found then
    return 'profile_not_found';
  elsif v_status = 'approved' then
    return 'already_approved';
  end if;

  insert into public.identity_verifications as iv
    (user_id, id_type, selfie_path, id_front_path, id_back_path,
     status, rejection_reason, submitted_at, reviewed_at, reviewed_by)
  values
    (p_user_id, p_id_type, p_selfie_path, p_id_front_path, p_id_back_path,
     'approved', null, now(), now(), null)
  on conflict (user_id) do update set
    id_type          = excluded.id_type,
    selfie_path      = excluded.selfie_path,
    id_front_path    = excluded.id_front_path,
    id_back_path     = excluded.id_back_path,
    status           = 'approved',
    rejection_reason = null,
    submitted_at     = now(),
    reviewed_at      = now(),
    reviewed_by      = null;

  update public.profiles p
     set onboarding_status = 'approved',
         -- A license also clears them to drive.
         driver_status     = case when v_is_driver then 'approved'::public.driver_status
                                  else p.driver_status end,
         first_name        = p_first_name,
         last_name         = p_last_name,
         full_name         = p_first_name || ' ' || p_last_name
   where p.id = p_user_id;

  return 'ok';
end;
$function$;

-- 2. Approve everyone already waiting. ----------------------------------
update public.identity_verifications iv
   set status = 'approved', reviewed_at = coalesce(iv.reviewed_at, now())
 where iv.status = 'pending';

update public.profiles p
   set onboarding_status = 'approved'
 where p.role = 'parent'
   and p.onboarding_status = 'pending_review';

update public.profiles p
   set driver_status = 'approved'
 where p.role = 'parent'
   and p.onboarding_status = 'approved'
   and p.driver_status in ('not_submitted', 'pending_review')
   and (p.driver_status = 'pending_review'
        or exists (select 1 from public.identity_verifications iv
                    where iv.user_id = p.id and iv.id_type = 'drivers_license'));

update public.driver_verifications dv
   set status = 'approved', reviewed_at = coalesce(dv.reviewed_at, now())
 where dv.status = 'pending';

-- 3. Matching: 3 miles, car optional. -----------------------------------
create or replace function public.eligible_driver_ids(
  p_uid uuid, p_location extensions.geography, p_seats integer, p_booster boolean)
returns setof uuid
language sql
stable
security definer
set search_path to ''
as $function$
  select p.id
    from public.profiles p
    join public.addresses a on a.user_id = p.id and a.is_default
    left join public.vehicles v on v.owner_id = p.id
   where p.role = 'parent'
     and p.onboarding_status = 'approved'
     and p.driver_status = 'approved'
     and p.id <> p_uid
     and extensions.st_dwithin(a.location, p_location, 4828.03)
     -- Seats / booster only when a car is saved.
     and (v.owner_id is null
          or (v.kid_seats >= p_seats and (not p_booster or v.has_booster)));
$function$;

commit;

notify pgrst, 'reload schema';

-- Check: how parents stand now.
select onboarding_status, driver_status, count(*)
  from public.profiles
 where role = 'parent'
 group by 1, 2
 order by 3 desc;
