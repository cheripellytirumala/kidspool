-- My car: a driver says how many seats their car has (4–8), and whether
-- they carry a booster. Profile › My car saves it; the driver's card shows
-- it, and ride requests only reach drivers with room for the kids.
--
-- vehicles.car_seats   all seats, driver included (5 = a 5-seater)
-- vehicles.kid_seats   seats free for kids = car_seats − 1 (was capped at 4)
-- model / plate / photo are optional now: seats alone are enough.

alter table public.vehicles add column if not exists car_seats smallint;
alter table public.vehicles drop constraint if exists vehicles_car_seats_check;
alter table public.vehicles add constraint vehicles_car_seats_check
  check (car_seats is null or car_seats between 2 and 9);

alter table public.vehicles drop constraint if exists vehicles_kid_seats_check;
alter table public.vehicles add constraint vehicles_kid_seats_check
  check (kid_seats between 1 and 8);

alter table public.vehicles alter column model drop not null;
alter table public.vehicles alter column plate_number drop not null;
alter table public.vehicles alter column photo_path drop not null;
alter table public.vehicles drop constraint if exists vehicles_model_check;
alter table public.vehicles drop constraint if exists vehicles_plate_number_check;

-- The signed-in parent's car, or null.
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
            'carSeats',   coalesce(v.car_seats, v.kid_seats + 1),
            'kidSeats',   v.kid_seats,
            'hasBooster', v.has_booster,
            'model',      v.model)
            from public.vehicles v where v.owner_id = v_uid);
end;
$$;

-- Saves the parent's car seats (and booster). Returns the car.
create or replace function public.set_my_car("carSeats" integer, "hasBooster" boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then raise sqlstate 'PT401' using message = 'not_authenticated'; end if;
  if "carSeats" is null or "carSeats" not between 2 and 9 then
    raise sqlstate 'PT400' using message = 'invalid_field', detail = 'carSeats (2–9)';
  end if;
  insert into public.vehicles (owner_id, car_seats, kid_seats, has_booster)
  values (v_uid, "carSeats", least("carSeats" - 1, 8), coalesce("hasBooster", false))
  on conflict (owner_id) do update
    set car_seats   = excluded.car_seats,
        kid_seats   = excluded.kid_seats,
        has_booster = excluded.has_booster,
        updated_at  = now();
  return public.get_my_car();
end;
$$;

revoke all on function public.get_my_car() from public, anon;
revoke all on function public.set_my_car(integer, boolean) from public, anon;
grant execute on function public.get_my_car() to authenticated;
grant execute on function public.set_my_car(integer, boolean) to authenticated;

-- The driver's card (ride request, tracking) also gives carSeats.
CREATE OR REPLACE FUNCTION public.driver_card_json(p_driver uuid, rr public.ride_requests, p_with_phone boolean)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select jsonb_build_object(
    'id',            p.id,
    'firstName',     p.first_name,
    'lastName',      p.last_name,
    'initials',      public.person_initials(p.first_name, p.last_name),
    'phone',         case when p_with_phone then p.phone end,
    'idVerified',    p.onboarding_status = 'approved',
    'rating',        (select round(avg(x.rating)::numeric, 1) from public.ride_ratings x where x.driver_id = p.id),
    'ratingCount',   (select count(*)::int from public.ride_ratings x where x.driver_id = p.id),
    'ridesGiven',    (select count(*)::int from public.ride_requests x
                       where x.driver_id = p.id and x.status = 'completed'),
    'memberSince',   p.created_at,
    'kidsAtSchool',  coalesce((select jsonb_agg(k.first_name order by k.created_at)
                                 from public.kids k
                                where k.parent_id = p.id and k.school_id = rr.school_id), '[]'::jsonb),
    'distanceMiles', (select round((extensions.st_distance(a.location, rr.pickup_location) / 1609.344)::numeric, 1)
                        from public.addresses a where a.user_id = p.id and a.is_default),
    'vehicle',       (select jsonb_build_object(
                               'model', v.model, 'plateNumber', v.plate_number,
                               'kidSeats', v.kid_seats, 'carSeats', coalesce(v.car_seats, v.kid_seats + 1),
                               'hasBooster', v.has_booster, 'photoPath', v.photo_path)
                        from public.vehicles v where v.owner_id = p.id)
  )
  from public.profiles p
  where p.id = p_driver;
$function$;
