-- Home "Available" switch: read the caller's current state on app open, so
-- the switch matches what other parents see (green dot) instead of forcing
-- Off. Same rule as the dot: public.driver_is_online.
create or replace function public.get_driver_available()
 returns jsonb
 language plpgsql
 stable security definer
 set search_path to ''
as $function$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then raise sqlstate 'PT401' using message = 'not_authenticated'; end if;
  return jsonb_build_object('available', public.driver_is_online(v_uid));
end;
$function$;

revoke all on function public.get_driver_available() from public, anon;
grant execute on function public.get_driver_available() to authenticated, service_role;
