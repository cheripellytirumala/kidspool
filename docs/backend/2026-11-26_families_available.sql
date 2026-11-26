-- Families near you: add `available` (green dot), same rule as Chats:
-- an approved Ride Partner whose "Available" switch is on right now
-- (public.driver_is_online). Only the select list changes.
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
             'available',     public.driver_is_online(f.id),
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
