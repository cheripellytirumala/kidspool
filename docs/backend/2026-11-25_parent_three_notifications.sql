-- Parent side: three notifications per ride, once it has started.
--   1. ride_started      "Ride started 🚗"            → opens the live ride
--   2. driver_at_pickup  "Ravi has arrived 📍" + PIN   → opens the live ride
--   3. ride_arrived      "Ride completed ✅"           → opens the summary
--  * New ride_requests.driver_at_pickup_at, set once by update_ride_location
--    when the Ride Partner is within 150 m of the pick-up before pick-up.
--  * get_my_notifications: the parent's "picked_up" row is replaced by
--    driver_at_pickup; "ride_overdue" goes to the Ride Partner only; the
--    completion row reads "Ride completed ✅ / Mia reached Lincoln at 8:05 AM".
--    Pre-ride rows (offers, booked) and cancellations are unchanged.
-- Idempotent; safe to re-run. Patches the live function bodies like
-- 2026-11-24_pickup_any_time.sql and fails loudly if a patch didn't apply.

alter table public.ride_requests
  add column if not exists driver_at_pickup_at timestamptz;

do $$
declare d text; patched text;
begin
  -- update_ride_location: mark the arrival at the pick-up (once) -----------
  select pg_get_functiondef(p.oid) into d
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'update_ride_location';
  if d not like '%driver_at_pickup_at%' then
    patched := replace(d, 'insert into public.ride_location_points',
      '-- Within 150 m of the pick-up before pick-up: the parent is told once.
  if v_row.picked_up_at is null and v_row.driver_at_pickup_at is null
     and v_row.pickup_location is not null
     and extensions.st_dwithin(v_pt, v_row.pickup_location, 150) then
    update public.ride_requests set driver_at_pickup_at = now()
     where id = v_row.id and driver_at_pickup_at is null;
  end if;
  insert into public.ride_location_points');
    if patched = d then
      raise exception 'update_ride_location: insert point not found';
    end if;
    execute patched;
  end if;

  -- get_my_notifications ----------------------------------------------------
  select pg_get_functiondef(p.oid) into d
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'get_my_notifications';
  if d not like '%driver_at_pickup%' then
    -- (a) parent "picked_up" → "driver_at_pickup" with the PIN. The first
    -- quantifier is non-greedy, so the whole match is the shortest one.
    patched := regexp_replace(d,
      'union all.{1,40}?''picked_up''.*?n\.picked_up_at is not null',
      'union all select n.id, ''driver_at_pickup'', n.driver_at_pickup_at,
      n.driver_name || '' has arrived 📍'',
      case when n.pickup_pin is not null
        then ''Your pick-up PIN is '' || n.pickup_pin || ''. Share it with ''
             || n.driver_name || '' to hand over '' || n.kids || ''.''
        else n.driver_name || '' is at the pick-up for '' || n.kids || ''.''
      end,
      false, n.driver_pid, n.driver_name, n.driver_initials
      from named n
      where n.parent_id = v_uid and n.driver_at_pickup_at is not null');
    if patched = d then
      raise exception 'get_my_notifications: picked_up row not found';
    end if;
    d := patched;

    -- (b) "Is this ride still going?" only for the Ride Partner.
    patched := regexp_replace(d,
      'n\.status = ''in_progress''\s+and\s+\(n\.parent_id = v_uid or n\.driver_id = v_uid\)',
      'n.status = ''in_progress'' and n.driver_id = v_uid');
    if patched = d then
      raise exception 'get_my_notifications: ride_overdue filter not found';
    end if;
    d := patched;

    -- (c) Completion copy: "Ride completed ✅" / "Mia reached Lincoln at …".
    patched := regexp_replace(d,
      'n\.kids\s*\|\|\s*'' reached ''\s*\|\|\s*n\.school\s*\|\|\s*'' ✅'',\s*n\.driver_name\s*\|\|\s*''’s car arrived at ''\s*\|\|',
      '''Ride completed ✅'', n.kids || '' reached '' || n.school || '' at '' ||');
    if patched = d then
      raise exception 'get_my_notifications: completion copy not found';
    end if;
    execute patched;
  end if;
end $$;
