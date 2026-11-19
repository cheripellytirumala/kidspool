-- "Your vehicle": year and color, and get_my_car returns everything the
-- screen shows. Saving goes through the save-vehicle Edge Function.
alter table public.vehicles add column if not exists year smallint;
alter table public.vehicles add column if not exists color text;

create or replace function public.get_my_car()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then raise sqlstate 'PT401' using message = 'not_authenticated'; end if;
  return (select jsonb_build_object(
            'carSeats',    coalesce(v.car_seats, v.kid_seats + 1),
            'kidSeats',    v.kid_seats,
            'hasBooster',  v.has_booster,
            'model',       v.model,
            'color',       v.color,
            'year',        v.year,
            'plateNumber', v.plate_number,
            'hasPhoto',    v.photo_path is not null)
            from public.vehicles v where v.owner_id = v_uid);
end;
$$;
