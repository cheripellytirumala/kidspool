-- "Not this time" on a ride request, saved on the server.
--
-- Before this, a Ride Partner's "Not this time" was only remembered on the
-- phone, so a reinstall, wiped app data or a second phone brought the
-- request back. Now:
--   * ride_request_notifications (one row per request × driver) gets
--     `passed_at`;
--   * pass_ride_request("requestId") sets it for the signed-in driver;
--   * get_open_requests() leaves out requests the driver passed.
-- Nothing else changes: the parent, other drivers and chats are untouched.
--
-- NOTE: dev, staging and production share project cojraqxramlirnepncrd.
-- Safe to re-run.

alter table public.ride_request_notifications
  add column if not exists passed_at timestamptz;

create or replace function public.pass_ride_request("requestId" uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise sqlstate 'PT401' using message = 'not_authenticated';
  end if;
  if "requestId" is null then
    raise sqlstate 'PT400' using message = 'missing_field', detail = 'requestId';
  end if;
  -- Only someone else's request; passing one that's no longer open is a no-op.
  if not exists (select 1 from public.ride_requests r
                  where r.id = "requestId" and r.parent_id <> v_uid) then
    raise sqlstate 'PT404' using message = 'request_not_found';
  end if;

  insert into public.ride_request_notifications (request_id, driver_id, seen_at, passed_at)
  values ("requestId", v_uid, now(), now())
  on conflict (request_id, driver_id) do update
    set passed_at = now(),
        seen_at   = coalesce(public.ride_request_notifications.seen_at, now());
end;
$$;

revoke execute on function public.pass_ride_request(uuid) from public, anon;
grant execute on function public.pass_ride_request(uuid) to authenticated;

-- get_open_requests(): skip passed requests. Only this one line changes.
do $$
declare
  v_def text;
  v_old constant text := $q$and public.driver_is_eligible(v_uid, r);$q$;
  v_new constant text := $q$and public.driver_is_eligible(v_uid, r)
     and not exists (select 1 from public.ride_request_notifications n
                      where n.request_id = r.id and n.driver_id = v_uid
                        and n.passed_at is not null);$q$;
begin
  v_def := pg_get_functiondef('public.get_open_requests()'::regprocedure);
  if position('n.passed_at is not null' in v_def) > 0 then
    raise notice 'get_open_requests already skips passed requests';
    return;
  end if;
  if position(v_old in v_def) = 0 then
    raise exception 'get_open_requests changed; eligibility line not found';
  end if;
  execute replace(v_def, v_old, v_new);
end $$;

notify pgrst, 'reload schema';
