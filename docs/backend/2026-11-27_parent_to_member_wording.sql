-- User-facing wording: "parent" → "member" in fallback names and
-- notification lines. Only these string literals change in each function.
do $$
declare
  f text;
  def text;
begin
  foreach f in array array[
    'add_ride_group_members_internal', 'create_ride_group', 'leave_ride_group',
    'rename_ride_group', 'get_my_notifications', 'ride_ask_json'
  ] loop
    for def in
      select pg_get_functiondef(p.oid)
        from pg_proc p join pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'public' and p.proname = f
    loop
      def := replace(def, '''A parent''', '''A member''');
      def := replace(def, 'we asked other parents again', 'we asked other members again');
      def := replace(def, 'ask again or try other parents', 'ask again or try other members');
      execute def;
    end loop;
  end loop;
end $$;
