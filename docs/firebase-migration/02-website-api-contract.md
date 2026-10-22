# 02 — Website ↔ Backend API Contract (Laravel → Firebase)

Scope: the public Next.js storefront at `website/` and the Laravel endpoints it depends on
(`admin/routes/api/public.php`). This is the contract the Firebase replacement
(Firestore + Cloud Functions + Auth + Storage) must honour so the website keeps identical behaviour.

Sources read: every file in `website/app`, `website/components`, `website/lib`, `website/package.json`,
`website/next.config.mjs`, `website/.env`; `admin/routes/api/public.php`,
`admin/app/Http/Controllers/Api/*.php` (non-Mobile), `admin/app/Http/Controllers/Api/Support/*.php`,
`admin/app/Services/{OnlineOrder,Uploads,Scheduling,Mailer}.php`, `admin/app/Services/Payments/*`
(plus `EmailTemplates.php` subjects, models, `config/go4foodie.php` for context).

---

## 1. Architecture as it is today

```
Browser ──same-origin──▶ Next.js route handlers (website/app/api/*)  ──server-side fetch──▶ ADMIN_API_URL/api/*
Next.js server components (menu/order pages) ─────────────────────────server-side fetch──▶ ADMIN_API_URL/api/*
```

* The browser **never** calls the admin host directly. All browser calls go to same-origin `/api/*`
  route handlers that are thin pass-through proxies (`req.text()` forwarded as the body,
  `Content-Type: application/json`, `cache: 'no-store'`, upstream status + JSON returned verbatim).
* Server components call `ADMIN_API_URL/api/menu` and `ADMIN_API_URL/api/tables/{code}` directly.
* Base URL: `website/lib/admin-api.ts` → `process.env.ADMIN_API_URL ?? 'http://127.0.0.1:33664'` (trailing `/` stripped).
* No auth of any kind is sent by the website (no cookies, no bearer tokens, no API key).
* **No polling, no SSE, no websockets, no uploads** from the website. The only "reactive" fetch is
  `DineInStep` re-fetching availability when the selected date changes.
* Payment secrets live only in the backend; the website receives public keys
  (`keyId`, `publishableKey`, `clientId`) at runtime from `POST /api/payment`. The website has no payment env vars.

### Proxy behaviour (common to all `website/app/api/*` handlers)

| Website route | Upstream | On upstream non-JSON body | On network error (fetch throws) |
|---|---|---|---|
| `GET /api/availability?date=` | `GET /api/reservations/availability?date=<encoded>` | `{error:'Unexpected response from server'}` w/ upstream status | `502 {error:'Availability unavailable'}` |
| `POST /api/orders` | `POST /api/orders` | same | `502 {error:'Ordering is temporarily unavailable. Please try again shortly.'}` |
| `POST /api/reservations` | `POST /api/reservations` | same | `502 {error:'Reservations are temporarily unavailable. Please try again shortly.'}` |
| `POST /api/gift-cards` | `POST /api/gift-cards` | same | `502 {error:'Gift cards are temporarily unavailable. Please try again shortly.'}` |
| `GET /api/payment` | `GET /api/payment` | `{razorpay:false,stripe:false,paypal:false}` w/ upstream status | `200 {razorpay:false,stripe:false,paypal:false}` |
| `POST /api/payment` | `POST /api/payment` | `{error:'Unexpected response from server'}` | `502 {error:'Payment is temporarily unavailable.'}` |
| `POST /api/payment/capture` | `POST /api/payment/capture` | same | `502 {error:'Payment is temporarily unavailable.'}` |

All client components surface errors the same way: `if (!res.ok) throw new Error(data.error || '<fallback>')`
and show the message in a red banner. **Therefore every error response must be JSON with a human-readable `error` string.**

---

## 2. Common backend conventions (must be reproduced)

* **Error body:** `{ "error": string, ...extra }`. Validation failures add `issues` (zod-v3-style array:
  `{code, path[], message, expected?, received?, minimum?, maximum?, type?, inclusive?, exact?, options?, validation?}`).
  The website only reads `error`; `issues` is informational (keep it for parity / mobile app).
* **Body parsing:** invalid/missing JSON is treated as `null` → fails schema validation → 400.
* **Objects strip unknown keys** (zod semantics). `z.coerce.number()` uses JS `Number()` semantics (`"3"` → 3, `""` → 0).
* **Numbers:** whole floats serialise as ints (`12.0` → `12`), like `JSON.stringify`.
* **Dates:** ISO-8601 UTC with milliseconds (`2026-10-22T18:30:00.000Z`).
* **Cache-Control:** `no-store` on menu, tables, payment endpoints (`Json::noStore`); none on others.
  Upload files: `public, max-age=31536000, immutable`.
* **IDs:** cuid strings generated app-side; `createdAt`/`updatedAt` set automatically.
* **Timezone ("server local"):** `config('app.local_timezone')` = env `APP_LOCAL_TIMEZONE`, default `UTC`.
  All slot/cutoff math is done in this zone. Cloud Functions run in UTC — the Firebase port must use an
  explicit, configured restaurant timezone to keep behaviour identical (and ideally fix it to the real one).
* **Email:** `Mailer::sendMail` via SMTP (`MAIL_*`). If SMTP is not configured, sending is skipped with a log
  warning. Mail failures are caught and reported — **they never fail the request.** From name: `Go4Foodie`.
