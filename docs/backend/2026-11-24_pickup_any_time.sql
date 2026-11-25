-- Ask for a ride for any time from now on (no 2-hour notice).
--  * ride_build_plan: only a pick-up in the past is refused (code kept as
--    pickup_too_soon so older app builds still show a message).
--  * expire_stale_ride_requests: an open request expires at its pick-up
--    time, not 1 hour before (else a ride asked for in 30 min expires at once).
-- Idempotent; safe to re-run.
do $$
declare d text;
begin
  select pg_get_functiondef(p.oid) into d
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'ride_build_plan';
  if d like '%now() + interval ''2 hours''%' then
    d := replace(d, 'if r.pickup_at < now() + interval ''2 hours'' then',
                    'if r.pickup_at < now() then');
    d := replace(d, 'detail = ''at least 2 hours from now''',
                    'detail = ''pick-up time has passed''');
    execute d;
  end if;

  select pg_get_functiondef(p.oid) into d
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'expire_stale_ride_requests';
  if d like '%pickup_at - interval ''1 hour'' <= now()%' then
    execute replace(d, 'and pickup_at - interval ''1 hour'' <= now();',
                       'and pickup_at <= now();');
  end if;
end $$;
