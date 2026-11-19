-- Your car (sign-up, after the driver's license): model ("White Honda
-- City") and plate too, not only seats. Model / plate left out keep what
-- is saved (Profile › My car only changes seats and booster).
drop function if exists public.set_my_car(integer, boolean);

create or replace function public.set_my_car(
  "carSeats" integer,
  "hasBooster" boolean default false,
  "model" text default null,
  "plateNumber" text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid   uuid := auth.uid();
  v_model text := nullif(btrim(set_my_car."model"), '');
  v_plate text := nullif(upper(btrim(set_my_car."plateNumber")), '');
begin
  if v_uid is null then raise sqlstate 'PT401' using message = 'not_authenticated'; end if;
  if "carSeats" is null or "carSeats" not between 2 and 9 then
    raise sqlstate 'PT400' using message = 'invalid_field', detail = 'carSeats (2–9)';
  end if;
  if char_length(coalesce(v_model, '')) > 60 then
    raise sqlstate 'PT400' using message = 'invalid_field', detail = 'model (max 60)';
  end if;
  if char_length(coalesce(v_plate, '')) > 15 then
    raise sqlstate 'PT400' using message = 'invalid_field', detail = 'plateNumber (max 15)';
  end if;
  insert into public.vehicles (owner_id, car_seats, kid_seats, has_booster, model, plate_number)
  values (v_uid, "carSeats", least("carSeats" - 1, 8), coalesce("hasBooster", false), v_model, v_plate)
  on conflict (owner_id) do update
    set car_seats    = excluded.car_seats,
        kid_seats    = excluded.kid_seats,
        has_booster  = excluded.has_booster,
        model        = coalesce(excluded.model, public.vehicles.model),
        plate_number = coalesce(excluded.plate_number, public.vehicles.plate_number),
        updated_at   = now();
  return public.get_my_car();
end;
$$;

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
            'plateNumber', v.plate_number)
            from public.vehicles v where v.owner_id = v_uid);
end;
$$;

revoke all on function public.set_my_car(integer, boolean, text, text) from public, anon;
grant execute on function public.set_my_car(integer, boolean, text, text) to authenticated;
