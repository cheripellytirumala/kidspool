-- Demo families for "Families near you" (test data only).
-- Adds 8 parents around Hyderabad whose kids go to St Paul's School or
-- Lincoln Elementary, so the test parent (home 17.385, 78.4867) sees results:
--   6 should appear (approved, within 10 mi, nearest first)
--   Ravi K  – hidden: ~10.6 mi away, outside the default radius
--   Sneha R – hidden: onboarding still pending_review
-- Demo users have no phone and no password, so nobody can sign in as them.
-- Every demo row hangs off auth.users ids 'de300000-…' / emails
-- '@demo.kidspool.test'; remove them all with
-- 2026-11-04_rollback_demo_families.sql.
-- NOTE: dev, staging and production builds all point at the same Supabase
-- project (cojraqxramlirnepncrd), so this data is visible in every build
-- until rolled back.
-- Safe to re-run: existing demo users are removed first.

begin;

delete from auth.users
 where id::text like 'de300000-%' or email like '%@demo.kidspool.test';

create temp table demo_family (
  n int, first_name text, last_name text, onboarding text, driver text,
  lat double precision, lng double precision, area text, zip text,
  kid text, kid_last text, dob date, grade text, school text,
  kid2 text, dob2 date, grade2 text, school2 text
) on commit drop;

insert into demo_family values
  (1, 'Priya',    'Sharma',    'approved',       'approved',      17.3950, 78.4930, 'Himayatnagar',  '500029', 'Aarav', 'Sharma',    '2017-03-14', 'Grade 3', 'St Paul''s School',  null,   null,         null,      null),
  (2, 'Jennifer', 'Thomas',    'approved',       'approved',      17.4060, 78.4770, 'Lakdikapul',    '500004', 'Emma',  'Thomas',    '2016-07-02', 'Grade 4', 'St Paul''s School',  'Noah', '2019-01-20', 'Grade 1', 'Lincoln Elementary'),
  (3, 'Arjun',    'Reddy',     'approved',       'not_submitted', 17.3720, 78.5050, 'Amberpet',      '500013', 'Diya',  'Reddy',     '2018-05-09', 'Grade 2', 'Lincoln Elementary', null,   null,         null,      null),
  (4, 'Maria',    'Fernandes', 'approved',       'approved',      17.4239, 78.4483, 'Banjara Hills', '500034', 'Lucas', 'Fernandes', '2016-11-23', 'Grade 4', 'St Paul''s School',  null,   null,         null,      null),
  (5, 'David',    'Wilson',    'approved',       'approved',      17.3616, 78.4747, 'Charminar',     '500002', 'Sophie','Wilson',    '2017-09-30', 'Grade 3', 'Lincoln Elementary', null,   null,         null,      null),
  (6, 'Fatima',   'Khan',      'approved',       'pending_review',17.4400, 78.4983, 'Secunderabad',  '500003', 'Zara',  'Khan',      '2018-02-11', 'Grade 2', 'St Paul''s School',  null,   null,         null,      null),
  (7, 'Ravi',     'Kumar',     'approved',       'approved',      17.2400, 78.4300, 'Shamshabad',    '501218', 'Kiran', 'Kumar',     '2017-06-18', 'Grade 3', 'St Paul''s School',  null,   null,         null,      null),
  (8, 'Sneha',    'Rao',       'pending_review', 'not_submitted', 17.3900, 78.4800, 'Nampally',      '500001', 'Anya',  'Rao',       '2018-08-05', 'Grade 2', 'St Paul''s School',  null,   null,         null,      null);

-- auth user → handle_new_user() creates the profile row
insert into auth.users (instance_id, id, aud, role, email, raw_app_meta_data,
                        raw_user_meta_data, created_at, updated_at)
select '00000000-0000-0000-0000-000000000000',
       ('de300000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid,
       'authenticated', 'authenticated',
       'family' || lpad(n::text, 2, '0') || '@demo.kidspool.test',
       jsonb_build_object('provider', 'email', 'providers', jsonb_build_array('email'), 'demo', true),
       jsonb_build_object('demo', true),
       now(), now()
  from demo_family;

update public.profiles p
   set first_name        = d.first_name,
       last_name         = d.last_name,
       full_name         = d.first_name || ' ' || d.last_name,
       role              = 'parent',
       onboarding_status = d.onboarding::public.onboarding_status,
       driver_status     = d.driver::public.driver_status
  from demo_family d
 where p.id = ('de300000-0000-4000-8000-' || lpad(d.n::text, 12, '0'))::uuid;

insert into public.addresses (user_id, label, address_line1, city, state, zip, location, is_default)
select ('de300000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid,
       'Home', 'Demo home, ' || area, 'Hyderabad', 'Telangana', zip,
       extensions.st_setsrid(extensions.st_makepoint(lng, lat), 4326)::extensions.geography,
       true
  from demo_family;

insert into public.kids (parent_id, first_name, last_name, date_of_birth, grade, school_id)
select ('de300000-0000-4000-8000-' || lpad(d.n::text, 12, '0'))::uuid,
       k.first_name, d.kid_last, k.dob, k.grade,
       (select s.id from public.schools s where s.name = k.school order by s.created_at limit 1)
  from demo_family d
 cross join lateral (values (d.kid, d.dob, d.grade, d.school),
                            (d.kid2, d.dob2, d.grade2, d.school2))
       as k(first_name, dob, grade, school)
 where k.first_name is not null;

commit;
