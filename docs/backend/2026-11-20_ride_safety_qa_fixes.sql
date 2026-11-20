-- QA round 2026-11-20: ride safety fixes.
--
--   #3  cancel_active_ride(): parent OR Ride Partner can cancel a started
--       ride until the kids are picked up.
--   #4  Every offer waits for the parent (Accept / Decline): offer_ride no
--       longer auto-confirms, "I can help" on a group ask too. New parent
--       notification `offer_received`.
--   #6  driver card: vehicle colour + year, gender.
--   #7  Pickup PIN: 4 digits per confirmed ride, shown to the requesting
--       parent; mark_picked_up(..., pin) checks it (5 tries, then 10 min
--       lock). Enforced once app_settings.require_pickup_pin = 1 — leave 0
--       until the build that sends the PIN is live, or older builds can't
--       mark pickups.
--   #9  driver card vehicle.kidsOnRide (seats taken on this ride).
--   #12 Rides left in progress: `ride_overdue` alert 1 h after the expected
--       drop-off; auto-ended 3 h after start (completed if picked up, else
--       cancelled), trip time capped. pg_cron runs the sweep every 5 min.
--   #14 profiles.gender (optional) + set_my_gender().
--
-- Additive; safe to re-run. Project cojraqxramlirnepncrd (shared dev/prod).

begin;

-- Columns ------------------------------------------------------------------
alter table public.ride_requests
  add column if not exists pickup_pin     text,
  add column if not exists pin_attempts   smallint not null default 0,
  add column if not exists pin_failed_at  timestamptz,
  add column if not exists cancelled_by   uuid references public.profiles(id) on delete set null,
  add column if not exists cancel_reason  text,
  add column if not exists auto_ended_at  timestamptz;

alter table public.profiles
  add column if not exists gender text;
do $$ begin
  alter table public.profiles add constraint profiles_gender_check
    check (gender is null or gender in ('female', 'male', 'non_binary', 'prefer_not_to_say'));
exception when duplicate_object then null; end $$;

insert into public.app_settings (key, value, description)
values ('require_pickup_pin', 0,
        '1 = Ride Partner must enter the parent''s 4-digit PIN to mark pick-up')
on conflict (key) do nothing;

-- #7 PIN on every confirmed ride --------------------------------------------
create or replace function public.ride_requests_assign_pin()
returns trigger language plpgsql set search_path to '' as $$
begin
  if new.pickup_pin is null and new.status in ('confirmed', 'in_progress') then
    new.pickup_pin := lpad((floor(random() * 10000))::int::text, 4, '0');
  end if;
  if tg_op = 'UPDATE' and new.driver_id is distinct from old.driver_id then
    new.pin_attempts := 0;
    new.pin_failed_at := null;
  end if;
  return new;
end $$;

drop trigger if exists ride_requests_assign_pin on public.ride_requests;
create trigger ride_requests_assign_pin
  before insert or update on public.ride_requests
  for each row execute function public.ride_requests_assign_pin();

update public.ride_requests
   set pickup_pin = lpad((floor(random() * 10000))::int::text, 4, '0')
 where pickup_pin is null and status in ('confirmed', 'in_progress');

drop function if exists public.mark_picked_up(uuid, double precision, double precision);
create or replace function public.mark_picked_up(
  "requestId" uuid,
  latitude double precision default null,
  longitude double precision default null,
  pin text default null)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_uid  uuid := auth.uid();
  v_row  public.ride_requests;
  v_pt   extensions.geography;
  v_dist double precision;
  v_need boolean;
