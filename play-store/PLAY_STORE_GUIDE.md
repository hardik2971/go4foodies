# Go4Foodie — Google Play release kit

## 0. Live servers (Firebase)

Everything now runs on Firebase — no VPS, no local network.

| What | URL | Used for |
|---|---|---|
| **API** (Cloud Function `api`) | `https://go4foodies.web.app` | The app's backend — `API_BASE_URL` |
| **Website** (Next.js static site, Firebase Hosting) | `https://go4foodies-restaurant.web.app` | Customer website, privacy policy, terms, payment page origin — `SITE_ORIGIN` |
| **Admin panel** (Flutter Web, Firebase Hosting) | `https://go4foodies-admin.web.app` | Restaurant back office (not part of the app) |
| Health check | `https://go4foodies.web.app/up` → `ok` | |

> **Custom domain later?** If you connect one (Firebase console → Hosting → `go4foodies-restaurant` → Add custom domain), use it everywhere below instead of the `web.app` address, rebuild the app and update the Play listing URLs.

> ⚠️ **Do not use `themerchant.disolutions.net`** anywhere in the Play Console. It is the old VPS site and its privacy page is titled *"Privacy Policy · The Merchant Boston"* — it does not mention Go4Foodie, so Google rejects it as an invalid privacy policy.

## 1. App identity

| Field | Value |
|---|---|
| App name | **Go4Foodie** |
| Package name | **com.infidec.go4foodie** (permanent after first upload) |
| Version | 1.0.0 (version code 1) — from `mobile-app/pubspec.yaml` (`version: 1.0.0+1`) |
| Min Android | Android 7.0 (API 24) |
| Target SDK | API 36 |
| Default language | English (United States) – en-US |
| App or game | App |
| Free or paid | Free |
| Category | Food & Drink |
| Ads | No ads |

## 2. Files in this folder

| File | Play Console field | Spec |
|---|---|---|
| `app-icon-512.png` | Store listing → App icon | 512×512 PNG |
| `feature-graphic-1024x500.png` | Store listing → Feature graphic | 1024×500 PNG |
| `phone-screenshot-01..08.png` | Store listing → Phone screenshots | 1080×1920 (9:16), 8 images (Play maximum) |
| `raw/` | Original emulator captures (not for upload) | — |

**Builds:** the files in `builds/` named `*-LAN-TEST` point at `http://192.168.1.44:33675` (an old local test server) and **must not be uploaded** — reviewers cannot reach that address, so they could not log in. Build a fresh release AAB for Play as described in section 7.

| File | Use |
|---|---|
| `mobile-app/build/app/outputs/bundle/release/app-release.aab` | **Upload this to Play Console** (Play only accepts AAB for new apps) |
| `mobile-app/build/app/outputs/flutter-apk/app-release.apk` | Signed APK to install directly on phones for testing |

## 3. Store listing text

**App name (max 30):**
```
Go4Foodie
```

**Short description (max 80):**
```
Order food, book a table and buy gift cards — all in one restaurant app.
```

**Full description (max 4000):**
```
Go4Foodie brings the whole restaurant experience to your phone.

ORDER YOUR WAY
• Browse the live menu with real prices and availability
• Search dishes and filter by category
• Order take away for now or schedule a pickup for later
• At the restaurant? Scan the QR code on your table and order straight to the kitchen
• Track every order live

BOOK A TABLE
• Pick a date, time and party size in a few taps
• Plan private events and celebrations
• See all your bookings in one place

GIFT CARDS
• Buy gift cards for friends and family
• Keep your gift cards and coupons in the app

FOR THE RESTAURANT TEAM
• Restaurant App: run the floor, kitchen orders and point of sale
• Owner App: business insights and full control

Secure payments are handled by trusted payment providers.

Great moments with great tastes — Go4Foodie.
```

**Tags (pick in Console):** Food & Drink, Restaurant, Food ordering, Table reservation

**Contact details (required):**
- Email: `info@infidec.com` (shown publicly — same address as the website, privacy policy and deletion page)
- Website: `https://go4foodies-restaurant.web.app` (or your custom domain)
- Phone: optional

## 4. Privacy policy (required)

**Privacy policy URL** (Play Console → Policy → App content → Privacy policy, and Store settings):
```
https://go4foodies-restaurant.web.app/privacy
```
The page is live and titled *"Privacy Policy · Go4Foodie"*. Terms: `https://go4foodies-restaurant.web.app/terms`.

Google rejects a policy that does not match the app, so before you submit check that the policy text (`website/app/privacy/page.tsx`):

