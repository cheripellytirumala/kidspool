-- Rollback for 2026-11-04_seed_demo_families.sql.
-- Deletes only the demo auth users; profiles, addresses and kids go with
-- them through ON DELETE CASCADE. Real users are never matched.

begin;

delete from auth.users
 where id::text like 'de300000-%' or email like '%@demo.kidspool.test';

commit;
