# S19 / S20 push notifications — setup

"Ride started 🚗" (S19) and "<Kid> reached <School> ✅" (S20) reach the parent
in two ways:

| | Works today | What it needs |
|---|---|---|
| **Local notifications** — the app polls `get_my_notifications` every 30 s while open and posts each new S19/S20 to Notification Center / the tray (and shows the lime banner). | Yes | Nothing. Permission is asked once, the first time a signed-in user reaches Home. |
| **Push (FCM)** — the backend pushes the moment `ride_requests.started_at` / `completed_at` is set, even when the app is closed. | After the steps below | Firebase project + config files, APNs key, SQL, Edge Function, Database Webhook. |

The app ships with push dormant: `Firebase.initializeApp()` fails without config
files, the app logs it and carries on exactly as before. Once the config files
are in, the same build registers the device token and handles pushes.

A push and the local notification for the same event share one notification id
(iOS `apns-collapse-id`, Android tag), so they replace each other instead of
showing twice.

---

## 1. Firebase project

1. <https://console.firebase.google.com> → **Add project** (Analytics optional).
2. Add an **iOS app** with the Runner bundle id and an **Android app** with
   `com.example.kidspool` (change both if you change the app ids later).

## 2. Config files in the app (`flutterfire configure`)

```sh
dart pub global activate flutterfire_cli
cd /Users/iosdeveloper/Desktop/kidspool
flutterfire configure            # pick the project, platforms iOS + Android
```

This adds `ios/Runner/GoogleService-Info.plist`,
`android/app/google-services.json`, the `com.google.gms.google-services` Gradle
plugin and `lib/firebase_options.dart`.

The app calls `Firebase.initializeApp()` **without options** (native config
files), so `firebase_options.dart` is not needed; leave it or delete it. Don't
switch to `DefaultFirebaseOptions.currentPlatform` unless the file is committed
for every environment.

Then `cd ios && LANG=en_US.UTF-8 pod install`.

## 3. Xcode capabilities (iOS)

Open `ios/Runner.xcworkspace` → Runner target → **Signing & Capabilities**:

1. **+ Capability → Push Notifications** (adds `aps-environment` to
   `Runner.entitlements`).
2. **+ Capability → Background Modes → Remote notifications**.

These weren't added automatically: the Push Notifications entitlement changes
code signing — the provisioning profile must include push, so builds with the
current profiles / `--no-codesign` setups would break until the App ID has push
enabled in the Apple Developer portal. Xcode's "Automatically manage signing"
updates the App ID and profile when you add the capability.

## 4. APNs key → Firebase

1. Apple Developer → **Certificates, Identifiers & Profiles → Keys → +** →
   enable **Apple Push Notifications service (APNs)** → download the `.p8`
   (once only) and note the Key ID and your Team ID.
2. Firebase console → Project settings → **Cloud Messaging** → Apple app
   configuration → **APNs Authentication Key → Upload** (`.p8`, Key ID, Team ID).

## 5. Database: `push_tokens`

Supabase → SQL editor (project `cojraqxramlirnepncrd`) → run
`docs/backend/2026-11-10_push_tokens.sql` (safe to re-run).

Before this runs, the app's `register_push_token` calls get a 404 and are
skipped silently.

## 6. Edge Function secrets

Firebase console → Project settings → **Service accounts → Generate new private
key** (downloads a JSON file). Then, with the Supabase CLI linked to the project:

```sh
supabase link --project-ref cojraqxramlirnepncrd
supabase secrets set FCM_SERVICE_ACCOUNT="$(cat ~/Downloads/<project>-firebase-adminsdk-xxxx.json)"
SECRET=$(openssl rand -hex 32)
supabase secrets set RIDE_PUSH_WEBHOOK_SECRET="$SECRET"
echo "$SECRET"                   # the webhook sends this value (step 8)
```

Don't commit the service-account JSON.

## 7. Deploy the Edge Function

```sh
supabase functions deploy send-ride-push --no-verify-jwt
```

`--no-verify-jwt` because the caller is the Database Webhook, authenticated by
the `x-webhook-secret` header instead of a user JWT.

## 8. Database Webhook

Supabase dashboard → **Database → Webhooks → Create a new hook**:

- Name: `send_ride_push`
- Table: `public.ride_requests`, Events: **Update** only
- Type: **HTTP Request**, Method **POST**
- URL: `https://cojraqxramlirnepncrd.supabase.co/functions/v1/send-ride-push`
- HTTP headers: `Content-Type: application/json`,
  `x-webhook-secret: <the RIDE_PUSH_WEBHOOK_SECRET value>`
- Timeout: 5000 ms

Every ride_requests update calls the function; it returns
`200 {"skipped": …}` unless `started_at` (S19) or `completed_at` (S20) just
went from null to a value.

## 9. Test

1. Build to a **real iPhone** (the simulator can't receive APNs pushes from FCM)
   or an Android device/emulator with Google Play services.
2. Sign in as a parent, reach Home, allow notifications.
   Check the token arrived:
   `select user_id, platform, updated_at from public.push_tokens;`
3. Send the app to the background. As the Ride Partner (another device or
   account), **Start ride** on a booked ride → the parent gets "Ride started 🚗".
   **Complete** it → "<Kid> reached <School> ✅".
4. Tap a push → the app opens live tracking (S19) or the ride summary (S20).
5. With the app open, the lime banner shows instead of a system banner.
6. Logs: Supabase → Edge Functions → `send-ride-push` → Logs
   (`{"kind":…, "sent":1, "failed":0, "removed":0}`). Webhook deliveries:
   `select * from net._http_response order by created desc limit 20;`

Manual call (replace values):

```sh
curl -X POST https://cojraqxramlirnepncrd.supabase.co/functions/v1/send-ride-push \
  -H "Content-Type: application/json" -H "x-webhook-secret: $SECRET" \
  -d '{"type":"UPDATE","table":"ride_requests","schema":"public",
       "record":{"id":"<request id>","parent_id":"<parent id>","driver_id":"<driver id>",
                 "school_id":null,"started_at":"2026-11-10T08:00:00Z","completed_at":null},
       "old_record":{"started_at":null,"completed_at":null}}'
```

## Without any of this

Local notifications already work: while the app is open (or right after it's
reopened, within 3 minutes of the event) new S19/S20 alerts show the lime banner
and land in Notification Center / the tray; tapping one opens the ride.