- [ ] names **Go4Foodie** and the developer exactly as on your Play developer account
- [ ] covers the **Android app**, not only the website ("when you visit our website…")
- [ ] lists the data the app collects: name, e-mail, phone, address, order / booking / gift-card history, account password (stored hashed)
- [ ] explains the **camera** permission (scanning table QR codes only; no photos are stored or uploaded)
- [ ] names the third parties: Google Firebase (hosting & database), Razorpay / Stripe / PayPal (payments — card data never reaches our servers), the e-mail (SMTP) provider
- [x] explains **how to delete an account** — "Account Deletion" section linking to `/delete-account` (added 28 Oct 2026)
- [ ] states how long data is kept (the deletion page does; add a short retention line to the policy too)
- [x] contact e-mail is `info@infidec.com`, highlighted in the theme colour (website, privacy, terms and deletion page all updated)
- [ ] real postal address (the policy, terms and footer still show the demo "245 Harbor View Avenue, Boston, MA 02127")
- [x] shows a "Last updated" date (October 28, 2026)

The privacy policy must also be **reachable inside the app** (Play User Data policy) — see the checklist in section 8.

## 5. App content answers (Policy → App content)

**Ads:** No, the app does not contain ads.

**App access:** "All or some functionality is restricted". Give reviewers these logins on the **live** server (all verified 28 Oct 2026 against `https://go4foodies.web.app`):
```
Customer App:    mohit@go4foodies.com / Hardee@2971
Restaurant App:  george@merchant.test / admin123
Owner App:       george@merchant.test / admin123
```
Instructions for reviewers: *"Open the app and choose Customer App, Restaurant App or Owner App, tap Sign in and use the matching login above."*

Keep these accounts active — if one is deleted, deactivated (Admin → Customers → Inactive) or its password is changed, the review fails. Mohit's phone number is a placeholder (`+91 9876543210`); change it in the app under Profile if you like.

> `george@merchant.test` is the restaurant **owner** account. It also signs in to the admin panel with full control, and its password is the public demo one. Before going live, consider creating separate reviewer accounts (a staff account for the Restaurant App) with a stronger password.

**Target audience:** 18+. The menu lists wine and drinks, so don't target children.