begin
  perform public.check_lat_lng(mark_picked_up.latitude, mark_picked_up.longitude, false);
  v_row := public.lock_driver_ride(v_uid, mark_picked_up."requestId");

  if v_row.status <> 'in_progress' then
    raise sqlstate 'PT409' using message = 'ride_not_started', detail = v_row.status::text;
  end if;
  if v_row.picked_up_at is not null then raise sqlstate 'PT409' using message = 'already_picked_up'; end if;

  v_need := coalesce((select s.value from public.app_settings s where s.key = 'require_pickup_pin'), 0) >= 1;
  if v_need or nullif(btrim(mark_picked_up.pin), '') is not null then
    if v_row.pin_attempts >= 5 and v_row.pin_failed_at > now() - interval '10 minutes' then
      raise sqlstate 'PT409' using message = 'pin_locked';
    end if;
    if nullif(btrim(mark_picked_up.pin), '') is null then
      raise sqlstate 'PT400' using message = 'pin_required';
    end if;
    if v_row.pickup_pin is null or btrim(mark_picked_up.pin) <> v_row.pickup_pin then
      -- Returned, not raised: a raise would roll back the attempt count.
      update public.ride_requests
         set pin_attempts  = case when pin_failed_at < now() - interval '10 minutes'
                                  then 1 else pin_attempts + 1 end,
             pin_failed_at = now()
       where id = v_row.id
      returning * into v_row;
      return jsonb_build_object('status', 'wrong_pin',
                                'attemptsLeft', greatest(0, 5 - v_row.pin_attempts));
    end if;
  end if;

  v_pt := public.make_point(mark_picked_up.latitude, mark_picked_up.longitude);
  v_dist := case when v_pt is not null then extensions.st_distance(v_pt, v_row.pickup_location) end;

  update public.ride_requests
     set picked_up_at = now(), picked_up_location = v_pt, pin_attempts = 0, pin_failed_at = null
   where id = v_row.id;

  update public.ride_tracking t
     set picked_up_at = now(), updated_at = now(),
         latitude    = coalesce(mark_picked_up.latitude, t.latitude),
         longitude   = coalesce(mark_picked_up.longitude, t.longitude),
         location_at = case when v_pt is not null then now() else t.location_at end
   where request_id = v_row.id;

  if v_pt is not null then
    insert into public.ride_location_points (request_id, location) values (v_row.id, v_pt);
  end if;

  return jsonb_build_object(
    'status',                   'picked_up',
    'requestId',                v_row.id,
    'pickedUpAt',               now(),
    'pickedUpTime',             to_char(now() at time zone v_row.time_zone, 'HH24:MI'),
    'distanceFromPickupMeters', round(v_dist::numeric)
  );
end;
$function$;
revoke all on function public.mark_picked_up(uuid, double precision, double precision, text) from public, anon;
grant execute on function public.mark_picked_up(uuid, double precision, double precision, text) to authenticated, service_role;

-- #3 Cancel a started ride before pick-up -----------------------------------
create or replace function public.cancel_active_ride("requestId" uuid, reason text default null)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_uid  uuid := auth.uid();
  v_row  public.ride_requests;
  v_role text;
begin
  if v_uid is null then raise sqlstate 'PT401' using message = 'not_authenticated'; end if;
  if cancel_active_ride."requestId" is null then
    raise sqlstate 'PT400' using message = 'missing_field', detail = 'requestId';
  end if;
  if char_length(coalesce(cancel_active_ride.reason, '')) > 300 then
    raise sqlstate 'PT400' using message = 'invalid_field', detail = 'reason';
  end if;

  select * into v_row from public.ride_requests r where r.id = cancel_active_ride."requestId" for update;
  v_role := case when found then public.ride_role(v_uid, v_row) end;
  if v_role is null then raise sqlstate 'PT404' using message = 'ride_not_found'; end if;
  if v_row.status <> 'in_progress' then
    raise sqlstate 'PT409' using message = 'cannot_cancel', detail = v_row.status::text;
  end if;
  if v_row.picked_up_at is not null then
    raise sqlstate 'PT409' using message = 'already_picked_up';
  end if;

  update public.ride_requests
     set status = 'cancelled', cancelled_at = now(), cancelled_by = v_uid,
         cancel_reason = nullif(btrim(cancel_active_ride.reason), '')
   where id = v_row.id;
  update public.ride_tracking set status = 'cancelled', updated_at = now() where request_id = v_row.id;

  return jsonb_build_object('status', 'cancelled', 'requestId', v_row.id,
                            'cancelledBy', v_role, 'cancelledAt', now());
end;
$function$;
revoke all on function public.cancel_active_ride(uuid, text) from public, anon;
grant execute on function public.cancel_active_ride(uuid, text) to authenticated, service_role;

-- #12 Auto-end long rides ---------------------------------------------------
create or replace function public.expire_stale_ride_requests()
returns void
language plpgsql
security definer
set search_path to ''
as $function$
begin
  update public.ride_requests
     set status = 'expired'
   where status = 'open'
     and pickup_at - interval '1 hour' <= now();

  -- confirmed but never started 30 min after pickup time
  update public.ride_requests
     set status = 'missed', missed_at = now()
   where status = 'confirmed'
     and pickup_at + interval '30 minutes' < now();

  -- in progress 3 h after start: close it (trip time capped at 3 h)
  with ended as (
    update public.ride_requests r
       set status        = case when r.picked_up_at is not null then 'completed' else 'cancelled' end::public.ride_status,
           completed_at  = case when r.picked_up_at is not null
                                then greatest(r.picked_up_at, r.started_at + interval '3 hours') end,
           cancelled_at  = case when r.picked_up_at is null then now() end,
           cancel_reason = case when r.picked_up_at is null then 'auto_ended' else r.cancel_reason end,
           auto_ended_at = now()
     where r.status = 'in_progress'
       and r.started_at < now() - interval '3 hours'
    returning r.id, r.status, r.completed_at
  )
  update public.ride_tracking t
     set status = e.status, completed_at = e.completed_at, updated_at = now()
    from ended e
   where t.request_id = e.id;

  update public.ride_offers o
     set status = 'auto_declined', responded_at = now()
    from public.ride_requests r
   where r.id = o.request_id
     and o.status = 'pending'
     and r.status <> 'open';
