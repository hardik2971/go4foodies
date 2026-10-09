# Go4Foodie — Google Play release kit

## 1. App identity

| Field | Value |
|---|---|
| App name | **Go4Foodie** |
| Package name | **com.go4foodie.app** (permanent after first upload) |
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

Builds (copies in `builds/`, originals in `mobile-app/build/app/outputs/`). The current `*-LAN-TEST` files point at `http://192.168.1.44:33675` (this PC), so they work on phones on the same Wi-Fi only. **Do not upload them to production.**

| File | Use |
|---|---|
| `bundle/release/app-release.aab` | **Upload this to Play Console** (Play only accepts AAB for new apps) |
| `flutter-apk/app-release.apk` | Signed APK to install directly on phones for testing |

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
- Email: `______________________` (fill in — shown publicly)
- Website: `______________________` (your live domain)
- Phone: optional

## 4. Privacy policy (required)

The website already has a privacy page at `/privacy`.
Privacy policy URL: `https://<your-domain>/privacy`, which must be publicly reachable before you submit.

## 5. App content answers (Policy → App content)

**Ads:** No, the app does not contain ads.

**App access:** "All or some functionality is restricted". Give reviewers a working login on the **live** server:
```
Customer App:  customer@merchant.test / customer123   (change to your own reviewer account)
```

**Target audience:** 18+. The menu lists wine and drinks, so don't target children.

**Content rating (IARC questionnaire):** category **"All other app types"**. Answer **No** to violence, sexuality, language, gambling and controlled substances. If the app **sells alcohol**, answer Yes to "references to alcohol". User-to-user interaction: No. Shares location: No. Digital purchases: **Yes** (gift cards / food orders paid in-app).

**Data safety form:**

| Data type | Collected | Shared | Purpose | Notes |
|---|---|---|---|---|
| Name | Yes | No | Account management, App functionality | Customer account |
| Email address | Yes | No | Account management, App functionality | Login |
| Phone number | Yes | No | App functionality | Bookings / orders |
| Purchase history | Yes | No | App functionality | Orders, bookings, gift cards |
| Payment info | **No** (handled by Razorpay / Stripe / PayPal) | — | — | Card details never reach your server |
| Photos / camera | **No** (camera only scans table QR codes, nothing is stored) | — | — | |
| Location | No | — | — | |

- Data encrypted in transit: **Yes**, but only true once the live server uses **HTTPS**
- Users can request data deletion: **Yes** (see account deletion below)

**Account deletion (required because users can create accounts):** Play requires
1. a way to delete the account inside the app, **and**
2. a public web link where users can request deletion (for example `https://<your-domain>/delete-account`, or an email address page).

**Not built yet.** Add this before submitting.

**Permissions:** `INTERNET`, `CAMERA` (QR code scanning). No sensitive-permission declaration form is needed.

**Government apps / financial features / health:** No.

## 6. Signing key: back this up now

| Item | Location |
|---|---|
| Upload keystore | `mobile-app/android/app/upload-keystore.jks` |
| Passwords + alias | `mobile-app/android/key.properties` (alias `upload`) |
| Valid until | 24 Feb 2054 |
| SHA-1 | `98:CD:9A:A0:2E:C4:CF:8D:C9:0E:48:C2:4F:E9:DE:F7:A5:B0:ED:5E` |
| SHA-256 | `93:07:3E:2C:1B:36:45:39:14:20:36:8A:64:45:13:66:F4:D5:76:C2:A1:97:9D:4D:E0:86:5C:70:1C:3E:D7:EB` |

- Both files are git-ignored. **Copy them to a safe place now** (password manager plus a cloud backup). If you lose them, you cannot publish updates without a Google support key reset.
- On first upload, accept **Play App Signing** (Google keeps the final app-signing key; this file is your *upload* key).

## 7. Final production build (after the server is live)

From `mobile-app/`:
```
flutter build appbundle --release ^
  --dart-define=API_BASE_URL=https://<your-api-domain> ^
  --dart-define=SITE_ORIGIN=https://<your-website-domain>
```
Output: `build/app/outputs/bundle/release/app-release.aab`. Upload that file.

For every later update, raise the version in `pubspec.yaml` (e.g. `1.0.1+2`; the number after `+` must always increase).

## 8. Checklist before you press "Send for review"

- [ ] Admin/API deployed on a public **HTTPS** domain
- [ ] Website deployed; `/privacy` page publicly reachable
- [ ] Rebuild the AAB with `API_BASE_URL` and `SITE_ORIGIN` (section 7). **The current build points at this PC's local network and won't work for the public.**
- [ ] Payment gateways (Razorpay / Stripe / PayPal) switched to **live** keys and the website domain allowed in their dashboards
- [ ] Restaurant profile in Admin → Settings updated (it still says "The Merchant Boston / 60 Franklin Street", and the app shows it on the customer home)
- [ ] Account deletion in-app + web link
- [ ] Reviewer login on the live server
- [ ] Contact email for the listing
- [ ] Keystore + key.properties backed up
- [ ] **New personal developer account?** Google requires a **closed test with at least 12 testers for 14 days** before you can apply for production. Organization accounts skip this. Start that test early.
