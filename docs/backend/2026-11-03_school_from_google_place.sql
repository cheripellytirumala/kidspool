-- Schools picked from Google Places search ("Add school & activity" → School).
-- The app searches Google by name, zip code or address, then calls
-- school_from_place(...) to get a schools.id for update-kid. The same Google
-- place always maps to the same school row.
-- Apply in Supabase → SQL editor, project cojraqxramlirnepncrd.

begin;

alter table public.schools add column if not exists google_place_id text;
create unique index if not exists schools_google_place_id_key
  on public.schools (google_place_id) where google_place_id is not null;

create or replace function public.school_from_place(
  "placeId" text,
  name text,
  "addressLine" text default null,
  city text default null,
  state text default null,
  zip text default null,
  latitude double precision default null,
  longitude double precision default null)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $fn$
declare
  v_uid  uuid := auth.uid();
  v_id   uuid;
  v_name text := nullif(trim(school_from_place.name), '');
  v_pid  text := nullif(trim(school_from_place."placeId"), '');
begin
  if v_uid is null then raise sqlstate 'PT401' using message = 'not_authenticated'; end if;
  if v_pid is null or char_length(v_pid) > 300 then
    raise sqlstate 'PT400' using message = 'invalid_field', detail = 'placeId';
  end if;
  if v_name is null or char_length(v_name) > 120 then
    raise sqlstate 'PT400' using message = 'invalid_field', detail = 'name';
  end if;
  if school_from_place.latitude is null or school_from_place.longitude is null
     or school_from_place.latitude not between -90 and 90
     or school_from_place.longitude not between -180 and 180 then
    raise sqlstate 'PT400' using message = 'invalid_field', detail = 'latitude/longitude';
  end if;
  if char_length(coalesce(school_from_place."addressLine", '')) > 160
     or char_length(coalesce(school_from_place.city, '')) > 60
     or char_length(coalesce(school_from_place.state, '')) > 60
     or char_length(coalesce(school_from_place.zip, '')) > 10 then
    raise sqlstate 'PT400' using message = 'invalid_field', detail = 'address (too long)';
  end if;

  select s.id into v_id from public.schools s where s.google_place_id = v_pid;
  if v_id is null then
    insert into public.schools (name, address_line, city, state, zip, location, google_place_id)
    values (
      v_name,
      nullif(trim(school_from_place."addressLine"), ''),
      nullif(trim(school_from_place.city), ''),
      nullif(trim(school_from_place.state), ''),
      nullif(trim(school_from_place.zip), ''),
      extensions.st_setsrid(extensions.st_makepoint(school_from_place.longitude, school_from_place.latitude), 4326)::extensions.geography,
      v_pid)
    on conflict (google_place_id) where google_place_id is not null do nothing
    returning id into v_id;
    if v_id is null then  -- created concurrently
      select s.id into v_id from public.schools s where s.google_place_id = v_pid;
    end if;
  end if;

  return (select jsonb_build_object(
    'id', s.id, 'name', s.name, 'addressLine', s.address_line,
    'city', s.city, 'state', s.state, 'zip', s.zip)
    from public.schools s where s.id = v_id);
end;
$fn$;

revoke all on function public.school_from_place(text, text, text, text, text, text, double precision, double precision) from public, anon;
grant execute on function public.school_from_place(text, text, text, text, text, text, double precision, double precision) to authenticated, service_role;

commit;

notify pgrst, 'reload schema';
