-- Optional drop-off location for a ride (any place picked from map search).
-- Without one, the ride still goes to the kids' school exactly as before.
-- Driver matching already uses the pick-up location and is unchanged.
-- Apply in Supabase → SQL editor (project cojraqxramlirnepncrd), or allow
-- `mcp__supabase__apply_migration` so Claude Code can run it.
-- Each function edit aborts if the expected text isn't found.

begin;

alter table public.ride_requests
  add column if not exists dropoff_label          text,
  add column if not exists dropoff_address_line1  text,
  add column if not exists dropoff_city           text,
  add column if not exists dropoff_state          text,
  add column if not exists dropoff_zip            text,
  add column if not exists dropoff_location       extensions.geography;

-- A ride to a custom drop-off doesn't need the kid to have a school yet.
alter table public.ride_requests alter column school_id drop not null;

alter type public.ride_plan
  add attribute dropoff_label text,
  add attribute dropoff_line1 text,
  add attribute dropoff_city text,
  add attribute dropoff_state text,
  add attribute dropoff_zip text,
  add attribute dropoff_location extensions.geography;

create or replace function public.ride_dropoff_json(rr public.ride_requests)
returns jsonb
language sql
stable
set search_path to ''
as $fn$
  select case when rr.dropoff_location is null then null else jsonb_build_object(
    'label',        rr.dropoff_label,
    'addressLine1', rr.dropoff_address_line1,
    'city',         rr.dropoff_city,
    'state',        rr.dropoff_state,
    'zip',          rr.dropoff_zip,
    'latitude',     extensions.st_y(rr.dropoff_location::extensions.geometry),
    'longitude',    extensions.st_x(rr.dropoff_location::extensions.geometry)
  ) end
$fn$;
revoke all on function public.ride_dropoff_json(public.ride_requests) from public, anon, authenticated;

do $mig$
declare
  d text;
  fn regprocedure;
  t text;
  school_rr  constant text := 'from public.schools s where s.id = rr.school_id),';
  school_row constant text := 'from public.schools s where s.id = v_row.school_id),';
  arrive_old constant text := 'select s.location into v_school from public.schools s where s.id = v_row.school_id;';
  arrive_new constant text := 'select coalesce(v_row.dropoff_location, s.location) into v_school from public.schools s where s.id = v_row.school_id;';
  sig_old    constant text := 'p_address_id uuid, p_address jsonb)';
  sig_new    constant text := 'p_address_id uuid, p_address jsonb, p_dropoff jsonb DEFAULT NULL::jsonb)';
  schreq_old constant text := 'if exists (select 1 from public.kids k where k.id = any(p_kid_ids) and k.school_id is null) then';
  schreq_new constant text := 'if p_dropoff is null and exists (select 1 from public.kids k where k.id = any(p_kid_ids) and k.school_id is null) then';
  diff_old   constant text := 'if v_schools > 1 then';
  diff_new   constant text := 'if p_dropoff is null and v_schools > 1 then';
  unav_old   constant text := 'if not v_school.is_active or v_school.location is null then';
  unav_new   constant text := 'if p_dropoff is null and (not v_school.is_active or v_school.location is null) then';
  dist_old   constant text := 'r.distance_meters := extensions.st_distance(r.location, v_school.location);';
  dist_new   constant text := $q$if p_dropoff is not null then
    if jsonb_typeof(p_dropoff) <> 'object'
       or jsonb_typeof(p_dropoff->'latitude') is distinct from 'number'
       or jsonb_typeof(p_dropoff->'longitude') is distinct from 'number'
       or (p_dropoff->>'latitude')::double precision not between -90 and 90
       or (p_dropoff->>'longitude')::double precision not between -180 and 180 then
      raise sqlstate 'PT400' using message = 'invalid_field', detail = 'dropoffAddress.latitude/longitude';
    end if;
    r.dropoff_label := coalesce(nullif(trim(p_dropoff->>'label'), ''), 'Drop-off');
    r.dropoff_line1 := nullif(trim(p_dropoff->>'addressLine1'), '');
    r.dropoff_city  := nullif(trim(p_dropoff->>'city'), '');
    r.dropoff_state := nullif(trim(p_dropoff->>'state'), '');
    r.dropoff_zip   := nullif(trim(p_dropoff->>'zip'), '');
    if char_length(r.dropoff_label) > 60 or char_length(coalesce(r.dropoff_line1, '')) > 120
       or char_length(coalesce(r.dropoff_city, '')) > 60 or char_length(coalesce(r.dropoff_state, '')) > 60
       or char_length(coalesce(r.dropoff_zip, '')) > 10 then
      raise sqlstate 'PT400' using message = 'invalid_field', detail = 'dropoffAddress (too long)';
    end if;
    r.dropoff_location := extensions.st_setsrid(extensions.st_makepoint(
      (p_dropoff->>'longitude')::double precision, (p_dropoff->>'latitude')::double precision), 4326)::extensions.geography;
    if extensions.st_dwithin(r.dropoff_location, r.location, 50) then
      raise sqlstate 'PT400' using message = 'same_place', detail = 'drop-off is the pick-up address';
    end if;
    r.distance_meters := extensions.st_distance(r.location, r.dropoff_location);
  else
    r.distance_meters := extensions.st_distance(r.location, v_school.location);
  end if;$q$;
