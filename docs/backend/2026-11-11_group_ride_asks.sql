-- Ride asks in group chats: the ride request is created only when a
-- driver taps "I can help".
--
-- Before: asking for a ride in a group created the ride request right away
-- (it showed as "1 upcoming ride · Asking parents" with nobody driving).
-- Now:
--   post_ride_ask(groupId, rides, summary)
--       The parent posts the ride as a card in the group. Nothing is
--       created yet; the ride is only checked (date, time, places, kids).
--   get_group_ride_asks(groupId)
--       The cards in a group, so the app can show "I can help" on them.
--   help_with_ride_ask(askId)
--       A driver in the group taps "I can help": the ride request is
--       created for the parent and the driver's offer books it at once
--       (no approval step; see 2026-11-11_ride_ask_auto_approve.sql). If anything
--       fails (the driver isn't eligible, the time has passed…) nothing
--       is created.
--   cancel_ride_ask(askId)
--       The parent withdraws an ask nobody has taken.
--
-- `rides` is a list of create_ride_request arguments, one per day:
--   [{kidIds, pickupDate, pickupTime, timeZone, pickupAddressId,
--     pickupAddress, note, dropoffAddress}, ...]
--
-- NOTE: dev, staging and production share project cojraqxramlirnepncrd.
-- Safe to re-run.

begin;

create table if not exists public.ride_asks (
  id          uuid primary key default gen_random_uuid(),
  group_id    uuid not null references public.ride_groups(id) on delete cascade,
  parent_id   uuid not null references public.profiles(id) on delete cascade,
  message_id  uuid references public.group_messages(id) on delete set null,
  rides       jsonb not null,
  summary     text not null,
  status      text not null default 'open'
              check (status in ('open', 'taken', 'cancelled')),
  helper_id   uuid references public.profiles(id) on delete set null,
  request_ids uuid[] not null default '{}',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists ride_asks_group_idx on public.ride_asks (group_id, created_at desc);

-- Only reachable through the functions below.
alter table public.ride_asks enable row level security;
revoke all on public.ride_asks from anon, authenticated;

-- One card as JSON for the caller.
create or replace function public.ride_ask_json(a public.ride_asks, p_uid uuid)
returns jsonb
language sql
stable
security definer
set search_path to ''
as $fn$
  select jsonb_build_object(
    'id',         a.id,
    'messageId',  a.message_id,
    'isMine',     a.parent_id = p_uid,
    'isHelper',   a.helper_id is not null and a.helper_id = p_uid,
    'status',     a.status,
    'summary',    a.summary,
    'days',       jsonb_array_length(a.rides),
    'requestIds', to_jsonb(a.request_ids),
    'rideStatus', (select r.status::text from public.ride_requests r
                    where r.id = a.request_ids[1]),
    'helperName', (select coalesce(nullif(h.first_name, ''), 'A parent')
                     from public.profiles h where h.id = a.helper_id),
    -- "I can help" for approved drivers other than the parent.
    'canHelp',    a.status = 'open' and a.parent_id <> p_uid
                  and exists (select 1 from public.profiles d
                               where d.id = p_uid and d.role = 'parent'
                                 and d.onboarding_status = 'approved'
                                 and d.driver_status = 'approved'),
    'createdAt',  a.created_at);
$fn$;
revoke all on function public.ride_ask_json(public.ride_asks, uuid) from public, anon, authenticated;

-- Parent: post a ride ask in a group. -------------------------------------
create or replace function public.post_ride_ask("groupId" uuid, rides jsonb, summary text)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $fn$
declare
  v_uid  uuid := public.require_group_member("groupId");
  v_ride jsonb;
  v_msg  jsonb;
  v_ask  public.ride_asks;
begin
  if rides is null or jsonb_typeof(rides) <> 'array'
     or jsonb_array_length(rides) not between 1 and 20 then
    raise sqlstate 'PT400' using message = 'invalid_field', detail = 'rides (1–20 days)';
  end if;

  -- Check every day now, so the parent hears about problems at once.
  for v_ride in select * from jsonb_array_elements(rides) loop
    perform public.ride_build_plan(
      v_uid,
      array(select jsonb_array_elements_text(v_ride->'kidIds'))::uuid[],
      (v_ride->>'pickupDate')::date,
      v_ride->>'pickupTime',
      v_ride->>'timeZone',
      nullif(v_ride->>'pickupAddressId', '')::uuid,
      case when jsonb_typeof(v_ride->'pickupAddress') = 'object' then v_ride->'pickupAddress' end,
      case when jsonb_typeof(v_ride->'dropoffAddress') = 'object' then v_ride->'dropoffAddress' end);
  end loop;

  v_msg := public.send_ride_group_message("groupId", summary);

  insert into public.ride_asks (group_id, parent_id, message_id, rides, summary)
  values ("groupId", v_uid, (v_msg->>'id')::uuid, rides, btrim(summary))
  returning * into v_ask;

  return v_msg || jsonb_build_object('rideAsk', public.ride_ask_json(v_ask, v_uid));
end;
$fn$;

-- Anyone in the group: the asks shown as cards. ----------------------------
create or replace function public.get_group_ride_asks("groupId" uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $fn$
declare
  v_uid uuid := public.require_group_member("groupId");
begin
  return coalesce((
    select jsonb_agg(public.ride_ask_json(a, v_uid) order by a.created_at)
      from public.ride_asks a
     where a.group_id = "groupId"
       and a.created_at > now() - interval '60 days'
  ), '[]'::jsonb);
end;
$fn$;

-- Driver: "I can help". ------------------------------------------------------
create or replace function public.help_with_ride_ask("askId" uuid)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $fn$
declare
  v_uid     uuid := auth.uid();
  v_ask     public.ride_asks;
  v_claims  text := current_setting('request.jwt.claims', true);
  v_sub     text := current_setting('request.jwt.claim.sub', true);
  v_ride    jsonb;
  v_created jsonb;
  v_ids     uuid[] := '{}';
  v_id      uuid;
begin
  perform public.require_driver(v_uid);

  select * into v_ask from public.ride_asks a where a.id = "askId" for update;
  if not found then raise sqlstate 'PT404' using message = 'ride_ask_not_found'; end if;
  perform public.require_group_member(v_ask.group_id);
  if v_ask.parent_id = v_uid then raise sqlstate 'PT409' using message = 'own_request'; end if;
  if v_ask.status = 'taken' then raise sqlstate 'PT409' using message = 'already_taken'; end if;
  if v_ask.status <> 'open' then raise sqlstate 'PT409' using message = 'request_not_open'; end if;

  -- Create the request(s) as the parent who asked (books on first offer).
  perform set_config('request.jwt.claims',
                     jsonb_build_object('sub', v_ask.parent_id::text, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', v_ask.parent_id::text, true);
  for v_ride in select * from jsonb_array_elements(v_ask.rides) loop
    v_created := public.create_ride_request(
      array(select jsonb_array_elements_text(v_ride->'kidIds'))::uuid[],
      (v_ride->>'pickupDate')::date,
      v_ride->>'pickupTime',
      v_ride->>'timeZone',
      nullif(v_ride->>'pickupAddressId', '')::uuid,
      case when jsonb_typeof(v_ride->'pickupAddress') = 'object' then v_ride->'pickupAddress' end,
      v_ride->>'note',
      false,
      false,
      case when jsonb_typeof(v_ride->'dropoffAddress') = 'object' then v_ride->'dropoffAddress' end);
    v_ids := v_ids || array(
      select (r->>'id')::uuid from jsonb_array_elements(v_created->'requests') r);
  end loop;

  -- Back to the driver: offer on every day just created.
  perform set_config('request.jwt.claims', coalesce(v_claims, ''), true);
  perform set_config('request.jwt.claim.sub', coalesce(v_sub, ''), true);
  foreach v_id in array v_ids loop
    perform public.offer_ride(v_id, 'this');
  end loop;

  update public.ride_asks
     set status = 'taken', helper_id = v_uid, request_ids = v_ids, updated_at = now()
   where id = v_ask.id
  returning * into v_ask;

  perform public.send_ride_group_message(v_ask.group_id, 'I can help with this ride 🙌');

  return jsonb_build_object(
    'status',     'confirmed',
    'requestIds', to_jsonb(v_ids),
    'rideAsk',    public.ride_ask_json(v_ask, v_uid));
end;
$fn$;

-- Parent: withdraw an ask nobody has taken. --------------------------------
create or replace function public.cancel_ride_ask("askId" uuid)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_ask public.ride_asks;
begin
  if v_uid is null then raise sqlstate 'PT401' using message = 'not_authenticated'; end if;
  update public.ride_asks a
     set status = 'cancelled', updated_at = now()
   where a.id = "askId" and a.parent_id = v_uid and a.status = 'open'
  returning * into v_ask;
  if not found then raise sqlstate 'PT404' using message = 'ride_ask_not_found'; end if;
  return public.ride_ask_json(v_ask, v_uid);
end;
$fn$;

revoke all on function public.post_ride_ask(uuid, jsonb, text) from public, anon;
revoke all on function public.get_group_ride_asks(uuid) from public, anon;
revoke all on function public.help_with_ride_ask(uuid) from public, anon;
revoke all on function public.cancel_ride_ask(uuid) from public, anon;
grant execute on function public.post_ride_ask(uuid, jsonb, text) to authenticated;
grant execute on function public.get_group_ride_asks(uuid) to authenticated;
grant execute on function public.help_with_ride_ask(uuid) to authenticated;
grant execute on function public.cancel_ride_ask(uuid) to authenticated;

commit;

notify pgrst, 'reload schema';
