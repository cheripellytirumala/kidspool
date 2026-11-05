-- "Families near you" (Home → FAMILIES / See all).
-- Other ID-approved parents whose kids go to the same school as one of the
-- caller's kids, within "radiusMiles" of the caller's default home.
-- Shares only: first name + last initial, initials, kids' first names and
-- schools, distance rounded to 0.1 mi, and whether they give rides.
-- Never returns addresses, phone numbers or exact locations.
-- Apply in Supabase → SQL editor, project cojraqxramlirnepncrd.

begin;

create or replace function public.get_families_near_me(
  "schoolId" uuid default null,
  "radiusMiles" double precision default 10)
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
             'distanceMiles', case when v_home is null or f.home is null then null
                                   else round((extensions.st_distance(v_home, f.home) / 1609.344)::numeric, 1) end
           ) order by case when v_home is null or f.home is null then null
                           else extensions.st_distance(v_home, f.home) end nulls last,
                      f.first_name)
      from fam f
     where v_home is null or f.home is null or extensions.st_dwithin(v_home, f.home, v_radius)
  ), '[]'::jsonb);
end;
$fn$;

revoke all on function public.get_families_near_me(uuid, double precision) from public, anon;
grant execute on function public.get_families_near_me(uuid, double precision) to authenticated, service_role;

commit;

notify pgrst, 'reload schema';
