-- Pick-up PIN is optional, the driver's choice (2026-11-25):
--  * entered → mark_picked_up checks it (5 wrong tries lock it for 10 min);
--  * skipped → the pick-up goes through without one.
-- Set 1 to make it mandatory again (installed apps then hide "Skip").
-- Briefly set to 1 earlier on 2026-11-25, then back to 0 on request.
update public.app_settings set value = 0 where key = 'require_pickup_pin';
