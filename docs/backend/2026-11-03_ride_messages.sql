-- Ride chat (Messages tab, F24/F24a/F19) between a ride's parent and a Ride
-- Partner. Based on the old project's draft 20261026120000_ride_messages.sql,
-- tightened:
--   * open requests: only parents the request was sent to
--     (ride_request_notifications) can start a chat — not any signed-in user;
--   * errors use the PT401/PT403 codes the app maps to messages;
--   * no default PUBLIC/anon execute on the new functions.
-- A chat is (request, driver). Apply in Supabase → SQL editor,
-- project cojraqxramlirnepncrd.

begin;

create table if not exists public.ride_messages (
  id          uuid primary key default gen_random_uuid(),
  request_id  uuid not null references public.ride_requests (id) on delete cascade,
  driver_id   uuid not null references public.profiles (id) on delete cascade,
  sender_id   uuid not null references public.profiles (id) on delete cascade,
  body        text not null check (length(btrim(body)) between 1 and 2000),
  created_at  timestamptz not null default now(),
  read_at     timestamptz
);

create index if not exists ride_messages_chat_idx
  on public.ride_messages (request_id, driver_id, created_at);
create index if not exists ride_messages_driver_idx
  on public.ride_messages (driver_id, created_at desc);

alter table public.ride_messages enable row level security;

-- Either end of the chat can read it; writes only via send_ride_message.
drop policy if exists ride_messages_select on public.ride_messages;
create policy ride_messages_select on public.ride_messages
  for select to authenticated
  using (
    driver_id = (select auth.uid())
    or exists (select 1 from public.ride_requests rr
                where rr.id = request_id and rr.parent_id = (select auth.uid()))
  );

-- Whether p_uid may chat in (p_request, p_driver).
create or replace function public.can_ride_chat(p_uid uuid, p_request uuid, p_driver uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.ride_requests rr
     where rr.id = p_request
       and rr.status not in ('cancelled', 'expired')
       and (rr.parent_id = p_uid or p_driver = p_uid)
       and p_driver <> rr.parent_id
       and (rr.driver_id = p_driver
            or exists (select 1 from public.ride_offers o
                        where o.request_id = rr.id and o.driver_id = p_driver)
            or (rr.status = 'open'
                and exists (select 1 from public.ride_request_notifications n
                             where n.request_id = rr.id and n.driver_id = p_driver)))
  );
$$;

create or replace function public.send_ride_message("requestId" uuid, "driverId" uuid, body text)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  m public.ride_messages;
begin
  if v_uid is null then raise sqlstate 'PT401' using message = 'not_authenticated'; end if;
  if body is null or length(btrim(body)) not between 1 and 2000 then
    raise sqlstate 'PT400' using message = 'invalid_field', detail = 'body (1–2000 characters)';
  end if;
  if not public.can_ride_chat(v_uid, "requestId", "driverId") then
    raise sqlstate 'PT403' using message = 'cannot_message';
  end if;
  insert into public.ride_messages (request_id, driver_id, sender_id, body)
  values ("requestId", "driverId", v_uid, btrim(body))
  returning * into m;
  return jsonb_build_object('id', m.id, 'senderId', m.sender_id,
                            'body', m.body, 'createdAt', m.created_at);
end;
$$;

-- One chat, oldest first; marks the other side's messages read.
create or replace function public.get_ride_messages("requestId" uuid, "driverId" uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then raise sqlstate 'PT401' using message = 'not_authenticated'; end if;
  if not public.can_ride_chat(v_uid, "requestId", "driverId") then
    raise sqlstate 'PT403' using message = 'cannot_message';
  end if;
  update public.ride_messages set read_at = now()
   where request_id = "requestId" and driver_id = "driverId"
     and sender_id <> v_uid and read_at is null;
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', m.id, 'senderId', m.sender_id,
                                        'body', m.body, 'createdAt', m.created_at,
                                        'readAt', m.read_at)
                     order by m.created_at)
      from public.ride_messages m
     where m.request_id = "requestId" and m.driver_id = "driverId"), '[]'::jsonb);
end;
$$;

-- The Messages tab: each chat the user is in, newest first.
create or replace function public.get_my_ride_chats()
returns jsonb
language sql stable security definer set search_path = ''
as $$
  with mine as (
    select m.request_id, m.driver_id,
           max(m.created_at) as last_at,
           count(*) filter (where m.sender_id <> auth.uid() and m.read_at is null)::int as unread
      from public.ride_messages m
      join public.ride_requests rr on rr.id = m.request_id
     where m.driver_id = auth.uid() or rr.parent_id = auth.uid()
     group by m.request_id, m.driver_id
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'requestId', c.request_id,
           'driverId',  c.driver_id,
           'iAmDriver', c.driver_id = auth.uid(),
           'status',    rr.status,
           'other',     jsonb_build_object('id', p.id, 'firstName', p.first_name,
                                           'initials', public.person_initials(p.first_name, p.last_name)),
           'lastMessage', (select m.body from public.ride_messages m
                            where m.request_id = c.request_id and m.driver_id = c.driver_id
                            order by m.created_at desc limit 1),
           'lastAt',    c.last_at,
           'unread',    c.unread)
         order by c.last_at desc), '[]'::jsonb)
    from mine c
    join public.ride_requests rr on rr.id = c.request_id
    join public.profiles p
      on p.id = case when c.driver_id = auth.uid() then rr.parent_id else c.driver_id end;
$$;

revoke all on function public.can_ride_chat(uuid, uuid, uuid) from public, anon, authenticated;
revoke all on function public.send_ride_message(uuid, uuid, text) from public, anon;
revoke all on function public.get_ride_messages(uuid, uuid) from public, anon;
revoke all on function public.get_my_ride_chats() from public, anon;
grant execute on function public.send_ride_message(uuid, uuid, text) to authenticated;
grant execute on function public.get_ride_messages(uuid, uuid) to authenticated;
grant execute on function public.get_my_ride_chats() to authenticated;

commit;

notify pgrst, 'reload schema';