end;
$function$;

-- #4 Offers always wait for the parent --------------------------------------
do $$
declare v_def text;
begin
  v_def := pg_get_functiondef('public.offer_ride(uuid, text)'::regprocedure);
  if position('v_auto := not v_req.require_approval;' in v_def) > 0 then
    execute replace(v_def, 'v_auto := not v_req.require_approval;',
                    'v_auto := false;  -- parents always accept or decline (QA #4)');
  end if;

  v_def := pg_get_functiondef('public.help_with_ride_ask(uuid)'::regprocedure);
  if position($q$'status',     'confirmed',$q$ in v_def) > 0 then
    execute replace(v_def, $q$'status',     'confirmed',$q$, $q$'status',     'waiting_for_parent',$q$);
  end if;
end $$;

-- #6 #9 #14 Driver card -----------------------------------------------------
do $$
declare v_def text;
begin
  v_def := pg_get_functiondef('public.driver_card_json(uuid, public.ride_requests, boolean)'::regprocedure);
  if position('''gender''' in v_def) = 0 then
    v_def := replace(v_def,
      $q$'idVerified',    p.onboarding_status = 'approved',$q$,
      $q$'idVerified',    p.onboarding_status = 'approved',
    'gender',        p.gender,$q$);
    v_def := replace(v_def,
      $q$'hasBooster', v.has_booster, 'photoPath', v.photo_path)$q$,
      $q$'hasBooster', v.has_booster, 'photoPath', v.photo_path,
                               'color', v.color, 'year', v.year,
                               'kidsOnRide', (select count(*)::int from public.ride_request_kids rk
                                               where rk.request_id = rr.id))$q$);
    if position('''gender''' in v_def) = 0 or position('''kidsOnRide''' in v_def) = 0 then
      raise exception 'driver_card_json changed; anchors not found';
    end if;
    execute v_def;
  end if;
end $$;

create or replace function public.set_my_gender(gender text)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_g   text := nullif(lower(btrim(set_my_gender.gender)), '');
begin
  if v_uid is null then raise sqlstate 'PT401' using message = 'not_authenticated'; end if;
  if v_g is not null and v_g not in ('female', 'male', 'non_binary', 'prefer_not_to_say') then
    raise sqlstate 'PT400' using message = 'invalid_field', detail = 'gender';
  end if;
  update public.profiles set gender = v_g where id = v_uid;
  return jsonb_build_object('gender', v_g);
end;
$function$;
revoke all on function public.set_my_gender(text) from public, anon;
grant execute on function public.set_my_gender(text) to authenticated, service_role;

do $$
declare v_def text;
begin
  v_def := pg_get_functiondef('public.get_my_status()'::regprocedure);
  if position('''gender''' in v_def) = 0 then
    v_def := replace(v_def, $q$'lastName',          p.last_name,$q$,
                            $q$'lastName',          p.last_name,
    'gender',            p.gender,$q$);
    if position('''gender''' in v_def) = 0 then raise exception 'get_my_status anchor not found'; end if;
    execute v_def;
  end if;
end $$;

-- get_ride_tracking: PIN, cancel, auto-end, overdue ---------------------------
do $$
declare v_def text;
begin
  v_def := pg_get_functiondef('public.get_ride_tracking(uuid, boolean)'::regprocedure);
  if position('''pickupPin''' in v_def) = 0 then
    v_def := replace(v_def, $q$'missedAt',        v_row.missed_at,$q$,
      $q$'missedAt',        v_row.missed_at,
    -- QA 2026-11-20
    'pickupPin',       case when v_role = 'parent' and v_row.picked_up_at is null
                             and v_row.status in ('confirmed', 'in_progress')
                            then v_row.pickup_pin end,
    'pinRequired',     coalesce((select s.value from public.app_settings s
                                  where s.key = 'require_pickup_pin'), 0) >= 1,
    'cancelledAt',     v_row.cancelled_at,
    'cancelledBy',     case when v_row.cancelled_by is null then
                              case when v_row.status = 'cancelled' and v_row.auto_ended_at is not null then 'system' end
                            when v_row.cancelled_by = v_row.parent_id then 'parent'
                            when v_row.cancelled_by = v_row.driver_id then 'driver' end,
    'cancelReason',    nullif(v_row.cancel_reason, 'auto_ended'),
    'autoEndedAt',     v_row.auto_ended_at,
    'overdueAt',       coalesce(v_row.estimated_dropoff_at, v_row.pickup_at) + interval '1 hour',
    'autoEndAt',       v_row.started_at + interval '3 hours',$q$);
    if position('''pickupPin''' in v_def) = 0 then raise exception 'get_ride_tracking anchor not found'; end if;
    execute v_def;
  end if;
