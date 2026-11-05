-- Notifications (Home bell → F25b · Notifications; S19/S20 alert copy).
-- There is no notifications table: the feed is derived from timestamps the
-- ride flow already records, so nothing new has to be written anywhere.
--
-- As the parent who asked (ride_requests.parent_id):
--   ride_confirmed   confirmed_at          "Jen will drive Emma"
--   ride_started     started_at            "Ride started 🚗"            (S19)
--   picked_up        picked_up_at          "Emma is in the car"
--   ride_arrived     completed_at          "Emma reached Lincoln ✅"     (S20)
--   driver_cancelled driver_cancelled_at   "Jen can’t drive anymore"
--   ride_missed      missed_at
--   ride_expired     status = expired      "No one could take this ride"
-- As a Ride Partner:
--   ride_request     ride_request_notifications.notified_at
--   offer_declined   ride_offers declined / auto_declined   (F25b row 3)
--
-- Last 30 days, newest first, at most 60 rows. Shares first names only.
-- Apply in Supabase → SQL editor, project cojraqxramlirnepncrd.

begin;

create or replace function public.get_my_notifications()
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $fn$
declare
  v_uid   uuid := auth.uid();
  v_since timestamptz := now() - interval '30 days';
begin
  if v_uid is null then raise sqlstate 'PT401' using message = 'not_authenticated'; end if;

  return coalesce((
    with rides as (
      -- Every ride the caller asked for or was involved in driving.
      select rr.*,
             coalesce(nullif(rr.time_zone, ''), 'UTC') as tz,
             s.name as school_name,
             (select string_agg(k.first_name, ' & ' order by k.first_name)
                from public.ride_request_kids rk
                join public.kids k on k.id = rk.kid_id
               where rk.request_id = rr.id) as kid_names,
             (select count(*) from public.ride_request_kids rk
               where rk.request_id = rr.id) as kid_count
        from public.ride_requests rr
        left join public.schools s on s.id = rr.school_id
       where rr.parent_id = v_uid
          or rr.driver_id = v_uid
          or exists (select 1 from public.ride_request_notifications n
                      where n.request_id = rr.id and n.driver_id = v_uid)
          or exists (select 1 from public.ride_offers o
                      where o.request_id = rr.id and o.driver_id = v_uid)
    ),
    named as (
      select r.*,
             coalesce(r.kid_names, 'your kids') as kids,
             case when r.kid_count > 1 then 'are' else 'is' end as verb,
             coalesce(r.school_name, 'school') as school,
             to_char(r.pickup_at at time zone r.tz, 'Dy, Mon FMDD · FMHH12:MI AM') as when_label,
             d.id as driver_pid,
             coalesce(nullif(d.first_name, ''), split_part(d.full_name, ' ', 1), 'Your Ride Partner') as driver_name,
             upper(left(coalesce(nullif(d.first_name, ''), d.full_name, ''), 1)
                   || left(coalesce(d.last_name, ''), 1)) as driver_initials,
             coalesce(nullif(pa.first_name, ''), split_part(pa.full_name, ' ', 1), 'A parent') as parent_name,
             upper(left(coalesce(nullif(pa.first_name, ''), pa.full_name, ''), 1)
                   || left(coalesce(pa.last_name, ''), 1)) as parent_initials
        from rides r
        left join public.profiles d on d.id = r.driver_id
        join public.profiles pa on pa.id = r.parent_id
    ),
    events as (
      -- Parent side ---------------------------------------------------------
      select n.id, 'ride_confirmed' as kind, n.confirmed_at as at,
             n.driver_name || ' will drive ' || n.kids as title,
             n.when_label || ' · to ' || n.school as body,
             false as i_am_driver, n.driver_pid as other_id,
             n.driver_name as other_name, n.driver_initials as other_initials
        from named n
       where n.parent_id = v_uid and n.confirmed_at is not null and n.driver_id is not null
      union all
      select n.id, 'ride_started', n.started_at,
             'Ride started 🚗',
             n.driver_name || ' is on the way to pick up ' || n.kids || '.',
             false, n.driver_pid, n.driver_name, n.driver_initials
        from named n
       where n.parent_id = v_uid and n.started_at is not null
      union all
      select n.id, 'picked_up', n.picked_up_at,
             n.kids || ' ' || n.verb || ' in the car',
             n.driver_name || ' picked them up at '
               || to_char(n.picked_up_at at time zone n.tz, 'FMHH12:MI AM') || '.',
             false, n.driver_pid, n.driver_name, n.driver_initials
        from named n
       where n.parent_id = v_uid and n.picked_up_at is not null
      union all
      select n.id, 'ride_arrived', n.completed_at,
             n.kids || ' reached ' || n.school || ' ✅',
             n.driver_name || '’s car arrived at '
               || to_char(n.completed_at at time zone n.tz, 'FMHH12:MI AM') || '.',
             false, n.driver_pid, n.driver_name, n.driver_initials
        from named n
       where n.parent_id = v_uid and n.completed_at is not null
      union all
      select n.id, 'driver_cancelled', n.driver_cancelled_at,
             'Your Ride Partner can’t drive anymore',
             n.when_label || ' · we asked other parents again',
             false, null, null, null
        from named n
       where n.parent_id = v_uid and n.driver_cancelled_at is not null
      union all
      select n.id, 'ride_missed', n.missed_at,
             'The ride for ' || n.kids || ' was missed',
             n.when_label || ' · to ' || n.school,
             false, n.driver_pid, n.driver_name, n.driver_initials
        from named n
       where n.parent_id = v_uid and n.missed_at is not null
      union all
      select n.id, 'ride_expired', n.updated_at,
             'No one could take this ride',
             n.when_label || ' · ask again or try other parents',
             false, null, null, null
        from named n
       where n.parent_id = v_uid and n.status = 'expired'
      -- Ride Partner side ---------------------------------------------------
      union all
      select n.id, 'ride_request', rn.notified_at,
             n.parent_name || ' needs a ride for ' || n.kids,
             n.when_label || ' · to ' || n.school,
             true, n.parent_id, n.parent_name, n.parent_initials
        from named n
        join public.ride_request_notifications rn
          on rn.request_id = n.id and rn.driver_id = v_uid
       where n.parent_id <> v_uid
      union all
      select n.id, 'offer_declined', coalesce(o.responded_at, o.updated_at),
             n.parent_name || ' chose another parent',
             'Your offer for ' || n.kids || ' was withdrawn',
             true, n.parent_id, n.parent_name, n.parent_initials
        from named n
        join public.ride_offers o
          on o.request_id = n.id and o.driver_id = v_uid
       where o.status in ('declined', 'auto_declined')
    )
    select jsonb_agg(jsonb_build_object(
             'id',            e.kind || ':' || e.id::text,
             'kind',          e.kind,
             'title',         e.title,
             'body',          e.body,
             'createdAt',     e.at,
             'requestId',     e.id,
             -- RideAlertsHost (S19/S20 banners) reads the ride from data.
             'data',          jsonb_build_object('requestId', e.id),
             'iAmDriver',     e.i_am_driver,
             'otherId',       e.other_id,
             'otherName',     e.other_name,
             'otherInitials', nullif(e.other_initials, ''))
           order by e.at desc)
      from (select * from events
             where at is not null and at >= v_since and at <= now() + interval '1 minute'
             order by at desc
             limit 60) e
  ), '[]'::jsonb);
end;
$fn$;

revoke all on function public.get_my_notifications() from public, anon;
grant execute on function public.get_my_notifications() to authenticated;

commit;

notify pgrst, 'reload schema';