**Content rating (IARC questionnaire):** category **"All other app types"**. Answer **No** to violence, sexuality, language, gambling and controlled substances. If the app **sells alcohol**, answer Yes to "references to alcohol". User-to-user interaction: No. Shares location: No. Shares precise location with other users: **No**. Purchase of **digital goods: No** (food, table bookings and restaurant gift cards are physical goods/services). Cash rewards / gift cards / play-to-earn / NFTs: **No** (gift cards are bought with the customer's own money, not earned as rewards; neither follow-up option applies). Web browser or search engine: No. News or educational: No.

**Data safety form:**

| Data type (Play category) | Collected | Shared | Purpose | Notes |
|---|---|---|---|---|
| Personal info → Name | Yes | No | Account management, App functionality | Customer account |
| Personal info → Email address | Yes | No | Account management, App functionality | Login, order e-mails |
| Personal info → Phone number | Yes | No | App functionality | Orders, bookings |
| Personal info → **Address** | Yes (optional) | No | App functionality | Profile address field |
| Financial info → Purchase history | Yes | No | App functionality | Orders, bookings, gift cards |
| Financial info → Payment info | **No** | — | — | Handled by Razorpay / Stripe / PayPal; card details never reach our servers |
| Photos and videos / Camera | **No** | — | — | Camera only scans table QR codes; nothing is stored |
| Location | No | — | — | |
| App activity, App info & performance, Device IDs | No | — | — | No analytics or crash SDKs in the app |

- Data is collected: **required** for name / e-mail / phone (account), **optional** for address.
- Data encrypted in transit: **Yes** — the live API and website are HTTPS-only (Firebase). Build the release with HTTPS URLs (section 7).
- Users can request data deletion: **Yes**.
- **Delete account URL** (Data safety → Data deletion): `https://go4foodies-restaurant.web.app/delete-account` — **live**.

**Account deletion (required because users can create accounts):** Play requires
1. a way to delete the account **inside the app** (e.g. Profile → Delete account), **and**
2. a **public web page** where users can request deletion without the app (the URL above).

**Status:**
- ✅ Web page **done** — `/delete-account` explains the steps (e-mail `info@infidec.com` from the account address), what is deleted, what is kept (order/payment records up to 7 years, anonymised) and the 30-day timeline. Linked from the footer and the privacy policy.
- ✅ In-app option **built** — Customer app: **Profile → Privacy & legal → Delete account**. The user confirms with their password and the account is deleted immediately (`DELETE /api/mobile/auth/me`): the customer record and sign-in details are removed, and past orders, bookings, gift cards and table sessions are unlinked, with name, e-mail and phone replaced by "Deleted customer". Restaurant and Owner logins (staff accounts managed by the restaurant) open the `/delete-account` page instead.
- ✅ **Privacy Policy** and **Terms** links in the app: Profile → Privacy & legal (all three modes), plus the sign-in and create-account screens. They open in an in-app browser tab.
- E-mail requests sent via the web page are still handled by hand: delete the customer in Admin → Customers.

**Permissions:** `INTERNET`, `CAMERA` (QR code scanning). No sensitive-permission declaration form is needed.

**Government apps / financial features / health:** No.

## 6. Signing key: back this up now

| Item | Location |
|---|---|
| Upload keystore | `mobile-app/android/app/upload-keystore.jks` |
| Passwords + alias | `mobile-app/android/key.properties` (alias `upload`) |
| Valid until | ~2054 (10,000 days from 28 Oct 2026) |
| SHA-1 | `3D:57:01:5C:EF:D6:43:4F:EA:02:C3:30:CF:7B:94:FD:52:18:FC:91` |
| SHA-256 | `1E:74:DE:0B:CE:FD:CB:E6:08:74:81:7A:BD:03:C9:66:C7:19:BC:B1:C6:BF:8B:12:85:E4:67:91:DB:9B:CE:6A` |
| Backup copy | `secrets/go4foodie-upload-keystore.jks` + `secrets/go4foodie-key.properties` (regenerated 28 Oct 2026 for `com.infidec.go4foodie` — the old key was missing, so builds fell back to the debug key and Play rejected them) |

- Both files are git-ignored. **Copy them to a safe place now** (password manager plus a cloud backup). If you lose them, you cannot publish updates without a Google support key reset.
- On first upload, accept **Play App Signing** (Google keeps the final app-signing key; this file is your *upload* key).

## 7. Final production build (servers are live)

The app now defaults to the live servers (`API_BASE_URL` = `https://go4foodies.web.app`, `SITE_ORIGIN` = the website above). Passing both values anyway keeps the build explicit.

From `mobile-app/` (Windows `cmd`):
```
flutter build appbundle --release ^
  --dart-define=API_BASE_URL=https://go4foodies.web.app ^
  --dart-define=SITE_ORIGIN=https://go4foodies-restaurant.web.app
```
PowerShell: replace each `^` with a backtick `` ` ``. Git Bash / macOS: replace `^` with `\`.

Output: `build/app/outputs/bundle/release/app-release.aab`. Upload that file.

Before uploading, install the matching APK (`flutter build apk --release` with the same two `--dart-define`s) on a real phone **on mobile data** (not your Wi-Fi) and check: login, menu, take-away order, booking, card payment screen, Profile.

Recommended for production: remove `android:usesCleartextTraffic="true"` from `android/app/src/main/AndroidManifest.xml` (only needed for old `http://` test servers) so the app can only talk HTTPS.

For every later update, raise the version in `pubspec.yaml` (e.g. `1.0.1+2`; the number after `+` must always increase).

## 8. Checklist before you press "Send for review"

Servers
- [x] API live on HTTPS — `https://go4foodies.web.app` (Firebase Cloud Functions)
- [x] Website live on HTTPS — `https://go4foodies-restaurant.web.app` (Firebase Hosting); `/privacy`, `/terms` and `/delete-account` reachable. The old `…hosted.app` address is deleted.
- [x] Admin panel live — `https://go4foodies-admin.web.app`
- [x] Reviewer login works on the live server (`mohit@go4foodies.com`)

Privacy & policy (most common rejection reasons)
- [ ] Privacy policy URL in Play Console = `https://go4foodies-restaurant.web.app/privacy` (**not** `themerchant.disolutions.net`)
- [ ] Privacy policy text fully updated for the app (section 4 list — e-mail and deletion done; app, camera, third parties, retention, address still to do)
- [x] Privacy policy link **inside the app** — Profile → Privacy & legal, plus the sign-in and create-account screens
- [x] Public account-deletion page `/delete-account` — live
- [x] In-app account deletion option — Profile → Delete account (needs the `functions` deploy with `DELETE /api/mobile/auth/me`)
- [ ] Data safety form filled exactly as section 5 (including **Address** and the deletion URL)

Build & listing
- [ ] Release AAB built with the section 7 command (live `API_BASE_URL` + `SITE_ORIGIN`) — **not** a `*-LAN-TEST` build
- [ ] Payment gateways (Razorpay / Stripe / PayPal) switched to **live** keys and the website domain allowed in their dashboards (currently test/sandbox keys)
- [ ] Restaurant profile in Admin → Settings updated (it still says "The Merchant Boston / 60 Franklin Street", and the app shows it on the customer home)
- [x] Contact email for the listing — `info@infidec.com`
- [ ] Keystore + key.properties backed up
- [ ] **New personal developer account?** Google requires a **closed test with at least 12 testers for 14 days** before you can apply for production. Organization accounts skip this. Start that test early.