end $$;

-- get_my_notifications: offer_received, ride_cancelled, ride_overdue, ride_auto_ended
do $$
declare
  v_def    text;
  v_anchor constant text := '      -- Ride Partner side ---------------------------------------------------';
begin
  v_def := pg_get_functiondef('public.get_my_notifications()'::regprocedure);
  if position('offer_received' in v_def) > 0 then return; end if;
  if position(v_anchor in v_def) = 0 then raise exception 'get_my_notifications anchor not found'; end if;

  -- an auto-ended ride didn't "arrive"
  v_def := replace(v_def,
    'where n.parent_id = v_uid and n.completed_at is not null',
    'where n.parent_id = v_uid and n.completed_at is not null and n.auto_ended_at is null');

  v_def := replace(v_def, v_anchor, $q$      union all
      select n.id, 'offer_received', o.created_at,
             coalesce(nullif(od.first_name, ''), split_part(od.full_name, ' ', 1), 'A Ride Partner')
               || ' offered to drive ' || n.kids,
             n.when_label || ' · accept or decline',
             false, od.id,
             coalesce(nullif(od.first_name, ''), split_part(od.full_name, ' ', 1)),
             upper(left(coalesce(nullif(od.first_name, ''), od.full_name, ''), 1) || left(coalesce(od.last_name, ''), 1))
        from named n
        join public.ride_offers o on o.request_id = n.id and o.status = 'pending'
        join public.profiles od on od.id = o.driver_id
       where n.parent_id = v_uid and n.status = 'open'
      -- Both sides of a started ride ----------------------------------------
      union all
      select n.id, 'ride_cancelled', n.cancelled_at,
             'Ride cancelled',
             case when n.auto_ended_at is not null
                    then 'Not picked up 3 hours after it started, so it was closed.'
                  when n.cancelled_by = n.driver_id then n.driver_name || ' cancelled before pick-up'
                  else n.parent_name || ' cancelled before pick-up' end
               || coalesce(' · ' || nullif(nullif(n.cancel_reason, ''), 'auto_ended'), ''),
             n.driver_id = v_uid,
             case when n.parent_id = v_uid then n.driver_pid else n.parent_id end,
             case when n.parent_id = v_uid then n.driver_name else n.parent_name end,
             case when n.parent_id = v_uid then n.driver_initials else n.parent_initials end
        from named n
       where n.status = 'cancelled' and n.started_at is not null and n.cancelled_at is not null
         and (n.parent_id = v_uid or n.driver_id = v_uid)
         and n.cancelled_by is distinct from v_uid
      union all
      select n.id, 'ride_overdue', coalesce(n.estimated_dropoff_at, n.pickup_at) + interval '1 hour',
             'Is this ride still going?',
             'It’s running over an hour late. Finish it in the app — it closes by itself 3 hours after it started.',
             n.driver_id = v_uid,
             case when n.parent_id = v_uid then n.driver_pid else n.parent_id end,
             case when n.parent_id = v_uid then n.driver_name else n.parent_name end,
             case when n.parent_id = v_uid then n.driver_initials else n.parent_initials end
        from named n
       where n.status = 'in_progress' and (n.parent_id = v_uid or n.driver_id = v_uid)
         and now() >= coalesce(n.estimated_dropoff_at, n.pickup_at) + interval '1 hour'
      union all
      select n.id, 'ride_auto_ended', n.auto_ended_at,
             'Ride closed automatically',
             'It was still in progress 3 hours after it started.',
             n.driver_id = v_uid,
             case when n.parent_id = v_uid then n.driver_pid else n.parent_id end,
             case when n.parent_id = v_uid then n.driver_name else n.parent_name end,
             case when n.parent_id = v_uid then n.driver_initials else n.parent_initials end
        from named n
       where n.status = 'completed' and n.auto_ended_at is not null
         and (n.parent_id = v_uid or n.driver_id = v_uid)
$q$ || v_anchor);
  execute v_def;
end $$;

commit;

-- Sweep every 5 minutes (outside the transaction: extension + cron job).
create extension if not exists pg_cron;
select cron.unschedule(jobid) from cron.job where jobname = 'expire-stale-rides';
select cron.schedule('expire-stale-rides', '*/5 * * * *', 'select public.expire_stale_ride_requests()');
