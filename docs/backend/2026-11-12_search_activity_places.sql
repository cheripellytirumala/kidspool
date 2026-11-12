-- Search activity places parents already saved (kid_activities), so the
-- app doesn't need Google for most activity searches (Google Places has a
-- small daily quota on this project). Schools already have get_schools().
--
--   search_activity_places(search text default null)
--     → [{placeKey, name, category, addressLine, city, state, zip,
--         latitude, longitude, families}]
--   Places whose name or city matches `search` (all when empty), most used
--   first, at most 50. Only the place itself — never who goes there.
--
-- Needs 2026-11-11_kid_activities.sql. Safe to re-run.

create or replace function public.search_activity_places(search text default null)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $fn$
declare
  v_q text := nullif(btrim(search_activity_places.search), '');
begin
  if auth.uid() is null then raise sqlstate 'PT401' using message = 'not_authenticated'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'placeKey',    t.place_key,
             'name',        t.name,
             'category',    t.category,
             'addressLine', t.address_line,
             'city',        t.city,
             'state',       t.state,
             'zip',         t.zip,
             'latitude',    extensions.st_y(t.location::extensions.geometry),
             'longitude',   extensions.st_x(t.location::extensions.geometry),
             'families',    t.families) order by t.families desc, t.name)
      from (
        select a.place_key, min(a.name) as name, min(a.category) as category,
               min(a.address_line) as address_line, min(a.city) as city,
               min(a.state) as state, min(a.zip) as zip,
               (array_agg(a.location) filter (where a.location is not null))[1] as location,
               count(distinct a.parent_id)::int as families
          from public.kid_activities a
         where v_q is null
            or a.name ilike '%' || v_q || '%'
            or a.city ilike '%' || v_q || '%'
            or a.zip = v_q
         group by a.place_key
         limit 50
      ) t
     where t.location is not null
  ), '[]'::jsonb);
end;
$fn$;

revoke all on function public.search_activity_places(text) from public, anon;
grant execute on function public.search_activity_places(text) to authenticated;

notify pgrst, 'reload schema';
