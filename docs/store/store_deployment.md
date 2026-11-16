# Kid Pool: App Store and Google Play deployment

What you need in each store, plus the gaps in the app that will block review.
The Android build and signing steps are in [../play_store_submission.md](../play_store_submission.md).

| | iOS (App Store) | Android (Google Play) |
|---|---|---|
| App name | Kid Pool | Kid Pool |
| Bundle ID / package | `com.nfc.kidpool` | `com.nfc.kidpool` |
| Version (pubspec `1.0.0+1`) | 1.0.0 (build 1) | versionName 1.0.0, versionCode 1 |
| Minimum OS | iOS 15.5 | Android 7.0 (SDK 24), target SDK 36 |
| Build command | `flutter build ipa --release` → Transporter / Xcode Organizer | `flutter build appbundle --release` |

Bump the build number in `pubspec.yaml` (`+1` → `+2`) for every upload to either store.

---

## 1. Public URLs (both stores)

Right now all three in-app links point to `example.com`
(`lib/common/core/constants/app_constants.dart`). Host real pages and update
those constants **before** building the release.

| Page | Needed by | Notes |
|---|---|---|
| **Privacy Policy** | App Store (required), Play (required) | Must cover children's data (names, DOB, school, photos), precise location including background during rides, ID/license scans, phone numbers and push tokens. Also say who processes it (Supabase, Google Maps, Firebase). |
| **Terms of Service** | Linked from sign-up | Must include or link the Child Safety Standards. |
| **Child Safety Standards** | **Google Play (your current rejection)** | Draft ready: [child-safety-standards.html](child-safety-standards.html). See section 2. |
| **Support / Help** | App Store (Support URL, required) | A page with a contact email and a "Report a problem" form or email. |
| **Account deletion** | Play (Data safety → "delete account URL"), App Store guideline 5.1.1(v) | A web page explaining how to delete the account, plus an email or form. |
| Marketing website | Optional | |

Rules for these URLs: an **HTML page** on a public **https** URL that
loads without a login. Play rejects PDFs, Google Docs and editable formats.
Use the same app name as the store listing: **Kid Pool**.

---

## 2. Fix: Google Play "Child Safety Standards" rejection

1. Fill in the `[…]` placeholders in `docs/store/child-safety-standards.html`.
   The **developer name** must be exactly as shown on the Play listing. Add a
   real child-safety email, a contact name and an address.
2. Host it at a public URL such as `https://<your-domain>/child-safety`
   (GitHub Pages, Netlify, Firebase Hosting or your website).
   Open it in a private window to confirm it loads.
3. Link it from the Terms of Service and the Help/Support page.
4. Play Console → **Policy and programs → App content → Child safety standards**:
   - **Published standards URL:** the page from step 2.
   - **Child safety point of contact:** a person and email that can answer
     Google about CSAE (the same email as on the page).
   - Confirm that the app has an **in-app way to report concerns**, complies
     with child safety laws, and reports CSAM to NCMEC / national authorities.
5. Save → go to **Publishing overview** → **Send for review**.

In-app reporting is built: long-press a message or family card, a ride
chat's ⋮ menu, or a group member → **Report** (optionally **Block**).
Reports land in `public.user_reports` (see section 6 for reviewing them).

---

## 3. Images

### App icon
| Store | Size | Format |
|---|---|---|
| App Store | **1024 × 1024** | PNG, no transparency, no rounded corners. Already in `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png` (no alpha ✓). |
| Google Play | **512 × 512** | 32-bit PNG, ≤ 1 MB. Export from `assets/brand/app_icon.png`. |

### iPhone screenshots (App Store)
Portrait. Upload 1 to 10 per size. App Store Connect scales the largest set
down to smaller iPhones, so the **6.9″ set is the one you need**.

| Display | Devices | Portrait size (px) |
|---|---|---|
| **6.9″ (required)** | iPhone 16 Pro Max, 15 Pro Max, 16 Plus | **1320 × 2868** (also accepted: 1290 × 2796, 1260 × 2736) |
| 6.5″ (only if no 6.9″ set) | iPhone 11 Pro Max, XS Max | 1284 × 2778 or 1242 × 2688 |
| 6.3″ | iPhone 16 Pro, 15 Pro | 1206 × 2622 or 1179 × 2556 |
| 6.1″ | iPhone 16, 15, 14 | 1179 × 2556 or 1170 × 2532 |
| 5.5″ | iPhone 8 Plus | 1242 × 2208 |

