-- S18 Profile: per-user settings (How far I'll drive, Who can message me,
-- Let parents call me, Arrival alerts) and saving "My car".
-- Applied to the live project on 2026-11-09. Values are stored only; matching,
-- calls and alerts don't read them yet.

create table if not exists public.user_settings (
  user_id            uuid primary key references public.profiles (id) on delete cascade,
  drive_radius_miles smallint not null default 10
                       check (drive_radius_miles between 1 and 50),
  who_can_message    text not null default 'school_families'
                       check (who_can_message in ('school_families', 'ride_groups', 'nearby_families')),
  allow_calls        boolean not null default false,
  arrival_alerts     boolean not null default true,
  updated_at         timestamptz not null default now()
);

alter table public.user_settings enable row level security;

revoke all on public.user_settings from anon;
grant select, insert, update on public.user_settings to authenticated;

drop policy if exists "Users read their settings" on public.user_settings;
create policy "Users read their settings" on public.user_settings
  for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users create their settings" on public.user_settings;
create policy "Users create their settings" on public.user_settings
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users update their settings" on public.user_settings;
create policy "Users update their settings" on public.user_settings
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- get_my_settings() → {driveRadiusMiles, whoCanMessage, allowCalls, arrivalAlerts}
-- (defaults when nothing is saved yet).
create or replace function public.get_my_settings()
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.user_settings;
begin
  if v_uid is null then raise sqlstate 'PT401' using message = 'not_authenticated'; end if;
  select * into v_row from public.user_settings where user_id = v_uid;
  return jsonb_build_object(
    'driveRadiusMiles', coalesce(v_row.drive_radius_miles, 10),
    'whoCanMessage',    coalesce(v_row.who_can_message, 'school_families'),
    'allowCalls',       coalesce(v_row.allow_calls, false),
    'arrivalAlerts',    coalesce(v_row.arrival_alerts, true)
  );
end;
$$;

-- update_my_settings(patch) — any subset of the keys above; returns the result.
create or replace function public.update_my_settings(patch jsonb)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then raise sqlstate 'PT401' using message = 'not_authenticated'; end if;
  insert into public.user_settings as s (user_id, drive_radius_miles, who_can_message, allow_calls, arrival_alerts)
  values (
    v_uid,
    coalesce((patch->>'driveRadiusMiles')::smallint, 10),
    coalesce(patch->>'whoCanMessage', 'school_families'),
    coalesce((patch->>'allowCalls')::boolean, false),
    coalesce((patch->>'arrivalAlerts')::boolean, true)
  )
  on conflict (user_id) do update set
    drive_radius_miles = coalesce((patch->>'driveRadiusMiles')::smallint, s.drive_radius_miles),
    who_can_message    = coalesce(patch->>'whoCanMessage', s.who_can_message),
    allow_calls        = coalesce((patch->>'allowCalls')::boolean, s.allow_calls),
    arrival_alerts     = coalesce((patch->>'arrivalAlerts')::boolean, s.arrival_alerts),
    updated_at         = now();
  return public.get_my_settings();
end;
$$;

-- get_my_vehicle() → {model, plateNumber, kidSeats, hasBooster} or null.
create or replace function public.get_my_vehicle()
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select jsonb_build_object('model', v.model, 'plateNumber', v.plate_number,
                            'kidSeats', v.kid_seats, 'hasBooster', v.has_booster)
  from public.vehicles v
  where v.owner_id = (select auth.uid());
$$;

-- save_my_vehicle(model, plateNumber, kidSeats, hasBooster?) — the caller's
-- own car only (vehicles has no write grant for clients).
create or replace function public.save_my_vehicle(
  model text, "plateNumber" text, "kidSeats" smallint, "hasBooster" boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then raise sqlstate 'PT401' using message = 'not_authenticated'; end if;
  insert into public.vehicles as v (owner_id, model, plate_number, kid_seats, has_booster)
  values (v_uid, btrim(save_my_vehicle.model), upper(btrim(save_my_vehicle."plateNumber")),
          save_my_vehicle."kidSeats", coalesce(save_my_vehicle."hasBooster", false))
  on conflict (owner_id) do update set
    model = excluded.model, plate_number = excluded.plate_number,
    kid_seats = excluded.kid_seats, has_booster = excluded.has_booster, updated_at = now();
  return jsonb_build_object('model', btrim(save_my_vehicle.model),
                            'plateNumber', upper(btrim(save_my_vehicle."plateNumber")),
                            'kidSeats', save_my_vehicle."kidSeats",
                            'hasBooster', coalesce(save_my_vehicle."hasBooster", false));
end;
$$;

revoke execute on function public.get_my_settings() from public, anon;
revoke execute on function public.update_my_settings(jsonb) from public, anon;
revoke execute on function public.get_my_vehicle() from public, anon;
revoke execute on function public.save_my_vehicle(text, text, smallint, boolean) from public, anon;
grant execute on function public.get_my_settings() to authenticated;
grant execute on function public.update_my_settings(jsonb) to authenticated;
grant execute on function public.get_my_vehicle() to authenticated;
grant execute on function public.save_my_vehicle(text, text, smallint, boolean) to authenticated;
