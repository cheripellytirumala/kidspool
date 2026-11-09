-- Ride groups: a standing set of up to 8 families with one shared chat.
-- Plan: docs/plans/2026-11-09_group_ride_chats.md (phases 1–2, chat only).
--
-- Access is only through the SECURITY DEFINER functions below (same pattern
-- as the ride chat RPCs): the tables have RLS on and no client grants.
-- Every function checks auth.uid() and group membership itself.
--
-- Who can join: an approved parent who shares a school with the member adding
-- them, or whose default home is within 10 miles of theirs. Any member can
-- add parents. Members see first names, initials and kids' first names only.
--
-- Safe to re-run.

-- ───────────────────────────── tables ─────────────────────────────

create table if not exists public.ride_groups (
  id         uuid primary key default gen_random_uuid(),
  name       text not null check (char_length(btrim(name)) between 1 and 60),
  school_id  uuid references public.schools (id) on delete set null,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ride_group_members (
  group_id     uuid not null references public.ride_groups (id) on delete cascade,
  user_id      uuid not null references public.profiles (id) on delete cascade,
  role         text not null default 'member' check (role in ('owner', 'member')),
  muted        boolean not null default false,
  joined_at    timestamptz not null default now(),
  last_read_at timestamptz not null default now(),
  primary key (group_id, user_id)
);
create index if not exists ride_group_members_user_idx on public.ride_group_members (user_id);

create table if not exists public.group_messages (
  id         uuid primary key default gen_random_uuid(),
  group_id   uuid not null references public.ride_groups (id) on delete cascade,
  sender_id  uuid references public.profiles (id) on delete set null,
  kind       text not null default 'text' check (kind in ('text', 'system')),
  body       text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default now()
);
create index if not exists group_messages_group_created_idx
  on public.group_messages (group_id, created_at desc);

alter table public.ride_groups        enable row level security;
alter table public.ride_group_members enable row level security;
alter table public.group_messages     enable row level security;
revoke all on public.ride_groups, public.ride_group_members, public.group_messages
  from anon, authenticated;

-- ───────────────────────────── helpers ─────────────────────────────

create or replace function public.ride_group_max_members()
returns int language sql immutable set search_path = '' as $$ select 8 $$;

-- Raises unless the caller is signed in and a member of the group.
create or replace function public.require_group_member(p_group uuid)
returns uuid
language plpgsql stable security definer set search_path = ''
as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise sqlstate 'PT401' using message = 'not_authenticated'; end if;
  if not exists (select 1 from public.ride_group_members m
                  where m.group_id = p_group and m.user_id = v_uid) then
    raise sqlstate 'PT404' using message = 'group_not_found';
  end if;
  return v_uid;
end;
$$;

-- Can p_adder add p_target? Approved parent, and shares a school with the
-- adder or lives within 10 miles of them.
create or replace function public.can_add_to_ride_group(p_adder uuid, p_target uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select p_target <> p_adder
     and exists (select 1 from public.profiles p
                  where p.id = p_target and p.role::text = 'parent'
                    and p.onboarding_status::text = 'approved')
     and (
       exists (select 1 from public.kids a join public.kids b on b.school_id = a.school_id
                where a.parent_id = p_adder and b.parent_id = p_target)
       or exists (select 1 from public.addresses a, public.addresses b
                   where a.user_id = p_adder and a.is_default
                     and b.user_id = p_target and b.is_default
                     and extensions.st_dwithin(a.location, b.location, 16093.4))
     );
$$;

-- Adds members (skipping existing ones). Checks the cap and who may join.
create or replace function public.add_ride_group_members_internal(
  p_group uuid, p_adder uuid, p_members uuid[])
returns int
language plpgsql security definer set search_path = ''
as $$
declare
  v_id uuid;
  v_added int := 0;
  v_names text[] := '{}';
  v_count int;
begin
  foreach v_id in array coalesce(p_members, '{}') loop
    continue when exists (select 1 from public.ride_group_members m
                           where m.group_id = p_group and m.user_id = v_id);
    if not public.can_add_to_ride_group(p_adder, v_id) then
      raise sqlstate 'PT403' using message = 'cannot_add_member', detail = v_id::text;
    end if;
    select count(*) into v_count from public.ride_group_members m where m.group_id = p_group;
    if v_count >= public.ride_group_max_members() then
      raise sqlstate 'PT409' using message = 'group_full';
    end if;
    insert into public.ride_group_members (group_id, user_id) values (p_group, v_id);
    v_names := v_names || (select coalesce(p.first_name, 'A parent') from public.profiles p where p.id = v_id);
    v_added := v_added + 1;
  end loop;
  if v_added > 0 then
    insert into public.group_messages (group_id, sender_id, kind, body)
    values (p_group, null, 'system',
            (select coalesce(p.first_name, 'A parent') from public.profiles p where p.id = p_adder)
            || ' added ' || array_to_string(v_names, ', '));
    update public.ride_groups set updated_at = now() where id = p_group;
  end if;
  return v_added;
end;
$$;

-- Member list JSON for a group.
create or replace function public.ride_group_members_json(p_group uuid)
returns jsonb
language sql stable security definer set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id',        p.id,
           'firstName', coalesce(p.first_name, ''),
           'initials',  public.person_initials(p.first_name, p.last_name),
           'role',      m.role,
           'isMe',      p.id = auth.uid(),
           'kids',      (select coalesce(jsonb_agg(k.first_name order by k.first_name), '[]'::jsonb)
                           from public.kids k where k.parent_id = p.id))
         order by (m.role = 'owner') desc, m.joined_at), '[]'::jsonb)
    from public.ride_group_members m
    join public.profiles p on p.id = m.user_id
   where m.group_id = p_group;