**Easiest way:** run the app on the **iPhone 16 Pro Max** simulator and take a
screenshot with ⌘S. That gives 1320 × 2868.

### iPad screenshots: required at the moment
The Xcode target supports iPad (`TARGETED_DEVICE_FAMILY = "1,2"`), so App Store
Connect requires a **13″ iPad** set: **2064 × 2752** (or 2048 × 2732).
Either upload them (iPad Pro 13-inch simulator) or make the app
**iPhone-only**: Xcode → Runner → General → Supported Destinations → remove
iPad. iPhone-only is recommended because the layouts are designed for phones.

### Google Play graphics
| Asset | Size |
|---|---|
| Feature graphic (required) | **1024 × 500** PNG/JPG, no transparency |
| Phone screenshots (2–8) | 9:16, e.g. **1080 × 1920** or **1080 × 2400**. Each side 320–3840 px. |
| 7″ / 10″ tablet screenshots | Optional (Android). Skip unless you support tablets. |

**Suggested screenshot set (both stores, 5–6 images):**
1. Home dashboard with the next ride
2. Ask for a ride (route, date, time)
3. Families near you / group chat
4. Live ride tracking map
5. Ride summary / drop-off confirmed
6. Profile: kids, schools & activities

Don't use real people's names, phone numbers or children's photos. Use the
demo families.

---

## 4. App Store Connect

- **App Information:** name *Kid Pool*, subtitle (≤ 30 characters), category
  **Navigation** or **Lifestyle**, age rating questionnaire. "Unrestricted
  web access" is No. User-generated content and location sharing are Yes,
  which will likely give a 12+ or 17+ rating.
- **App Privacy** ("nutrition labels"): declare precise location, name, phone,
  photos, other user content (chats), children's info and device ID
  (push token). Purpose: app functionality. Not used for tracking/ads.
- **App Review Information:**
  - give a **demo parent account and a demo driver account** (phone + how to
    get the OTP, e.g. a fixed test OTP);
  - explain the ride flow in notes;
  - say that **background location is used only during an active ride, as
    the driver**.
- **Background location:** `UIBackgroundModes: location` is on. Reviewers
  check it, so the notes and the Info.plist usage strings must match
  (they do now).
- **Export compliance:** HTTPS only means "uses standard encryption, exempt".
  Add `ITSAppUsesNonExemptEncryption = NO` to Info.plist to skip the question
  on every build.
- **Push notifications:** only once Firebase/APNs is set up
  (see `docs/backend/2026-11-10_push_setup.md`).
- **Sign in:** the app uses phone OTP only, with no Google/Facebook login,
  so *Sign in with Apple* isn't required.

## 5. Google Play Console

Follow `docs/play_store_submission.md`. Additionally:
- **App content → Child safety standards:** see section 2.
- **Data safety → account deletion URL:** the deletion page from section 1.
- **Foreground service (location):** a short video of a driver starting a
  ride, the ongoing notification, and the app tracking until drop-off.
- **Target audience: 18+ only.** Children don't use the app.

---

## 6. Gaps in the app that will block review

| Gap | Store rule | What to build |
|---|---|---|
| Policy links are `example.com` | Both | Real URLs in `app_constants.dart` (section 1). |
| ~~No in-app account deletion~~ **Built** | Apple 5.1.1(v), Play User Data | Profile → **Delete account** (type DELETE to confirm). It needs the `delete-account` Edge Function deployed (`supabase/functions/delete-account`). |
| ~~No report / block~~ **Built** | Apple 1.2, Play Child Safety | Long-press messages and family cards, the ride chat ⋮ menu, group members → Report / Block. Profile → **Blocked people** to unblock. Needs `docs/backend/2026-11-16_reports_and_blocks.sql`. |
| **Someone must review reports within 24 hours** | Apple 1.2, Play Child Safety | `select * from public.user_reports where status = 'open' order by created_at;` in the SQL editor, at least daily. Set `status` / `review_notes` when handled. An email alert on new reports is a good next step. |
| Help & support is just a web link | Play Child Safety | The support page should still list a contact email. |
| Push notifications are off | Not a review blocker | Only matters if the listing promises notifications when the app is closed. |
| iPad enabled without iPad layouts | Apple 2.1 / screenshots | Make the app iPhone-only (section 3). |
| Test data on the shared Supabase project | Not a review blocker | Reviewers will see demo families. Fine for review, but a separate production project is recommended before launch. |