* **Audit logs:** none of the public endpoints write `AuditLog`.
* **Stock:** none of the public endpoints change inventory/stock.

### Scheduling constants (`admin/app/Services/Scheduling.php`, mirrored in `website/lib/order.ts`)

| Constant | Value | Mirrored in website |
|---|---|---|
| `BUSINESS_HOURS` | open 10, close 22, 30-min slots → `10:00 … 21:30` (24 slots) | yes (`BUSINESS_HOURS`, `allSlots()`) |
| `LEAD_MINUTES` | 30 | yes |
| `PREP_MINUTES` | 25 | yes (ASAP estimate label) |
| `SLOT_CAPACITY` | 6 TABLE reservations per slot | **no** (server only) |
| `SCHEDULE_DAYS` | — | website only: 14-day picker |

`validateSlot(date, time)`:
1. `time` not in `allSlots()` → `"Outside business hours"`
2. date/time not matching `YYYY-MM-DD` / `H:mm|HH:mm` → `"Invalid date or time"`
3. slot < now + 30 min → `"That time is too soon — please pick a later slot"`

`estimatePickup('LATER', d, t)` = slot datetime; `'NOW'` (or missing d/t) = now + 25 min.

---

## 3. Endpoints used by the website

### 3.1 `GET /api/menu`

| | |
|---|---|
| Auth | none (public) |
| Called by | `website/lib/menu-api.ts#getLiveMenu` (used by `components/Menu.tsx` on `/` and `app/menu/page.tsx`), `website/app/order/page.tsx#getMenu` — **server-side**, `cache:'no-store'` |
| Request | none |

Query: `MenuItem m JOIN Category c ON c.id = m.categoryId WHERE m.available = true AND c.active = true ORDER BY c.name, m.name`.

Response `200` (`Cache-Control: no-store`):
```json
{
  "items": [
    { "id": "cuid", "name": "string", "description": "string|null", "price": 26, "rating": 4.8,
      "tag": "string (\"\" if null)", "category": "Category.name", "imageUrl": "string|null" }
  ],
  "categories": ["distinct category names, in item order (i.e. alphabetical)"]
}
```
Errors: `503 {error:'Menu unavailable'}`.
Side effects: none.

Website consumption:
* `lib/menu-api.ts`: requires `res.ok` and `items.length > 0`, else falls back to the static `MENU_ITEMS`
  / `MENU_CATEGORIES` from `lib/content.ts` (`live:false`). Maps `description→desc`, `imageUrl→image`,
  `tag ?? ''`, and uses `categories ?? MENU_CATEGORIES`. Fields used: `id,name,description,price,rating,tag,category,imageUrl`, `categories`.
* `app/order/page.tsx`: same fallback (static menu mapped to `OrderMenuItem`, categories derived from items).
  Uses the payload as-is (`OrderMenuItem` = exactly the item shape above).
* `components/Menu.tsx` shows `items.slice(0, 6)` on the home page.
* `MenuExplorer` filters by `category` and searches `name`/`desc` client-side.
* `price` must be a JS number (`.toFixed(2)` is called on it). `rating` feeds `<Stars>`.
* Images are rendered with plain `<img src={imageUrl}>` (MenuCard, MenuStep, OrderFlow summary) — **not**
  `next/image`, so any host (e.g. `firebasestorage.googleapis.com`) works without `next.config.mjs` changes.

Firebase notes: Firestore read of `menuItems where available == true` + `categories where active == true`
(join in code, sort by category name then item name). Can be served by an HTTPS function or read directly
by the Next.js server with the Admin SDK. `imageUrl` values currently pointing at
`<admin-host>/api/uploads/<name>` must be migrated to Storage download URLs (see §5).

---

### 3.2 `GET /api/tables/{code}` — table QR resolution

| | |
|---|---|
| Auth | none |
| Called by | `website/app/order/page.tsx#getTable` (server-side) when `/order?table=<code>` |
| Request | path `code` (QR token; cuid generated when the table is created) |

Query: `Table WHERE code = :code AND status = 'ACTIVE'`, columns `id, number, name, code`.

Response `200` (`no-store`): `{ "table": { "id": "cuid", "number": "string", "name": "string|null", "code": "string" } }`
Errors: `404 {error:'Table not found or inactive'}`, `503 {error:'Lookup failed'}`.
Side effects: none.

Website consumption: non-OK or thrown → `null` → page silently renders the normal `OrderFlow` instead of
`TableOrderFlow`. Uses `table.number` (banner, payment description, success copy), `table.name` (banner, optional),
`table.code` (sent back as `tableCode` in the order). `id` unused.
QR codes encode `<WEBSITE_URL>/order?table=<code>` (admin `config('go4foodie.website_url')`, env `WEBSITE_URL`) —
the Firebase admin must keep generating this exact URL format.

---

### 3.3 `GET /api/reservations/availability?date=YYYY-MM-DD`

| | |
|---|---|
| Auth | none |
| Called by | browser `components/order/DineInStep.tsx` → `GET /api/availability?date=<iso>` (proxy `app/api/availability/route.ts`). Fires on every date change; no polling. |
| Validation | `date` must match `^\d{4}-\d{2}-\d{2}$` |

