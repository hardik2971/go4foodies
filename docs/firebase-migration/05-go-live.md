# Go-live runbook — VPS → Firebase

Everything runs in Firebase project **go4foodies** (region asia-south1). Nothing depends on the VPS afterwards.

| Piece | Where it runs (live URL) | Source |
|---|---|---|
| Backend API (`/api/*`, `/api/mobile/*`, `/api/admin/*`) | Cloud Function `api` (asia-south1, runs as `firebase-adminsdk-fbsvc@…`) behind Hosting: **https://go4foodies.web.app/api/…** (also `/api` on the admin site) | `firebase/functions` |
| Database | Firestore `(default)` (asia-south1) | migrated by `firebase/migration/migrate.mjs` |
| Uploads | Cloud Storage `uploads/` | via `/api/upload`, served at `/api/uploads/:name` |
| Admin panel | Firebase Hosting site `go4foodies-admin`: **https://go4foodies-admin.web.app** | `admin-app` (Flutter Web) |
| API host | Firebase Hosting site `go4foodies`: **https://go4foodies.web.app** (`/api/**` → function; `/` → admin site) | `firebase/api-public` |
| Public website | Firebase App Hosting backend `go4foodies-web` (asia-southeast1 — App Hosting has no Mumbai region): **https://go4foodies-web--go4foodies.asia-southeast1.hosted.app** | `website` (`firebase.json` + `apphosting.yaml`) |
| Mobile app | Play Store / App Store | `mobile-app` (only the default API URL changed) |

Redeploy:
```
cd admin-app && flutter build web --release        # then:
cd firebase && FUNCTIONS_DISCOVERY_TIMEOUT=90 firebase deploy --only functions,hosting,firestore,storage
cd website  && firebase deploy --only apphosting
```

## 1. One-time Google Cloud permissions (project owner, in the console)

The `firebase-adminsdk-fbsvc@go4foodies.iam.gserviceaccount.com` key cannot enable APIs. Either deploy from
your own account (`firebase login`, then the commands below), **or** grant that service account, in
IAM & Admin → IAM: *Editor*, *Service Account User*, *Service Account Token Creator*, *Cloud Functions Admin*,
*Secret Manager Admin*, *Firebase Hosting Admin*.

Enable these APIs once (APIs & Services → Library), or let the first `firebase deploy` do it from an owner login:
- IAM Service Account Credentials API (`iamcredentials.googleapis.com`) — admin login mints Firebase tokens
- Cloud Functions, Cloud Build, Artifact Registry, Cloud Run, Secret Manager, Eventarc

The project must be on the **Blaze** plan.

Then allow the function's runtime identity to mint custom tokens (admin login):
IAM → the *Default compute service account* (`<number>-compute@developer.gserviceaccount.com`) →
add role **Service Account Token Creator**.

## 2. Secrets and config

Secrets (Secret Manager) — values from the VPS `.env`:
```
firebase functions:secrets:set AUTH_SECRET          # MUST equal the VPS value, so app logins survive
firebase functions:secrets:set MAIL_PASSWORD
firebase functions:secrets:set RAZORPAY_KEY_SECRET
firebase functions:secrets:set STRIPE_SECRET_KEY
firebase functions:secrets:set PAYPAL_CLIENT_SECRET
```
Plain config — `firebase/functions/.env.go4foodies` (deployed with the function; no secrets in it):
```
LOCAL_TZ=Asia/Kolkata
WEBSITE_URL=https://themerchant.disolutions.net
MAIL_HOST=…  MAIL_PORT=…  MAIL_SCHEME=…  MAIL_USERNAME=…  MAIL_FROM_ADDRESS=…
RAZORPAY_KEY_ID=…  RAZORPAY_CURRENCY=…
STRIPE_PUBLISHABLE_KEY=…  STRIPE_CURRENCY=…
PAYPAL_CLIENT_ID=…  PAYPAL_ENV=…  PAYPAL_CURRENCY=…
```
A secret that has no value yet must still exist (set it to an empty string) or the deploy fails.

## 3. Deploy
```
cd admin-app && flutter build web --release
cd ../firebase && firebase deploy --only functions,hosting,firestore,storage
cd ../website && firebase apphosting:backends:create --location asia-south1   # first time; connect the GitHub repo
```
Smoke test: `https://go4foodies.web.app/up` → `ok`; sign in to the admin; `GET /api/menu`.

## 4. Cut-over (short write freeze)
1. Stop taking orders on the VPS (maintenance page) — or pick a quiet hour.
2. On the VPS: `mysqldump -u root -p restaurant_db > restaurant_db.sql`; copy to `secrets/`.
   Copy any files in the VPS `UPLOAD_DIR` to Storage `uploads/` (today all menu images are external URLs).
3. `cd firebase/migration && node migrate.mjs --reset` (Firestore becomes an exact copy of the dump).
4. Point the website (App Hosting) at the custom domain; update DNS.
5. Release the mobile app build (default API URL is now `https://go4foodies.web.app`).
6. Watch `firebase functions:log` for a day, then shut down the VPS.

## Verified before go-live
Run side-by-side against the same dump (old Laravel on MariaDB vs new function on Firestore):
- 33 read endpoints (public + all mobile staff/customer screens): identical JSON (1 diff = config URL).
- 24-step POS write workflow (open → items → void → billing → split pay → close, order status,
  inventory, error cases) and the resulting floor/history/transactions/audit/analytics/dashboard: identical.
- Website writes (reservations, take-away + dine-in orders, gift cards, coupons, validation errors): identical
  apart from creation timestamps.
- Website end-to-end (production `next build` + `next start` against the new API): take-away order, table-QR
  order, table booking and gift-card purchase completed through the real pages in a browser; records appear in
  the admin (QR order auto-opens the table session); SSR `/menu` and `/order?table=` render from the new API.
- Mobile app (release build on an Android emulator, API_BASE_URL → new API): Owner app (dashboard, floor,
  reports, manage, profile); Restaurant app full POS cycle (open table → KOT → void → $10 UPI part-payment →
  close & settle by card → stored as "Mixed", table → Cleaning); Customer app (register, table booking with live
  slots, pay-at-restaurant order, in-app Stripe card payment → order stored with provider=stripe, My Orders).
  Release builds default to `https://go4foodies.web.app`; no other app change was needed.
- Payments (sandbox keys): Razorpay/Stripe/PayPal orders created; Stripe paid in browser + in app; Razorpay
  signature accepted/forged rejected; PayPal unapproved rejected; orders without payment → 402.
- SMTP (Ethereal test account, then Gmail): all 9 email types sent with 0 failures — order confirmed / completed,
  table + event reservation confirmed, reservation completed, gift card + coupon purchased, gift card redeemed.
  Production only needs the real `MAIL_*` values.
