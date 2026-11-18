-- Ride requests reach drivers whose home is within 25 km (15.5 mi) of the
-- pick-up, up from 3 mi (4.8 km). Used by create_ride_request (who gets the
-- request), count_eligible_drivers, get_open_requests and offer_ride (via
-- driver_is_eligible). Invited families (invite_to_ride_request) stay at
-- 10 mi from home.
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
     and extensions.st_dwithin(a.location, p_location, 25000) -- 25 km
     -- Seats / booster only when a car is saved.
     and (v.owner_id is null
          or (v.kid_seats >= p_seats and (not p_booster or v.has_booster)));
$$;
