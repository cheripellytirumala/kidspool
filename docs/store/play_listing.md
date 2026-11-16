# Google Play store listing text

Copy into Play Console → **Grow users → Store presence → Main store listing**
(en-US). Fixes the "Metadata policy: insufficient description" rejection.

**App name and app label:** the listing says **KidsPool**, but the app
installs as **Kid Pool** (`android:label` / `CFBundleDisplayName`). Pick one
and use it everywhere: the store name, the app label, the Child Safety
Standards page and the privacy policy. Play checks the Child Safety page
against the listing name. The text below uses **KidsPool**. Replace it if
you choose "Kid Pool".

---

## App name (max 30 characters)

```
KidsPool: School Ride Sharing
```
(29 characters. Or just `KidsPool`.)

## Short description (max 80 characters)

```
Share school and activity rides with verified parents near you.
```
(64 characters)

## Full description (max 4,000 characters)

```
KidsPool helps parents share school and activity rides with other trusted families nearby, so fewer cars do the school run and every parent gets a little time back.

HOW IT WORKS
• Add your kids, their school and their activities (sports, music, swimming and more).
• See families near you whose kids go to the same school or activity.
• Ask for a ride: choose the kids, the pick-up and drop-off, the day and the time. Ask for just once or for several days, with an optional return trip.
• Send the request to families you choose, or post it in a ride group. A parent who can help taps "I can help" and the ride is booked.
• Chat with other parents in one-to-one ride chats or in ride groups for your school.

FOLLOW EVERY RIDE
• When the driving parent starts the ride, you can follow the car live on the map.
• See when your kids are picked up and when they reach school or their activity.
• Ride summary at drop-off, with the time and route.
• Call or message the driving parent from the ride screen in one tap.

GIVE RIDES TOO
• Switch between "I get rides only" and "I get and give rides" at any time.
• Drivers verify their driver's license before giving rides.
• Get a reminder 30 minutes before a ride you're driving.

BUILT FOR SAFETY
• Every account belongs to an adult parent or guardian. Children don't use the app.
• Other families see only a first name, an approximate area and the shared school or activity. Your exact address and phone number stay private until a ride is booked.
• An SOS button during rides alerts the other parent and the KidsPool team, with a prompt to call emergency services.
• Report or block any user from chats, group members and family cards. Reports go to the KidsPool safety team.
• Delete your account and data at any time from Profile.

PRIVACY
KidsPool uses your location to find families near you and, for the driving parent only, to share the car's position during an active ride, including in the background until drop-off. Location sharing stops when the ride ends. We never sell your data.

KidsPool is for parents and legal guardians aged 18 and over.

Questions or feedback? Contact us at bowapps@nfcsolutionsusa.com.
Child safety standards: https://kidspool-legal.netlify.app/child-safety/
Privacy policy: https://kidspool-legal.netlify.app/privacy/
```
(About 2,300 of 4,000 characters.)

---

## Before you resubmit

- [x] Contact email and policy links filled in. Both pages are public
      (checked: no login).
- [ ] Every claim above must be true in the build you submit:
      - live tracking, 30-minute reminder, SOS, report/block and delete
        account are in the app;
      - report/block needs `docs/backend/2026-11-16_reports_and_blocks.sql`
        applied on the server;
      - don't add "notifications when the app is closed" until push
        (Firebase) is set up.
- [ ] Graphics: 512×512 icon, 1024×500 feature graphic, 2–8 phone
      screenshots (see `store_deployment.md`).
- [ ] Category: **Maps & Navigation** or **Parenting**. Tags: carpool,
      parenting, school.
- [ ] Save the listing, then **create a new release** (bump the build number
      in `pubspec.yaml`, e.g. `1.0.0+2`). Send it for review from
      **Publishing overview**.