Logic: day bounds = `date 00:00:00` … `23:59:59` in local tz → UTC. Count `Reservation` rows with
`kind='TABLE'`, `date` within bounds, `status NOT IN ('CANCELED','NO_SHOW')`, `time IS NOT NULL`, grouped by `time`.
For each slot in `allSlots()`: `remaining = max(0, 6 - used)`; `available = remaining > 0 && slot >= now + 30min`.

Response `200` (no explicit cache header):
```json
{ "date": "2026-10-22", "slots": [ { "time": "10:00", "available": false, "remaining": 6 }, ... 24 entries ] }
```
Errors: `400 {error:'A valid date (YYYY-MM-DD) is required'}`, `503 {error:'Availability unavailable'}`.
Side effects: none.

Website consumption: if `Array.isArray(data.slots)` uses `slots[].time/available` (`remaining` unused in UI);
otherwise (any error or bad JSON) falls back to local `allSlots()` with cutoff-only availability and shows
"Showing standard times — live availability is offline." Unavailable slots are rendered disabled/struck-through.

> Caveat to preserve or consciously fix: reservations are stored with `date = jsDate('YYYY-MM-DD')` =
> **UTC midnight**, but availability/double-booking use **local-day** bounds. Identical when tz = UTC (the default).

---

### 3.4 `POST /api/reservations`

| | |
|---|---|
| Auth | none |
| Called by | `components/ReservationFlow.tsx` (`/table-reservation`, both kinds) and `components/order/OrderFlow.tsx` (`/order` Dine-In mode, `kind:'TABLE'` only) via proxy `app/api/reservations/route.ts` |

Request schema (discriminated on `kind`, unknown keys stripped):

| field | TABLE | PRIVATE_EVENT |
|---|---|---|
| `kind` | `'TABLE'` | `'PRIVATE_EVENT'` |
| `date` | string min 1 (website sends `YYYY-MM-DD`) | string min 1 |
| `time` | string min 1 (`HH:mm`) | — |
| `guests` | coerce number, int, ≥1 | — |
| `eventType` | — | string min 1 |
| `guestRange` | — | string min 1 (e.g. `"10–20"`) |
| `space` | — | string min 1 |
| `name` | string min 2 | string min 2 |
| `email` | string, email | string, email |
| `phone` | string min 5 | string min 5 |
| `occasion` | optional string | — |
| `requests` | optional string | — |
| `company` | — | optional string |
| `message` | — | optional string |

What the website sends:
* `ReservationFlow` TABLE: `{kind,date,time,guests,name,email,phone,occasion?,requests?}` — time from fixed
  `TIME_SLOTS` `17:00…21:30` (no availability lookup; relies on server 409/422).
* `ReservationFlow` PRIVATE_EVENT: `{kind,eventType,date,guestRange,space,name,email,phone,company?,message?}`.
* `OrderFlow` dine-in: `{kind:'TABLE',date,time,guests,name,email,phone,requests?}` (time chosen from availability).

Processing order:
1. Validate → `400 {error:'Invalid payload', issues}`.
2. `reference = (kind==='PRIVATE_EVENT' ? 'EV' : 'SV') + '-' + random 100000–999999` (no uniqueness check).
3. TABLE only: `Scheduling::validateSlot(date,time)` → `422 {error:<reason>}` (see §2).
4. TABLE only: count same-day (local bounds) same-`time` TABLE reservations not CANCELED/NO_SHOW;
   `>= 6` → `409 {error:'That time slot is fully booked — please choose another.'}` (not transactional — race possible).
5. Upsert `Customer` by `email`: existing → set `name`, `phone`, `updatedAt`; else create `{name,email,phone}`.
6. Insert `Reservation`: `{id, reference, kind, date: jsDate(date) (UTC midnight for YYYY-MM-DD), name, email, phone, customerId}`
   + TABLE `{time, guests, occasion, requests}` or PRIVATE_EVENT `{eventType, guestRange, space, company, message}`.
   `status` is left to the DB default (schema not in this repo; admin treats CANCELED/NO_SHOW as terminal).
7. Email to `email`: `reservationConfirmationEmail` — subject `Table reserved {reference} · Go4Foodie` or
   `Event request {reference} · Go4Foodie`; body includes date label (`D, M j, Y`), time (12h), guests, occasion,
   requests / eventType, guestRange, space, message. Failure ignored.

Response `201`: `{ "reference": "SV-123456", "id": "cuid" }`
Errors: 400 / 422 / 409 as above; `503 {error:'Database unavailable'}`; invalid date in step 4 also lands in 503.
Website uses: `reference` only (success screen).

Shared: the Customer mobile app calls the same `ReservationController::create` (`/api/mobile/customer/reservations`).

---

### 3.5 `POST /api/orders` — online order (TAKE_AWAY and table-QR DINE_IN)

| | |
|---|---|
| Auth | none |
| Called by | `components/order/OrderFlow.tsx` (TAKE_AWAY) and `components/order/TableOrderFlow.tsx` (DINE_IN) via proxy `app/api/orders/route.ts` |

Request schema (discriminated on `type`):

