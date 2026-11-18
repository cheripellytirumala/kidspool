-- Search radius as an editable server setting.
--
-- Change it in Supabase → Table Editor → app_settings → row
-- "search_radius_km" → value (e.g. 40). It applies at once to every user and
-- every installed build. Values are kept between 1 and 80 km.
--
-- Used by:
--   eligible_driver_ids    who gets a ride request (from the pick-up)
--   get_families_near_me   Families near you (from home)
--   invite_to_ride_request Say Hi / hand-picked invites (from home)
--   can_add_to_ride_group  adding a family to a ride group (from home)
--
-- The table is private: RLS on with no policies, and no grants to anon or
-- authenticated, so the app can neither read nor change it. Admins edit it
-- in the dashboard, or with the secret (service role) key over REST.

create table if not exists public.app_settings (
  key         text primary key,
  value       numeric not null,
  description text,
  updated_at  timestamptz not null default now()
);
alter table public.app_settings enable row level security;
revoke all on table public.app_settings from anon, authenticated;

insert into public.app_settings (key, value, description)
values ('search_radius_km', 25,
        'Radius in km for drivers, Families near you, invites and ride groups (1–80).')
on conflict (key) do nothing;

create or replace function public.touch_app_settings()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;
drop trigger if exists app_settings_touch on public.app_settings;
create trigger app_settings_touch before update on public.app_settings
  for each row execute function public.touch_app_settings();

-- The radius in metres, from the setting (25 km if missing), kept 1–80 km.
create or replace function public.search_radius_m()
returns double precision
language sql
stable
security definer
set search_path = ''
as $$
  select least(greatest(coalesce(
           (select s.value from public.app_settings s where s.key = 'search_radius_km'),
           25), 1), 80)::double precision * 1000;
$$;
revoke all on function public.search_radius_m() from public, anon, authenticated;

create or replace function public.eligible_driver_ids(p_uid uuid, p_location extensions.geography, p_seats integer, p_booster boolean)
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.id
    from public.profiles p
    join public.addresses a on a.user_id = p.id and a.is_default
    left join public.vehicles v on v.owner_id = p.id
   where p.role = 'parent'
     and p.onboarding_status = 'approved'
     and p.driver_status = 'approved'
     and p.id <> p_uid
     and extensions.st_dwithin(a.location, p_location, public.search_radius_m())
     and (v.owner_id is null
          or (v.kid_seats >= p_seats and (not p_booster or v.has_booster)));
$$;

CREATE OR REPLACE FUNCTION public.can_add_to_ride_group(p_adder uuid, p_target uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select p_target <> p_adder
     and exists (select 1 from public.profiles p
                  where p.id = p_target and p.role::text = 'parent'
                    and p.onboarding_status::text = 'approved')
     and (
       exists (select 1 from public.kids a join public.kids b on b.school_id = a.school_id
                where a.parent_id = p_adder and b.parent_id = p_target)
       or exists (select 1 from public.addresses a, public.addresses b
                   where a.user_id = p_adder and a.is_default
                     and b.user_id = p_target and b.is_default
                     and extensions.st_dwithin(a.location, b.location, public.search_radius_m()))
     );
$function$;

-- "radiusMiles" is kept so older app builds still call it, but the radius
-- now comes from app_settings.
CREATE OR REPLACE FUNCTION public.get_families_near_me("schoolId" uuid DEFAULT NULL::uuid, "radiusMiles" double precision DEFAULT 10)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid    uuid := auth.uid();
  v_home   extensions.geography;
  v_radius double precision := public.search_radius_m();
begin
  if v_uid is null then raise sqlstate 'PT401' using message = 'not_authenticated'; end if;

  select a.location into v_home
    from public.addresses a
   where a.user_id = v_uid and a.is_default;

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
$function$;

CREATE OR REPLACE FUNCTION public.invite_to_ride_request("requestIds" uuid[], "parentIds" uuid[])
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid   uuid := auth.uid();
  v_home  extensions.geography;
  v_count int;
begin
  if v_uid is null then
    raise sqlstate 'PT401' using message = 'not_authenticated';
  end if;
  if coalesce(cardinality("requestIds"), 0) = 0
     or coalesce(cardinality("parentIds"), 0) = 0 then
    return jsonb_build_object('invited', 0);
  end if;
  if cardinality("requestIds") > 20 or cardinality("parentIds") > 50 then
    raise sqlstate 'PT400' using message = 'invalid_field',
      detail = 'requestIds (max 20) / parentIds (max 50)';
  end if;

  select a.location into v_home
    from public.addresses a
   where a.user_id = v_uid and a.is_default;
  if v_home is null then
    raise sqlstate 'PT400' using message = 'address_required';
  end if;

  with targets as (
    select p.id
      from public.profiles p
      join public.addresses a on a.user_id = p.id and a.is_default
     where p.id = any("parentIds")
       and p.id <> v_uid
       and p.role = 'parent'
       and p.onboarding_status = 'approved'
       and extensions.st_dwithin(a.location, v_home, public.search_radius_m())
  ), ins as (
    insert into public.ride_request_notifications (request_id, driver_id, invited_at)
    select r.id, t.id, now()
      from public.ride_requests r
      cross join targets t
     where r.id = any("requestIds")
       and r.parent_id = v_uid
       and r.status = 'open'
    on conflict (request_id, driver_id) do update
      set invited_at = coalesce(public.ride_request_notifications.invited_at, now())
    returning driver_id
  )
  select count(distinct driver_id) into v_count from ins;

  return jsonb_build_object('invited', v_count);
end;
$$;
