-- DEMO ONLY: every verified parent sees 5 families near them.
--
-- For each parent whose ID was sent or approved and who has a kid with a
-- school, this creates up to 5 demo families:
--   * a kid at one of that parent's kids' schools (so "Families near you"
--     lists them),
--   * a home 0.3–0.7 mi from the parent's default home,
--   * approved ID + approved driver + a car (so the parent's ride requests
--     reach them and "Say Hi" messages are delivered into ride chats).
-- Demo parents have no phone or password: nobody can sign in as them.
--
-- New parents get theirs automatically (triggers on profiles / kids).
-- Everything is tagged: email `…@demo-near.kidspool.test`,
-- raw_user_meta_data.demo_for = <parent id>.
-- Remove it all with 2026-11-10_remove_demo_families_near_every_parent.sql.
--
-- NOTE: dev, staging and production share project cojraqxramlirnepncrd.
-- Safe to re-run.

create or replace function public.demo_ensure_families(p_uid uuid)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_home      extensions.geography;
  v_lat       double precision;
  v_lng       double precision;
  v_schools   uuid[];
  v_have      int;
  v_made      int := 0;
  v_id        uuid;
  i           int;
  -- first, last, kid, grade, d_lat, d_lng (degrees from the parent's home)
  v_people constant text[][] := array[
    array['Olivia', 'Bennett', 'Ella',  'Grade 2', '0.0040',  '0.0020'],
    array['Ethan',  'Carter',  'Leo',   'Grade 3', '-0.0050', '0.0030'],
    array['Mia',    'Foster',  'Ava',   'Grade 1', '0.0030',  '-0.0060'],
    array['Noah',   'Hayes',   'Zoe',   'Grade 4', '-0.0070', '-0.0040'],
    array['Sofia',  'Patel',   'Aryan', 'Grade 2', '0.0080',  '0.0060']
  ];
begin
  -- Only real parents whose ID was sent or approved.
  if p_uid is null
     or exists (select 1 from auth.users u
                 where u.id = p_uid and coalesce(u.raw_user_meta_data->>'demo', '') = 'true')
     or not exists (select 1 from public.profiles p
                     where p.id = p_uid and p.role::text = 'parent'
                       and p.onboarding_status::text in ('approved', 'pending_review')) then
    return 0;
  end if;

  select a.location into v_home
    from public.addresses a where a.user_id = p_uid and a.is_default;
  if v_home is null then return 0; end if;
  v_lat := extensions.st_y(v_home::extensions.geometry);
  v_lng := extensions.st_x(v_home::extensions.geometry);

  select array_agg(distinct k.school_id) into v_schools
    from public.kids k where k.parent_id = p_uid and k.school_id is not null;
  if v_schools is null or cardinality(v_schools) = 0 then return 0; end if;

  select count(*) into v_have
    from auth.users u where u.raw_user_meta_data->>'demo_for' = p_uid::text;

  for i in (v_have + 1) .. 5 loop
    v_id := gen_random_uuid();

    -- auth user → handle_new_user() creates the profile row
    insert into auth.users (instance_id, id, aud, role, email,
                            raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values ('00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated',
            'family-' || p_uid::text || '-' || i || '@demo-near.kidspool.test',
            jsonb_build_object('provider', 'email', 'providers', jsonb_build_array('email'), 'demo', true),
            jsonb_build_object('demo', true, 'demo_for', p_uid::text),
            now(), now());

    update public.profiles p
       set first_name        = v_people[i][1],
           last_name         = v_people[i][2],
           full_name         = v_people[i][1] || ' ' || v_people[i][2],
           role              = 'parent',
           onboarding_status = 'approved',
           driver_status     = 'approved'
     where p.id = v_id;

    insert into public.addresses (user_id, label, address_line1, city, state, zip, location, is_default)
    values (v_id, 'Home', 'Demo home ' || i, 'Nearby', '--', '00000',
            extensions.st_setsrid(extensions.st_makepoint(
              v_lng + v_people[i][6]::double precision,
              v_lat + v_people[i][5]::double precision), 4326)::extensions.geography,
            true);

    insert into public.kids (parent_id, first_name, last_name, date_of_birth, grade, school_id)
    values (v_id, v_people[i][3], v_people[i][2], date '2017-06-01', v_people[i][4],
            v_schools[1 + ((i - 1) % cardinality(v_schools))]);

    insert into public.vehicles (owner_id, model, plate_number, kid_seats, has_booster, photo_path)
    values (v_id, 'Demo car', 'DEMO' || i, 3, i % 2 = 0, v_id::text || '/vehiclePhoto.jpg');

    v_made := v_made + 1;
  end loop;
  return v_made;
end;
$$;

revoke execute on function public.demo_ensure_families(uuid) from public, anon, authenticated;

-- New parents: when the ID is sent/approved, and when a kid gets a school.
create or replace function public.demo_families_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- kids rows carry parent_id; profiles rows are the parent (id).
  perform public.demo_ensure_families(coalesce(
    (to_jsonb(new) ->> 'parent_id')::uuid, (to_jsonb(new) ->> 'id')::uuid));
  return null;
end;
$$;
revoke execute on function public.demo_families_trigger() from public, anon, authenticated;

drop trigger if exists demo_families_on_profile on public.profiles;
create trigger demo_families_on_profile
  after update of onboarding_status on public.profiles
  for each row
  when (new.onboarding_status::text in ('approved', 'pending_review'))
  execute function public.demo_families_trigger();

drop trigger if exists demo_families_on_kid on public.kids;
create trigger demo_families_on_kid
  after insert or update of school_id on public.kids
  for each row
  when (new.school_id is not null)
  execute function public.demo_families_trigger();

-- Everyone who already qualifies.
select p.first_name, p.last_name, public.demo_ensure_families(p.id) as families_added
  from public.profiles p
 where p.role::text = 'parent'
   and p.onboarding_status::text in ('approved', 'pending_review')
   and not exists (select 1 from auth.users u
                    where u.id = p.id and coalesce(u.raw_user_meta_data->>'demo', '') = 'true')
 order by p.first_name;