| field | TAKE_AWAY | DINE_IN |
|---|---|---|
| `type` | `'TAKE_AWAY'` | `'DINE_IN'` |
| `scheduleType` | enum `NOW`/`LATER` | — |
| `scheduleDate` | optional string (`YYYY-MM-DD`) | — |
| `scheduleTime` | optional string (`HH:mm`) | — |
| `tableCode` | — | string min 1 |
| `items` | array ≥1 (`'Add at least one item'`) of `{menuItemId: string min1, name?: string, qty: coerce int 1..50}` | same |
| `name` | string min 2 | string min 1 |
| `email` | string, email (required) | optional email, or `''` |
| `phone` | string min 5 | optional string, or `''` |
| `notes` | optional string max 500 | same |
| `payment` | optional `PaymentResult` (see §3.8) | same |

Website payloads:
* TAKE_AWAY: `{type, scheduleType, scheduleDate?, scheduleTime?, items:[{menuItemId,name,qty}], name, email, phone, notes?, payment?}`
  (client pre-validates name ≥2, email regex, phone ≥5; LATER slots filtered client-side by cutoff only).
* DINE_IN: `{type:'DINE_IN', tableCode, items, name, phone?, email?, notes?, payment?}` (client requires name ≥1).
* Both call `pay({amount: subtotal, ...})` **before** posting; `payment` omitted when no gateway configured.

Processing (`App\Services\OnlineOrder::placeOnlineOrder`):
1. Validate → `400 {error:'Invalid order', issues}`.
2. Payment gate `PaymentGate::accepted(payment)` (§3.8) → `402 {error:'Payment required'|'Payment verification failed'|'Unknown payment provider'}`.
3. TAKE_AWAY + LATER: `validateSlot(scheduleDate, scheduleTime)` → `422 {error:<reason>}`.
4. Price the cart from live `MenuItem` rows: `WHERE id IN ids OR name IN names`; match each line by id, else by name
   (this is how the static fallback menu ids `m1…m21` still resolve). Missing → `422 {error:'Item not found: <name|id>'}`;
   `available=false` → `422 {error:'Item unavailable: <name>'}`. **Client prices are never trusted.** `total = Σ price×qty`.
   (Category `active` is NOT checked here.)
5. `outletId` = first `Outlet.id` or literal `'online'`. `number = 'ORD-' + random 10000–99999` (no uniqueness check).
6. If `email`: upsert `Customer` by email (update `name`, `phone` if given, `updatedAt`; or create `{name,email,phone}`).
7. **DINE_IN branch**
   * `Table WHERE code=tableCode AND status='ACTIVE'` else `422 {error:'Table not found or inactive'}`.
   * Find `TableSession WHERE tableId AND status='OPEN'`; if none → create `TableSession {tableId, customerName:name}`
     and update `Table.state='OCCUPIED', updatedAt=now`.
   * Insert `Order {number, type:'DINE_IN', status:'PENDING', channel:'ONLINE', paymentMethod: payment ? 'ONLINE' : null,
     paymentProvider, razorpayPaymentId: <payment ref>, total, outletId, customerName, customerEmail, customerPhone,
     customerId, tableId, tableNumber, sessionId, notes}` + `OrderItem {orderId, menuItemId, name, qty, price}` per line,
     in one DB transaction.
   * If email: order confirmation email, `pickupLabel = "Dine-in · Table {number}"`.
   * `201 {number, id, total, tableNumber}`.
8. **TAKE_AWAY branch**
   * Insert `Order {number, type:'PICKUP', status:'PENDING', channel:'ONLINE', paymentMethod:'ONLINE', paymentProvider,
     razorpayPaymentId, total, outletId, customerName, customerEmail, customerPhone, customerId, scheduleType,
     scheduleDate: LATER ? jsDate(scheduleDate) : null, scheduleTime: LATER ? scheduleTime : null, notes}` + items (transaction).
     Note `paymentMethod` is `'ONLINE'` even when no gateway is configured (website path; `payAtRestaurant` is mobile-only).
   * Email (always, email is required): `pickupLabel` = LATER `D, M j, g:i A` or `"As soon as possible (around g:i A)"`.
   * `201 {number, id, total, estimatedPickup: ISO}`.
9. Any other exception → `503 {error:'Could not place order'}`.

Email: `orderConfirmationEmail` — subject `Order {number} confirmed · Go4Foodie`, lists items (name, qty, line total), total,
pickup label, notes.

Website uses: TAKE_AWAY `number`, `estimatedPickup` (formatted `weekday, h:mm`; falls back to "We will text you…"), `total`
(stored but not displayed); DINE_IN `number` only.

Side-effect consumers: new `Order` rows appear in the admin Orders module / dashboard / kitchen and trigger the admin
floor SSE (`/api/floor-stream` watches `max(updatedAt)` of Table/TableSession/Order). In Firebase the admin
should use Firestore listeners instead.

Shared: Customer mobile app calls the same service (`/api/mobile/customer/orders`, with `payAtRestaurant`).

---

### 3.6 `POST /api/gift-cards` — gift card / coupon purchase

| | |
|---|---|
| Auth | none |
| Called by | `components/GiftCard.tsx` (home page dialog, also opened via `open-giftcard` window event from Header/Hero) via proxy `app/api/gift-cards/route.ts` |

Request schema:

