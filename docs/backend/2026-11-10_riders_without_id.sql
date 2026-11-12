-- Parents who only need rides ("I need rides") skip the ID / license step
-- and go straight to adding their kids. Their onboarding_status stays
-- 'not_started', which ride_build_plan (used by create_ride_request) used to
-- reject with `not_approved`, so they couldn't ask for a ride.
--
-- This lets 'not_started' parents ask for rides. Offering rides is unchanged:
-- drivers still need an approved ID (require_driver / eligible_driver_ids),
-- and a rejected ID still blocks asking.
--
-- Only the one status check changes; the rest of the function is untouched.
-- Safe to re-run.

do $$
declare
  v_def text;
  v_old constant text := $q$if v_onb not in ('approved', 'pending_review') then$q$;
  v_new constant text := $q$if v_onb not in ('approved', 'pending_review', 'not_started') then$q$;
begin
  v_def := pg_get_functiondef(
    'public.ride_build_plan(uuid, uuid[], date, text, text, uuid, jsonb)'::regprocedure);
  if position(v_new in v_def) > 0 then
    raise notice 'ride_build_plan already allows not_started';
    return;
  end if;
  if position(v_old in v_def) = 0 then
    raise exception 'ride_build_plan changed; status check not found';
  end if;
  execute replace(v_def, v_old, v_new);
end $$;
