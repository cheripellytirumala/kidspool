-- "I can help" on a ride card books the ride straight away: no approval
-- step for the parent, who sees it as booked (and can open live tracking).
--
-- help_with_ride_ask() created the request with requireApproval = true, so
-- the driver's offer waited for the parent. Now it's created with
-- requireApproval = false: offer_ride confirms the first offer at once.
-- Only those two values change. Safe to re-run.

do $$
declare
  v_def text;
  v_old  constant text := E'v_ride->>''note'',\n      false,\n      true,';
  v_new  constant text := E'v_ride->>''note'',\n      false,\n      false,';
  v_old2 constant text := $q$'status',     'waiting_for_parent',$q$;
  v_new2 constant text := $q$'status',     'confirmed',$q$;
begin
  v_def := pg_get_functiondef('public.help_with_ride_ask(uuid)'::regprocedure);
  if position(v_new in v_def) > 0 then
    raise notice 'help_with_ride_ask already books straight away';
    return;
  end if;
  if position(v_old in v_def) = 0 or position(v_old2 in v_def) = 0 then
    raise exception 'help_with_ride_ask changed; approval flag not found';
  end if;
  execute replace(replace(v_def, v_old, v_new), v_old2, v_new2);
end $$;