begin
  -- ride_build_plan: optional p_dropoff (school checks skipped when set).
  fn := 'public.ride_build_plan(uuid, uuid[], date, text, text, uuid, jsonb)'::regprocedure;
  d := pg_get_functiondef(fn);
  foreach t in array array[sig_old, schreq_old, diff_old, unav_old, dist_old] loop
    if (length(d) - length(replace(d, t, ''))) / length(t) <> 1 then
      raise exception 'ride_build_plan: expected exactly one "%", aborting', t;
    end if;
  end loop;
  d := replace(d, sig_old, sig_new);
  d := replace(d, schreq_old, schreq_new);
  d := replace(d, diff_old, diff_new);
  d := replace(d, unav_old, unav_new);
  d := replace(d, dist_old, dist_new);
  drop function public.ride_build_plan(uuid, uuid[], date, text, text, uuid, jsonb);
  execute d;
  revoke all on function public.ride_build_plan(uuid, uuid[], date, text, text, uuid, jsonb, jsonb) from public, anon, authenticated;

  -- create_ride_request: optional "dropoffAddress" (same JSON shape as pickupAddress).
  fn := 'public.create_ride_request(uuid[], date, text, text, uuid, jsonb, text, boolean, boolean)'::regprocedure;
  d := pg_get_functiondef(fn);
  foreach t in array array[
    '"requireApproval" boolean DEFAULT false)',
    'create_ride_request."pickupAddressId", create_ride_request."pickupAddress");',
    E'seats_needed, needs_booster, note, require_approval\n    ) values (',
    E'p.seats_needed, p.needs_booster, v_note, coalesce(create_ride_request."requireApproval", false)\n    ) returning id into v_id;'] loop
    if (length(d) - length(replace(d, t, ''))) / length(t) <> 1 then
      raise exception 'create_ride_request: expected exactly one "%", aborting', t;
    end if;
  end loop;
  d := replace(d, '"requireApproval" boolean DEFAULT false)',
                  '"requireApproval" boolean DEFAULT false, "dropoffAddress" jsonb DEFAULT NULL::jsonb)');
  d := replace(d, 'create_ride_request."pickupAddressId", create_ride_request."pickupAddress");',
                  'create_ride_request."pickupAddressId", create_ride_request."pickupAddress", create_ride_request."dropoffAddress");');
  d := replace(d, E'seats_needed, needs_booster, note, require_approval\n    ) values (',
                  E'seats_needed, needs_booster, note, require_approval,\n      dropoff_label, dropoff_address_line1, dropoff_city, dropoff_state, dropoff_zip, dropoff_location\n    ) values (');
  d := replace(d, E'p.seats_needed, p.needs_booster, v_note, coalesce(create_ride_request."requireApproval", false)\n    ) returning id into v_id;',
                  E'p.seats_needed, p.needs_booster, v_note, coalesce(create_ride_request."requireApproval", false),\n      p.dropoff_label, p.dropoff_line1, p.dropoff_city, p.dropoff_state, p.dropoff_zip, p.dropoff_location\n    ) returning id into v_id;');
  drop function public.create_ride_request(uuid[], date, text, text, uuid, jsonb, text, boolean, boolean);
  execute d;
  revoke all on function public.create_ride_request(uuid[], date, text, text, uuid, jsonb, text, boolean, boolean, jsonb) from public, anon;
  grant execute on function public.create_ride_request(uuid[], date, text, text, uuid, jsonb, text, boolean, boolean, jsonb) to authenticated, service_role;

  -- "dropoff" in the ride JSON and tracking.
  foreach fn in array array[
    'public.ride_request_json(public.ride_requests)'::regprocedure,
    'public.driver_request_json(public.ride_requests, uuid)'::regprocedure] loop
    d := pg_get_functiondef(fn);
    if (length(d) - length(replace(d, school_rr, ''))) / length(school_rr) <> 1 then
      raise exception '%: expected one school block, aborting', fn;
    end if;
    execute replace(d, school_rr, school_rr || E'\n    ''dropoff'',              public.ride_dropoff_json(rr),');
  end loop;

  fn := 'public.get_ride_tracking(uuid, boolean)'::regprocedure;
  d := pg_get_functiondef(fn);
  if (length(d) - length(replace(d, school_row, ''))) / length(school_row) <> 1 then
    raise exception 'get_ride_tracking: expected one school block, aborting';
  end if;
  execute replace(d, school_row, school_row || E'\n    ''dropoff'',         public.ride_dropoff_json(v_row),');

  -- Arrival distance: to the drop-off when set, else the school.
  fn := 'public.complete_ride(uuid, double precision, double precision)'::regprocedure;
  d := pg_get_functiondef(fn);
  if position(arrive_old in d) = 0 then
    raise exception 'complete_ride: expected text not found, aborting';
  end if;
  execute replace(d, arrive_old, arrive_new);
end
$mig$;

commit;

notify pgrst, 'reload schema';
