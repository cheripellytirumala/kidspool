-- Report and block other users (App Store 1.2 / Google Play Child Safety:
-- an in-app way to report people and content, and to block them).
--
--   report_user(reported uuid, reason text, details text default null,
--               context text default null, context_id text default null,
--               message_id text default null, also_block boolean default false)
--     → {reportId, blocked}
--   block_user(target uuid)   → void
--   unblock_user(target uuid) → void
--   get_my_blocks()           → [{userId, name, initials, blockedAt}]
--
-- Reports are kept when either account is deleted: the reported person's
-- name and phone are copied in at report time, for the safety team and
-- the authorities. Blocks are only between the two accounts; the app
-- hides a blocked person's messages and family card.
--
-- Review reports (service role / SQL editor):
--   select * from public.user_reports where status = 'open' order by created_at;
--
-- Safe to re-run.

create table if not exists public.user_reports (
  id              uuid primary key default gen_random_uuid(),
  reporter_id     uuid references auth.users(id) on delete set null,
  reported_id     uuid references auth.users(id) on delete set null,
  reported_name   text,
  reported_phone  text,
  reason          text not null check (reason in (
                    'child_safety', 'harassment', 'inappropriate',
                    'unsafe_driving', 'spam', 'fake_profile', 'other')),
  details         text check (char_length(details) <= 1000),
  context         text check (context in ('group_chat', 'ride_chat', 'family', 'member')),
  context_id      text,
  message_id      text,
  status          text not null default 'open'
                    check (status in ('open', 'reviewing', 'actioned', 'dismissed')),
  created_at      timestamptz not null default now(),
  reviewed_at     timestamptz,
  review_notes    text
);
create index if not exists user_reports_status_idx on public.user_reports (status, created_at);
create index if not exists user_reports_reported_idx on public.user_reports (reported_id);

create table if not exists public.user_blocks (
  blocker_id  uuid not null references auth.users(id) on delete cascade,
  blocked_id  uuid not null references auth.users(id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
create index if not exists user_blocks_blocked_idx on public.user_blocks (blocked_id);

-- Only the functions below touch these tables.
alter table public.user_reports enable row level security;
alter table public.user_blocks  enable row level security;
revoke all on public.user_reports from anon, authenticated;
revoke all on public.user_blocks  from anon, authenticated;

create or replace function public.block_user(target uuid)
returns void
language plpgsql
security definer
set search_path to ''
as $fn$
declare v_me uuid := auth.uid();
begin
  if v_me is null then raise sqlstate 'PT401' using message = 'not_authenticated'; end if;
  if target is null or target = v_me then
    raise sqlstate 'PT400' using message = 'invalid_user';
  end if;
  insert into public.user_blocks (blocker_id, blocked_id)
  values (v_me, target)
  on conflict do nothing;
end;
$fn$;

create or replace function public.unblock_user(target uuid)
returns void
language plpgsql
security definer
set search_path to ''
as $fn$
declare v_me uuid := auth.uid();
begin
  if v_me is null then raise sqlstate 'PT401' using message = 'not_authenticated'; end if;
  delete from public.user_blocks where blocker_id = v_me and blocked_id = target;
end;
$fn$;

create or replace function public.get_my_blocks()
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $fn$
declare v_me uuid := auth.uid();
begin
  if v_me is null then raise sqlstate 'PT401' using message = 'not_authenticated'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'userId',    b.blocked_id,
             'name',      coalesce(nullif(btrim(p.first_name), ''), 'Parent'),
             'initials',  upper(left(coalesce(p.first_name, 'P'), 1) || left(coalesce(p.last_name, ''), 1)),
             'blockedAt', b.created_at) order by b.created_at desc)
      from public.user_blocks b
      left join public.profiles p on p.id = b.blocked_id
     where b.blocker_id = v_me
  ), '[]'::jsonb);
end;
$fn$;

create or replace function public.report_user(
  reported   uuid,
  reason     text,
  details    text    default null,
  context    text    default null,
  context_id text    default null,
  message_id text    default null,
  also_block boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $fn$
declare
  v_me     uuid := auth.uid();
  v_id     uuid;
  v_name   text;
  v_phone  text;
begin
  if v_me is null then raise sqlstate 'PT401' using message = 'not_authenticated'; end if;
  if reported is null or reported = v_me then
    raise sqlstate 'PT400' using message = 'invalid_user';
  end if;
  -- At most 20 reports an hour per person (stops flooding).
  if (select count(*) from public.user_reports r
       where r.reporter_id = v_me and r.created_at > now() - interval '1 hour') >= 20 then
    raise sqlstate 'PT429' using message = 'too_many_reports';
  end if;

  select btrim(concat_ws(' ', p.first_name, p.last_name)), u.phone
    into v_name, v_phone
    from auth.users u
    left join public.profiles p on p.id = u.id
   where u.id = reported;
  if not found then raise sqlstate 'PT404' using message = 'user_not_found'; end if;

  insert into public.user_reports
    (reporter_id, reported_id, reported_name, reported_phone,
     reason, details, context, context_id, message_id)
  values
    (v_me, reported, nullif(v_name, ''), v_phone,
     report_user.reason, nullif(btrim(report_user.details), ''),
     report_user.context, report_user.context_id, report_user.message_id)
  returning id into v_id;

  if also_block then
    insert into public.user_blocks (blocker_id, blocked_id)
    values (v_me, reported)
    on conflict do nothing;
  end if;

  return jsonb_build_object('reportId', v_id, 'blocked', also_block);
end;
$fn$;

revoke all on function public.block_user(uuid)   from public, anon;
revoke all on function public.unblock_user(uuid) from public, anon;
revoke all on function public.get_my_blocks()    from public, anon;
revoke all on function public.report_user(uuid, text, text, text, text, text, boolean) from public, anon;
grant execute on function public.block_user(uuid)   to authenticated;
grant execute on function public.unblock_user(uuid) to authenticated;
grant execute on function public.get_my_blocks()    to authenticated;
grant execute on function public.report_user(uuid, text, text, text, text, text, boolean) to authenticated;

notify pgrst, 'reload schema';
