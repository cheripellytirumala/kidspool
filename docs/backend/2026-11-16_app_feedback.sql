-- In-app feedback: problems people hit and ideas to improve KidsPool.
-- Stored for the team to study. (Reports about *people* go to
-- user_reports instead, see 2026-11-16_reports_and_blocks.sql.)
--
--   submit_app_feedback(kind text, message text, rating int default null,
--                       area text default null, app_version text default null,
--                       platform text default null, os_version text default null)
--     → {feedbackId}
--
-- Study it (SQL editor / service role):
--   select kind, area, rating, message, app_version, platform, created_at
--     from public.app_feedback order by created_at desc;
--   select kind, area, count(*), round(avg(rating), 1) avg_rating
--     from public.app_feedback group by 1, 2 order by 3 desc;
--
-- Email: after saving, the app calls the notify-feedback Edge Function
-- (with the screenshots, if any), which stores the attachments, then emails
-- every not-yet-emailed row to the team (FEEDBACK_EMAIL_TO, default
-- ebountibusiness@gmail.com) through Resend and sets notified_at.
--
-- Safe to re-run.

create table if not exists public.app_feedback (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid references auth.users(id) on delete set null,
  kind         text not null check (kind in ('problem', 'idea', 'praise', 'other')),
  area         text check (area in ('sign_up', 'kids', 'ask_ride', 'families',
                                     'messages', 'live_ride', 'driving', 'profile', 'other')),
  message      text not null check (char_length(btrim(message)) between 3 and 2000),
  rating       smallint check (rating between 1 and 5),
  app_version  text check (char_length(app_version) <= 40),
  platform     text check (platform in ('ios', 'android', 'other')),
  os_version   text check (char_length(os_version) <= 120),
  -- Team workflow while studying the feedback.
  status       text not null default 'new'
                 check (status in ('new', 'reviewed', 'planned', 'done', 'wont_do')),
  team_notes   text,
  -- Set by the notify-feedback Edge Function once emailed to the team.
  notified_at  timestamptz,
  created_at   timestamptz not null default now()
);
-- (Re-run safe for tables created before this column existed.)
alter table public.app_feedback add column if not exists notified_at timestamptz;
create index if not exists app_feedback_unnotified_idx
  on public.app_feedback (created_at) where notified_at is null;
-- Screenshots / photos: up to 3 storage paths in the private
-- feedback-attachments bucket ("<user id>/<feedback id>/<n>.jpg"). Only the
-- notify-feedback Edge Function (service role) reads or writes them.
alter table public.app_feedback add column if not exists attachments text[] not null default '{}';
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('feedback-attachments', 'feedback-attachments', false, 2097152,
        array['image/jpeg', 'image/png', 'image/heic'])
on conflict (id) do nothing;

create index if not exists app_feedback_created_idx on public.app_feedback (created_at desc);
create index if not exists app_feedback_kind_idx on public.app_feedback (kind, status);

-- Only the function below writes; nobody reads through the API.
alter table public.app_feedback enable row level security;
revoke all on public.app_feedback from anon, authenticated;

create or replace function public.submit_app_feedback(
  kind        text,
  message     text,
  rating      int  default null,
  area        text default null,
  app_version text default null,
  platform    text default null,
  os_version  text default null
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $fn$
declare
  v_me uuid := auth.uid();
  v_id uuid;
begin
  if v_me is null then raise sqlstate 'PT401' using message = 'not_authenticated'; end if;
  if char_length(btrim(coalesce(submit_app_feedback.message, ''))) < 3 then
    raise sqlstate 'PT400' using message = 'message_too_short';
  end if;
  -- At most 10 a hour per person.
  if (select count(*) from public.app_feedback f
       where f.user_id = v_me and f.created_at > now() - interval '1 hour') >= 10 then
    raise sqlstate 'PT429' using message = 'too_much_feedback';
  end if;

  insert into public.app_feedback
    (user_id, kind, area, message, rating, app_version, platform, os_version)
  values
    (v_me, submit_app_feedback.kind, submit_app_feedback.area,
     btrim(submit_app_feedback.message), submit_app_feedback.rating,
     left(submit_app_feedback.app_version, 40), submit_app_feedback.platform,
     left(submit_app_feedback.os_version, 120))
  returning id into v_id;

  return jsonb_build_object('feedbackId', v_id);
end;
$fn$;

revoke all on function public.submit_app_feedback(text, text, int, text, text, text, text) from public, anon;
grant execute on function public.submit_app_feedback(text, text, int, text, text, text, text) to authenticated;

notify pgrst, 'reload schema';