$$;

-- ───────────────────────────── RPCs ─────────────────────────────

-- create_ride_group(name, memberIds, schoolId?) → {id}
create or replace function public.create_ride_group(
  name text, "memberIds" uuid[], "schoolId" uuid default null)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_id  uuid;
begin
  if v_uid is null then raise sqlstate 'PT401' using message = 'not_authenticated'; end if;
  if name is null or char_length(btrim(name)) not between 1 and 60 then
    raise sqlstate 'PT400' using message = 'invalid_field', detail = 'name (1–60 characters)';
  end if;
  if coalesce(array_length("memberIds", 1), 0) = 0 then
    raise sqlstate 'PT400' using message = 'invalid_field', detail = 'memberIds';
  end if;
  if coalesce(array_length("memberIds", 1), 0) + 1 > public.ride_group_max_members() then
    raise sqlstate 'PT409' using message = 'group_full';
  end if;

  insert into public.ride_groups (name, school_id, created_by)
  values (btrim(create_ride_group.name), "schoolId", v_uid) returning id into v_id;
  insert into public.ride_group_members (group_id, user_id, role) values (v_id, v_uid, 'owner');
  insert into public.group_messages (group_id, sender_id, kind, body)
  values (v_id, null, 'system',
          (select coalesce(p.first_name, 'A parent') from public.profiles p where p.id = v_uid)
          || ' created the group');
  perform public.add_ride_group_members_internal(v_id, v_uid, "memberIds");
  return jsonb_build_object('id', v_id);
end;
$$;

-- add_ride_group_members(groupId, memberIds) → {added}. Any member can add.
create or replace function public.add_ride_group_members("groupId" uuid, "memberIds" uuid[])
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare v_uid uuid := public.require_group_member("groupId");
begin
  return jsonb_build_object('added',
    public.add_ride_group_members_internal("groupId", v_uid, "memberIds"));
end;
$$;

