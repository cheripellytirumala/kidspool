-- Demo families for "Families near you" / "Say Hi" (test data only).
-- Re-seed of 2026-11-04_seed_demo_families.sql (which had been rolled back),
-- extended so every test cluster sees parents:
--   Hyderabad   (17.385, 78.4867)   – St Paul's School, Lincoln Elementary
--   San Francisco (37.76, -122.415) – Jefferson, Maple Grove, Washington High,
--                                     St Paul's School, Lincoln Elementary
--   Long Island (40.759, -73.408)   – Weldon E. Howitt, Hicksville, Wyandanch,
--                                     Milton L Olive, Lincoln Elementary
-- Hidden on purpose: Ravi K (~10.6 mi, outside radius), Sneha R (pending).
-- Demo users have no phone and no password, so nobody can sign in as them.
-- Same ids/emails as before ('de300000-…' / '@demo.kidspool.test'): remove
-- them all with 2026-11-04_rollback_demo_families.sql.
-- NOTE: dev, staging and production share project cojraqxramlirnepncrd.
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
  (8, 'Sneha',    'Rao',       'pending_review', 'not_submitted', 17.3900, 78.4800, 'Nampally',      '500001', 'Anya',  'Rao',       '2018-08-05', 'Grade 2', 'St Paul''s School',  null,   null,         null,      null),
  -- San Francisco
  (9,  'Olivia',   'Martinez',  'approved',       'approved',      37.7642, -122.4210, 'Mission',       '94110', 'Liam',  'Martinez',  '2016-04-12', 'Grade 4', 'Jefferson Elementary',   null,   null,         null,      null),
  (10, 'James',    'Chen',      'approved',       'not_submitted', 37.7580, -122.4080, 'Potrero Hill',  '94107', 'Ella',  'Chen',      '2018-09-03', 'Grade 2', 'Jefferson Elementary',   'Max',  '2019-12-01', 'Grade 1', 'Maple Grove Elementary'),
  (11, 'Hannah',   'Lee',       'approved',       'approved',      37.7700, -122.4300, 'Duboce',        '94114', 'Ryan',  'Lee',       '2017-02-17', 'Grade 3', 'Maple Grove Elementary', null,   null,         null,      null),
  (12, 'Marcus',   'Brown',     'approved',       'approved',      37.7525, -122.4180, 'Bernal Heights','94110', 'Tyler', 'Brown',     '2010-06-25', 'Grade 10','Washington High School', null,   null,         null,      null),
  (13, 'Grace',    'Kim',       'approved',       'not_submitted', 37.7490, -122.4150, 'Mission',       '94110', 'Chloe', 'Kim',       '2017-10-08', 'Grade 3', 'St Paul''s School',      'Owen', '2019-03-15', 'Grade 1', 'Lincoln Elementary'),
  (14, 'Daniel',   'Garcia',    'approved',       'approved',      37.7615, -122.4005, 'Dogpatch',      '94107', 'Mason', 'Garcia',    '2016-08-19', 'Grade 4', 'Lincoln Elementary',     null,   null,         null,      null),
  -- Long Island
  (15, 'Emily',    'Johnson',   'approved',       'approved',      40.7620, -73.4130,  'Wyandanch',     '11798', 'Ava',   'Johnson',   '2013-05-22', 'Grade 7', 'Weldon E. Howitt Middle School', null, null, null, null),
  (16, 'Michael',  'Davis',     'approved',       'not_submitted', 40.7680, -73.4020,  'Dix Hills',     '11746', 'Jack',  'Davis',     '2012-11-30', 'Grade 8', 'Hicksville Middle School',  'Lily', '2017-07-07', 'Grade 3', 'Lincoln Elementary'),
  (17, 'Sophia',   'Miller',    'approved',       'approved',      40.7540, -73.3950,  'Wheatley Hts',  '11798', 'Ethan', 'Miller',    '2009-03-04', 'Grade 11','Wyandanch Memorial High School', null, null, null, null),
  (18, 'Robert',   'Wilson',    'approved',       'approved',      40.7570, -73.4180,  'Wyandanch',     '11798', 'Nora',  'Wilson',    '2013-01-28', 'Grade 7', 'Milton L Olive Middle School',   null, null, null, null);

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
       'Home', 'Demo home, ' || area,
       case when lat between 30 and 45 and lng < -100 then 'San Francisco'
            when lng < -70 then 'Wyandanch' else 'Hyderabad' end,
       case when lng < -100 then 'CA' when lng < -70 then 'NY' else 'Telangana' end,
       zip,
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
