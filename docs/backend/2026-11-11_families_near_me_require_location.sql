-- get_families_near_me: only return genuine nearby families.
-- Previously a missing home location (the caller's or the other family's)
-- skipped the distance check, so far-away families could appear.
-- Now: caller without a home -> []; families without a home are excluded;
-- everyone returned is within the radius and has a distanceMiles.
-- Applied 2026-11-11 (migration: families_near_me_require_location).

CREATE OR REPLACE FUNCTION public.get_families_near_me("schoolId" uuid DEFAULT NULL::uuid, "radiusMiles" double precision DEFAULT 10)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
    fam as (
      select p.id, p.first_name, p.last_name,
             (p.driver_status::text = 'approved') as gives_rides,
             (select a.location from public.addresses a
               where a.user_id = p.id and a.is_default) as home,
             jsonb_agg(distinct jsonb_build_object(
               'firstName',  k.first_name,
               'schoolId',   s.id,
               'schoolName', s.name)) as kids
        from public.kids k
        join my_schools ms on ms.school_id = k.school_id
        join public.profiles p on p.id = k.parent_id
        join public.schools s on s.id = k.school_id
       where k.parent_id <> v_uid
         and p.role::text = 'parent'
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
             'distanceMiles', round((extensions.st_distance(v_home, f.home) / 1609.344)::numeric, 1)
           ) order by extensions.st_distance(v_home, f.home), f.first_name)
      from fam f
     where f.home is not null
       and extensions.st_dwithin(v_home, f.home, v_radius)
  ), '[]'::jsonb);
end;
$function$;
