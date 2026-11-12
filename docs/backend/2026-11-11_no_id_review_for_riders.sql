-- No ID review for now: parents who only need rides are approved as soon
-- as they finish "About you", so they can add their kids straight away
-- (add-kid only accepts approved / pending_review parents and answered
-- "Your ID is still being reviewed").
--
--   set_my_profile_basics("firstName", "lastName", "startNow")
--     Saves the parent's name (it used to be saved only with the ID, so
--     parents who skip the ID had no name). With startNow = true ("I need
--     rides") a not-started parent is approved on the spot. Parents who
--     offer rides still send their license, which approves them at once
--     (2026-11-11_auto_approve_and_3mi_radius.sql).
--
-- Also approves every parent stuck at "not started" right now.
-- NOTE: dev, staging and production share project cojraqxramlirnepncrd.
-- Safe to re-run.

begin;

create or replace function public.set_my_profile_basics(
  "firstName" text, "lastName" text, "startNow" boolean default false)
returns text
language plpgsql
security definer
set search_path to ''
as $fn$
declare
  v_uid   uuid := auth.uid();
  v_first text := nullif(btrim("firstName"), '');
  v_last  text := nullif(btrim("lastName"), '');
  v_out   text;
begin
  if v_uid is null then raise sqlstate 'PT401' using message = 'not_authenticated'; end if;
  if v_first is not null and char_length(v_first) > 50 then
    raise sqlstate 'PT400' using message = 'invalid_field', detail = 'firstName';
  end if;
  if v_last is not null and char_length(v_last) > 50 then
    raise sqlstate 'PT400' using message = 'invalid_field', detail = 'lastName';
  end if;

  update public.profiles p
     set first_name = coalesce(v_first, p.first_name),
         last_name  = coalesce(v_last, p.last_name),
         full_name  = coalesce(nullif(btrim(coalesce(v_first, p.first_name, '') || ' ' ||
                                            coalesce(v_last, p.last_name, '')), ''), p.full_name),
         onboarding_status = case
           when coalesce("startNow", false) and p.role::text = 'parent'
                and p.onboarding_status::text = 'not_started'
           then 'approved'::public.onboarding_status
           else p.onboarding_status end
   where p.id = v_uid
  returning p.onboarding_status::text into v_out;

  if v_out is null then raise sqlstate 'PT404' using message = 'profile_not_found'; end if;
  return v_out;
end;
$fn$;

revoke all on function public.set_my_profile_basics(text, text, boolean) from public, anon;
grant execute on function public.set_my_profile_basics(text, text, boolean) to authenticated;

-- Parents stuck at "not started" (they skipped the ID): approve them.
update public.profiles
   set onboarding_status = 'approved'
 where role::text = 'parent'
   and onboarding_status::text = 'not_started';

commit;

notify pgrst, 'reload schema';
