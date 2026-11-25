-- Parent cancels a ride after accepting a Ride Partner (confirmed, not
-- started): record who and why, and tell the Ride Partner.
--  * cancel_ride_request(requestId, scope, reason?) also sets cancelled_by
--    and cancel_reason. Old apps that send no reason keep working.
--  * get_my_notifications: the booked Ride Partner gets "ride_cancelled"
--    ("Vivek cancelled the ride" / "Tue, Nov 25 · 9:30 AM · Casey · reason").
--    Rides cancelled after the start already had their own row.
-- Idempotent; safe to re-run. Fails loudly if a patch didn't apply.

do $$
declare d text; patched text;
begin
  -- cancel_ride_request ----------------------------------------------------
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = 'cancel_ride_request'
       and pg_get_function_identity_arguments(p.oid) like '%reason%'
  ) then
    select pg_get_functiondef('public.cancel_ride_request(uuid, text)'::regprocedure)
      into d;
    patched := regexp_replace(d,
      'scope text DEFAULT ''this''::text\)',
      'scope text DEFAULT ''this''::text, reason text DEFAULT NULL::text)');
    if patched = d then
      raise exception 'cancel_ride_request: signature not found';
    end if;
    d := patched;
    patched := regexp_replace(d,
      'set\s+status\s*=\s*''cancelled'',\s*cancelled_at\s*=\s*now\(\)',
      'set status = ''cancelled'', cancelled_at = now(), cancelled_by = v_uid,
         cancel_reason = nullif(btrim(cancel_ride_request.reason), '''')');
    if patched = d then
      raise exception 'cancel_ride_request: update not found';
    end if;
    -- One function only, or PostgREST can't tell the two apart.
    drop function public.cancel_ride_request(uuid, text);
    execute patched;
    revoke all on function public.cancel_ride_request(uuid, text, text)
      from public, anon;
    grant execute on function public.cancel_ride_request(uuid, text, text)
      to authenticated, service_role;
  end if;

  -- get_my_notifications: tell the booked Ride Partner ------------------------
  select pg_get_functiondef(p.oid) into d
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'get_my_notifications';
  if d not like '%cancelled the ride%' then
    patched := regexp_replace(d,
      'union all\s+select n\.id, ''ride_request'',',
      'union all select n.id, ''ride_cancelled'', n.cancelled_at,
      n.parent_name || '' cancelled the ride'',
      n.when_label || '' · '' || n.kids
        || coalesce('' · '' || nullif(btrim(n.cancel_reason), ''''), ''''),
      true, n.parent_id, n.parent_name, n.parent_initials
      from named n
      where n.status = ''cancelled'' and n.started_at is null
        and n.driver_id = v_uid and n.parent_id <> v_uid
        and n.cancelled_by = n.parent_id and n.cancelled_at is not null
    union all select n.id, ''ride_request'',');
    if patched = d then
      raise exception 'get_my_notifications: ride_request row not found';
    end if;
    execute patched;
  end if;
end $$;