| field | rule |
|---|---|
| `kind` | enum `GIFT_CARD`/`COUPON`, default `GIFT_CARD` |
| `amount` | coerce number, `> 0` (`'Choose an amount'`), ≤ 100000 |
| `name` | string min 2 (`'Name is required'`) |
| `email` | optional email, or `''` |
| `message` | optional string max 500 |
| `payment` | optional `PaymentResult` |

Website payload: `{kind, amount, name: yourName, email?, message?, payment?}`. **The UI also collects quantity,
recipientType/recipientName, delivery (email/print), timing and sendDate — none of these are sent**, and the charge is
`pay({amount: form.amount})` (not `amount × quantity`, although the UI computes `total`). One code per purchase.
Preserve this exactly (or fix deliberately in both places).

Processing:
1. Validate → `400 {error:'Invalid purchase', issues}`.
2. Payment gate → `402 {error:<reason>}`.
3. `expiryDate` = COUPON ? now + 365 days : null.
4. If email: upsert `Customer` by email (update `name`, `updatedAt`, or create `{name,email}`).
5. Insert `GiftCard {code, kind, customerName:name, customerEmail: email or '', customerId, amount, message, expiryDate,
   paymentStatus:'PAID', paymentProvider, razorpayPaymentId:<payment ref>, status:'ACTIVE'}`.
   `code = (COUPON ? 'COUPON' : 'GIFT') + '-' + 6 chars from '0123456789ABCDEFGHJKMNPQRSTUVWXYZ'`; retried up to 5×
   on unique-constraint collision, else `503 {error:'Could not generate a code, please retry'}`.
   Note `paymentStatus:'PAID'` even when no gateway is configured.
6. If email: `giftCardConfirmationEmail` — subject `Your Gift Card|Coupon {code} · Go4Foodie`, with amount, message,
   "Valid until M j, Y" for coupons.

Response `201`: `{ "code": "GIFT-AB12CD", "id": "cuid", "amount": 100, "kind": "GIFT_CARD" }`
Errors: 400 / 402 / 503 (`'Could not complete purchase'`).
Website uses: `code` only (shown as the reference on the success step).

Shared: Customer app `/api/mobile/customer/gift-cards` uses the same `purchase()`.

---

### 3.7 Payments — `GET /api/payment`, `POST /api/payment`, `POST /api/payment/capture`

Client flow (`website/lib/payment.ts#pay`):
1. `GET /api/payment` → `{razorpay:boolean, stripe:boolean, paypal:boolean}` (any failure ⇒ all false).
2. No provider ⇒ return `null` (dev fallback; caller submits without `payment`).
   >1 provider ⇒ in-page chooser modal (cancel ⇒ throws `'Payment cancelled.'`). Order of options: razorpay, stripe, paypal.
3. Provider-specific (all start with `POST /api/payment {provider, amount, description}`):
   * **Razorpay:** loads `https://checkout.razorpay.com/v1/checkout.js`; opens `new Razorpay({key: keyId, order_id: orderId,
     amount, currency, name:'Go4Foodie', description, prefill:{name,email,contact}, theme})`. Resolves
     `{provider:'razorpay', orderId: razorpay_order_id, paymentId: razorpay_payment_id, signature: razorpay_signature}`.
     Dismiss ⇒ `'Payment cancelled.'`; `payment.failed` ⇒ error description.
   * **Stripe:** loads `https://js.stripe.com/v3/`; `Stripe(publishableKey).elements({clientSecret, appearance:night})`,
     Payment Element in a modal, `confirmPayment({elements, redirect:'if_required'})`; requires
     `paymentIntent.status === 'succeeded'`. Resolves `{provider:'stripe', paymentIntentId}`.
   * **PayPal:** loads `https://www.paypal.com/sdk/js?client-id=<clientId>&currency=<currency||USD>`; `paypal.Buttons({createOrder: () => orderId,
     onApprove: POST /api/payment/capture {orderId}})`; requires `capData.status === 'COMPLETED'`. Resolves `{provider:'paypal', orderId}`.
4. The resolved `PaymentResult` is attached as `payment` to `/api/orders` or `/api/gift-cards`, where it is **re-verified server-side**.

Amounts shown in the UI are always `$` (USD); Razorpay currency defaults to `INR` server-side.

#### `GET /api/payment`
Auth none. Response `200` (`no-store`): `{ "razorpay": bool, "stripe": bool, "paypal": bool }`
* razorpay configured ⇔ `RAZORPAY_KEY_ID` and key secret non-empty
* stripe ⇔ `STRIPE_SECRET_KEY` and `STRIPE_PUBLISHABLE_KEY` non-empty
* paypal ⇔ `PAYPAL_CLIENT_ID` and client secret non-empty

#### `POST /api/payment`
Request (not schema-validated): `provider` (`'stripe'|'paypal'`, anything else ⇒ `'razorpay'`), `amount` (JS `Number()`; must be `> 0`),
`description` (string, default `'Order payment'`).
Website sends description like `Take Away order · $42.00`, `Table 5 order · $42.00`, `Gift card · $100`.

