# 03 — Mobile API contract (Flutter app ⇄ Laravel admin `/api/mobile/*`)

Purpose: freeze the exact behaviour of the API the Flutter app (`mobile-app/`) consumes today, so the
Firebase re-implementation (Firestore + Cloud Functions + Firebase Auth + Storage + FCM) can reproduce it
with identical functionality. Sources read in full:

- Server: `admin/routes/api/mobile.php`, `admin/routes/api/public.php`,
  `admin/app/Http/Controllers/Api/Mobile/{Auth,Customer,Staff}Controller.php`,
  `admin/app/Http/Controllers/Api/Support/*` (Body, Json, MobileCtx, MobileErrors, MobileRouter, RawCacheControl, Schemas, Z, ZodError),
  `admin/app/Support/{MobileJwt,Rbac,CurrentUser,Cuid,Iso}.php`, `admin/app/Services/{MobileUsers,Queries,Actions,Validation,OnlineOrder,Scheduling}.php`,
  `admin/app/Services/Payments/PaymentGate.php`, `admin/app/Http/Controllers/Api/{Menu,Payment,GiftCard,Reservation}Controller.php`,
  `admin/app/Http/Middleware/{MobileAuth,RequirePermission}.php`, `admin/config/go4foodie.php`, `admin/app/Models/*` (keys / hidden fields).
- App: every file in `mobile-app/lib/**`, `pubspec.yaml`, `android/app/build.gradle.kts`, `android/settings.gradle.kts`,
  `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`, `ios/Runner.xcodeproj/project.pbxproj`, `test/widget_test.dart`.

No source files were modified.

---

## 1. The Flutter app at a glance

| Aspect | Current implementation |
|---|---|
| Package / product | `go4foodie` 1.0.0+1, "Go4Foodie - Customer, Restaurant & Owner app". Dart SDK ^3.11.1. |
| Flavors | **None.** One binary, one `applicationId`, three "apps in one" chosen at runtime (`AppRole` enum in `core/session.dart`). |
| Roles (runtime) | `customer` → `/c` (CustomerShell), `restaurant` → `/r` (RestaurantShell), `owner` → `/o` (OwnerShell). Chosen on `/welcome` (RoleSelectScreen); stored as `role` in secure storage and `lastRole` in SharedPreferences. Router keeps a signed-in user inside their role's root. |
| Identities behind roles | customer app → `Customer` row (`kind=customer`). Restaurant app → `User` row (any role) **or** `Employee` row (`kind=employee`). Owner app → `User` with `role=OWNER` only. |
| State management | `flutter_riverpod` ^2.6.1 (Provider, StateProvider, FutureProvider(.autoDispose/.family), NotifierProvider, AsyncNotifierProvider.family for POS). |
| Navigation | `go_router` ^17.5.0 for top level (`/`, `/welcome`, `/onboarding/:role`, `/login/:role`, `/register`, `/c`, `/r`, `/o`); everything inside a shell uses `Navigator.push(MaterialPageRoute)` + IndexedStack tabs. |
| HTTP client | `dio` ^5.11.1 wrapped by `core/api.dart` `Api` (JSON, `validateStatus: (_) => true`, connect 12 s / receive 25 s). Every call returns `Map<String,dynamic>`; non-2xx throws `ApiException(message = body.error ?? 'Request failed (status)', status)`. 401 while a token is set → `onUnauthorized` → `SessionController.signOut()`. |
| Base URL | `--dart-define=API_BASE_URL` (default `http://10.0.2.2:33664`), overridable at runtime through the "Server settings" sheet (saved to SharedPreferences `baseUrl`). All paths are absolute (`/api/mobile/...`, `/api/menu`, ...). |
| Website origin | `--dart-define=SITE_ORIGIN` (default `https://themerchant.disolutions.net`) — only used as `baseUrl` for the payment WebView HTML (gateways check the domain). |
| Token storage | `flutter_secure_storage` keys `token` (JWT), `role` (AppRole name), `profile` (JSON of `user`). SharedPreferences: `baseUrl`, `themeMode`, `lastRole`, `onboarded_<role>`. |
| Session restore | Splash → `SessionController.restore()` → `GET /api/mobile/auth/me`; 401 clears token; network error keeps cached profile. |
| Image loading | `cached_network_image` via `widgets/common.dart` `NetImage`, URLs passed through `Api.image()`: relative `/x` → `baseUrl + /x`; `localhost`/`127.0.0.1` host rewritten to the configured server. Menu/category/trending images come from `MenuItem.imageUrl` (DB). App never uploads (`Api.upload()` exists but is unused; menu form takes an *Image URL* text field). |
| Payments | Razorpay Checkout and Stripe Payment Element run in `webview_flutter` (`features/customer/payment_webview.dart`) with keys from `POST /api/payment`; the JS posts `{provider,...}` back through a `Pay` JavaScript channel; the result is sent as `payment` to the order / gift-card endpoint which verifies server-side. PayPal intentionally hidden in-app. |
| QR | `mobile_scanner` (table QR → `.../order?table=<code>` or raw code) and `qr_flutter` (render table QR in Tables & QR admin). |
| Charts | `fl_chart` (owner dashboard, reports). |
| Polling (no realtime today) | Floor plan every **8 s** (`floor_screen.dart`), staff orders board every **10 s** (`orders_board_screen.dart`), customer order detail every **10 s** until COMPLETED/CANCELED (`orders_screen.dart`), owner dashboard every **30 s** (`dashboard_screen.dart`). The web admin uses SSE `/api/floor-stream`; the app does not. |
| Push notifications | **None.** No `firebase_messaging`, no FCM/APNs config, no notification permission in manifest/plist. (FCM would be new functionality.) |
| Other packages | `shared_preferences`, `google_fonts`, `intl`, `smooth_page_indicator`, `flutter_native_splash`, `cupertino_icons`; dev: `flutter_lints`, `flutter_launcher_icons`. |
| Android | `namespace`/`applicationId` **`com.go4foodie.app`**; AGP 8.11.1, Kotlin 2.2.20, Java 17; permissions INTERNET, CAMERA; `usesCleartextTraffic="true"`. Release signing via `android/key.properties`. |
| iOS | `PRODUCT_BUNDLE_IDENTIFIER` **`com.go4foodie.app`** (RunnerTests: `com.go4foodie.app.RunnerTests`); deployment target 13.0; display name "Go4Foodie". **Info.plist has no `NSCameraUsageDescription`** (mobile_scanner will crash on iOS — pre-existing bug). |
| Tests | `test/widget_test.dart` imports `core/api.dart` and tests cart, slots, order/reservation status flows (pure logic). |

### 1.1 Screens per role

