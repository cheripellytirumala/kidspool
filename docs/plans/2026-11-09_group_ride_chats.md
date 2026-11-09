# Group ride chats — plan

_Status: proposal, 2026-11-09. Nothing built yet._

## Where we are today

- A ride request is sent to **every eligible driver** within 1 mile of the pickup
  (`create_ride_request` → `ride_request_notifications`). There is no upper limit.
- Chats are **one-to-one**: `ride_messages` is keyed by `(request_id, driver_id)`, so a
  conversation always has exactly two people. `can_ride_chat` enforces it.
- A ride has **one driver and one family's kids** (`ride_requests.driver_id`, `parent_id`).
- The app already has the screens a group needs, built from Figma but fed by 1:1 data:
  F24 Chats list, F19 ride chat (bubbles, ride card), GC6 group info, Profile › Ride groups,
  Home › "Your ride group" card.
- Chats refresh by polling (`ride_chat_provider.dart`); the app has no realtime client.
- `ride_offers.group_id` exists but only links offers from one series — it is not a chat group.

## Goal

A **ride group**: a standing set of families that share a route ("Home → Lincoln parents",
up to N members). It has one shared chat, and members can ask the whole group for a ride.

## Phase 1 — Group chat (backend)

New tables (RLS on; a user only sees groups they belong to):

| Table | Columns |
|---|---|
| `ride_groups` | `id`, `name`, `school_id`, `created_by`, `created_at`, `updated_at` |
| `ride_group_members` | `group_id`, `user_id`, `role` (`owner`/`member`), `joined_at`, `muted`, `last_read_at` |
| `group_messages` | `id`, `group_id`, `sender_id` (null for system), `kind` (`text`/`system`/`ride`), `body`, `request_id` (for ride cards), `created_at` |

RPCs (each checks `auth.uid()` membership; same error style as today):

- `create_ride_group(name, schoolId, memberIds)` — members must be approved parents who share
  the school (same rule as `get_families_near_me`). Adds a "Vivek created the group" system message.
- `add_group_members(groupId, memberIds)`, `leave_ride_group(groupId)`,
  `rename_ride_group(groupId, name)`, `set_group_muted(groupId, muted)`
- `get_my_ride_groups()` → `[{id, name, memberCount, unread, lastMessage, lastAt}]`
- `get_group_info(groupId)` → name, school, members (first name, initials, kids' first names)
- `get_group_messages(groupId, before?)` → page of messages with sender first name/initials
- `send_group_message(groupId, body)` and `mark_group_read(groupId)`

Privacy stays as today: members see first names, kids' first names and grades, never phone
numbers or addresses.

## Phase 2 — Group chat (app)

- **Data**: `RideGroup`, `GroupMessage` entities + repository in the Messages feature.
- **Chats tab (F24)**: group rows listed with 1:1 chats, newest first, with unread counts.
- **Group chat**: reuse the F19 chat screen; bubbles show the sender's name/avatar because
  there are several senders. Polling as today.
- **Group info (GC6)**: members list, Add parents (reuse the Families near you picker),
  rename, mute, leave. Mute, rename and Add parents are the Figma items still missing.
- **Create a group**: from Families near you select mode ("Start a group" with the picked
  families), and from a confirmed ride ("Make this a group").
- **Entry points**: Profile › Ride groups, Home › "Your ride group", bottom-nav badge counts
  group unread too.

## Phase 3 — Ask the group for a ride

- `create_ride_request(…, groupId?)`: notify group members (in addition to nearby drivers)
  and post a **ride card** message in the group chat.
- Any member can tap **I can drive** on the card (existing offer flow); the requester approves
  as today. The card updates to "Ava drives · confirmed".

## Phase 4 (later, separate) — Multi-family carpool

One car carrying kids from several families (a "ride pool") needs a trip that links several
requests to one driver, with seat counting and multi-stop pickup. This changes booking and
live tracking, not just chat — plan it on its own after groups are in use.

## Demo data

Seed one group "Home → Lincoln parents" with Vivek, Test, Ava, Ben, Chloe and Dev (6
members) and a few messages. Ava, Ben and Chloe already live within 1 mile of Vivek
(3140 25th St, SF) and have cars.

## Decisions needed

1. ~~**Who can add members**~~ — **decided 2026-11-09: any member** can add parents
   (still only approved parents who share the school).
2. ~~**Group size cap**~~ — **decided: 8 families** per group.
3. ~~**Ask the group (phase 3)**~~ — **decided: chat first.** The first release is phases 1–2;
   ask the group follows once chat works.
4. **Applying SQL** — the new schema ships as a file in `docs/backend/` for you to run in the
   Supabase SQL editor (the `cojraqxramlirnepncrd` project also serves production).

## Rough size

| Phase | Work |
|---|---|
| 1 | 3 tables, ~9 RPCs, RLS, SQL tests |
| 2 | ~2 new screens' worth (group chat, create group) + changes to 5 existing screens |
| 3 | `create_ride_request` change + ride card in group chat |
| 4 | Separate project |
