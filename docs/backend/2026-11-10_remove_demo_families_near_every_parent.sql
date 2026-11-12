-- Removes everything 2026-11-10_demo_families_near_every_parent.sql created:
-- the triggers, the functions and every demo parent (their profiles,
-- addresses, kids, cars, ride offers/messages go with them via cascades).
-- Real parents and their data are untouched. Safe to re-run.

begin;

drop trigger if exists demo_families_on_profile on public.profiles;
drop trigger if exists demo_families_on_kid on public.kids;
drop function if exists public.demo_families_trigger();
drop function if exists public.demo_ensure_families(uuid);

delete from auth.users
 where email like '%@demo-near.kidspool.test'
   and raw_user_meta_data->>'demo' = 'true';

commit;
