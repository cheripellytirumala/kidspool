-- Kids' activities (soccer, swim, Funland…) on the server.
--
-- Until now activities only lived on each parent's phone, so "Families near
-- you" could only match families by school. Now:
--   * kid_activities: one row per kid × place (a Google place or a
--     catalogue id), with the place's name, address and location;
--   * set_my_kid_activities(activities) replaces the caller's activities
--     (the app sends its whole list whenever it changes);
--   * get_my_kid_activities() returns them (restores a new phone);
--   * get_families_near_me() also lists nearby families whose kids go to
--     the same activities, each with "activities": [{id, name}] (shared
--     ones), so the app shows a chip per activity like it does per school.
--     Kids that aren't at one of my schools come back with schoolId null.
--
-- NOTE: dev, staging and production share project cojraqxramlirnepncrd.
-- Safe to re-run.

begin;

create table if not exists public.kid_activities (
  id           uuid primary key default gen_random_uuid(),
  parent_id    uuid not null references public.profiles(id) on delete cascade,
  kid_id       uuid not null references public.kids(id) on delete cascade,
  place_key    text not null check (char_length(place_key) between 1 and 300),
  name         text not null check (char_length(name) between 1 and 120),
  category     text not null default 'activity',
  address_line text,
  city         text,
  state        text,
  zip          text,
  location     extensions.geography,
  created_at   timestamptz not null default now(),
  unique (kid_id, place_key)
);
create index if not exists kid_activities_place_idx on public.kid_activities (place_key);
create index if not exists kid_activities_parent_idx on public.kid_activities (parent_id);

alter table public.kid_activities enable row level security;
revoke all on public.kid_activities from anon, authenticated;

-- Replace the caller's activities. ------------------------------------------
-- activities: [{placeKey, name, category, addressLine, city, state, zip,
--               latitude, longitude, kidIds: [uuid]}]
create or replace function public.set_my_kid_activities(activities jsonb)
returns int
language plpgsql
security definer
set search_path to ''
as $fn$
declare
  v_uid  uuid := auth.uid();
  v_item jsonb;
  v_kid  text;
  v_n    int := 0;
begin
  if v_uid is null then raise sqlstate 'PT401' using message = 'not_authenticated'; end if;
  if activities is null or jsonb_typeof(activities) <> 'array'
     or jsonb_array_length(activities) > 100 then
    raise sqlstate 'PT400' using message = 'invalid_field', detail = 'activities (up to 100)';
  end if;

  delete from public.kid_activities where parent_id = v_uid;

  for v_item in select * from jsonb_array_elements(activities) loop
    continue when coalesce(btrim(v_item->>'placeKey'), '') = ''
               or coalesce(btrim(v_item->>'name'), '') = '';
    for v_kid in select * from jsonb_array_elements_text(coalesce(v_item->'kidIds', '[]'::jsonb)) loop
      -- Only the caller's own kids.
      continue when not exists (select 1 from public.kids k
                                 where k.id::text = v_kid and k.parent_id = v_uid);
      insert into public.kid_activities
        (parent_id, kid_id, place_key, name, category, address_line, city, state, zip, location)
      values (
        v_uid, v_kid::uuid, left(btrim(v_item->>'placeKey'), 300), left(btrim(v_item->>'name'), 120),
        coalesce(nullif(v_item->>'category', ''), 'activity'),
        nullif(v_item->>'addressLine', ''), nullif(v_item->>'city', ''),
        nullif(v_item->>'state', ''), nullif(v_item->>'zip', ''),
        case when jsonb_typeof(v_item->'latitude') = 'number'
              and jsonb_typeof(v_item->'longitude') = 'number'
             then extensions.st_setsrid(extensions.st_makepoint(
                    (v_item->>'longitude')::double precision,
                    (v_item->>'latitude')::double precision), 4326)::extensions.geography
        end)
      on conflict (kid_id, place_key) do nothing;
      v_n := v_n + 1;
    end loop;
  end loop;
  return v_n;
end;
$fn$;