| provider | provider call | `200` response (`no-store`) |
|---|---|---|
| stripe | `POST https://api.stripe.com/v1/payment_intents` form: `amount=round(amount*100)`, `currency=STRIPE_CURRENCY` (lower, default `usd`), `description`, `automatic_payment_methods[enabled]=true`; Bearer secret | `{provider:'stripe', publishableKey, clientSecret}` |
| paypal | OAuth `POST {base}/v1/oauth2/token` (client credentials) then `POST {base}/v2/checkout/orders` `{intent:'CAPTURE', purchase_units:[{amount:{currency_code: PAYPAL_CURRENCY (upper, default USD), value: amount.toFixed(2)}, description: first 127 chars}]}`; base = `api-m.paypal.com` if `PAYPAL_ENV=live` else `api-m.sandbox.paypal.com` | `{provider:'paypal', clientId, orderId, currency}` |
| razorpay | `POST https://api.razorpay.com/v1/orders` basic auth `{amount: round(amount*100), currency: RAZORPAY_CURRENCY (default INR), receipt:'rcpt_<epoch ms>'}` (description not sent) | `{provider:'razorpay', keyId, orderId, amount (minor units), currency}` |

Errors: `400 {error:'Invalid amount'}`; `503 {error:'Stripe not configured'|'PayPal not configured'|'Razorpay not configured'}`;
`502 {error:'Could not start payment'}` on provider failure.
Side effects: provider-side order/intent only; **no DB writes**.
Website uses: razorpay `keyId, orderId, amount, currency`; stripe `publishableKey, clientSecret`; paypal `clientId, orderId, currency`.

#### `POST /api/payment/capture` (PayPal only)
Request: `{orderId: string}`.
Checks: PayPal not configured ⇒ `503 {error:'PayPal not configured'}`; empty `orderId` ⇒ `400 {error:'Missing orderId'}`.
Provider call: OAuth + `POST {base}/v2/checkout/orders/{orderId}/capture` (empty JSON body).
Response `200` (`no-store`): `{ "status": "COMPLETED" | <other PayPal status> }`. Failure ⇒ `502 {error:'Could not capture payment'}`.
Website requires `res.ok && status === 'COMPLETED'`. No DB writes.

#### Server-side verification — `PaymentGate::accepted(payment)` (used by orders & gift cards)
* No gateway configured ⇒ **allowed without payment**.
* Configured and `payment` missing ⇒ `402 'Payment required'`.
* razorpay ⇒ `hash_hmac('sha256', orderId|paymentId, keySecret)` constant-time equals `signature`.
* stripe ⇒ `GET /v1/payment_intents/{id}` → `status === 'succeeded'`.
* paypal ⇒ OAuth + `GET /v2/checkout/orders/{id}` → `status === 'COMPLETED'`.
* failure ⇒ `402 'Payment verification failed'`; other provider ⇒ `402 'Unknown payment provider'`.
* Persisted reference (`razorpayPaymentId` column, despite the name, for all providers): razorpay `paymentId`, stripe `paymentIntentId`, paypal `orderId`.

> Known gaps to decide on in the port (current behaviour, not bugs introduced by the website):
> (a) the verified **amount is never compared** to the server-computed order total / gift-card amount;
> (b) a payment reference is **not checked for reuse** — the same verified payment can back multiple orders.
> A Firebase port can close both (store `payments/{ref}` with amount and a `consumed` flag in a transaction) without any website change.

---

### 3.8 `PaymentResult` (the `payment` field)
```ts
| { provider: 'razorpay'; orderId: string; paymentId: string; signature: string }
| { provider: 'stripe';   paymentIntentId: string }
| { provider: 'paypal';   orderId: string }
```
Optional; zod union — anything not matching one branch ⇒ 400.

---

## 4. Endpoints in `public.php` NOT used by the website

