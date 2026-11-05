-- Easy flow (Kumar, Oct 26): F06 "Add a child" has no School / School ID card
-- fields; the school is picked later on F08/F09 "Where do your kids go?" and
-- saved with update-kid. This lets a kid exist before their school is chosen.
-- Rides still require a school (ride_build_plan raises `school_required`).
--
-- Apply in Supabase → SQL editor (project cojraqxramlirnepncrd), or let Claude
-- Code run it once you've allowed `mcp__supabase__apply_migration`.
-- Existing rows are not changed. Each function edit aborts if the expected
-- text isn't found, so it can't silently half-apply.

begin;

alter table public.kids alter column school_id drop not null;

do $mig$
declare
  d text;
begin
  -- get_my_kids: keep kids without a school (returns "school": null).
  d := pg_get_functiondef('public.get_my_kids()'::regprocedure);
  if position('join public.schools s on s.id = k.school_id' in d) = 0
     or position($q$'school',           jsonb_build_object('id', s.id, 'name', s.name),$q$ in d) = 0 then
    raise exception 'get_my_kids: expected text not found, aborting';
  end if;
  d := replace(d, $q$'school',           jsonb_build_object('id', s.id, 'name', s.name),$q$,
                  $q$'school',           case when s.id is null then null else jsonb_build_object('id', s.id, 'name', s.name) end,$q$);
  d := replace(d, '    join public.schools s on s.id = k.school_id',
                  '    left join public.schools s on s.id = k.school_id');
  execute d;

  -- ride_build_plan: clear error when a chosen kid has no school yet.
  d := pg_get_functiondef('public.ride_build_plan(uuid, uuid[], date, text, text, uuid, jsonb)'::regprocedure);
  if position($q$if v_found <> v_count then raise sqlstate 'PT404' using message = 'kid_not_found'; end if;$q$ in d) = 0 then
    raise exception 'ride_build_plan: expected text not found, aborting';
  end if;
  d := replace(d,
    $q$if v_found <> v_count then raise sqlstate 'PT404' using message = 'kid_not_found'; end if;$q$,
    $q$if v_found <> v_count then raise sqlstate 'PT404' using message = 'kid_not_found'; end if;
  if exists (select 1 from public.kids k where k.id = any(p_kid_ids) and k.school_id is null) then
    raise sqlstate 'PT409' using message = 'school_required';
  end if;$q$);
  execute d;
end
$mig$;

commit;

-- Edge function add-kid (deploy after the SQL above):
--   * schoolId: optional. If sent, validate it exactly as today; otherwise insert school_id = null.
--   * schoolIdCard: optional. Upload it only when a file is sent.