-- leave_ride_group(groupId). The last member leaving deletes the group.
create or replace function public.leave_ride_group("groupId" uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
declare v_uid uuid := public.require_group_member("groupId");
begin
  delete from public.ride_group_members where group_id = "groupId" and user_id = v_uid;
  if not exists (select 1 from public.ride_group_members where group_id = "groupId") then
    delete from public.ride_groups where id = "groupId";
    return;
  end if;
  -- Keep an owner.
  if not exists (select 1 from public.ride_group_members where group_id = "groupId" and role = 'owner') then
    update public.ride_group_members set role = 'owner'
     where group_id = "groupId"
       and user_id = (select user_id from public.ride_group_members
                       where group_id = "groupId" order by joined_at limit 1);
  end if;
  insert into public.group_messages (group_id, sender_id, kind, body)
  values ("groupId", null, 'system',
          (select coalesce(p.first_name, 'A parent') from public.profiles p where p.id = v_uid) || ' left');
end;
$$;

-- rename_ride_group(groupId, name)
create or replace function public.rename_ride_group("groupId" uuid, name text)
returns void
language plpgsql security definer set search_path = ''
as $$
declare v_uid uuid := public.require_group_member("groupId");
begin
  if name is null or char_length(btrim(name)) not between 1 and 60 then
    raise sqlstate 'PT400' using message = 'invalid_field', detail = 'name (1–60 characters)';
  end if;
  update public.ride_groups set name = btrim(rename_ride_group.name), updated_at = now()
   where id = "groupId";
  insert into public.group_messages (group_id, sender_id, kind, body)
  values ("groupId", null, 'system',
          (select coalesce(p.first_name, 'A parent') from public.profiles p where p.id = v_uid)
          || ' renamed the group to “' || btrim(rename_ride_group.name) || '”');
end;
$$;

-- set_ride_group_muted(groupId, muted) — only for the caller.
create or replace function public.set_ride_group_muted("groupId" uuid, muted boolean)
returns void
language plpgsql security definer set search_path = ''
as $$
declare v_uid uuid := public.require_group_member("groupId");
begin
  update public.ride_group_members set muted = coalesce(set_ride_group_muted.muted, false)
   where group_id = "groupId" and user_id = v_uid;
end;
$$;

-- get_my_ride_groups() → [{id, name, memberCount, unread, muted, lastMessage, lastAt}]
create or replace function public.get_my_ride_groups()
returns jsonb
language sql stable security definer set search_path = ''
as $$
  select coalesce(jsonb_agg(row_to_json(t)::jsonb order by t."lastAt" desc nulls last), '[]'::jsonb)
    from (
      select g.id,
             g.name,
             (select count(*) from public.ride_group_members x where x.group_id = g.id)::int as "memberCount",
             (select count(*) from public.group_messages gm
               where gm.group_id = g.id and gm.created_at > me.last_read_at
                 and gm.sender_id is distinct from auth.uid()
                 and gm.kind = 'text')::int as unread,
             me.muted,
             (select case when gm.kind = 'system' then gm.body
                          else coalesce(p.first_name, 'Someone') || ': ' || gm.body end
                from public.group_messages gm left join public.profiles p on p.id = gm.sender_id
               where gm.group_id = g.id order by gm.created_at desc limit 1) as "lastMessage",
             coalesce((select max(gm.created_at) from public.group_messages gm where gm.group_id = g.id),
                      g.created_at) as "lastAt"
        from public.ride_group_members me
        join public.ride_groups g on g.id = me.group_id
       where me.user_id = auth.uid()
    ) t;
$$;

-- get_ride_group(groupId) → {id, name, schoolName, muted, maxMembers, members:[…]}
create or replace function public.get_ride_group("groupId" uuid)
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare v_uid uuid := public.require_group_member("groupId");
begin
  return (
    select jsonb_build_object(
             'id', g.id, 'name', g.name,
             'schoolName', s.name,
             'muted', (select m.muted from public.ride_group_members m
                        where m.group_id = g.id and m.user_id = v_uid),
             'maxMembers', public.ride_group_max_members(),
             'members', public.ride_group_members_json(g.id))
      from public.ride_groups g left join public.schools s on s.id = g.school_id
     where g.id = "groupId");
end;
$$;

-- get_ride_group_messages(groupId, before?) → newest 50 before `before`, oldest first.
create or replace function public.get_ride_group_messages("groupId" uuid, before timestamptz default null)
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare v_uid uuid := public.require_group_member("groupId");
begin
  return (
    select coalesce(jsonb_agg(jsonb_build_object(
             'id', t.id, 'kind', t.kind, 'body', t.body, 'createdAt', t.created_at,
             'sender', case when t.sender_id is null then null else jsonb_build_object(
                         'id', t.sender_id, 'firstName', coalesce(t.first_name, ''),
                         'initials', public.person_initials(t.first_name, t.last_name)) end)
           order by t.created_at), '[]'::jsonb)
      from (
        select gm.*, p.first_name, p.last_name
          from public.group_messages gm left join public.profiles p on p.id = gm.sender_id
         where gm.group_id = "groupId"
           and (get_ride_group_messages.before is null or gm.created_at < get_ride_group_messages.before)
         order by gm.created_at desc
         limit 50
      ) t);
end;
$$;

-- send_ride_group_message(groupId, body) → the message.
create or replace function public.send_ride_group_message("groupId" uuid, body text)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := public.require_group_member("groupId");
  m public.group_messages;
begin
  if body is null or char_length(btrim(body)) not between 1 and 2000 then
    raise sqlstate 'PT400' using message = 'invalid_field', detail = 'body (1–2000 characters)';
  end if;
  insert into public.group_messages (group_id, sender_id, body)
  values ("groupId", v_uid, btrim(body)) returning * into m;
  update public.ride_group_members set last_read_at = now()
   where group_id = "groupId" and user_id = v_uid;
  return (select jsonb_build_object(
            'id', m.id, 'kind', m.kind, 'body', m.body, 'createdAt', m.created_at,
            'sender', jsonb_build_object('id', p.id, 'firstName', coalesce(p.first_name, ''),
                                         'initials', public.person_initials(p.first_name, p.last_name)))
            from public.profiles p where p.id = v_uid);
end;
$$;

-- mark_ride_group_read(groupId)
create or replace function public.mark_ride_group_read("groupId" uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
declare v_uid uuid := public.require_group_member("groupId");
begin
  update public.ride_group_members set last_read_at = now()
   where group_id = "groupId" and user_id = v_uid;
end;
$$;

-- get_ride_group_candidates(groupId?) → parents the caller may add
-- [{id, firstName, initials, kids:[…], sharedSchool}] (excludes current members).
create or replace function public.get_ride_group_candidates("groupId" uuid default null)
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise sqlstate 'PT401' using message = 'not_authenticated'; end if;
  if "groupId" is not null then perform public.require_group_member("groupId"); end if;
  return (
    select coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'firstName', coalesce(p.first_name, ''),
             'initials', public.person_initials(p.first_name, p.last_name),
             'kids', (select coalesce(jsonb_agg(k.first_name order by k.first_name), '[]'::jsonb)
                        from public.kids k where k.parent_id = p.id))
           order by p.first_name), '[]'::jsonb)
      from public.profiles p
     where public.can_add_to_ride_group(v_uid, p.id)
       and ("groupId" is null or not exists (
             select 1 from public.ride_group_members m
              where m.group_id = "groupId" and m.user_id = p.id)));
end;
$$;

-- ───────────────────────────── grants ─────────────────────────────

do $$
declare f text;
begin
  foreach f in array array[
    'public.ride_group_max_members()',
    'public.require_group_member(uuid)',
    'public.can_add_to_ride_group(uuid, uuid)',
    'public.add_ride_group_members_internal(uuid, uuid, uuid[])',
    'public.ride_group_members_json(uuid)'
  ] loop
    execute format('revoke execute on function %s from public, anon, authenticated', f);
  end loop;
  foreach f in array array[
    'public.create_ride_group(text, uuid[], uuid)',
    'public.add_ride_group_members(uuid, uuid[])',
    'public.leave_ride_group(uuid)',
    'public.rename_ride_group(uuid, text)',
    'public.set_ride_group_muted(uuid, boolean)',
    'public.get_my_ride_groups()',
    'public.get_ride_group(uuid)',
    'public.get_ride_group_messages(uuid, timestamptz)',
    'public.send_ride_group_message(uuid, text)',
    'public.mark_ride_group_read(uuid)',
    'public.get_ride_group_candidates(uuid)'
  ] loop
    execute format('revoke execute on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;

notify pgrst, 'reload schema';
