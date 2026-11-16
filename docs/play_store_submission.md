# Google Play submission — Kid Pool (Android)

Package name: **`com.nfc.kidpool`** (permanent after the first upload)
Version: `1.0.0 (1)` — from `version:` in `pubspec.yaml`

## 1. Build the release bundle

```sh
flutter clean            # if you use the iCloud build/ symlink, recreate it after
flutter build appbundle --release
# → build/app/outputs/bundle/release/app-release.aab
```

For every later upload, bump the build number in `pubspec.yaml`
(`1.0.0+1` → `1.0.0+2`). Play rejects a repeated versionCode.

### Signing

- Upload keystore: `~/AndroidKeys/kidpool-upload-keystore.jks`, alias `upload`.
- Passwords are in `android/key.properties`, which git ignores. Without that
  file, Gradle falls back to the debug key and Play rejects the bundle.
- **Back up the keystore and its password** to a password manager.
- Use **Play App Signing** (the default for new apps). Google holds the app
  signing key. If the upload key is lost, Play support can reset it.
- Upload certificate SHA-256:
  `8A:B9:99:6B:75:28:E6:5E:D9:54:A9:EC:6C:14:32:99:5A:08:D2:7A:0E:6C:96:79:1C:17:E8:EA:31:17:72:B1`

## 2. Before the first upload

- [ ] **Firebase (push):** add an Android app with package `com.nfc.kidpool`
      in the Firebase console. Put `google-services.json` in `android/app/`.
      The Gradle plugin turns on automatically when the file is present.
      Without it, the app runs but push notifications are off on Android.
- [ ] **Google Maps / Places key restrictions:** add package `com.nfc.kidpool`
      with **both** the upload SHA-1 and the **Play App Signing SHA-1**
      (Play Console → Test and release → App integrity). Otherwise, maps go
      blank in Play-installed builds.
      `keytool -list -v -keystore ~/AndroidKeys/kidpool-upload-keystore.jks -alias upload`
- [ ] **Privacy policy URL:** this is required. The app collects children's
      personal data and location. Host it on a public URL.
- [ ] **Account deletion:** Play requires an in-app path and a web URL for
      deleting accounts.
- [ ] **Test login** for the reviewer (the app requires sign-in).
- [ ] Optional: change `description:` in `pubspec.yaml`. It doesn't affect Play.

## 3. Play Console → App content

| Form | What to declare |
|---|---|
| Privacy policy | URL from above |
| Ads | No ads (unless added) |
| App access | Login required. Give the test account credentials and steps. |
| Content rating | IARC questionnaire. Users share location and contact other parents, so answer "yes" to sharing location and user interaction. |
| Target audience | **18+ only.** Parents use the app, not children. Choosing an under-13 age group brings the app under the Families policy. |
| Data safety | See below |
| Foreground service | **Location** type, for live ride tracking. Explain that it runs only during an active ride, with an ongoing notification, and attach a short screen recording. |
| Location permission | Foreground only (`ACCESS_FINE/COARSE_LOCATION`). No background-location declaration needed, because `ACCESS_BACKGROUND_LOCATION` isn't requested. |
| Government / financial / health apps | No |

### Data safety (check against the backend before submitting)

Based on the fields the app handles:

| Data type | Collected | Purpose |
|---|---|---|
| Precise location | Yes | App functionality (ride tracking, matching nearby families) |
| Name | Yes | App functionality, account management |
| Phone number | Yes | App functionality (call buttons), account |
| Email (if used for login) | Yes | Account management |
| Photos | Yes | Profile photos, school ID card |
| Other personal info (children's names, date of birth, school, grade) | Yes | App functionality |
| Device IDs (FCM token) | Yes | Push notifications |

- Data encrypted in transit: **Yes** (HTTPS).
- Users can request deletion: **Yes** (required; see the account deletion item above).
- Data shared with third parties: probably **No**. Google Maps and Firebase
  count as service providers, not sharing.

## 4. Store listing

- [ ] App name: **Kid Pool** (≤30 chars)
- [ ] Short description (≤80 chars)
- [ ] Full description (≤4000 chars)
- [ ] App icon: 512×512 PNG, 32-bit, ≤1 MB
- [ ] Feature graphic: 1024×500 PNG/JPG
- [ ] Phone screenshots: 2–8, 16:9 or 9:16, min side 320 px
- [ ] Category: Maps & Navigation, or Lifestyle / Parenting
- [ ] Contact email and website

## 5. Release

1. Testing → Internal testing → create a release → upload `app-release.aab`.
2. Install it from the Play internal link. Check maps, login, and push.
3. A **personal** developer account needs a **closed test with 12+ testers
   for 14 days** before production access. An organization account doesn't.
4. Promote the release to Production → submit for review.

## Permissions in the release bundle (for reference)

`INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_FINE_LOCATION`,
`ACCESS_COARSE_LOCATION`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`
(service type `location`), `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`,
`VIBRATE`, `WAKE_LOCK`, `c2dm.RECEIVE` (FCM).
Target SDK 36, min SDK 24.