- Shared: `SplashScreen`, `RoleSelectScreen` (/welcome), `OnboardingScreen` (once per role), `LoginScreen`, `RegisterScreen` (customer only), server settings sheet, `ProfileScreen` (edit profile, change password, theme, server address, sign out; employees also get a duty-status selector; customers get a Gift cards link).
- Customer (`/c`, tabs): Home (`CustomerHome`: hero, quick actions, live orders, upcoming bookings, chef's picks from public menu, visit card from restaurant profile), Menu (`MenuScreen` + item sheet + cart bar), Orders (`MyOrdersScreen` → `OrderDetailScreen` with polling timeline + table bill), Bookings (`BookingsScreen` → `ReservationFormScreen` table/private event with live slot availability), Profile. Plus `CheckoutScreen` (take-away NOW/LATER or DINE_IN table order, pay at restaurant or online) → `OrderPlacedScreen`, `TableScanScreen`, `GiftCardsScreen` / `BuyGiftCardScreen`, payment WebView.
- Restaurant (`/r`, tabs): Floor (`FloorScreen` → `PosScreen` → `TableHistoryScreen`, long-press table state sheet), Orders (`OrdersBoardScreen`, pending-count badge), Bookings (`StaffReservationsScreen`), Menu (`MenuAdminScreen`), Me (`ProfileScreen` + `ModuleList` of Inventory, Customers, Gift cards, Staff, Tables & QR, Reports, Activity — each gated by permission).
- Owner (`/o`, tabs): Dashboard (`DashboardScreen`, alerts badge → `ActivityScreen`), Floor, Reports (`ReportsScreen`: Sales / Tables / Transactions), Manage (`ManageHub` grid: Orders, Reservations, Menu, Inventory, Staff, Customers, Gift cards, Tables & QR, Outlets, Activity, Settings — permission gated), Me.
- Module → permission (client-side gating only, `features/staff/manage_hub.dart`): Orders/Floor `manage:orders`, Reservations `manage:reservations`, Menu `manage:menu`, Inventory `manage:inventory`, Staff `manage:staff`, Customers `manage:customers`, Gift cards `manage:coupons`, Tables & QR `manage:tables`, Reports `view:reports`, Outlets `manage:outlets`, Activity `view:dashboard` (audit tab needs `manage:settings`), Settings `manage:settings`. In-screen: menu edit controls need `manage:menu`; POS open/close & table state need `operate:floor`; POS history needs `view:reports`.

---

## 2. Transport conventions (must be preserved or consciously replaced)

- All `/api/mobile/*` responses are JSON (`JSON_UNESCAPED_SLASHES|UNICODE`), floats that are whole are emitted as ints (`12.0` → `12`), NaN → null. Dates are JS ISO strings `YYYY-MM-DDTHH:mm:ss.SSSZ` (UTC) via `Iso::of`; some staff fields are date-only `YYYY-MM-DD` via `Iso::date` (noted per field). Keys whose value is null are **omitted** in most view objects (`?? undefined` semantics) — the app treats a missing key and null the same.
- IDs are Prisma-style cuids (`c` + 24 base36 chars) generated app-side; `Table.code` is also a cuid. Order numbers `ORD-<10000..99999>` (random, no uniqueness check), reservation refs `SV-######` (table) / `EV-######` (event), gift codes `GIFT-XXXXXX` / `COUPON-XXXXXX` (alphabet without I, L, O; retried on unique collision).
- Auth header: `Authorization: Bearer <jwt>` (regex `^Bearer\s+(.+)$`, case-insensitive).
- Cache-Control: router results and `me` → `no-store`; login/register responses carry no Cache-Control. (Irrelevant once on Firebase.)
- `MobileRouter` (customer/staff): first route whose method + segment pattern match wins; `:param` segments are `rawurldecode`d. If the route has an RBAC action and `Rbac::can(token.role, action)` is false → **403** `{"error":"You do not have permission for this action"}` *before* the handler runs. No route → **404** `{"error":"Not found"}`. Handler array → 200 JSON; handler `null` → `{"ok":true}`; handler Response → as-is (status may be 201/4xx).
- Body parsing: invalid/empty JSON body is treated as `{}` (router) or `null` (auth endpoints → validated as `[]` → "Required" issues).
- Error mapping (`MobileErrors::respond`, used by router + auth controller):

| Thrown | HTTP | Body |
|---|---|---|
| `HttpError(status, msg)` | status | `{"error": msg}` |
| `ZodError` (Z::parse) | 400 | `{"error": issues[0].message, "issues": [zod-v3-shaped issues]}` |
| `ValidationException` (Actions' `Validation::*`) | 400 | `{"error": first message, "issues": [{"code":"custom","path":[field],"message":msg}, ...]}` |
| `ForbiddenException` / message "Forbidden" (Actions' `CurrentUser::authorize`) | 403 | `{"error":"You do not have permission for this action"}` |
| `QueryException` / `PDOException` / `ModelNotFoundException` (incl. update/delete of a missing id via `findOrFail`) | 503 | `{"error":"The restaurant database is unavailable. Please try again shortly."}` |
| anything else (e.g. `RuntimeException('Session is closed')`, `'Item not found'`) | 500 | `{"error": message or "Server error"}` |

- Middleware `mobile:<kinds>` (`MobileAuth`): missing/invalid/expired token or `kind` not in the allowed list → **401** `{"error":"Unauthorized"}`. The app reacts to any 401 (with a token set) by signing out.
- Zod issue objects keep zod v3 shapes, e.g. `{"code":"invalid_type","expected":"string","received":"undefined","path":["email"],"message":"Required"}`, `{"code":"too_small","minimum":5,"type":"string","inclusive":true,"exact":false,"message":"...","path":[...]}`, `{"validation":"email","code":"invalid_string","message":"...","path":[...]}`, `invalid_enum_value`, `invalid_literal`, `invalid_union`, `invalid_union_discriminator`. **The app only ever reads `error`** (shown in a toast/inline) — `issues` is never used by Dart.

---

## 3. Authentication model (JWT) — and what it means for Firebase Auth

### 3.1 Token (`app/Support/MobileJwt.php`)

- HS256, secret `AUTH_SECRET` (`config('go4foodie.auth_secret')`, shared byte-for-byte with the old Next.js admin's `mobile-auth.ts`). Header `{"alg":"HS256","typ":"JWT"}`, base64url without padding.
- Payload claims: `sub` (= id), `id`, `name`, `email`, `role` (`OWNER|MANAGER|STAFF|null`), `outletId` (string|null), `kind` (`customer|user|employee`), `aud: "mobile"`, `iat`, `exp = iat + 30 days` (2 592 000 s).
- Verify: 3 parts, constant-time HMAC compare, `aud === "mobile"`, numeric `exp >= now`. Missing `kind` defaults to `customer`. **No refresh, no revocation, no server-side session**: name/email/role are frozen in the token for 30 days (e.g. a staff role change or deactivation does not take effect until re-login, except where a handler re-reads the DB). Signing out is purely client-side.
- The verified claims become `CurrentUser` (`{id,name,email,role,outletId,kind}`) for the request; every `Actions::*` write re-authorizes with `Rbac::can(role, action)` and writes `AuditLog.userId/userName` from it.

### 3.2 Identity → table mapping

| `kind` | Table | Used by app role | `role` claim | Login condition | Password column |
|---|---|---|---|---|---|
| `customer` | `Customer` | customer | `null` (so every staff RBAC check is false) | `password` set and matches; then `status === 'ACTIVE'` else 403 | `Customer.password` (nullable — website guests have none) |
| `user` | `User` (admin logins, roles `OWNER|MANAGER|STAFF`) | restaurant (any role), owner (`OWNER` only) | `User.role` | password matches; owner app also requires `role === 'OWNER'` | `User.password` |
| `employee` | `Employee` (staff directory) | restaurant only | `MobileUsers::employeeRole(Employee.role)`: `/manager|super admin/i` → `MANAGER`, else `STAFF` | User lookup failed (no row or wrong password), Employee row with password that matches; then `active` else 403 | `Employee.password` (nullable; set by managers in Staff screen) |

`outletId`: `User.outletId` / `Employee.outletId` / `null` for customers. It is carried in the token but **no mobile handler filters by outlet** (single-tenant data).

### 3.3 RBAC (`app/Support/Rbac.php`, mirrored client-side via `user.permissions`)

Actions (order matters — `permissions` array is emitted in this order): `view:dashboard, manage:menu, manage:orders, manage:reservations, manage:tables, operate:floor, manage:coupons, manage:outlets, manage:staff, manage:customers, manage:inventory, view:reports, manage:settings`.

| Role | Permissions |
|---|---|
| OWNER | all 13 |
| MANAGER | all except `manage:settings` |
| STAFF | `view:dashboard, manage:orders, manage:reservations, operate:floor` |
| null (customer) | none |

### 3.4 Password hashing

- **bcrypt, cost 10.** New hashes are written as `$2b$10$...` (`AuthController::hash` and `Actions::hashPassword` take PHP's `$2y$` output and swap the prefix to `$2b$` for bcryptjs compatibility). Verification is `password_verify`, which accepts `$2a$`, `$2b$`, `$2y$` — existing rows may carry any of the three (Next.js/bcryptjs wrote `$2a$`/`$2b$`).
- Same scheme for `User`, `Employee` and `Customer`. Empty/null hash → login impossible (guest customers, staff without an app password).
- Models hide `password` from serialization (`$hidden`).

### 3.5 Implications / recommended mapping to Firebase Auth

1. **Hashes are importable**: `firebase auth:import users.json --hash-algo=BCRYPT` (or Admin SDK `importUsers` with `hash: {algorithm: 'BCRYPT'}`) accepts standard modular-crypt bcrypt strings; normalise `$2y$` → `$2b$` (identical algorithm) before import to be safe. Users without a hash are imported passwordless (they can never sign in with a password — same as today; a customer "register" on an existing guest email must then *set* the password, see 4.A.2).
2. **Email collisions across the three tables are the blocker** for a naïve single-namespace import: one email can exist in `Customer`, `User` and `Employee` with different passwords, and the restaurant login deliberately tries `User` first and falls back to `Employee`. Firebase Auth enforces unique emails per project/tenant. Options that keep identical behaviour:
   - **(Recommended) Callable Cloud Function login** `mobileLogin({email,password,app})` that replays the decision tree of 4.A.1 against bcrypt hashes kept in a server-only Firestore collection (or Secret/Admin-only fields), then returns `createCustomToken(uid, claims)` with `uid = "<kind>:<id>"` (e.g. `customer:ck...`, `user:cl...`, `employee:cm...`) and custom claims `{kind, role, outletId, app}`. The app signs in with `signInWithCustomToken`. Register / change password / staff password set become callables too. This preserves three namespaces, the `app` gate, the "inactive" 403s and exact error strings.
   - Identity Platform multi-tenancy (tenant `customers` + tenant `staff`) with BCRYPT import per tenant; still needs a custom resolution for the User-vs-Employee overlap in the staff tenant.
3. Token lifetime changes: Firebase ID tokens last 1 h and auto-refresh; refresh tokens don't expire. To mimic "role frozen until re-login" nothing is needed; to *improve* it, set custom claims on role/active changes and revoke refresh tokens on deactivation.
4. Server-side authorization must move to Firestore Security Rules + Callable/HTTPS Functions reading `request.auth.token.kind/role` — the RBAC table in 3.3 is the source of truth. Customer data scoping is "own `customerId` **or** matching email" (see `mine`, `ownsReservation`, gift cards) — rules need either a denormalised `customerUid` on legacy rows or a function-mediated read.
5. `name`/`email` in the token are used for: order/reservation/gift-card ownership by email, audit `userName`, and `updateMe` returns the token's (stale) email. Keep `email` as a custom claim or read from the profile doc.

---

## 4. Endpoint catalogue

Paths below are relative to `/api/mobile` unless they start with `/api/`. "Kinds" = token kinds the middleware admits. "RBAC" = router-level permission (Actions re-check the same action unless noted).

### 4.0 Summary table

| # | Method & path | Kinds | RBAC | Called from (Dart) |
|---|---|---|---|---|
| A1 | POST `auth/login` | public | – | `core/session.dart` `signIn` |
| A2 | POST `auth/register` | public | – | `core/session.dart` `register` |
| A3 | GET `auth/me` | customer,user,employee | – | `core/session.dart` `restore`, `refreshProfile` |
| A4 | PUT `auth/me` | customer,user,employee | – | `features/common/profile_screen.dart` `_editProfile` |
| A5 | POST `auth/password` | customer,user,employee | – | `features/common/profile_screen.dart` `_changePassword` |
| C1 | GET `customer/home` | customer | – | `customer_providers.dart` `customerHomeProvider` |
| C2 | GET `customer/orders` | customer | – | `myOrdersProvider` |
| C3 | GET `customer/orders/:id` | customer | – | `orderDetailProvider` (polled 10 s) |
| C4 | POST `customer/orders` | customer | – | `checkout_screen.dart` `_place` |
| C5 | GET `customer/reservations` | customer | – | `myReservationsProvider` |
| C6 | POST `customer/reservations` | customer | – | `bookings_screen.dart` `_submit` |
| C7 | POST `customer/reservations/:id/cancel` | customer | – | `bookings_screen.dart` `ReservationTile` |
| C8 | GET `customer/gift-cards` | customer | – | `myGiftCardsProvider` |
| C9 | POST `customer/gift-cards` | customer | – | `gift_cards_screen.dart` `_buy` |
| C10 | GET `customer/tables/:code` | customer | – | `table_scan_screen.dart` `_resolve` |
| P1 | GET `/api/menu` | public | – | `menuProvider` |
| P2 | GET `/api/reservations/availability?date=` | public | – | `bookings_screen.dart` `_loadSlots` |
| P3 | GET `/api/payment` | public | – | `paymentConfigProvider` |
| P4 | POST `/api/payment` | public | – | `payment_webview.dart` `payOnline` |
| S1 | GET `staff/dashboard` | user,employee | view:dashboard | `dashboardProvider` (polled 30 s) |
| S2 | GET `staff/notifications` | user,employee | view:dashboard | `notificationsProvider` |
| S3 | PATCH `staff/me/duty` | user,employee | – (employee only) | `profile_screen.dart` `_DutySelector` |
| S4 | GET `staff/orders` | user,employee | manage:orders | `staffOrdersProvider` (polled 10 s) |
| S5 | PATCH `staff/orders/:id/status` | user,employee | manage:orders | `orders_board_screen.dart` `StaffOrderCard._set` |
| S6 | GET `staff/floor` | user,employee | manage:orders | `floorProvider` (polled 8 s) |
| S7 | PATCH `staff/tables/:id/state` | user,employee | operate:floor | `floor_screen.dart` `showTableStateSheet` |
| S8 | GET `staff/pos/:tableId` | user,employee | manage:orders | `PosController.build/refresh` |
| S9 | POST `staff/pos/:tableId/open` | user,employee | operate:floor | `PosController.open` |
| S10 | POST `staff/sessions/:id/items` | user,employee | manage:orders | `PosController.addItems` |
| S11 | POST `staff/sessions/:id/void` | user,employee | manage:orders | `PosController.voidItem` |
| S12 | PUT `staff/sessions/:id/billing` | user,employee | manage:orders | `PosController.billing` |
| S13 | POST `staff/sessions/:id/payments` | user,employee | manage:orders | `PosController.pay` |
| S14 | POST `staff/sessions/:id/close` | user,employee | operate:floor | `PosController.close` |
| S15 | POST `staff/sessions/:id/merge` | user,employee | manage:orders | `PosController.mergeInto` |
| S16 | GET `staff/tables` | user,employee | manage:tables | `tablesAdminProvider` |
| S17 | POST `staff/tables` | user,employee | manage:tables | `business_screens.dart` `TablesAdminScreen._form` |
| S18 | PUT `staff/tables/:id` | user,employee | manage:tables | same |
| S19 | DELETE `staff/tables/:id` | user,employee | manage:tables | same |
| S20 | GET `staff/table-analytics?days=` | user,employee | view:reports | `tableAnalyticsProvider` |
| S21 | GET `staff/table-history/:tableId?days=` | user,employee | view:reports | `tableHistoryProvider` |
| S22 | GET `staff/reservations` | user,employee | manage:reservations | `staffReservationsProvider` |
| S23 | PATCH `staff/reservations/:id/status` | user,employee | manage:reservations | `reservations_screen.dart` `_set` |
| S24 | PUT `staff/reservations/:id` | user,employee | manage:reservations | **not called by app** |
| S25 | GET `staff/menu` | user,employee | manage:orders | `staffMenuProvider` |
| S26 | POST `staff/menu` | user,employee | manage:menu | `menu_admin_screen.dart` `openMenuItemForm` |
| S27 | PUT `staff/menu/:id` | user,employee | manage:menu | same |
| S28 | DELETE `staff/menu/:id` | user,employee | manage:menu | same |
| S29 | PATCH `staff/menu/:id/availability` | user,employee | manage:menu | `MenuAdminScreen` switch |
| S30 | PATCH `staff/categories/:id` | user,employee | manage:menu | `MenuAdminScreen._categories` |
| S31 | GET `staff/inventory` | user,employee | manage:inventory | `inventoryProvider` |
| S32 | POST `staff/inventory` | user,employee | manage:inventory | `inventory_screen.dart` `_form` |
| S33 | PUT `staff/inventory/:id` | user,employee | manage:inventory | same |
| S34 | POST `staff/inventory/:id/adjust` | user,employee | manage:inventory | `_adjust` |
| S35 | DELETE `staff/inventory/:id` | user,employee | manage:inventory | `_form` |
| S36 | GET `staff/staff` | user,employee | manage:staff | `staffListProvider` |
| S37 | POST `staff/staff` | user,employee | manage:staff | `team_screen.dart` `TeamScreen._form` |
| S38 | PUT `staff/staff/:id` | user,employee | manage:staff | same |
| S39 | PATCH `staff/staff/:id/status` | user,employee | manage:staff | `TeamScreen` duty popup |
| S40 | PATCH `staff/staff/:id/active` | user,employee | manage:staff | **not called by app** (active sent via PUT) |
| S41 | DELETE `staff/staff/:id` | user,employee | manage:staff | `TeamScreen._form` |
| S42 | GET `staff/customers` | user,employee | manage:customers | `customersProvider` |
| S43 | POST `staff/customers` | user,employee | manage:customers | `team_screen.dart` `CustomersScreen._form` |
| S44 | PUT `staff/customers/:id` | user,employee | manage:customers | same |
| S45 | DELETE `staff/customers/:id` | user,employee | manage:customers | `CustomersScreen._detail` |
| S46 | GET `staff/gift-cards` | user,employee | manage:coupons | `giftCardsAdminProvider` |
| S47 | PATCH `staff/gift-cards/:id/status` | user,employee | manage:coupons | `business_screens.dart` `GiftCardsAdminScreen` |
| S48 | DELETE `staff/gift-cards/:id` | user,employee | manage:coupons | **not called by app** |
| S49 | GET `staff/reports` | user,employee | view:reports | `reportsProvider` |
| S50 | GET `staff/transactions` | user,employee | view:reports | `transactionsProvider` |
| S51 | GET `staff/outlets` | user,employee | manage:outlets | `outletsProvider` |
| S52 | GET `staff/settings` | user,employee | manage:settings | `settingsProvider` |
| S53 | PUT `staff/settings` | user,employee | manage:settings | `owner/settings_screen.dart` |
| S54 | GET `staff/audit?limit=` | user,employee | manage:settings | `auditProvider` (no `limit` sent → 150) |

Public endpoints also present but **not** used by the app: `POST /api/orders`, `GET|POST /api/reservations`, `GET /api/tables/{code}`, `POST /api/payment/capture`, `POST /api/gift-cards`, `GET /api/customers`, `GET|POST /api/staff`, `GET|POST /api/outlets`, `GET /api/uploads/{name}` (serves images that menu `imageUrl`s may point to — the app loads these through `NetImage`), `POST /api/upload`, `GET /api/floor-stream` (cookie session).

---

### 4.A Auth (`AuthController`)

#### A1. POST `/api/mobile/auth/login`  (public)
Request: `{"email": string, "password": string, "app": "customer"|"restaurant"|"owner"}`.
Validation (Z, 400 on failure): `email` string + zod email regex, message `Enter a valid email`; `password` string min 1 `Password is required`; `app` enum (`Invalid enum value. Expected 'customer' | 'restaurant' | 'owner', received '...'`). Email is **not** trimmed/lowercased server-side (app trims; matching relies on MySQL's case-insensitive collation).
Decision tree:
1. `app=customer`: `Customer` by email. No row / no password / bcrypt mismatch → **401** `Invalid email or password`. `status !== 'ACTIVE'` → **403** `This account is inactive. Please contact the restaurant.` → token `{kind:'customer', role:null, outletId:null}`.
2. otherwise `User` by email; if row and password matches: `app=owner` and `role !== 'OWNER'` → **403** `Owner access only. Use the Restaurant app.`; else token `{kind:'user', role:User.role, outletId:User.outletId}`.
3. else if `app=restaurant`: `Employee` by email; no row / no password / mismatch → **401** `Invalid email or password`; `!active` → **403** `Your staff account is inactive.`; token `{kind:'employee', role: employeeRole(Employee.role), outletId}`; `email = Employee.email ?? request email`.
4. else (owner app, no matching User) → **401** `Invalid email or password`.
Response 200: `{"token": "<jwt>", "user": Profile}` (Profile in §5.1). Side effects: none (no last-login, no audit).
Dart (`core/session.dart` `_accept`): reads `token`, `user`; stores token/role/profile; profile fields used: `id, name, email, phone, address, kind, role, title, dutyStatus, permissions`. Errors: `LoginScreen` shows `ApiException.message` inline.

#### A2. POST `/api/mobile/auth/register`  (public, customer only)
Request: `{"name","email","phone","password"}` (app trims name/email/phone).
Validation (Z): `name` trim, min 2 `Name is required`; `email` trim + lowercase + email `Enter a valid email`; `phone` trim, min 5 `Enter a valid phone number`; `password` min 6 `Password must be at least 6 characters`.
Logic: `Customer` by (lower-cased) email. Exists **with** password → **409** `An account with this email already exists. Please sign in.` Exists without password (website guest) → update `name, phone, password, updatedAt` (claims the guest row, its history becomes visible). Else create `Customer{name,email,phone,password}` (DB defaults: `status` ACTIVE). Hash: bcrypt `$2b$10$`.
Response **201**: `{"token","user": Profile(kind=customer)}`. Note: no `status` check here (an INACTIVE guest row can be claimed and gets a token).
Dart: `RegisterScreen` → `SessionController.register` → `_accept(AppRole.customer, res)`; errors → toast.

#### A3. GET `/api/mobile/auth/me`
Response 200: `{"user": Profile}` built from the **token** claims + fresh DB reads for phone/address/title/dutyStatus (`MobileUsers::mobileProfile`). Name/email/role come from the token (stale until re-login). Customer row missing → phone/address `''` (no error).
Dart: `restore()` (401 → clear token, stay on welcome with role remembered) and `refreshProfile()` (after duty change).

#### A4. PUT `/api/mobile/auth/me`
Request (app always sends all three): `{"name": string, "phone": string, "address": string}`.
Validation: `name` trim min 2 `Name is required`; `phone`, `address` optional trimmed string or `''`.
Side effects by kind: customer → `Customer.name, phone (''→null), address (''→null), updatedAt`; employee → `Employee.name, phone (''→null)` (address ignored); user → `User.name, updatedAt` (phone/address ignored).
Response 200: `{"user": Profile}` with the **new name** merged over token claims. The JWT is **not** reissued (old name remains in token → `me` later returns the old name until re-login; audit logs use the token name).
Dart: `profile_screen.dart` → `SessionController.updateProfile(res.user)`.

#### A5. POST `/api/mobile/auth/password`
Request: `{"currentPassword": string, "newPassword": string}`. Validation: current min 1 `Current password is required`; new min 6 `New password must be at least 6 characters`.
Logic: table by kind (Customer/Employee/User); hash missing or mismatch → **400** `Current password is incorrect`; else update `password` (bcrypt `$2b$10$`) (+ `updatedAt` except Employee). Existing tokens remain valid.
Response 200: `{"ok": true}`. Dart: only success/failure toast.

---

### 4.B Customer app (`CustomerController`, kind `customer`)

Ownership helpers (re-implement in rules/functions):
- `mine` (orders): `Order.customerId = token.id OR Order.customerEmail = token.email`.
- `ownsReservation`: `Reservation.customerId = token.id OR Reservation.email = token.email`.
- gift cards: `GiftCard.customerId = token.id OR GiftCard.customerEmail = token.email`.
- `me()`: `Customer::find(token.id)` or **401** `Account not found` (used by POST orders/reservations/gift-cards).

#### C1. GET `customer/home`
Response: `{"profile": RestaurantProfile, "activeOrders": OrderView[], "upcomingReservations": ReservationView[]}`.
- `profile` = `{name ('Go4Foodie'), currency ('USD'), timezone ('America/New_York'), address (''), phone (''), email ('')}` from `RestaurantProfile` id `default` (defaults in parentheses).
- `activeOrders`: mine, status ∈ PENDING/PREPARING/READY, newest first, limit 5.
- `upcomingReservations`: owned, status ∈ REQUESTED/CONFIRMED, `date >= today 00:00 server-local`, ascending by date, limit 3.
Dart (`customer_shell.dart` `CustomerHome`): `activeOrders` → `OrderTile` (`id, number, type, status, tableNumber, createdAt, total, items[].qty/name`); `upcomingReservations` → `ReservationTile`; `profile.name/address/phone` → `_VisitCard` (hard-coded fallbacks when empty; opening hours text is hard-coded).

#### C2. GET `customer/orders`
Response: `{"orders": OrderView[]}` — mine, newest first, limit 100. Dart: `MyOrdersScreen` → `OrderTile` (fields as above).

#### C3. GET `customer/orders/:id`
Response: `{"order": OrderView}`; not mine / missing → **404** `Order not found`.
Dart `OrderDetailScreen` (polls every 10 s unless status COMPLETED/CANCELED): `number, status, type, tableNumber, createdAt, scheduleType, scheduleDate, scheduleTime, estimatedPickup, items[name,qty,price], total, paid, paymentProvider, session{total,paid,remaining,status}, notes`.

#### C4. POST `customer/orders`
Request built by `checkout_screen.dart`:
```json
{ "items": [{"menuItemId": "...", "name": "...", "qty": 2}],
  "notes": "optional",
  "payment": {"provider":"razorpay","orderId","paymentId","signature"} | {"provider":"stripe","paymentIntentId"}   // or
  "payAtRestaurant": true,
  "type": "DINE_IN", "tableCode": "<code>"                                                                       // or
  "type": "TAKE_AWAY", "scheduleType": "NOW"|"LATER", "scheduleDate": "YYYY-MM-DD", "scheduleTime": "HH:mm" }
```
Server merges identity **under** the body: `{name: Customer.name, email: Customer.email, phone: Customer.phone ?: body.phone ?: ''} + body` (PHP `+`: identity keys win; body cannot override name/email/phone unless the customer has no phone, then `body.phone` is used).
Validation (`Schemas::onlineOrder`, discriminated on `type`; failure → **400** `{error: first issue message || 'Invalid order', issues}`):
- common `items`: array min 1 (`Add at least one item`) of `{menuItemId: string min 1, name?: string, qty: coerce int 1..50}`; `notes?` max 500; `payment?` union of the 3 provider shapes (razorpay/stripe/paypal).
- TAKE_AWAY: `scheduleType` enum NOW|LATER; `scheduleDate?`, `scheduleTime?`; `name` min 2; `email` valid; `phone` min 5 (a customer without phone gets `String must contain at least 5 character(s)`).
- DINE_IN: `tableCode` min 1; `name` min 1; `email` valid or ''; `phone` optional or ''.
`payAtRestaurant === true` (strict boolean) **and** no `payment` → skip payment gate, store unpaid. Otherwise `PaymentGate::accepted(payment)`: if any gateway is configured, payment is required and verified (Razorpay HMAC-SHA256 of `orderId|paymentId` with key secret; Stripe PaymentIntent `status==='succeeded'`; PayPal order verify) → else **402** `Payment required` / `Payment verification failed` / `Unknown payment provider`. If no gateway configured → allowed. **The paid amount is not compared with the order total** (existing gap).
TAKE_AWAY LATER → `Scheduling::validateSlot(date,time)`: slot must be one of `10:00..21:30` every 30 min (`Outside business hours`), parsable (`Invalid date or time`), ≥ now + 30 min (`That time is too soon — please pick a later slot`) → **422**.
Pricing: menu rows matched by id, else by name; missing → `Item not found: <name|id>`, `available=false` → `Item unavailable: <name>` → **422**. Price from DB, total = Σ price×qty. `outletId` = first Outlet id or `'online'`. Number `ORD-#####`.
Side effects: upsert `Customer` by email (name, phone if given, updatedAt). Create `Order` + `OrderItem`s in a transaction:
- DINE_IN: `Table` by `code` & `status=ACTIVE` else **422** `Table not found or inactive`; attach to the table's OPEN `TableSession` or create one (`customerName`) and set `Table.state=OCCUPIED`; order `{type:DINE_IN, status:PENDING, channel:ONLINE, paymentMethod: payment?'ONLINE':null, paymentProvider, razorpayPaymentId: payment ref, total, outletId, customerName/Email/Phone/Id, tableId, tableNumber, sessionId, notes}`. **Note: session `subtotal/total` is NOT recomputed** here (unlike POS adds).
- TAKE_AWAY: order `{type:'PICKUP', status:PENDING, channel:ONLINE, paymentMethod: payLater?null:'ONLINE', ..., scheduleType, scheduleDate (UTC midnight of date) | null, scheduleTime | null, notes}`.
- Confirmation email (best effort) with items/total/pickup label (`Dine-in · Table N` / `As soon as possible (around h:mm A)` / `D, M j, g:i A`).
Response **201**: DINE_IN `{"number","id","total","tableNumber"}`; TAKE_AWAY `{"number","id","total","estimatedPickup": ISO}`. Other errors: **503** `Could not place order`.
Dart uses `res.id`, `res.number` (→ `OrderPlacedScreen`), clears cart (keeps table for dine-in), invalidates orders/home.

#### C5. GET `customer/reservations`
Response `{"reservations": ReservationView[]}` — owned, ordered by `date` desc. Dart `BookingsScreen` → `ReservationTile`: `kind, status, date, eventType, guests, space, guestRange, time, occasion, reference, id`.

#### C6. POST `customer/reservations`
Request (`bookings_screen.dart`):
- TABLE: `{"kind":"TABLE","date":"YYYY-MM-DD","time":"HH:mm","guests":int,"occasion":string,"requests"?:string}`
- PRIVATE_EVENT: `{"kind":"PRIVATE_EVENT","eventType","date","guestRange","space","company"?,"message"?}`
Server: `array_merge(body, {name: Customer.name, email: Customer.email, phone: Customer.phone ?: body.phone ?: ''})` (identity overrides body). Validation `Schemas::reservation` (discriminated on `kind`): TABLE `date` min1, `time` min1, `guests` coerce int ≥1, `name` min 2, `email` valid, `phone` min 5, `occasion?`, `requests?`; PRIVATE_EVENT `eventType, date, guestRange, space` min1, `name` min2, `email`, `phone` min5, `company?`, `message?`. Failure → **400** `{"error":"Invalid payload","issues":[...]}` (note the literal message; a customer with no phone on file always fails here).
TABLE: `validateSlot` → **422** reason; count of TABLE reservations same day (server-local bounds) & time not CANCELED/NO_SHOW ≥ 6 → **409** `That time slot is fully booked — please choose another.`
Side effects: upsert Customer by email (name, phone, updatedAt); create `Reservation{reference SV-/EV-######, kind, date (UTC midnight), name, email, phone, customerId, +kind fields}` (status default REQUESTED); confirmation email (best effort).
Response **201** `{"reference","id"}`; DB error **503** `Database unavailable`. Dart shows `res.reference` in a dialog, invalidates bookings/home.

#### C7. POST `customer/reservations/:id/cancel`
Not owned/missing → **404** `Reservation not found`; status not REQUESTED/CONFIRMED → **422** `This booking can no longer be cancelled`. Side effect: `status=CANCELED, updatedAt`. Response `{"reservation": ReservationView}`. Dart ignores the body (invalidates lists).

#### C8. GET `customer/gift-cards`
Response `{"giftCards": [{id, code, kind ('GIFT_CARD'|'COUPON'), amount (number), message?, status, paymentStatus, expiryDate? (full ISO), createdAt}]}` newest first. Dart `_GiftCard`: `kind, status, amount, code, expiryDate`.

#### C9. POST `customer/gift-cards`
Request: `{"kind":"GIFT_CARD"|"COUPON","amount":int,"message"?:string,"payment"?:{...}}` (amount chips 10–1000). `payment` omitted only when no gateway is configured.
Validation step 1 (Z::parse → 400 `{error, issues}`): `kind` default GIFT_CARD enum; `amount` coerce number, positive (`Number must be greater than 0`); `message?` max 500; `payment?` unknown. Step 2 `GiftCardController::purchase({...body, name: Customer.name, email: Customer.email})` with `Schemas::giftCardPurchase` (`amount` positive `Choose an amount`, max 100000; `name` min 2 `Name is required`; email or ''; payment union) → **400** `{"error":"Invalid purchase","issues"}`; gate → **402**.
Side effects: upsert Customer by email (name, updatedAt); create `GiftCard{code, kind, customerName, customerEmail, customerId, amount, message, expiryDate: COUPON ? now+365d : null, paymentStatus:'PAID', paymentProvider, razorpayPaymentId: ref, status:'ACTIVE'}` (5 attempts on code collision → **503** `Could not generate a code, please retry`); confirmation email.
Response **201** `{"code","id","amount","kind"}`; other failure **503** `Could not complete purchase`. Dart toasts `res.code`.

#### C10. GET `customer/tables/:code`
`Table` with `code = :code` and `status = 'ACTIVE'` else **404** `Table not found or not accepting orders`. Response `{"table": {id, number (string), name?, code}}`. Dart sets cart `TableContext(code, number, name)` and switches to Menu tab. (`code` extracted from scanned URL query `table=` or raw text.)

---

### 4.P Public endpoints the app also calls (no auth; app still sends the Bearer header)

#### P1. GET `/api/menu`
Available items in active categories, ordered by category name then item name. Response `{"items":[{id, name, description, price (number), rating (number), tag ('' if null), category (name), imageUrl}], "categories": [distinct category names in order]}`; failure **503** `Menu unavailable`. Dart `MenuItem`: `id, name, description, price, rating, tag, category, imageUrl`; categories → chips. Cart `payloadItems` sends `menuItemId, name, qty`.

#### P2. GET `/api/reservations/availability?date=YYYY-MM-DD`
Bad date → **400** `A valid date (YYYY-MM-DD) is required`. Response `{"date", "slots":[{"time":"HH:mm","available":bool,"remaining":int}]}` for all 24 slots 10:00–21:30; `remaining = max(0, 6 − active TABLE bookings at that time that day)`; `available = remaining>0 && slot ≥ now+30 min`. **503** `Availability unavailable`. Dart: on any error falls back to local `pickupSlots()` with `remaining: 6`.

#### P3. GET `/api/payment`
Response `{"razorpay": bool, "stripe": bool, "paypal": bool}` (configured gateways). Dart keeps only `razorpay`, `stripe`.

#### P4. POST `/api/payment`
Request `{"provider":"razorpay"|"stripe","amount": number (major units),"description": string}` (unknown provider → razorpay). `amount` must be > 0 → **400** `Invalid amount`. Not configured → **503** `<Provider> not configured`; gateway failure → **502** `Could not start payment`.
- stripe → `{"provider":"stripe","publishableKey","clientSecret"}` (PaymentIntent, amount×100, currency `STRIPE_CURRENCY` default usd).
- razorpay → `{"provider":"razorpay","keyId","orderId","amount": int minor units,"currency"}` (order amount×100, currency `RAZORPAY_CURRENCY` default INR, receipt `rcpt_<ms>`).
- paypal → `{"provider":"paypal","clientId","orderId","currency"}` (unused by app).
Dart builds Razorpay options `{key: keyId, order_id: orderId, amount, currency, name:'Go4Foodie', description, prefill{name,email,contact}, theme}` or Stripe Elements with `publishableKey`/`clientSecret`; WebView returns `{"provider":"razorpay","orderId","paymentId","signature"}` or `{"provider":"stripe","paymentIntentId"}`.
→ Firebase: needs a callable `createPayment` holding gateway secrets (Secret Manager); verification moves into the order/gift-card functions.

---

### 4.S Restaurant + Owner apps (`StaffController`, kinds `user|employee`)

Helpers: `str(v)` = string or `''`; `num(v)` = `Number(v ?? 0) || 0`; `days(v,d)` = `clamp(Number(v)||d, 1, 365)`; `enum(options, body.field)` = Z enum (400 on mismatch, message `Invalid enum value. Expected ..., received '...'` or `Required`). `sessionTable(sessionId)` → 404 `Session not found`. **POS mutations return the full POS view** `pos(tableId)` (see §5.6), which the app writes straight into `posProvider`.

#### S1. GET `staff/dashboard` (view:dashboard)
Response = `getDashboardData()` + `attention` + `floor`:
```
{ kpis: [{key:'orders',label:'Total Orders',value:"1,234",delta:10,accent:true},
         {key:'delivered',label:'Total Delivered',value,delta:7.5},
         {key:'canceled',label:'Canceled Order',value,delta:-3.5},
         {key:'revenue',label:'Total Revenue',value:"$15,750",delta:7.5}],      // value strings; deltas hard-coded
  trending: {name, subtitle, rating, orders, price, image},                      // most-ordered item, or DashboardConfig.trendingItemId override
  outletSeries: [{outlet, sells, cost}],                                         // latest OutletMetric per outlet
  outletActive: string, revenueTotal: "$..",
  topCategories: [{name, percent, image}],                                       // top 3 by qty, or DashboardConfig.topCategories JSON override
  employee: {total, segments:[{label:'On Duty',value,color:'var(--color-success)'},{label:'On Break',...,'var(--color-warn)'},{label:'Absent',...,'var(--color-danger)'}]},
  pos: {totalSales:"$..", salesDelta:12, totalBills:int, avgValue:"$..", peakHour:"5.00 PM", payment:{cash:%,card:%,online:%}},
  recentOrders: [{line:"01", orderId, customer, type:'Dine-in'|'Delivery'|'Pick-up', status, price, image}],  // latest 3
  salesTypes: [{label:'Dine-in',percent},{label:'Delivery',percent},{label:'Pick-up',percent}],
  attention: int,              // REQUESTED reservations + low-stock items + tables in CLEANING/WAITING_PAYMENT
  floor: {total, available, occupied, reserved, waitingPayment, cleaning} }
```
All-time aggregates over every order (no date window). Dart (`dashboard_screen.dart`, polled 30 s): `kpis[].label/value/delta/key/accent`, `pos.totalSales/totalBills/avgValue/peakHour/payment.cash|card|online`, `floor.available/occupied/reserved/waitingPayment`, `outletSeries[].outlet/sells/cost`, `trending.name/subtitle/rating/orders/price/image`, `salesTypes[].label/percent`, `employee.total/segments[].label/value/color` (CSS var colors are not hex → fallback accent), `topCategories[].name/image/percent`, `recentOrders[].image/orderId/customer/type/price/status`, `attention` (badge).

#### S2. GET `staff/notifications` (view:dashboard)
Response `{"notifications":[{id, type:'order'|'reservation'|'stock'|'table', title, detail, time: ISO}]}` sorted by `time` desc. Sources: 6 latest orders (`New order ORD-x`, `<customer> · $total`); 6 latest REQUESTED reservations; inventory with `quantity <= reorderLevel` (`Low stock: name`, `"<q> <unit> left (reorder at <r>)"`, time = updatedAt); tables CLEANING (`Table N needs cleaning`) / WAITING_PAYMENT (`Table N payment pending`), open sessions > 120 min (`Table N occupied 2h+`), open sessions total ≥ 300 (`Large bill at Table N`). Computed on read (not stored). Dart `ActivityScreen._Alerts`: `type, title, detail, time`. → natural FCM candidate later.

#### S3. PATCH `staff/me/duty` (no RBAC)
Body `{"status": "ON_DUTY"|"ON_BREAK"|"ABSENT"|"OFF"}` (enum validated first → 400). Token kind ≠ employee → **422** `Duty status applies to staff accounts`. Side effect `Employee.status`. Response `{"status": "..."}`. Dart then calls `auth/me` to refresh `dutyStatus` (app offers ON_DUTY/ON_BREAK/OFF only).

#### S4. GET `staff/orders` (manage:orders)
Response `{"orders": StaffOrder[]}` — all orders newest first, first 300. StaffOrder: `{id, number, type, status, channel, paymentMethod ('CASH' if null), outlet (outlet name or id), customer, customerEmail?, customerPhone?, items:[{name,qty,price}], total, scheduleType?, scheduleDate? (ISO), scheduleTime?, notes?, tableNumber?, paymentProvider?, razorpayPaymentId?, createdAt}`.
Dart `StaffOrderCard`: `id, number, status, items[qty,name], channel, scheduleType, scheduleDate, scheduleTime, createdAt, tableNumber, type, customer, notes, total`; pending count badge from `status`.

#### S5. PATCH `staff/orders/:id/status` (manage:orders)
Body `{"status": PENDING|PREPARING|READY|COMPLETED|CANCELED}` (any transition allowed server-side; app advances PENDING→PREPARING→READY→COMPLETED or CANCELED). Side effects: `Order.status, updatedAt`; on COMPLETED with `customerEmail` → "order completed" email. No audit entry. Missing id → 503. Response `{"ok":true}`.

#### S6. GET `staff/floor` (manage:orders)
Response `{"tables": FloorTable[], "waiters": [{id,name}] (active employees by name)}`; FloorTable in §5.5. Dart (`floor_screen.dart`, polled 8 s): `tables[].id, number, name, capacity, state, session{currentBill, customerCount, openedAt, waiterName}`.

#### S7. PATCH `staff/tables/:id/state` (operate:floor)
Body `{"state": AVAILABLE|RESERVED|OCCUPIED|WAITING_PAYMENT|CLEANING|OUT_OF_SERVICE}`. Side effects: `Table.state`, audit `table.state` (entityId tableId, detail state). Response `{"ok":true}`.

#### S8. GET `staff/pos/:tableId` (manage:orders)
Response PosView (§5.6); unknown table → **404** `Table not found`.

#### S9. POST `staff/pos/:tableId/open` (operate:floor)
Body `{"customerCount": int, "waiterId": string|null, "customerName": string|null}` (`customerCount` = max(1, num)). If an OPEN session already exists → no-op. Else (transaction) create `TableSession{tableId, status OPEN, openedAt now, customerCount, waiterId||null, customerName||null}` and `Table.state=OCCUPIED`; audit `session.open` (`"<n> guests"`). Response PosView.

#### S10. POST `staff/sessions/:id/items` (manage:orders)
Body `{"items":[{"menuItemId": string, "qty": 1..50}]}` (Z array min 1 → 400). Session missing/CLOSED → **500** `Session is closed`; unknown menu id → **500** `Item not found` (note: availability not checked for POS). Creates one POS order `{number ORD-#####, type DINE_IN, status PENDING, channel POS, scheduleType NOW, total, outletId (first outlet or 'pos'), customerName (session name or 'Table N'), tableId, tableNumber, sessionId}` + items; recompute session totals (`subtotal = Σ orders.total`, `total = max(0, subtotal − discount + tax + serviceCharge + tip)`); audit `order.add` (`"<n> item(s)"`). Response PosView (of the session's table).

#### S11. POST `staff/sessions/:id/void` (manage:orders)
Body `{"menuItemId": string min 1}`. Finds the newest OrderItem for that menu item in the session; qty>1 → qty−1 else delete; order with no items is deleted, else order total recomputed; session totals recomputed; audit `order.void`. No match → no-op. Response PosView.

#### S12. PUT `staff/sessions/:id/billing` (manage:orders)
Body `{"discount","tax","serviceCharge","tip"}` numbers (absolute amounts; app offers % of subtotal helpers). Each clamped ≥0; saves then recomputes totals. Missing session → 503. Response PosView.

#### S13. POST `staff/sessions/:id/payments` (manage:orders)
Body `{"amount": number, "method": string}`; amount ≤0 → **400** `Enter an amount`; method default `Cash` (app: Cash, Credit Card, Debit Card, UPI, Wallet). Creates `Payment{sessionId, amount, method}`; audit `payment.add`. No over-payment check. Response PosView.

#### S14. POST `staff/sessions/:id/close` (operate:floor)
Body `{"paymentMethod": string}` (optional). If session missing/closed → no-op. Else recompute `subtotal/total`, `paid = Σ payments`, `remaining = round2(total − paid)`; if remaining > 0.001 add a Payment of `remaining` with `paymentMethod || 'Cash'`; session `status CLOSED, closedAt, subtotal, total, paymentStatus PAID, paymentMethod = single method or 'Mixed'`; `Table.state = CLEANING` (transaction); audit `session.close`. Response PosView (now with `session: null`). App then pops the POS screen.

#### S15. POST `staff/sessions/:id/merge` (manage:orders)
Body `{"intoSessionId": string min 1}`. Same id or either closed/missing → no-op. Moves Orders and Payments to target session, target `customerCount += source.customerCount`, source `CLOSED, closedAt, notes "Merged into table <tableId>"`, source table `CLEANING`, recompute target totals, audit `session.merge`. Response PosView of the **source** table.

#### S16. GET `staff/tables` (manage:tables)
Response `{"tables":[{id, number, name?, code, status ('ACTIVE'|'INACTIVE'), orderCount, createdAt}], "websiteUrl": WEBSITE_URL}` ordered by number. Dart: QR = `<websiteUrl without trailing />/order?table=<code>`; `number, name, orderCount, status, code, id`.

#### S17 / S18. POST `staff/tables`, PUT `staff/tables/:id` (manage:tables)
Body `{"number": string, "name": string, "status": "ACTIVE"|"INACTIVE"}`. Validation: `number` min 1 `Table number is required`; `name` optional/''; `status` enum default ACTIVE. Create sets `name ''→null`, `code` = new cuid (state/capacity DB defaults). POST response `{"table": {id, number, name?, code, status, orderCount:0, createdAt}}`; PUT `{"ok":true}` (missing → 503). No audit.

#### S19. DELETE `staff/tables/:id` (manage:tables) → `{"ok":true}`; missing → 503. (FK consequences on sessions/orders depend on DB constraints.)

#### S20. GET `staff/table-analytics?days=N` (view:reports; default 1, clamp 1..365; app sends 1/7/30)
Response `{"analytics": {days, live:{total,available,occupied,reserved,cleaning,outOfService}, summary:{sessions,customers,orders,revenue,avgBill,avgCustomersPerTable,avgDiningMinutes}, perTable:[{id,number,name?,sessions,customers,orders,revenue,avgBill,avgDiningMinutes,occupiedMinutes,occupancyPct,utilizationPct}], top:{highestRevenue,mostUsed,mostCustomers,highestAvgBill,longestOccupied,fastestTurnover: {number,value}|null}, least:{leastUsed,lowestRevenue,lowestOccupancy}, busyHours:[{hour,label,sessions}] (10..21), peakHour:"7:00 PM"|'—', peakDay:'Fri'|'—', customer:{served, avgSpend, favouriteItems:[{name,qty}] (top 5), paymentMix:[{method,count}]}}}`. Range = sessions opened since start-of-today − (days−1); operating minutes = 12 h × days.
Dart `_TablesTab`: `summary.revenue/sessions/avgBill/avgDiningMinutes`, `peakHour`, `peakDay`, `busyHours[].hour/sessions`, `perTable[].number/sessions/customers/occupancyPct/revenue`, `customer.favouriteItems[].name/qty`.

#### S21. GET `staff/table-history/:tableId?days=N` (view:reports; default 30)
Response `{"history": {table: {id,number,name?}|null, sessions:[{id, openedAt, closedAt?, durationMinutes, customerCount, customerName?, waiterName?, items:[{name,qty,price}] (aggregated by name), subtotal, discount, tax, serviceCharge, tip, total, paymentMethod?, status}]}}` (newest first). Unknown table → `{table:null, sessions:[]}` (200). Dart: `sessions[].openedAt,status,customerCount,durationMinutes,waiterName,paymentMethod,items[qty,name],total`.

#### S22. GET `staff/reservations` (manage:reservations)
Response `{"reservations":[{id, reference, kind, status, date: 'YYYY-MM-DD' (Iso::date), name, email, phone, time?, guests?, occasion?, requests?, eventType?, guestRange?, space?, company?, message?, createdAt}]}` newest created first. Dart filters Today/Upcoming/Requests/All locally and shows all those fields.

#### S23. PATCH `staff/reservations/:id/status` (manage:reservations)
Body `{"status": REQUESTED|CONFIRMED|SEATED|COMPLETED|CANCELED|NO_SHOW}` (any transition server-side; app mirrors `nextStatuses()` flows TABLE: REQUESTED→CONFIRMED→SEATED→COMPLETED; EVENT: REQUESTED→CONFIRMED→COMPLETED; plus CANCELED, NO_SHOW for TABLE). Side effects: status, updatedAt; COMPLETED + email → thank-you email. No audit. → `{"ok":true}`.

#### S24. PUT `staff/reservations/:id` (manage:reservations) — not used by app
Body subset of `{date:'YYYY-MM-DD', time, guests (≥1), occasion, requests}`; only present keys updated (date only if non-empty). → `{"ok":true}`.

#### S25. GET `staff/menu` (manage:orders)
Response `{"items":[{id,name,description,price,rating,tag,category,imageUrl,available}] (all items incl. unavailable, by name), "categories":[{id,name,active,itemCount}]}`. Dart `MenuAdminScreen`: items `id,name,category,price,imageUrl,available,description,rating,tag`; categories `id,name,itemCount,active`.

#### S26 / S27. POST `staff/menu`, PUT `staff/menu/:id` (manage:menu)
Body `{"name","description","price","rating","tag","category","imageUrl","available"}`. Validation (`Validation::menuItem`): `name` min 2 `Name is required`; `description` min 4 `Add a short description`; `price` coerce ≥0 `Price must be positive`; `rating` 0..5 default 0; `tag?`; `category` enum `Breakfast|Starters|Main Meals|Fish|Pasta & Salads|Desserts|Drinks`; `imageUrl` must be a URL `Enter a valid image URL` (relative paths rejected); `available` boolean default true. Category resolved by name (`firstOrCreate`). PUT bumps updatedAt; missing → 503. No audit. → `{"ok":true}`.

#### S28. DELETE `staff/menu/:id` (manage:menu) → `{"ok":true}`.
#### S29. PATCH `staff/menu/:id/availability` (manage:menu) body `{"available": bool}` (`=== true`, anything else = false) → `{"ok":true}`.
#### S30. PATCH `staff/categories/:id` (manage:menu) body `{"active": bool}` (strict true) → `{"ok":true}`. Disabled categories disappear from `/api/menu`.

#### S31. GET `staff/inventory` (manage:inventory)
`{"items":[{id,name,category,unit,quantity,reorderLevel,costPerUnit,supplier ('' if null)}]}` by name. Dart computes OUT/LOW/IN_STOCK and stock value.

#### S32 / S33. POST `staff/inventory`, PUT `staff/inventory/:id` (manage:inventory)
Body `{"name","category","unit","quantity","reorderLevel","costPerUnit","supplier"}`. Validation: `name` min 2; `category` enum `Produce|Meat & Fish|Dairy|Beverage|Dry Goods|Bakery`; `unit` min 1 `Unit is required`; numbers coerce ≥0; `supplier?`. → `{"ok":true}`.

#### S34. POST `staff/inventory/:id/adjust` (manage:inventory) body `{"delta": number}` → `quantity = max(0, quantity + delta)`; missing item → silent no-op. → `{"ok":true}`.
#### S35. DELETE `staff/inventory/:id` → `{"ok":true}`.

#### S36. GET `staff/staff` (manage:staff)
`{"employees":[{id,name,role,outlet,email ('' if null),phone?,active,status,createdAt}], "roles":["Super Admin","Manager","Cashier","Kitchen Staff","Waiter"]}`. (Password hash never returned.) Dart `TeamScreen`: `id,name,role,email,phone,active,status`; `roles` for the dropdown.

#### S37 / S38. POST `staff/staff`, PUT `staff/staff/:id` (manage:staff)
Body `{"name","email","phone","password","role","active"}`. Validation: `name` min 2; `email` valid `Enter a valid email`; `phone` optional/''; `password` optional/'' else min 6 `Min 6 characters`; `role` enum of the 5 roles; `active` bool default true. Create: `Employee{name, role, email, phone||null, active, password: bcrypt or null, outletId: first outlet or 'default'}` (status DB default). Update: same fields; empty password keeps the old hash. **This is how Restaurant-app employee logins are provisioned** (role "Manager"/"Super Admin" ⇒ MANAGER permissions). → `{"ok":true}`.

#### S39. PATCH `staff/staff/:id/status` body `{"status": ON_DUTY|ON_BREAK|ABSENT|OFF}` → `{"ok":true}`.
#### S40. PATCH `staff/staff/:id/active` body `{"active": bool}` → `{"ok":true}` (unused by app).
#### S41. DELETE `staff/staff/:id` → `{"ok":true}`.

#### S42. GET `staff/customers` (manage:customers)
`{"customers":[{id,name,email,phone?,address?,status,orders:[{number,total,status,date}],reservations:[{reference,kind,status,date}],totalSpend (non-canceled order totals),lastActivity (max ISO or ''),createdAt}]}` by name (orders/reservations linked by `customerId` only). Dart: `name,email,phone,totalSpend,orders,status,lastActivity,reservations,address,id`.

#### S43 / S44. POST `staff/customers`, PUT `staff/customers/:id` (manage:customers)
Body `{"name","email","phone","address","status"}`. Validation: `name` min 2; `email` valid; `phone`, `address` optional/'' (stored ''→null); `status` ACTIVE|INACTIVE default ACTIVE (INACTIVE blocks customer app login). Password untouched. → `{"ok":true}`.
#### S45. DELETE `staff/customers/:id` → `{"ok":true}`.

#### S46. GET `staff/gift-cards` (manage:coupons)
`{"giftCards":[{id,code,kind,customerName,customerEmail?,amount,message?,expiryDate? ('YYYY-MM-DD'),paymentStatus,status,paymentProvider?,razorpayPaymentId?,createdAt}]}` newest first. Dart: `status, amount, code, customerName, kind, createdAt, id`.
#### S47. PATCH `staff/gift-cards/:id/status` body `{"status": PENDING_PAYMENT|PAID|ACTIVE|REDEEMED|EXPIRED|CANCELLED}`; REDEEMED + email → "redeemed" email. → `{"ok":true}`.
#### S48. DELETE `staff/gift-cards/:id` → `{"ok":true}` (unused by app).

#### S49. GET `staff/reports` (view:reports)
`{"reports": {summary:{revenue (non-canceled), orders (all), itemsSold, avgOrder}, revenueByOutlet:[{outlet,revenue,orders}] (locale-sorted), topItems:[{name,qty,revenue}] (top 8 by qty), categoryMix:[{category,qty,revenue}] (by revenue), orderTypes:[{type:'Dine-in'|'Delivery'|'Pick-up',count}], paymentMix:[{method:'Cash'|'Card'|'Online',count}]}}` — all-time. Dart `_SalesTab` uses all of these.

#### S50. GET `staff/transactions` (view:reports)
`{"transactions":[{id ('o-'|'g-'|'p-' + id), source:'Order'|'Gift Card'|'Table', reference, customer, amount, method, paymentId?, status, date}]}` — union of ≤250 orders with paymentMethod, ≤250 PAID gift cards, ≤250 POS payments, sorted by date desc, first 300. `method` = gateway label (Razorpay/Stripe/PayPal) or paymentMethod / 'Online' / payment method. Dart: `source, reference, customer, method, date, amount`.

#### S51. GET `staff/outlets` (manage:outlets)
`{"outlets":[{id,name,location,address,phone,manager,isActive,weekly:[{week:'W1'..,revenue,cost}]}]}`. Dart: `name,isActive,location,manager,weekly.last.revenue/cost`.

#### S52. GET `staff/settings` (manage:settings)
`{"profile": RestaurantProfile, "team": [{id,name,email,role}] (User rows)}`. Dart: profile `name,currency,timezone,address,phone,email`; team `name,email,role`.
#### S53. PUT `staff/settings` (manage:settings)
Body `{"name","currency","timezone","address","phone","email"}` (trimmed strings). Validation: `name` min 2 `Restaurant name is required`; `currency`, `timezone` min 1; `address?`, `phone?`; `email` valid/''. Upserts `RestaurantProfile` id `default`. Response `{"profile": RestaurantProfile}` (app ignores it).

#### S54. GET `staff/audit?limit=N` (manage:settings; default 150, max 500)
`{"logs":[{id, action, entity, entityId?, detail?, userName?, createdAt}]}` newest first. Only POS/floor actions write audit entries from mobile (`session.open`, `order.add`, `order.void`, `session.merge`, `payment.add`, `session.close`, `table.state`). Dart: `action, userName, detail, createdAt`.

---

## 5. Shared view shapes

### 5.1 Profile (`MobileUsers::mobileProfile`) — returned by login, register, me (GET/PUT)
```
base: { id, name, email, kind: 'customer'|'user'|'employee', role: 'OWNER'|'MANAGER'|'STAFF'|null, permissions: string[] }
customer: + { phone: Customer.phone ?? '', address: Customer.address ?? '' }
employee: + { phone: Employee.phone ?? '', title: Employee.role ?? 'Staff', dutyStatus: Employee.status ?? 'OFF' }
user:     + { phone: '', title: 'Owner'|'Manager'|'Staff' (from role) }
```
`role`/`name`/`email` come from the JWT; `role` and `permissions` are always present (null / []). Dart `Profile` getters: id, name, email, phone, address, kind, role, title (fallback role ?? 'Guest'), dutyStatus, permissions, `can(action)`, initials.

### 5.2 OrderView (customer)
`{id, number, type ('PICKUP'|'DINE_IN'|'DELIVERY'), status, channel, total, paid, paymentProvider?, scheduleType?, scheduleDate? (ISO), scheduleTime?, estimatedPickup? (PICKUP only: scheduled slot or createdAt+25 min), tableNumber?, notes?, items:[{name,qty,price}], session?: {id, status ('OPEN'|'CLOSED'), total, paid (Σ payments), remaining (max(0, round2(total−paid)))}, createdAt}`. `paid = paymentMethod==='ONLINE' || !!razorpayPaymentId`.

### 5.3 ReservationView (customer)
`{id, reference, kind ('TABLE'|'PRIVATE_EVENT'), status, date (ISO), time?, guests?, occasion?, requests?, eventType?, guestRange?, space?, company?, message?, createdAt}` — no name/email/phone.

### 5.4 RestaurantProfile
`{name, currency, timezone, address, phone, email}` with defaults `Go4Foodie / USD / America/New_York / '' / '' / ''`.

### 5.5 FloorTable
`{id, number, name?, capacity, status, state, session: null | {id, openedAt, customerCount, customerName?, waiterName?, currentBill (Σ order totals, not session.total), orderCount}}`.

### 5.6 PosView (`StaffController::pos`)
```
{ table: {id, number, name?, capacity, state},
  session: null | { id, openedAt, customerCount, customerName?, waiterName?,
                    lines: [{menuItemId, name, qty, price}],          // aggregated by menuItemId across session orders
                    orders: [{id, number, createdAt, items:[{name,qty,price}]}],
                    subtotal, discount, tax, serviceCharge, tip, total,
                    payments: [{amount, method, createdAt}], paid, remaining },
  menu: [available MenuItem rows as in S25 items],
  mergeTargets: [{tableId, sessionId, number}],                       // other OPEN sessions, by table number
  waiters: [{id, name}] }
```
Dart `pos_screen.dart`: `table.number/name/capacity/state`, `waiters[].id/name`, `session.customerName/customerCount/openedAt/waiterName/total/orders.length/lines[name,qty,price,menuItemId]/subtotal/discount/tax/serviceCharge/tip/paid/remaining/payments[method,createdAt,amount]/id`, `menu[].id/name/price/category/imageUrl`, `mergeTargets[].number/sessionId`.

---

## 6. Side-effect inventory (must be reproduced by Functions/triggers)

| Trigger | Effect |
|---|---|
| Register / order / reservation / gift card purchase | Upsert `Customer` by email (name, phone, updatedAt). |
| Customer order | Order + items; DINE_IN auto-opens a TableSession + table OCCUPIED; confirmation email. |
| Reservation create | Capacity check (6/slot), confirmation email. |
| Gift card purchase | Unique code, coupon expiry +365 d, confirmation email. |
| Order → COMPLETED | Completion email. Reservation → COMPLETED: thank-you email. Gift card → REDEEMED: email. |
| POS mutations | Session total recomputation; audit log entries; table state transitions (open → OCCUPIED, close/merge → CLEANING). |
| All staff writes | RBAC check with token role (twice: router + Actions). |
| Payments | Gateway verification (Razorpay HMAC / Stripe intent status / PayPal) when any gateway configured; amount not cross-checked. |

Emails go through `App\Services\Mailer` (SMTP) — need an equivalent (e.g. Trigger Email extension or a mail Function).

---

## 7. Polling → realtime mapping

| Screen | Today | Firebase replacement |
|---|---|---|
| FloorScreen | GET `staff/floor` every 8 s | Firestore snapshots on `tables` (+ open `sessions`) |
| OrdersBoardScreen + pending badge | GET `staff/orders` every 10 s | snapshot query on `orders` (latest 300) |
| OrderDetailScreen (customer) | GET `customer/orders/:id` every 10 s | snapshot on `orders/{id}` (+ session doc) |
| DashboardScreen | GET `staff/dashboard` every 30 s | keep callable aggregate (polled) or maintained aggregate docs |
| PosScreen | refetch after each mutation | snapshot on session + table docs |

Optional new FCM topics/tokens (not in the current app): new order / reservation request / low stock to staff (the `notifications` sources), order status changes to customers.

---

## 8. Dart files that need changes

| File | Why |
|---|---|
| `pubspec.yaml` | add `firebase_core`, `firebase_auth`, `cloud_firestore`, `cloud_functions`, `firebase_storage` (if uploads), `firebase_messaging` (+ `flutter_local_notifications`) if FCM; `dio` may be dropped. |
| `lib/main.dart` | `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`; new `lib/firebase_options.dart` (flutterfire configure). |
| `lib/core/api.dart` | Replace the Dio REST client (base URL, Bearer token, `ApiException`, 401 hook, `image()` URL rewriting) with Firestore/Functions repositories; keep an `ApiException`-like error type with the same user-facing messages. |
| `lib/core/session.dart` | Firebase Auth (custom-token login via callable, register callable, `authStateChanges`, `getIdTokenResult().claims` for kind/role/permissions); remove secure-storage token; keep `role` + `lastRole`; Profile from Firestore doc + claims. |
| `lib/core/router.dart` | Only if session readiness semantics change (refresh on auth stream). |
| `lib/features/auth/login_screen.dart`, `register_screen.dart` | Error types; remove/repurpose Server settings button. |
| `lib/features/auth/server_settings.dart`, `role_select_screen.dart`, `features/common/profile_screen.dart` | "Server address" concept goes away (or becomes emulator toggle); profile edit, password change (re-auth/callable), duty status. |
| `lib/features/splash/splash_screen.dart` | Restore flow now waits for Firebase Auth. |
| `lib/features/customer/customer_providers.dart` | All customer providers (`/api/menu`, home, orders, order detail, reservations, gift cards, payment config). |
| `lib/features/customer/checkout_screen.dart` | Place order → callable. |
| `lib/features/customer/bookings_screen.dart` | Availability + create + cancel. |
| `lib/features/customer/gift_cards_screen.dart` | Purchase callable. |
| `lib/features/customer/payment_webview.dart` | `POST /api/payment` → callable `createPayment`; `kSiteOrigin` import. |
| `lib/features/customer/table_scan_screen.dart` | Table lookup by code. |
| `lib/features/customer/orders_screen.dart` | Replace 10 s polling with a stream (optional but recommended). |
| `lib/features/staff/staff_providers.dart` | Every staff read + `PosController` mutations. |
| `lib/features/staff/floor_screen.dart`, `orders_board_screen.dart`, `owner/dashboard_screen.dart` | Polling timers → streams; table state / order status writes. |
| `lib/features/staff/pos_screen.dart` | Consumes PosView via provider — changes only if the provider's shape changes. |
| `lib/features/staff/menu_admin_screen.dart`, `inventory_screen.dart`, `team_screen.dart` (staff + customers), `business_screens.dart` (gift cards, tables & QR, outlets), `reservations_screen.dart`, `owner/settings_screen.dart` | Direct `apiProvider` writes. Menu form may gain image upload to Storage. |
| `lib/features/owner/reports_screen.dart`, `owner/activity_screen.dart`, `staff/table_history_screen.dart` | Use providers only; change only if response shapes change. |
| `lib/widgets/common.dart` | `NetImage` uses `api.image()` (Storage download URLs / `gs://` resolution); `guard()` catches `ApiException`. |
| `test/widget_test.dart` | Imports `core/api.dart`. |
| Native: `android/settings.gradle.kts` + `android/app/build.gradle.kts` (google-services plugin), `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`, iOS deployment target (raise to the FlutterFire minimum, likely 15.0), `ios/Runner/Info.plist` (add `NSCameraUsageDescription`; FCM: push capability, background modes), `AndroidManifest.xml` (FCM: `POST_NOTIFICATIONS`; `usesCleartextTraffic` can be removed). |

---

## 9. Firebase app registrations

| Platform | Identifier | Notes |
|---|---|---|
| Android | `com.go4foodie.app` | Single app for all three roles (no flavors). Add SHA-1/SHA-256 of the debug key and the Play upload key (`android/key.properties`) and the Play App Signing key. |
| iOS | `com.go4foodie.app` | Single bundle. `com.go4foodie.app.RunnerTests` needs no registration. APNs auth key required if FCM is added. |
| (Web, outside this app) | — | The public website (`website/`) uses `/api/menu`, `/api/orders`, `/api/payment`, `/api/reservations`, `/api/gift-cards`, `/api/tables/{code}` and the table QR URL `<WEBSITE_URL>/order?table=<code>`; it will need its own Web app registration if it moves to Firebase too. |

No Firebase config files exist in the repo today.

---

## 10. Gaps, quirks and risks to carry forward (or fix deliberately)

1. Three identity namespaces with possible email overlap (§3.5) — decide on custom-token login vs. tenants before importing users.
2. JWT claims are stale for 30 days; deactivating an Employee/Customer does not kill existing tokens (only login checks `active`/`status`).
3. Customer orders/reservations require a phone on the Customer record (≥5 chars) — customers registered via the app always have one; staff-created customers may not.
4. Payment amount is never compared with the order/gift-card amount; PaymentGate is bypassed entirely when no gateway is configured.
5. Customer DINE_IN orders do not recompute the session's `subtotal/total` (POS adds do) — the POS "Total" can lag the floor's `currentBill` (Σ order totals) until a POS mutation recomputes it.
6. Order numbers and reservation references are random without a uniqueness check.
7. Updates/deletes of unknown ids return 503 "database unavailable" rather than 404.
8. `GET staff/menu` requires `manage:orders` (read for floor staff); edits require `manage:menu`.
9. Times: slot validation and "today" use the server-local timezone (`config('app.local_timezone')`, default UTC); dates are stored at UTC midnight. Cloud Functions must pin the same timezone.
10. iOS build is missing `NSCameraUsageDescription` (QR scan); Android allows cleartext HTTP.
11. Dashboard/report aggregates scan all orders on every call — on Firestore these should become maintained aggregate documents or scheduled functions.
