-- 5 more test families like "vivek l" (+1 884 822 3103) and
-- "Driver Sample" (+1 978 777 6725), in Coimbatore:
--   * a real phone account: sign in with the number, the OTP shows in the
--     app (demo mode), exactly like the two above;
--   * approved to ask for AND give rides (license on file), with a car;
--   * home between vivek and Driver Sample (within 3 miles of both, so
--     everyone gets each other's ride requests);
--   * one kid at Doon Public School.
--
--   Phone             Parent           Kid
--   +1 884 822 3111   Jessica Miller   Emma     (Grade 3)
--   +1 884 822 3112   Michael Brown    Liam     (Grade 2)
--   +1 884 822 3113   Ashley Johnson   Olivia   (Grade 4)
--   +1 884 822 3114   David Wilson     Noah     (Grade 3)
--   +1 884 822 3115   Sarah Davis      Ava      (Grade 1)
--
-- Tagged raw_user_meta_data.test_family = 'coimbatore' (removal at the
-- bottom). Safe to re-run: existing numbers are skipped.
-- NOTE: dev, staging and production share project cojraqxramlirnepncrd.

begin;

do $$
declare
  v_school constant uuid := '5fa458ab-d461-4141-b4a9-c5b52fce640b'; -- Doon Public School
  -- phone, first, last, kid, grade, street, lng, lat
  v_people constant text[][] := array[
    array['18848223111', 'Jessica', 'Miller',  'Emma',   'Grade 3', 'Race Course Road',   '76.9510', '11.0290'],
    array['18848223112', 'Michael', 'Brown',   'Liam',   'Grade 2', 'Avinashi Road',      '76.9600', '11.0250'],
    array['18848223113', 'Ashley',  'Johnson', 'Olivia', 'Grade 4', 'Bharathi Park Road', '76.9550', '11.0200'],
    array['18848223114', 'David',   'Wilson',  'Noah',   'Grade 3', 'Trichy Road',        '76.9630', '11.0300'],
    array['18848223115', 'Sarah',   'Davis',   'Ava',    'Grade 1', 'Sungam Bypass',      '76.9500', '11.0230']
  ];
  v_id uuid;
  i int;
begin
  for i in 1 .. array_length(v_people, 1) loop
    if exists (select 1 from auth.users u where u.phone = v_people[i][1]) then
      raise notice '% already exists, skipped', v_people[i][1];
      continue;
    end if;
    v_id := gen_random_uuid();

    -- Phone account (same shape as one made by verify-otp). handle_new_user
    -- creates the profile with phone +1….
    insert into auth.users (
      instance_id, id, aud, role, phone, phone_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, recovery_token, email_change_token_new, email_change,
      email_change_token_current, phone_change, phone_change_token,
      reauthentication_token, is_sso_user, is_anonymous)
    values (
      '00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated',
      v_people[i][1], now(),
      '{"provider": "phone", "providers": ["phone"]}'::jsonb,
      '{"test_family": "coimbatore"}'::jsonb, now(), now(),
      '', '', '', '', '', '', '', '', false, false);

    insert into auth.identities (provider_id, user_id, identity_data, provider,
                                 last_sign_in_at, created_at, updated_at)
    values (v_id::text, v_id,
            jsonb_build_object('sub', v_id::text, 'phone', v_people[i][1],
                               'email_verified', false, 'phone_verified', false),
            'phone', now(), now(), now());

    update public.profiles p
       set first_name        = v_people[i][2],
           last_name         = v_people[i][3],
           full_name         = v_people[i][2] || ' ' || v_people[i][3],
           role              = 'parent',
           onboarding_status = 'approved',
           driver_status     = 'approved'
     where p.id = v_id;

    insert into public.identity_verifications
      (user_id, id_type, selfie_path, id_front_path, id_back_path,
       status, submitted_at, reviewed_at)
    values (v_id, 'drivers_license', v_id || '/selfie.jpg', v_id || '/idFront.jpg',
            v_id || '/idBack.jpg', 'approved', now(), now());

    insert into public.addresses (user_id, label, address_line1, city, state, zip, location, is_default)
    values (v_id, 'Home', v_people[i][6], 'Coimbatore', 'Tamil Nadu', '641018',
            extensions.st_setsrid(extensions.st_makepoint(
              v_people[i][7]::double precision, v_people[i][8]::double precision),
              4326)::extensions.geography,
            true);

    insert into public.kids (parent_id, first_name, last_name, date_of_birth, grade, school_id)
    values (v_id, v_people[i][4], v_people[i][3], date '2018-03-15', v_people[i][5], v_school);

    insert into public.vehicles (owner_id, model, plate_number, kid_seats, has_booster, photo_path)
    values (v_id, 'Test car', 'TN66-' || i, 3, i % 2 = 0, v_id || '/vehiclePhoto.jpg');
  end loop;
end $$;

commit;

-- Check: the new families and how far each is from vivek / Driver Sample.
select p.first_name || ' ' || p.last_name as parent,
       p.phone,
       p.onboarding_status, p.driver_status,
       round(extensions.st_distance(a.location, va.location)) as m_from_vivek,
       round(extensions.st_distance(a.location, da.location)) as m_from_driver_sample
  from public.profiles p
  join auth.users u on u.id = p.id and u.raw_user_meta_data->>'test_family' = 'coimbatore'
  join public.addresses a on a.user_id = p.id and a.is_default
  join public.profiles vp on vp.phone = '+18848223103'
  join public.addresses va on va.user_id = vp.id and va.is_default
  join public.profiles dp on dp.phone = '+19787776725'
  join public.addresses da on da.user_id = dp.id and da.is_default
 order by p.phone;

-- To remove them later (the profile, address, kid, car and rides go too):
--   delete from public.identity_verifications where user_id in (
--     select id from auth.users where raw_user_meta_data->>'test_family' = 'coimbatore');
--   delete from auth.users where raw_user_meta_data->>'test_family' = 'coimbatore';
