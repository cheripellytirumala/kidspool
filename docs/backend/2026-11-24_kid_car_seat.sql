-- QA round 5 (#10): "Car seat needed" for young children (harness car seat),
-- alongside the existing booster flag. Additive; safe to re-run.
alter table public.kids
  add column if not exists needs_car_seat boolean not null default false;

CREATE OR REPLACE FUNCTION public.get_my_kids()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise sqlstate 'PT401' using message = 'not_authenticated';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id',               k.id,
             'firstName',        k.first_name,
             'lastName',         k.last_name,
             'dateOfBirth',      k.date_of_birth,
             'age',              extract(year from age(current_date, k.date_of_birth))::int,
             'grade',            k.grade,
             'school',           case when s.id is null then null else jsonb_build_object('id', s.id, 'name', s.name) end,
             'needsBooster',     k.needs_booster,
             'needsCarSeat',     k.needs_car_seat,
             'healthNotes',      k.health_notes,
             'emergencyContact', case when k.emergency_contact_name is null then null
                                      else jsonb_build_object('name', k.emergency_contact_name,
                                                              'phone', k.emergency_contact_phone) end,
             'photoPath',        k.photo_path,
             'schoolIdCardPath', k.school_id_card_path
           ) order by k.created_at)
    from public.kids k
    left join public.schools s on s.id = k.school_id
    where k.parent_id = v_uid
  ), '[]'::jsonb);
end;
$function$;

-- Ride Partners see "car seat needed" next to the booster flag.
do $$
declare d text;
begin
  for d in
    select pg_get_functiondef(p.oid)
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.proname in ('driver_request_json', 'ride_kids_health_json')
  loop
    if d not like '%needsCarSeat%' then
      execute regexp_replace(d,
        '''needsBooster'',(\s*)k\.needs_booster,',
        '''needsBooster'',\1k.needs_booster, ''needsCarSeat'', k.needs_car_seat,',
        'g');
    end if;
  end loop;
end $$;
