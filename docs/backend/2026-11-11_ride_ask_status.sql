-- Ride cards (get_group_ride_asks / post_ride_ask / help_with_ride_ask)
-- also say:
--   rideStatus  status of the booked ride (open, confirmed, in_progress,
--               completed, …) — the parent's "Track ride" shows only once
--               it's in_progress (the driver started it);
--   isHelper    the caller is the driver who said "I can help" — once
--               a card is taken it disappears for everyone else.
-- Only ride_ask_json changes. Safe to re-run.

create or replace function public.ride_ask_json(a public.ride_asks, p_uid uuid)
returns jsonb
language sql
stable
security definer
set search_path to ''
as $fn$
  select jsonb_build_object(
    'id',         a.id,
    'messageId',  a.message_id,
    'isMine',     a.parent_id = p_uid,
    'isHelper',   a.helper_id is not null and a.helper_id = p_uid,
    'status',     a.status,
    'summary',    a.summary,
    'days',       jsonb_array_length(a.rides),
    'requestIds', to_jsonb(a.request_ids),
    'rideStatus', (select r.status::text from public.ride_requests r
                    where r.id = a.request_ids[1]),
    'helperName', (select coalesce(nullif(h.first_name, ''), 'A parent')
                     from public.profiles h where h.id = a.helper_id),
    'canHelp',    a.status = 'open' and a.parent_id <> p_uid
                  and exists (select 1 from public.profiles d
                               where d.id = p_uid and d.role = 'parent'
                                 and d.onboarding_status = 'approved'
                                 and d.driver_status = 'approved'),
    'createdAt',  a.created_at);
$fn$;
revoke all on function public.ride_ask_json(public.ride_asks, uuid) from public, anon, authenticated;
