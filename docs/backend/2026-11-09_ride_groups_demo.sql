-- Demo ride group (test data). Run AFTER 2026-11-09_ride_groups.sql.
-- "Home → Lincoln parents": Vivek (owner), Test, Ava, Ben, Chloe, Dev.
-- Safe to re-run: the demo group (fixed id) is replaced.

begin;

delete from public.ride_groups where id = '6a0c0000-0000-4000-8000-000000000001';

insert into public.ride_groups (id, name, school_id, created_by, created_at)
select '6a0c0000-0000-4000-8000-000000000001', 'Home → Lincoln parents', s.id,
       'c91e1206-e066-4cd4-8fd1-2cef2397177a', now() - interval '2 days'
  from public.schools s where s.name = 'Lincoln Elementary' limit 1;

insert into public.ride_group_members (group_id, user_id, role, joined_at, last_read_at)
select '6a0c0000-0000-4000-8000-000000000001', v.uid, v.role,
       now() - interval '2 days', now() - interval '3 hours'
  from (values
    ('c91e1206-e066-4cd4-8fd1-2cef2397177a'::uuid, 'owner'),   -- Vivek
    ('f7d6a7fc-51b8-44b7-9265-5d1fbffd7267'::uuid, 'member'),  -- Test
    ('5eed0000-0000-4000-8000-00000000000a'::uuid, 'member'),  -- Ava
    ('5eed0000-0000-4000-8000-00000000000b'::uuid, 'member'),  -- Ben
    ('5eed0000-0000-4000-8000-00000000000c'::uuid, 'member'),  -- Chloe
    ('5eed0000-0000-4000-8000-00000000000d'::uuid, 'member')   -- Dev
  ) v(uid, role);

insert into public.group_messages (group_id, sender_id, kind, body, created_at) values
 ('6a0c0000-0000-4000-8000-000000000001', null, 'system', 'Vivek created the group', now() - interval '2 days'),
 ('6a0c0000-0000-4000-8000-000000000001', null, 'system', 'Vivek added Test, Ava, Ben, Chloe, Dev', now() - interval '2 days' + interval '1 minute'),
 ('6a0c0000-0000-4000-8000-000000000001', 'c91e1206-e066-4cd4-8fd1-2cef2397177a', 'text', 'Hi all! Thought a group would make the Lincoln runs easier to plan.', now() - interval '1 day 20 hours'),
 ('6a0c0000-0000-4000-8000-000000000001', '5eed0000-0000-4000-8000-00000000000c', 'text', 'Great idea. I can do Monday mornings.', now() - interval '1 day 19 hours'),
 ('6a0c0000-0000-4000-8000-000000000001', 'f7d6a7fc-51b8-44b7-9265-5d1fbffd7267', 'text', 'I’ll take Wednesdays.', now() - interval '1 day 18 hours'),
 ('6a0c0000-0000-4000-8000-000000000001', '5eed0000-0000-4000-8000-00000000000a', 'text', 'Friday works for me. Booster seat is in my car if anyone needs it.', now() - interval '5 hours'),
 ('6a0c0000-0000-4000-8000-000000000001', '5eed0000-0000-4000-8000-00000000000b', 'text', 'Thanks Ava! Can someone cover Thursday this week?', now() - interval '2 hours'),
 ('6a0c0000-0000-4000-8000-000000000001', '5eed0000-0000-4000-8000-00000000000d', 'text', 'I can do Thursday.', now() - interval '1 hour');

commit;