| Endpoint | Auth | What it does | Used by website? | Firebase recommendation |
|---|---|---|---|---|
| `GET /api/reservations` | **none** | All `Reservation` rows (newest first, raw Prisma shape, PII) → `{reservations:[...]}` | **No** | Do not expose publicly; admin reads Firestore directly. |
| `GET /api/customers` (DirectoryController) | **none** | All customers + their orders (`number,total,status,createdAt`) + reservations; password column omitted | **No** | Drop (admin-only data; PII leak today). |
| `GET /api/staff` | **none** | All employees (password omitted) → `{employees}` | **No** | Drop. |
| `POST /api/staff` | **none** | Creates `Employee {name≥2, role, outletId, email?, phone?, status=OFF}` → `201 {employee}` | **No** | Drop (unauthenticated write). |
| `GET /api/outlets` | **none** | Outlets + `OutletMetric` rows → `{outlets}` | **No** | Drop. |
| `POST /api/outlets` | **none** | Creates `Outlet {name, location?, address?, phone?, manager?, isActive=true}` → `201 {outlet}` | **No** | Drop. |
| `POST /api/upload` | admin web session, or mobile staff JWT with `manage:menu` | multipart `file`, image/*, ≤5 MB → stored as `<ms>-<rand6>.<ext>` in `UPLOAD_DIR` → `201 {url: <request host>/api/uploads/<name>}`; errors 401/400/413/415/500 | **No** (admin + staff app only) | Replace with Firebase Storage upload from the admin (Storage rules: authenticated staff with menu permission, `image/*`, < 5 MB). |
| `GET /api/uploads/{name}` | none | Serves an uploaded file (name `^[a-z0-9._-]+$`, else 400; missing 404) with long immutable cache | **Indirectly** — only if a `MenuItem.imageUrl` points here | Migrate files to Storage, rewrite `imageUrl`s (see §5). |
| `GET /api/floor-stream` | admin web session | SSE: `data: connected`, then every 4 s `data: refresh` or `: ping`; closes after `FLOOR_STREAM_MAX_SECONDS` (120) | **No** | Replace with Firestore `onSnapshot` in the admin. |

**DirectoryController conclusion:** a full-text search of `website/` finds no reference to `/api/customers`, `/api/staff`
or `/api/outlets` (nor to `GET /api/reservations`, `/api/upload(s)`, `/api/floor-stream`). They were ported "as-is" from
the old Next.js admin and are unauthenticated. They need **not** be recreated for the website.

---

## 5. Images / uploads

* Website static assets live in `website/public` (logos, `front-image.png`, `og-image.png`, videos) — unaffected.
* Marketing images use Unsplash via `next/image` (`images.unsplash.com`, `loremflickr.com` allow-listed in `next.config.mjs`).
* Menu images: `MenuItem.imageUrl` rendered with plain `<img>` — any absolute URL works. Existing values may be
  `http(s)://<admin-host>/api/uploads/<file>` (absolute URL built from the upload request host) or external URLs.
  Migration: copy files from `UPLOAD_DIR` (default `admin/uploads`) to Storage (e.g. `menu/<file>`) and rewrite
  `imageUrl` to the Storage download URL / public URL. No website code change required.
* Static fallback menu (`lib/content.ts`) uses Unsplash URLs.

---

## 6. Website pages / routes

| Route | Type | Rendering | Backend use |
|---|---|---|---|
| `/` (`app/page.tsx`) | page | **Dynamic SSR** — `<Menu>` server component does `fetch(..., {cache:'no-store'})` | `GET /api/menu` (server); `GiftCard` dialog → `/api/payment*`, `/api/gift-cards` (browser) |
| `/menu` (`app/menu/page.tsx`) | page | `export const dynamic = 'force-dynamic'` | `GET /api/menu` (server) |
| `/order` (`app/order/page.tsx`) | page, reads `searchParams.table` | `force-dynamic` | `GET /api/menu`, `GET /api/tables/{code}` (server); `OrderFlow` → `/api/payment*`, `/api/orders`, `/api/availability`, `/api/reservations`; `TableOrderFlow` → `/api/payment*`, `/api/orders` |
| `/table-reservation` | page | static shell + client component | `ReservationFlow` → `/api/reservations` |
| `/about`, `/privacy`, `/terms` | page | static | none |
| `/sitemap.xml`, `/robots.txt` | metadata routes | static (uses `siteUrl`) | none |
| `/api/availability` | route handler (GET) | server | proxy |
| `/api/orders` | route handler (POST) | server | proxy |
| `/api/reservations` | route handler (POST) | server | proxy |
| `/api/gift-cards` | route handler (POST) | server | proxy |
| `/api/payment` | route handler (GET, POST) | server | proxy |
| `/api/payment/capture` | route handler (POST) | server | proxy |

Client components that call the backend: `components/GiftCard.tsx`, `components/ReservationFlow.tsx`,
`components/order/OrderFlow.tsx`, `components/order/TableOrderFlow.tsx`, `components/order/DineInStep.tsx`, `lib/payment.ts`.
Pure UI (no backend): Header, Hero, Footer, About, Contact, Kitchen, Marquee, MenuCard, MenuExplorer, Reveal, Stars,
Stories, Testimonials, Visit, order/MenuStep, order/ScheduleStep, order/styles.

---

## 7. Website environment variables

| Name | Where read | Value in `website/.env` | Notes |
|---|---|---|---|
| `ADMIN_API_URL` | `lib/admin-api.ts` (server only) | **commented out** (`# ADMIN_API_URL=http://192.168.1.190:20134`) | Unset ⇒ fallback `http://127.0.0.1:33664`. Will point at the Firebase functions base. |
| `NEXT_PUBLIC_SITE_URL` | `lib/site.ts` | `http://192.168.1.44:20133/` | Trailing slash stripped. Used for metadataBase, OG/Twitter image, canonical, JSON-LD, sitemap, robots. Inlined at build time. |
| `VERCEL_PROJECT_PRODUCTION_URL` | `lib/site.ts` | not set | Fallback for site URL; else `http://localhost:3000`. |

No secrets in the website env; no payment keys (fetched at runtime). Backend-side (admin) env names involved in this
contract: `RAZORPAY_KEY_ID`, `RAZORPAY_CURRENCY`, Razorpay key secret, `STRIPE_SECRET_KEY`, `STRIPE_PUBLISHABLE_KEY`,
`STRIPE_CURRENCY`, `PAYPAL_CLIENT_ID`, PayPal client secret, `PAYPAL_CURRENCY`, `PAYPAL_ENV`, `MAIL_*` (SMTP),
`APP_LOCAL_TIMEZONE`, `WEBSITE_URL`, `UPLOAD_DIR`, `FLOOR_STREAM_MAX_SECONDS`. In Firebase these become
Functions params / Secret Manager secrets.

---

## 8. Build & deploy (matters for Firebase Hosting)

* `package.json`: Next `^16.2.7`, React `^19.2.7`, Tailwind 4, TypeScript. Scripts: `next dev`, `next build`,
  `next start -p 20133`. No `output: 'export'`, no `output: 'standalone'`.
* **The site is NOT statically exportable as-is**:
  * `/`, `/menu`, `/order` render per request (`force-dynamic` / `no-store` fetch, `searchParams`);
  * six `app/api/*` route handlers run server-side (they hide the backend host and avoid CORS);
  * `next/image` with remote patterns needs the image optimizer.
* Firebase options:
  1. **Firebase App Hosting** (recommended; first-class Next.js SSR on Cloud Run) — keep the code as-is, set
     `ADMIN_API_URL` / `NEXT_PUBLIC_SITE_URL` in `apphosting.yaml`.
  2. Firebase Hosting with web-frameworks integration (`firebase experiments:enable webframeworks`) — deploys SSR to a Cloud Function.
  3. Static export (`output:'export'`) would require moving all server fetches to the client, replacing the
     `/api/*` proxies with direct calls to Cloud Functions (CORS) and `images.unoptimized` — a larger rewrite, not identical behaviour.
* Same-origin option: with App Hosting/Hosting, `/api/**` rewrites could point directly to a Cloud Function, but
  that would collide with the Next route handlers — keep the Next proxies and change only the upstream URL.

---

## 9. Files that need changes

### Recommended approach (contract-compatible Cloud Functions)
Implement one HTTPS Cloud Function (e.g. Express `api`) exposing **exactly** these paths and JSON shapes:
`GET /api/menu`, `GET /api/tables/:code`, `GET /api/reservations/availability`, `POST /api/reservations`,
`POST /api/orders`, `POST /api/gift-cards`, `GET|POST /api/payment`, `POST /api/payment/capture`.
Then the website changes are minimal:

| File | Change |
|---|---|
| `website/.env` (and App Hosting env / `apphosting.yaml`) | Set `ADMIN_API_URL` to the Functions base (e.g. `https://<region>-<project>.cloudfunctions.net/api` with the `/api/...` paths preserved, or a Hosting rewrite URL); set `NEXT_PUBLIC_SITE_URL` to the production origin. |
| `website/lib/admin-api.ts` | Update the fallback default (`http://127.0.0.1:33664`) to the Functions emulator / production URL; optionally rename the constant (e.g. `API_BASE_URL`). |
| new `website/apphosting.yaml` / `firebase.json` | Deployment config (new files, not edits). |

No component, page or `lib/payment.ts` changes are needed if the contract above is honoured byte-for-byte
(including `error` strings, status codes 400/402/409/422/503/502, `201` on create, and the `no-store` caching).

### If the Functions use different paths/shapes (or Next reads Firestore directly)
| File | What depends on the backend |
|---|---|
| `website/lib/admin-api.ts` | base URL |
| `website/lib/menu-api.ts` | `GET /api/menu` + item mapping |
| `website/app/order/page.tsx` | `GET /api/menu`, `GET /api/tables/{code}` |
| `website/app/api/availability/route.ts` | upstream path `reservations/availability` |
| `website/app/api/orders/route.ts` | upstream `orders` |
| `website/app/api/reservations/route.ts` | upstream `reservations` |
| `website/app/api/gift-cards/route.ts` | upstream `gift-cards` |
| `website/app/api/payment/route.ts` | upstream `payment` (GET/POST) |
| `website/app/api/payment/capture/route.ts` | upstream `payment/capture` |
| `website/.env` | `ADMIN_API_URL` |

Client components (`OrderFlow`, `TableOrderFlow`, `DineInStep`, `ReservationFlow`, `GiftCard`) and `lib/payment.ts`
only talk to same-origin `/api/*`, so they stay unchanged as long as the six Next proxy routes keep their current
request/response shapes. `next.config.mjs` needs no change (menu images use `<img>`); add a Storage host to
`images.remotePatterns` only if someone later switches menu images to `next/image`.

---

## 10. Suggested Firestore mapping for the writes above

| SQL table | Written by | Suggested collection | Notes |
|---|---|---|---|
| `Customer` | orders (if email), reservations, gift cards | `customers` (doc id = cuid; query by `email`, or doc id = normalized email for atomic upsert) | upsert name/phone/updatedAt |
| `Reservation` | `POST /api/reservations` | `reservations` | store `date` as Timestamp + `dateKey: 'YYYY-MM-DD'` + `time` to make the slot-capacity check a single indexed query; do the capacity check + insert in a transaction (or a `slots/{date_time}` counter doc) |
| `Order` + `OrderItem` | `POST /api/orders` | `orders` with `items` array (or `orders/{id}/items`) | write in a batch/transaction; `number` unique-ify |
| `TableSession` | DINE_IN orders (auto-open) | `tableSessions` | find OPEN by `tableId`, create if missing, in a transaction with the order |
| `Table` (`state`) | DINE_IN orders | `tables` (query by `code` + `status=='ACTIVE'`) | set `state:'OCCUPIED'`, `updatedAt` |
| `GiftCard` | `POST /api/gift-cards` | `giftCards` (doc id = code guarantees uniqueness via `create()`) | |
| `MenuItem`, `Category`, `Outlet` | read only | `menuItems`, `categories`, `outlets` | |

Emails: send from the Function (SMTP via nodemailer with Secret Manager creds, or the Firebase "Trigger Email"
extension writing to a `mail` collection). Keep "never fail the request on mail error".
