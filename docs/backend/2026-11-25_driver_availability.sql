-- Driver "Available" switch on the Home dashboard.
--
-- profiles.available         true  → the driver gets new ride requests
--                            false → hidden from new requests (open list,
--                                    "N drivers nearby" counts, offers)
-- profiles.available_seen_at last time the app said "still on".
--
-- The app turns it off when the driver switches it off or when the app is
-- killed (on the next launch it always starts off). A killed app can't always
-- reach the server, so an "on" that hasn't been refreshed for
-- app_settings.driver_available_hours (default 12) counts as off.
--
-- Default true (seen_at null) so drivers on older app builds keep getting
-- requests exactly as before. Booked rides are never affected. Idempotent.

alter table public.profiles
  add column if not exists available boolean not null default true,
  add column if not exists available_seen_at timestamptz;

insert into public.app_settings (key, value, description)
values ('driver_available_hours', 12,
        'Hours a driver''s "Available" stays on without the app checking in '
        '(covers an app killed in the background).')
on conflict (key) do nothing;

create or replace function public.driver_is_available(p_driver uuid)
returns boolean
language sql
stable
security definer
set search_path to ''
as $$
  select coalesce((
    select p.available
           and (p.available_seen_at is null
                or p.available_seen_at > now() - make_interval(hours =>
                     coalesce((select s.value from public.app_settings s
                                where s.key = 'driver_available_hours'), 12)::int))
      from public.profiles p
     where p.id = p_driver), false);
$$;

revoke all on function public.driver_is_available(uuid) from public, anon, authenticated;

-- set_driver_available(available) → {available}. The app calls it on toggle,
-- every few minutes while on (heartbeat), and with false on launch / kill.
create or replace function public.set_driver_available(available boolean)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise sqlstate 'PT401' using message = 'not_authenticated';
  end if;
  -- Only approved drivers can switch on; anyone may switch off.
  if set_driver_available.available and not exists (
       select 1 from public.profiles p
        where p.id = v_uid and p.driver_status::text = 'approved') then
    raise sqlstate 'PT403' using message = 'not_a_driver';
  end if;
  update public.profiles p
     set available = set_driver_available.available,
         available_seen_at = now()
   where p.id = v_uid;
  return jsonb_build_object('available', public.driver_is_available(v_uid));
end;
$$;

revoke all on function public.set_driver_available(boolean) from public, anon;
grant execute on function public.set_driver_available(boolean) to authenticated, service_role;

-- New requests only go to available drivers. Patch the live body so the rest
-- of eligible_driver_ids stays exactly as deployed.
do $$
declare
  v_def text := pg_get_functiondef('public.eligible_driver_ids(uuid, extensions.geography, integer, boolean)'::regprocedure);
  v_new text;
begin
  if v_def like '%driver_is_available%' then return; end if;
  v_new := replace(v_def,
    'and p.driver_status = ''approved''',
    'and p.driver_status = ''approved''
     and public.driver_is_available(p.id)');
  if v_new = v_def then raise exception 'eligible_driver_ids patch did not match'; end if;
  execute v_new;
end $$;

-- Invited requests too: an unavailable driver isn't offered anything new.
do $$
declare
  v_def text := pg_get_functiondef('public.driver_is_eligible(uuid, public.ride_requests)'::regprocedure);
  v_new text;
begin
  if v_def like '%driver_is_available%' then return; end if;
  v_new := replace(v_def,
    'and p.driver_status = ''approved''',
    'and p.driver_status = ''approved''
       and public.driver_is_available(p.id)');
  if v_new = v_def then raise exception 'driver_is_eligible patch did not match'; end if;
  execute v_new;
end $$;

-- Green "available" dot in Messages → Chats: the other person is an approved
-- driver who switched "Available" on (an untouched default doesn't count).
create or replace function public.driver_is_online(p_driver uuid)
returns boolean
language sql
stable
security definer
set search_path to ''
as $$
  select coalesce((
    select p.driver_status::text = 'approved'
           and p.available_seen_at is not null
           and public.driver_is_available(p.id)
      from public.profiles p
     where p.id = p_driver), false);
$$;

revoke all on function public.driver_is_online(uuid) from public, anon, authenticated;

-- get_my_ride_chats: other.available.
do $$
declare
  v_def text := pg_get_functiondef('public.get_my_ride_chats()'::regprocedure);
  v_new text;
begin
  if v_def like '%driver_is_online%' then return; end if;
  v_new := replace(v_def,
    '''initials'', public.person_initials(p.first_name, p.last_name))',
    '''initials'', public.person_initials(p.first_name, p.last_name),
                                           ''available'', public.driver_is_online(p.id))');
  if v_new = v_def then raise exception 'get_my_ride_chats patch did not match'; end if;
  execute v_new;
end $$;

-- Chat header: driver_card_json.available (same rule as the Chats list).
do $$
declare
  v_def text := pg_get_functiondef('public.driver_card_json(uuid, public.ride_requests, boolean)'::regprocedure);
  v_new text;
begin
  if v_def like '%driver_is_online%' then return; end if;
  v_new := replace(v_def,
    '''initials'',      public.person_initials(p.first_name, p.last_name),',
    '''initials'',      public.person_initials(p.first_name, p.last_name),
    ''available'',     public.driver_is_online(p.id),');
  if v_new = v_def then raise exception 'driver_card_json patch did not match'; end if;
  execute v_new;
end $$;
