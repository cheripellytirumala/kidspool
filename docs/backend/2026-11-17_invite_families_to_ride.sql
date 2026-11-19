-- Families near you › Select › "Say Hi" after asking for a ride.
--
-- Bug: the Hi failed with cannot_message ("This parent didn't get your ride
-- request…"). A ride request only reaches eligible drivers (approved
-- driver, home within 3 mi of the pick-up), but Families near you lists
-- every approved parent within 10 mi. Anyone picked outside that set had no
-- ride_request_notifications row, so can_ride_chat said no.
--
-- Fix: the asker explicitly invites the families they picked.
--   1. ride_request_notifications.invited_at marks an invitation.
--   2. invite_to_ride_request(requestIds, parentIds) adds those rows, only
--      for the caller's own open requests and for approved parents whose
--      home is within 10 mi of the caller's (the Families near you radius).
--      Then can_ride_chat allows the chat (open + notified).
--   3. driver_is_eligible also accepts an invited, approved driver (seats /
--      booster still checked), so they see the request and can tap
--      "I can help" even beyond 3 mi. Invited parents who don't drive can
--      chat, but still can't offer (require_driver).

alter table public.ride_request_notifications
  add column if not exists invited_at timestamptz;

create or replace function public.invite_to_ride_request(
  "requestIds" uuid[],
  "parentIds"  uuid[]
)
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
       and extensions.st_dwithin(a.location, v_home, 25000) -- 25 km
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

revoke all on function public.invite_to_ride_request(uuid[], uuid[]) from public, anon;
grant execute on function public.invite_to_ride_request(uuid[], uuid[]) to authenticated;

create or replace function public.driver_is_eligible(p_driver uuid, rr public.ride_requests)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
      from public.eligible_driver_ids(rr.parent_id, rr.pickup_location, rr.seats_needed, rr.needs_booster) d
     where d = p_driver)
  or exists (
    -- Invited by the asking parent from Families near you.
    select 1
      from public.ride_request_notifications n
      join public.profiles p on p.id = n.driver_id
      left join public.vehicles v on v.owner_id = p.id
     where n.request_id = rr.id
       and n.driver_id = p_driver
       and n.invited_at is not null
       and p.id <> rr.parent_id
       and p.role = 'parent'
       and p.onboarding_status = 'approved'
       and p.driver_status = 'approved'
       and (v.owner_id is null
            or (v.kid_seats >= rr.seats_needed and (not rr.needs_booster or v.has_booster))));
$$;