-- The caller's activities, one entry per place. -----------------------------
create or replace function public.get_my_kid_activities()
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $fn$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then raise sqlstate 'PT401' using message = 'not_authenticated'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'placeKey',    t.place_key,
             'name',        t.name,
             'category',    t.category,
             'addressLine', t.address_line,
             'city',        t.city,
             'state',       t.state,
             'zip',         t.zip,
             'latitude',    case when t.location is null then null
                                 else extensions.st_y(t.location::extensions.geometry) end,
             'longitude',   case when t.location is null then null
                                 else extensions.st_x(t.location::extensions.geometry) end,
             'kidIds',      t.kid_ids) order by t.name)
      from (
        select a.place_key, min(a.name) as name, min(a.category) as category,
               min(a.address_line) as address_line, min(a.city) as city,
               min(a.state) as state, min(a.zip) as zip,
               (array_agg(a.location))[1] as location,
               jsonb_agg(a.kid_id) as kid_ids
          from public.kid_activities a
         where a.parent_id = v_uid
         group by a.place_key
      ) t
  ), '[]'::jsonb);
end;
$fn$;

-- Families near me: same schools OR same activities. -------------------------
create or replace function public.get_families_near_me("schoolId" uuid default null, "radiusMiles" double precision default 10)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $fn$
declare
  v_uid    uuid := auth.uid();
  v_home   extensions.geography;
  v_radius double precision :=
    least(greatest(coalesce(get_families_near_me."radiusMiles", 10), 1), 25) * 1609.344;
begin
  if v_uid is null then raise sqlstate 'PT401' using message = 'not_authenticated'; end if;

  select a.location into v_home
    from public.addresses a
   where a.user_id = v_uid and a.is_default;

  -- Without a home location we can't tell who is nearby: show nobody.
  if v_home is null then return '[]'::jsonb; end if;

  return coalesce((
    with my_schools as (
      select distinct k.school_id
        from public.kids k
       where k.parent_id = v_uid
         and k.school_id is not null
         and (get_families_near_me."schoolId" is null or k.school_id = get_families_near_me."schoolId")
    ),
    my_activities as (
      select distinct a.place_key, a.name
        from public.kid_activities a
       where a.parent_id = v_uid
         and get_families_near_me."schoolId" is null
    ),
    their_kids as (
      -- Other parents' kids at one of my schools or my activities.
      select k.*, (k.school_id in (select school_id from my_schools)) as same_school
        from public.kids k
       where k.parent_id <> v_uid
         and (k.school_id in (select school_id from my_schools)
              or exists (select 1 from public.kid_activities a
                          join my_activities ma on ma.place_key = a.place_key
                         where a.kid_id = k.id))
    ),
    fam as (
      select p.id, p.first_name, p.last_name,
             (p.driver_status::text = 'approved') as gives_rides,
             (select a.location from public.addresses a
               where a.user_id = p.id and a.is_default) as home,
             jsonb_agg(distinct jsonb_build_object(
               'firstName',  tk.first_name,
               'schoolId',   case when tk.same_school then s.id end,
               'schoolName', case when tk.same_school then s.name end)) as kids,
             coalesce((select jsonb_agg(distinct jsonb_build_object(
                                'id', 'activity:' || ma.place_key, 'name', ma.name))
                         from public.kid_activities a
                         join my_activities ma on ma.place_key = a.place_key
                        where a.parent_id = p.id), '[]'::jsonb) as activities
        from their_kids tk
        join public.profiles p on p.id = tk.parent_id
        left join public.schools s on s.id = tk.school_id
       where p.role::text = 'parent'
         and p.onboarding_status::text = 'approved'
       group by p.id, p.first_name, p.last_name, p.driver_status
    )
    select jsonb_agg(jsonb_build_object(
             'id',            f.id,
             'firstName',     coalesce(f.first_name, ''),
             'lastInitial',   left(coalesce(f.last_name, ''), 1),
             'initials',      public.person_initials(f.first_name, f.last_name),
             'givesRides',    f.gives_rides,
             'kids',          f.kids,
             'activities',    f.activities,
             'distanceMiles', round((extensions.st_distance(v_home, f.home) / 1609.344)::numeric, 1)
           ) order by extensions.st_distance(v_home, f.home), f.first_name)
      from fam f
     where f.home is not null
       and extensions.st_dwithin(v_home, f.home, v_radius)
  ), '[]'::jsonb);
end;
$fn$;

revoke all on function public.set_my_kid_activities(jsonb) from public, anon;
revoke all on function public.get_my_kid_activities() from public, anon;
grant execute on function public.set_my_kid_activities(jsonb) to authenticated;
grant execute on function public.get_my_kid_activities() to authenticated;

commit;

notify pgrst, 'reload schema';
