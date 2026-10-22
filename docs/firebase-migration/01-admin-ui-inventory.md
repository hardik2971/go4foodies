# 01 — Admin Panel UI / Feature Inventory (Laravel → Flutter Web parity checklist)

Source of truth: `admin/` (Laravel 12 + Blade + Alpine.js + Chart.js + lucide + qrcode).
Everything below was read from the full files in `resources/views/**`, `resources/js/*.js`, `resources/css/app.css`,
`routes/web.php`, `routes/admin/*.php`, `app/Http/Controllers/Admin/*.php`, `AuthController.php`,
`app/Http/Middleware/*`, `app/Support/{Rbac,CurrentUser,Format}.php`, plus `app/Services/{Actions,Queries}.php`
and `bootstrap/app.php` (for data shapes, side effects and error mapping).

Conventions used in this document:
- **Perm** = route middleware `perm:<action>` (see RBAC). "Action authz" = the permission the `Actions::` method itself checks via `CurrentUser::authorize()` (can differ from the route perm!).
- All interactive mutations go through `window.api(url, {method, body})` (JSON, CSRF header). On non-2xx it throws `Error(data.error || first validation error || data.message || "Request failed (<status>)")`, and pages show it with `toast(message, 'error')`.
- "Optimistic" = UI is updated before the request; on failure behaviour is noted (some pages roll back, some don't).
- `fmtDate` / `bizDate` format in the **browser's local timezone**; server-rendered dates use `Format::localTz()` (`APP_LOCAL_TIMEZONE`, default `UTC`).

---

## 0. Page / route count summary

| # | Area | Route(s) | Perm |
|---|------|----------|------|
| 1 | Login | `GET/POST /login`, `POST /logout` | guest / auth |
| 2 | Layout (sidebar, topbar, toasts) | all auth pages | auth |
| 3 | Dashboard (Overview) | `GET /dashboard` (+2 JSON) | auth only (no perm) |
| 4 | Orders | `GET /orders` (+1 JSON) | `manage:orders` |
| 5 | Menu | `GET /menu` (+5 JSON) | `manage:menu` |
| 6 | Reservations | `GET /reservations` (+2 JSON) | `manage:reservations` |
| 7 | Tables (QR) | `GET /tables` (+4 JSON) | `manage:tables` |
| 8 | Floor (live) | `GET /floor` (+5 JSON) | `manage:tables` |
| 9 | POS | `GET /pos/{tableId}` (+8 JSON) | `manage:orders` |
| 10 | Table Analytics | `GET /table-analytics?days=` | `view:reports` |
| 11 | Table History | `GET /table-history/{tableId}?days=` | `view:reports` |
| 12 | Staff | `GET /staff` (+5 JSON) | `manage:staff` |
| 13 | Customers | `GET /customers` (+3 JSON) | `manage:customers` |
| 14 | Gift Cards & Coupons | `GET /gift-cards` (+3 JSON) | `manage:coupons` |
| 15 | Transactions | `GET /transactions` | `view:reports` |
| 16 | Inventory | `GET /inventory` (+4 JSON) | `manage:inventory` |
| 17 | Reports | `GET /reports` | `view:reports` |
| 18 | Outlets (hidden from nav) | `GET /outlets` | `manage:outlets` |
| 19 | Notifications | `GET /notifications` | auth only |
| 20 | Audit Log | `GET /audit` | `manage:settings` |
| 21 | Settings | `GET /settings` (+2 JSON) | `manage:settings` |

Also used by admin pages (API, session-cookie auth): `POST /api/upload` (menu image upload), `GET /api/uploads/{name}` (serving uploaded images), `GET /api/floor-stream` (SSE — exists but the Laravel floor page uses polling instead; see Floor).

`GET /` → redirect `/dashboard`. `resources/views/welcome.blade.php` is the stock Laravel welcome page and is **not routed** (ignore).

---

## 1. RBAC — full permission map (verbatim from `app/Support/Rbac.php`)

```php
public const ACTIONS = [
    'view:dashboard',
    'manage:menu',
    'manage:orders',
    'manage:reservations',
    'manage:tables',
    'operate:floor', // open/close table sessions, change live table state
    'manage:coupons',
    'manage:outlets',
    'manage:staff',
    'manage:customers',
    'manage:inventory',
    'view:reports',
    'manage:settings',
];

// OWNER can do everything; MANAGER runs day-to-day ops; STAFF is read/operate-only.
private const PERMISSIONS = [
    'OWNER' => '*',
    'MANAGER' => [
        'view:dashboard', 'manage:menu', 'manage:orders', 'manage:reservations', 'manage:tables',
        'operate:floor', 'manage:coupons', 'manage:outlets', 'manage:staff', 'manage:customers',
        'manage:inventory', 'view:reports',
    ],
    // STAFF runs the floor (open/close table sessions) but can't edit the table list.
    'STAFF' => ['view:dashboard', 'manage:orders', 'manage:reservations', 'operate:floor'],
];
```

Matrix:

| Action | OWNER | MANAGER | STAFF |
|---|---|---|---|
| view:dashboard | Y | Y | Y |
| manage:menu | Y | Y | – |
| manage:orders | Y | Y | Y |
| manage:reservations | Y | Y | Y |
| manage:tables | Y | Y | – |
| operate:floor | Y | Y | Y |
| manage:coupons | Y | Y | – |
| manage:outlets | Y | Y | – |
| manage:staff | Y | Y | – |
| manage:customers | Y | Y | – |
| manage:inventory | Y | Y | – |
| view:reports | Y | Y | – |
| manage:settings | Y | – | – |

`Rbac::can(role, action)` — unknown/null role → false (customers / no role always denied). `Rbac::permissions(role)` returns the allowed subset of ACTIONS in ACTIONS order.

Role display labels (topbar): `OWNER→Owner`, `MANAGER→Manager`, `STAFF→Staff` (else raw role).

### Guard behaviour (`RequirePermission` middleware, `bootstrap/app.php`)
- Not signed in → redirect `/login` (`redirectGuestsTo`). Signed-in user hitting `/login` → redirect `/dashboard`.
- Page request without perm → redirect `/dashboard` with flash error **"You do not have permission for that page."**
- JSON request without perm → `403 {"error":"You do not have permission for this action"}`.
- `Actions::` authorize failure (`ForbiddenException`) → JSON 403 same message; page → redirect `/dashboard` with flash **"You do not have permission for that."**
- Validation failure (JSON) → `400 {"error": <first message>, "errors": {...}}`.
- Missing row (`ModelNotFoundException`) → `404 {"error":"Not found"}`.
- DB error (`QueryException`) → `503 {"error":"The restaurant database is unavailable. Please try again shortly."}`.
- `RuntimeException` (e.g. "Session is closed", "Item not found") → `500 {"error": message || "Server error"}`.

### Role-related parity gotchas (current behaviour — keep or consciously fix)
1. **Floor sidebar + `/floor` route require `manage:tables`**, so STAFF (who has `operate:floor`) cannot open the Floor page. STAFF *can* open `/pos/{tableId}` (requires `manage:orders`) by URL, but its "Back to floor" link and the post-"Close & Pay" redirect to `/floor` bounce STAFF to `/dashboard` with the permission toast.
2. **Settings (incl. Change Password) requires `manage:settings` = OWNER only.** The topbar user menu shows a "Settings" link to everyone; MANAGER/STAFF get redirected with the permission toast. Non-owners therefore have no way to change their own password in the web admin.
3. Dashboard has **no perm middleware** (only `auth`) — comment: "every role has view:dashboard; guarding it would loop the perm redirect". Dashboard widget edit buttons are shown only if `CurrentUser::can('manage:menu')`.
4. Floor open/close/state endpoints sit behind `perm:manage:tables` (route) **and** `operate:floor` (Action). POS open/close use route perm `manage:orders` + Action `operate:floor`; POS add/decrement/billing/merge/payment use Action `manage:orders`.
5. Settings "Roles & Permissions" matrix only lists 10 modules (omits `manage:tables`, `operate:floor`, `manage:coupons`).
6. Mobile principals: `CurrentUser` can also be a JWT user (User / Employee / Customer via `MobileAuth` middleware `mobile:<kinds>`); customers have no role → always denied.

---

## 2. Global design system

### 2.1 Fonts
- Google Fonts: **Fraunces** (opsz 9..144, weights 500/600/700) = `--font-display` (`'Fraunces', Georgia, serif`) used for headings, KPI numbers (`font-display`).
- **Manrope** (400/500/600/700) = `--font-sans` (`'Manrope', system-ui, sans-serif`) — body.
- Monospace (`font-mono`) for gift-card codes, payment IDs. POS print docs use `'Courier New', monospace`; QR/analytics print use `system-ui`.

### 2.2 Colour tokens (`resources/css/app.css`)

| Token | Light | Dark (`html.dark`) |
|---|---|---|
| `--color-bg` | `#f2f6f4` | `#0a1c18` |
| `--color-surface` | `#ffffff` | `#0f2621` |
| `--color-surface-2` | `#f5f9f7` | `#15312a` |
| `--color-border` | `#dce7e2` | `#1f3f36` |
| `--color-fg` | `#0d1f1a` | `#f3f7f4` |
| `--color-fg-muted` | `#6a7f78` | `#94a9a1` |
| `--color-accent` | `#e8640f` | `#f5761e` |
| `--color-accent-soft` | `#fdeddf` | `#3a2416` |
| `--color-accent-deep` | `#c24c0a` | `#ffb067` |
| `--color-gold` | `#f5761e` | `#f5761e` |
| `--color-brand-green` | `#0b5e46` | `#2fa57e` |
| `--color-success` | `#2e9e57` | `#4fbd7c` |
| `--color-success-soft` | `#e6f4ea` | `#16311f` |
| `--color-danger` | `#d9483f` | `#f0766b` |
| `--color-danger-soft` | `#fbe9e6` | `#3a1d1a` |
| `--color-warn` | `#cf8a1e` | `#e6a93f` |
| `--color-warn-soft` | `#f9efd9` | `#362a13` |
| `--color-info` | `#3b7fe4` | `#6aa5f5` |
| `--color-info-soft` | `#e8f0fe` | `#1b2740` |

Other tokens: `--radius-card: 1rem`, `--radius-pill: 999px`; `--shadow-card: 0 1px 3px rgba(16,24,40,.06), 0 1px 2px rgba(16,24,40,.04)` (dark: `0 1px 3px rgba(0,0,0,.4), 0 1px 2px rgba(0,0,0,.3)`); `--shadow-pop: 0 12px 32px -12px rgba(16,24,40,.18)` (dark: `0 16px 40px -12px rgba(0,0,0,.6)`).

Hard-coded colours used in pages: `#3a3a3a` (Sells/Revenue line), `#f99a55`, `#fdd0aa` (sales-type bars 2/3), `#e6e8ec` (dim gauge tick), gauge gradient `rgb(22,163,74)`→`rgb(241,90,36)`, `#cbd0d8` (Online legend dot), `#3395ff` (payment gateway pill, 15% bg), `#b45309` (floor "Awaiting Pay" count), `#9a6cf1` (avatar/pie), `#0b5e46` avatar, `#0a1c18` (login brand panel/print text). Report pie palette: `['#e2470f','#f5761e','#0b5e46','#3b82f6','#9a6cf1','#16a34a','#ef4444']`. Avatar colour cycle `BIZ_AVATAR_COLORS = [accent, #0b5e46, info, gold, #9a6cf1]` (by row index).
Note: classes `text-gold-deep` (orders table badge, transactions "Gift Card" source) reference an **undefined** token (renders as default text colour).

Selection: accent bg + white text. Focus-visible: 2px accent outline, offset 2px, radius 4px. `prefers-reduced-motion` disables animation/transition.

### 2.3 Shared primitives
- `card`: radius 1rem, 1px border, surface bg, shadow-card.
- `input`: full width, rounded-xl, border, surface bg, px 14 / py 10, text-sm, focus border accent + ring accent/10.
- `btn` / `btn-primary` (accent bg, white, hover accent-deep) / `btn-ghost` (bordered) / `btn-danger`. Disabled: opacity 60%, not-allowed.
- `.table-base` (th: uppercase xs muted, border-bottom; td: px16 py12 border-bottom). Most pages use equivalent inline classes: header row `text-xs uppercase tracking-wide text-fg-muted`, cells `px-5 py-3`, rows `hover:bg-bg/60`, last row no border.
- Filter "pill" buttons: `rounded-pill px-3.5 py-1.5 text-sm`; active = accent bg + white; inactive = bordered surface, muted, hover border accent/40.
- Status badge with leading dot (`x-ops.badge`): rounded-md, xs semibold, 6px dot `bg-current`.
- Status colour map (`components/status.blade.php` — also the canonical colour map for all badges):
  - PENDING bg/muted · PREPARING warn · READY info · COMPLETED success · CANCELED/CANCELLED danger
  - REQUESTED warn · CONFIRMED info · SEATED accent · NO_SHOW bg/muted
  - ON_DUTY success · ON_BREAK warn · ABSENT danger · OFF bg/muted
  - ACTIVE success · INACTIVE bg/muted · PAID info · PENDING_PAYMENT warn · REDEEMED accent · EXPIRED bg/muted · FAILED danger
  - Table states: AVAILABLE success · RESERVED warn · OCCUPIED danger · WAITING_PAYMENT accent · CLEANING info · OUT_OF_SERVICE bg/muted · session OPEN accent · CLOSED success
- Stat tile (`x-biz.stat`): card, 40px accent-soft icon chip (lucide icon), xs muted label, `font-display text-xl` value.
- KPI tile (`x-kpi`, unused by current pages but defined): label, optional icon, value, delta "+x.x% vs last month" (green/red) or hint; accent variant.
- Empty state component (`x-empty`, defined, not used by pages): circle accent-soft icon, title "Nothing here yet", optional message.
- Modals: three variants with same look — overlay `bg-black/40` (+ `backdrop-blur-sm`; `x-modal` uses black/50), dialog `max-w-lg` (configurable), `max-h-[90vh]` scroll, rounded-2xl, padding 24, shadow-pop, header = display-font title + X close button. **Close on ESC, on backdrop click, on X.**
- Icons: lucide (stroke-width 2), named in each section.

### 2.4 Theme / dark mode
- Class-based (`html.dark`). Persisted in `localStorage['admin-theme']` = `'dark' | 'light'`; applied before paint by inline script on every page (incl. login).
- Topbar toggle button (`moon` icon in light, `sun` in dark) calls `toggleTheme()` → toggles class, saves key, dispatches `theme-changed` window event. **All Chart.js charts redraw on `theme-changed`** (colours read from CSS vars via `themeColor(name)`).
- Logos swap: `go4foodie-logo.png` (light) / `go4foodie-logo-light.png` (dark).

### 2.5 Formatting helpers
- **Server** `Format::formatCurrency(v, maxFrac=0)` → USD en-US, 0 decimals by default: `15750 → "$15,750"`, negatives `-$…`.
- `Format::formatCompact` (K/M/B/T, 1 decimal), `Format::locale` (en-US grouping, ≤3 decimals), `Format::js` (JS `String(number)`), `Format::localeTime` (`g:i:s A`), `Format::round` (JS Math.round half-up).
- **Client** `formatCurrency(v, opts)` / `bizMoney(v, opts)` → `Intl.NumberFormat('en-US',{style:'currency',currency:'USD',maximumFractionDigits:0})`. ⚠ This means POS/bills display **whole dollars** (e.g. `$12.50` shows `$13`) although amounts are stored with cents. `window.money` (2-decimal) exists but is unused.
- Currency is **always USD**; the Settings "Currency"/"Timezone" profile fields are stored but not used for formatting.
- `fmtDate(value, pattern)` (ops pages) supports tokens `yyyy EEE MMM MM dd d hh h HH mm a` and `'literal'`; browser-local time. Patterns used: `h:mm a`, `MMM d, h:mm a`, `EEE, MMM d`, `MMM d`, `EEE, MMM d, yyyy`, `EEE, MMM d · h:mm a`.
- `bizDate(value, pattern)` (business pages) supports `MMM d, yyyy`, `MMM d`, `MMM d, h:mm a`.
- Server-side timestamps (Notifications, Audit) → `Format::local(...)->format('M j, g:i A')` e.g. "Jun 5, 3:07 PM" in `APP_LOCAL_TIMEZONE` (default UTC).
- "Server local time" for analytics bucketing (`startOfToday`, hours, weekdays) = `APP_LOCAL_TIMEZONE` (default UTC).
- CSV: `toCsv(rows)` / `bizCsv(filename, rows)` — every cell double-quoted, `"` escaped as `""`, rows joined `\n`, MIME `text/csv;charset=utf-8`.
- `bizNiceAxis(max)` — recharts-like nice Y axis: 5 ticks, step = ceil((max/4)/unit)*unit, unit = 0.05·10^(floor(log10(max/4))+1); max<=0 → {max 4, step 1}.
- `bizInitials(name)` = first letters of first two words.

---

## 3. Login (`resources/views/auth/login.blade.php`, `AuthController`)

- Routes: `GET /login` (show, `guest`), `POST /login` (`guest`), `POST /logout` (`auth`).
- Page `<title>`: "Sign in · Go4Foodie Admin". Favicon `/images/go4foodie-icon.png`.
- Layout: 2 columns at `lg`:
  - **Brand panel** (lg+ only): autoplay/loop/muted video `/images/login-bg.mp4` (poster Unsplash `photo-1577219491135-ce391730fb2c`), dark gradients over `#0a1c18`; wide light logo `go4foodie-logo-wide-light.png` (h-16); big accent quote mark + blockquote **"Great restaurants are run in the details — every plate, every table, every shift."**; sub "Your kitchen has the craft. This is where you run the business behind it."; bullet list (accent dots): "Real-time orders, POS & reservations", "Live analytics across every outlet", "Menu, staff & inventory in one place".
  - **Form**: on mobile shows wide logo in dark pill. Eyebrow "WELCOME BACK" (accent, tracking 0.2em); H1 "Sign in to your dashboard"; sub "Manage your restaurant & team from one place."
- Fields: Email (`mail` icon, type email, autocomplete email, required, placeholder `you@restaurant.com`, old value retained); Password (`lock` icon, required, placeholder `••••••••`). Per-field error text under each.
- Submit "Sign in →" (arrow-right icon nudges on hover); while submitting shows "Signing in…" and disables.
- Server validation: `email` required|email, `password` required|string|min:1. `Auth::attempt(..., remember=true)` (persistent "remember me" always on).
- Errors (red banner `role=alert` above fields): **"Invalid email or password."**; DB unreachable → **"Cannot reach the database right now. Please try again shortly."** Email re-filled on error.
- Success → session regenerate → `redirect()->intended('/dashboard')`.
- Footer hint box: **"Demo · george@merchant.test / admin123"**.
- Logout (topbar menu "Sign out") → logout, invalidate session, regenerate CSRF, redirect `/login`.
- Auth users table: `User` (fields id, name, email, password bcrypt `$2b$` cost 10, role OWNER/MANAGER/STAFF, outletId).

---

## 4. Layout (`layouts/app.blade.php`) — sidebar, topbar, toasts

### 4.1 Document
- `<title>`: `"{Page title} · Go4Foodie Admin"`. CSRF meta. Fonts. Theme pre-paint script.

### 4.2 Sidebar (left, sticky, full height, 72px wide, surface bg, right border)
- Top: square logo link to `/dashboard` (64×64; light/dark logo variants).
- Nav icons (44×44, rounded-xl, tooltip `title` = label; active = accent bg + white + shadow; inactive muted, hover accent-soft/accent). Each shown only if user `can(perm)`. **Order:**

| # | Href | Label | lucide icon | Perm |
|---|---|---|---|---|
| 1 | /dashboard | Overview | layout-grid | view:dashboard |
| 2 | /orders | Orders | shopping-cart | manage:orders |
| 3 | /menu | Menu | clipboard-list | manage:menu |
| 4 | /reservations | Reservations | calendar-check | manage:reservations |
| 5 | /tables | Tables | qr-code | manage:tables |
| 6 | /floor | Floor | layout-dashboard | manage:tables |
| 7 | /table-analytics | Table Analytics | activity | view:reports |
| 8 | /staff | Staff | users | manage:staff |
| 9 | /customers | Customers | contact | manage:customers |
| 10 | /gift-cards | Gift Cards | gift | manage:coupons |
| 11 | /transactions | Transactions | credit-card | view:reports |
| 12 | /inventory | Inventory | package | manage:inventory |
| 13 | /reports | Reports | bar-chart-3 | view:reports |
| bottom | /audit | Audit Log | scroll-text | manage:settings |

- Not in sidebar: `/outlets` (hidden), `/notifications` (bell), `/settings` (user menu), `/pos/*`, `/table-history/*`.
- Active rule: `/dashboard` exact match; others `str_starts_with(path, href)`.
- Visible by role: OWNER all 14; MANAGER 13 (no Audit); STAFF: Overview, Orders, Reservations only.

### 4.3 Topbar (sticky, `bg-bg/80` + backdrop blur, bottom border)
- **Title + subtitle** chosen by path prefix (pages may override via `$pageTitle`/`$pageSubtitle`, none currently do):

| Prefix | Title | Subtitle |
|---|---|---|
| /dashboard | Overview | Manage your restaurant & team members from here. |
| /orders | Orders | Track and manage every order across outlets. |
| /menu | Menu | Manage dishes, categories, and availability. |
| /reservations | Reservations | Table bookings & private events from your guests. |
| /floor | Floor Plan | Live table status, sessions & occupancy. |
| /pos | Point of Sale | Table billing, order entry & checkout. |
| /tables | Table Management | QR codes for table-side ordering. |
| /outlets | Outlets | Locations, managers, and operational metrics. |
| /staff | Staff | Your team directory and duty status. |
| /customers | Customers | Guest profiles, history, and lifetime value. |
| /gift-cards | Gift Card & Coupon Management | Purchases, codes, and coupon status. |
| /transactions | Transactions | Payments across orders, gift cards & tables. |
| /inventory | Inventory | Stock levels and low-stock alerts. |
| /table-analytics | Table Analytics | Sessions, occupancy & table performance. |
| /table-history | Table History | Complete session timeline for a table. |
| /reports | Reports | Analytics and exportable insights. |
| /notifications | Notifications | Recent activity across the restaurant. |
| /audit | Audit Log | Every POS & table action, who and when. |
| /settings | Settings | Restaurant configuration and your profile. |

  Lookup = first entry (in the order above) whose prefix matches the path (`/dashboard` exact); fallback = Overview.
- **Global search** (md+ only, centered, max-w-xl): GET form to current URL with `?q=` and placeholder **"type here to search anything"**, search icon, `⌘F` kbd hint. ⚠ No controller reads `q` — it is effectively decorative (submits and reloads the page). The ⌘F shortcut is not wired.
- Right cluster:
  - **Theme toggle** (moon/sun).
  - **Notifications bell** → `/notifications`; badge (accent, white 10px text) showing `Queries::getAttentionCount()` = REQUESTED reservations + inventory items with `quantity <= reorderLevel` + tables in state CLEANING/WAITING_PAYMENT. Hidden if 0; shows **"9+"** if >9. Computed on every page render (no polling).
  - **User menu**: initials avatar (first letters of first 2 name words, accent-soft circle), name + role label (sm+), chevron. Dropdown (click-outside closes): header name/role; "Settings" (`settings` icon) → `/settings`; "Sign out" (`log-out` icon, danger, POST `/logout`).
- Main content padding 24px.

### 4.4 Toasts
- Fixed bottom-right stack. Auto-dismiss **3.5 s**. Error style: danger bg + white; success: `bg-fg text-bg` (inverted).
- Sources: session flash `success`, flash `error`, first validation error, and `window.toast(message, type)` events.

---

## 5. Dashboard / Overview (`GET /dashboard`, `dashboard/index.blade.php`)

- Perm: auth only. Data: `Queries::getDashboardData()` (fallback to hard-coded mock data if DB unreachable — see `DashboardController::mock()`), `Queries::getMenuItems()` (for trending options), `Queries::getMenuCategories()` (names, for top-category options), `Queries::getDashboardConfig()` (current trending override id). `editable = can('manage:menu')`.
- Layout: left/middle flex column + right column (336px at xl).

### 5.1 KPI row (4 cards)
| Key | Label | Value | Icon | Delta |
|---|---|---|---|---|
| orders | Total Orders (accent card: orange bg, white text) | count of all orders (en-US grouping) | package | **+10%** (hard-coded) |
| delivered | Total Delivered | count status=COMPLETED | package-check | +7.5% (hard-coded) |
| canceled | Canceled Order | count status=CANCELED | package-x | -3.5% (hard-coded) |
| revenue | Total Revenue | sum total of COMPLETED, `$x,xxx` | coins | +7.5% (hard-coded) |
Delta pill: trending-up/down icon, green/red (white on accent card), text "+10%" format (`+` only when >0), caption "Since last month".

### 5.2 "Outlets Operational Cost Vs Revenue" (line chart)
- Static filter pill **"Weekly"** (calendar icon + chevron; non-functional).
- Big number `revenueTotal` (= sum of each outlet's latest metric revenue, `$x`) + "Revenue" caption. Legend: Sells (`#3a3a3a`), Operational Cost (accent).
- Chart.js line, 260px tall: x = outlet names (from `outletSeries`: per outlet latest `OutletMetric` revenue → `sells`, operationalCost → `cost`), 2 monotone lines width 2.5, no points (hover radius 5), y min 0, suggestedMax 15000, step 3000, ticks `$xK`. Highlight band (accent 6% alpha) from first category to the "active outlet" (= outlet with highest cost). Dashed accent vertical hover line. Custom tooltip: pill(s) `$<round(v/1000)>K` coloured per series. No animation.

### 5.3 "Top Categories Item"
- 3 tiles: image (category image) with gradient + name overlay, big `percent%` beneath.
- Data: top 3 categories by ordered quantity (% of all ordered qty), image = first ordered item's photo in that category; overridden by `DashboardConfig.topCategories` JSON (name+percent, image = first menu image in category).
- **Edit (pencil; only if manage:menu)** → modal "Top categories": 3 rows each `select` (options "— None —" + all category names) + number input 0–100 + "%". Rows pre-seeded from current values (or first options). Buttons: **"Reset to auto"** (sends `categories:null`), **Cancel**, **Save** ("Saving…"). Save sends rows with non-empty name. `POST /dashboard/top-categories {categories: [{name, percent}]|null}` → `Actions::setTopCategories` (stores first 3, Action authz `manage:menu`). Errors are swallowed; page **reloads** after.

### 5.4 "Employee Status"
- Arrow-up-right button (non-functional). "Total Employees → **N**".
- Semicircle doughnut (Chart.js, rotation -90, circumference 180, cutout 70%, rounded segments, spacing 3, no tooltip) with centre total + "Employees". Legend list: On Duty (success), On Break (warn), Absent (danger) with 2-digit zero-padded counts. Data from Employee group-by status (OFF counted in total but not shown as segment).

### 5.5 "Recent Orders"
- Search input placeholder "eg: search here…" (**non-functional**), "View all" link → `/orders`.
- Empty: "No orders yet."
- Up to 3 cards (latest orders): first item's menu photo (or "No image"), customer name, line no. "01"…, Order ID (number), Type label (Dine-in/Delivery/Pick-up), status badge (order labels), total `$x`.

### 5.6 "Sales & Order Types"
- Arrow-up-right (non-functional). 3 columns Dine-in / Delivery / Pick-up with `%` of orders count (dashed separators), and a segmented bar (accent, `#f99a55`, `#fdd0aa`) widths = %.

### 5.7 "Trending Menu Item" (right column)
- Photo (h-44), name, subtitle (item tag, or "Popular"/"Featured"), price (accent), star rating, clock icon + order qty.
- Data: most-ordered item by qty (fallback first menu item) or override `DashboardConfig.trendingItemId`.
- **Edit (pencil; manage:menu only)** → modal "Trending menu item": select "Featured item" with **"Auto — most ordered"** + all menu items; helper "Choose a dish to feature, or Auto to use the best-seller."; Cancel / Save ("Saving…"). `POST /dashboard/trending {itemId|null}` → `Actions::setTrendingItem`. Errors swallowed, page reloads.

### 5.8 "POS Activities"
- Static filter pill "Today's" (non-functional; data is all-time).
- "Total Sales →" `$x` (= completed revenue) + green pill **+12%** (hard-coded) "Since Yesterday".
- 3 stats: Total Bills (all orders count), AVG Value (avg order total, `$`), Peak Hour (hour with most orders, format `"5.00 PM"`, default 17).
- "Payment Method": SVG ticked semicircle gauge (48 ticks, colour lerp green→orange, ticks above value dimmed `#e6e8ec`), centre `{cash}%` + "Cash Payment"; legend "Card x%" (accent dot), "Online x%" (`#cbd0d8`). % computed from orders.paymentMethod CASH/CARD/ONLINE.
- Button **"View Details"** full width (non-functional).

---

## 6. Orders (`GET /orders`, perm `manage:orders`)

- Data: `Queries::getOrders()` (all orders, newest first; fields: id, number, type, status, channel, paymentMethod (default 'CASH'), outlet name, customer, customerEmail?, customerPhone?, items[{name,qty,price}], total, scheduleType?, scheduleDate?, scheduleTime?, notes?, tableNumber?, paymentProvider?, razorpayPaymentId?, createdAt). Client-side only filtering; **no pagination, no sort controls, no export.**
- **Stats (4 tiles)**: Total Orders (`receipt`), Completed (`circle-check`), Canceled (`circle-x`), Revenue (`dollar-sign`, sum of COMPLETED totals). Computed on all orders (not filtered).
- **Filters**: status pills `All, pending, preparing, ready, completed, canceled` (lower-case, CSS-capitalised); select channel `All channels / Online / In-house (POS)` (ONLINE/POS); select type `All types / Dine-in / Delivery / Pick-up`; search input **"Search order # or customer…"** (matches number or customer, case-insensitive).
- **Table columns**: Order (number + badges: `Table N` (gold pill) if tableNumber, `Online` (accent pill) if channel ONLINE, gateway pill `Stripe/PayPal/Razorpay` if paymentProvider) · Customer · Type · Items (sum qty) · Total · Time (`h:mm a`) · Status (dot badge) · View (eye icon). Whole row clickable → detail modal.
- Empty row: **"No orders match your filters."**
- Footer: "Showing X of Y orders. Status changes are in-session until the MySQL data layer is connected." (stale copy; changes ARE persisted).
- **Order detail modal** (title = order number):
  - Status badge, Online pill, gateway pill; created `MMM d, h:mm a`.
  - Stepper PENDING→PREPARING→READY→COMPLETED (done = check icon, current = ring). If CANCELED: red box "This order was canceled."
  - Detail grid: Customer, Type, Table (if any), Outlet, Payment (paymentMethod), Phone?, Email?, "<Gateway> Payment" = razorpayPaymentId?.
  - Take-away scheduling box (if scheduleType): "Scheduled pickup" / "ASAP pickup"; text `EEE, MMM d · <time>` or "As soon as possible".
  - Notes box (if notes).
  - Items list `qty× name` + line total; Total.
  - "Update status": buttons **"Mark <Next>"** (next step in flow, accent) and **"Mark Canceled"** (danger outline). None for COMPLETED/CANCELED → text "This order is Completed — no further actions."
  - Action: optimistic local update; `PATCH /orders/{id}/status {status}` → `Actions::setOrderStatus` (authz manage:orders). **Side effect:** on COMPLETED with customerEmail → sends branded "order completed" email (`EmailTemplates::orderCompletedEmail`), failure logged only. Error → toast (no rollback).
- Status labels: Pending, Preparing, Ready, Completed, Canceled. Validation: status ∈ PENDING|PREPARING|READY|COMPLETED|CANCELED.
- Realtime: none (static until reload).

---

## 7. Menu (`GET /menu`, perm `manage:menu`)

- Data: `Queries::getMenuItems()` (id, name, description, price, rating, tag, category name, imageUrl, available; sorted by name), `Queries::getMenuCategories()` (id, name, active, itemCount; by name), constant `MENU_CATEGORIES = ['Breakfast','Starters','Main Meals','Fish','Pasta & Salads','Desserts','Drinks']`.
- **Categories card** (only if categories exist): caption "CATEGORIES" + "Disabled categories are hidden from the website menu". Chip per DB category: eye/eye-off icon, name, `(itemCount)`; active = success styling, inactive = muted + line-through. Tooltip "Click to hide from website"/"Click to show on website". Click → optimistic toggle, `PATCH /menu/categories/{id}/active {active}` → `Actions::setCategoryActive`. Error toast (no rollback).
- **Toolbar**: category filter pills `All` + MENU_CATEGORIES (constant list, not DB); search **"Search dishes…"** (name or tag); **"Add Item"** (plus icon).
- **Table** columns: Item (44px thumb + name + tag) · Category · Price (`$x`) · Rating (gold star + value) · Status (toggle switch green/grey = available) · Actions (pencil Edit, trash Delete). Empty: **"No dishes match your filters."** Footer "Showing X of Y items. Changes are in-session until the MySQL data layer is connected." No pagination/sort.
- **Availability toggle**: optimistic; `PATCH /menu/items/{id}/availability {available}` → `Actions::setMenuAvailability`.
- **Delete**: `confirm('Remove this item from the menu?')` → optimistic remove → `DELETE /menu/items/{id}` → `Actions::deleteMenuItem`.
- **Add/Edit modal** (title "Add menu item"/"Edit menu item"):
  - Name (placeholder "Truffle Risotto"), Description textarea (2 rows, "Short description of the dish…"), Category select (MENU_CATEGORIES, default "Main Meals"), Tag ("Popular"), Price ($) number step 0.01 (placeholder 26, default 0), Rating (0–5) step 0.1 (default 0), Image (64px preview / "No image"; URL input "https://… or upload →"; **Upload** button (file input `accept=image/*`, spinner "Uploading…"); helper "Paste an image URL or upload a file (max 5MB)."), checkbox "Available on menu" (default on). Default image URL `https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=400&q=70`.
  - Client validation messages: name <2 → "Name is required"; description <4 → "Add a short description"; price empty/NaN/<0 → "Price must be positive"; rating <0 → "Number must be greater than or equal to 0", >5 → "Number must be less than or equal to 5"; invalid URL → "Enter a valid image URL".
  - Server (`MenuController::input`): name required min 2; description required min 4; price numeric ≥0; rating 0–5 nullable; tag nullable; category ∈ MENU_CATEGORIES; imageUrl required url; available boolean. Same messages.
  - Upload: `POST /api/upload` multipart `file` (session auth or mobile staff token with manage:menu). Errors: "Unauthorized" 401, "No file provided" 400, "Only image files are allowed" 415, "Image must be under 5MB" 413, "Could not save image" 500; default "Upload failed". Success → `{url: <host>/api/uploads/<name>}` (201) put in imageUrl.
  - Submit button "Add item"/"Save changes". Edit: optimistic merge + `PUT /menu/items/{id}` → `Actions::updateMenuItem`. Add: optimistic prepend (temp id) + `POST /menu/items` → `Actions::createMenuItem` → response replaces `items` and `categories`. Category is created on the fly (`firstOrCreate` by name).

---

## 8. Reservations (`GET /reservations`, perm `manage:reservations`)

- Data: `Queries::getReservations()` (newest first): id, reference, kind (TABLE|PRIVATE_EVENT), status, date (YYYY-MM-DD), name, email, phone, time?, guests?, occasion?, requests?, eventType?, guestRange?, space?, company?, message?, createdAt.
- **Stats**: Total (`calendar-clock`), New Requests (REQUESTED; `users`), Confirmed (CONFIRMED + SEATED; `circle-check`), Private Events (`party-popper`).
- **Filters**: status pills `All, Pending, Confirmed, Checked In, Completed, Cancelled, No-show`; **date picker** (exact date match, "Clear date" link when set); kind select `All kinds / Table Booking / Private Event`; search **"Search ref, name, email…"**.
- **Table**: Reference (icon chip utensils/party-popper + reference) · Guest (name + email) · Kind · Date (`MMM d` + `· time`) · Party (`N guests` for TABLE, guestRange for events) · Status · View. Row click opens detail. Empty: **"No reservations match your filters."** Footer: "Showing X of Y reservations. Once MySQL is live, bookings submitted on the public site land here automatically."
- Status labels: REQUESTED "Pending", CONFIRMED "Confirmed", SEATED "Checked In", COMPLETED "Completed", CANCELED "Cancelled", NO_SHOW "No-show".
- **Detail modal** (title = reference):
  - Kind pill, status badge. Stepper: TABLE flow REQUESTED→CONFIRMED→SEATED→COMPLETED; PRIVATE_EVENT flow REQUESTED→CONFIRMED→COMPLETED. If CANCELED/NO_SHOW: red box "This reservation was cancelled." / "…no-show."
  - Contact card: name, `mailto:` email, `tel:` phone.
  - Details (read): Date `EEE, MMM d, yyyy`; TABLE: Time, Guests, Occasion, Requests; EVENT: Event type, Estimated guests, Space, Company, Details (empty values hidden).
  - **"Edit reservation"** (pencil) — only TABLE kind and status not COMPLETED/CANCELED/NO_SHOW. Edit form: Date (date), Time (time), Guests (number min 1), Occasion, Notes / requests (textarea). Cancel / **Save changes** → optimistic + `PATCH /reservations/{id}` (partial: date, time, guests, occasion, requests) → `Actions::updateReservation` (server: date `Y-m-d`, guests int ≥1).
  - "Update status": **Mark <next>** + for TABLE "Mark Cancelled", "Mark No-show" (danger), for EVENT "Mark Cancelled". Closed → "This reservation is <Label> — no further actions." Optimistic; `PATCH /reservations/{id}/status` → `Actions::setReservationStatus`. **Side effect:** COMPLETED + email → "reservation completed" thank-you email.
- No pagination/export/realtime. Reservations are created from the public site (`POST /api/reservations`), not here.

---

## 9. Tables / QR management (`GET /tables`, perm `manage:tables`)

- Data: `Queries::getTables()` (by number): id, number, name?, code, status ACTIVE|INACTIVE, orderCount, createdAt; `websiteUrl = config('go4foodie.website_url')` (env `WEBSITE_URL`, default `http://localhost:3000`).
- **QR payload**: `${websiteUrl}/order?table=${encodeURIComponent(code)}` (QR via `qrcode` lib, margin 1, errorCorrectionLevel M; cached per code|size).
- **Toolbar**: status pills `All / Active / Inactive`; search **"Search tables…"** (number or name); **"Add Table"**.
- **Card grid** (2/3/4 cols): "Table N", name; status badge **button** (tooltip "Click to deactivate"/"Click to activate") → optimistic toggle `PATCH /tables/{id}/status` → `Actions::setTableStatus`; QR image (160px) clickable → QR modal; "N orders"; action icons: QR (opens modal), Download, Print, | Edit, Delete.
- Empty: **"No tables match your filters."**
- **Download**: 600px PNG, filename `table-{number}-qr.png`.
- **Print**: popup 420×620 with "GO4FOODIE" (uppercase letter-spaced), "Scan to order · Table N · name", 300px QR, auto `print()` on image load.
- **QR modal** (title "Table N · QR code"): 260px QR on white, external link to the URL (new tab), buttons Download / Print.
- **Add/Edit modal** ("Add table"/"Edit table"): Table number (placeholder "12"; error "Table number is required"), Table name ("Window / Patio"), Status select Active/Inactive with helper **"Inactive tables stop accepting QR orders."**; buttons Cancel / "Add table" | "Save changes". Add → `POST /tables` → `Actions::createTable` returns created row (prepended; code auto-generated by model). Edit → optimistic + `PUT /tables/{id}` → `Actions::updateTable`. Server validation number required min 1 ("Table number is required"), status ∈ ACTIVE/INACTIVE.
- **Delete**: `confirm("Delete table N? Its QR code will stop working.")` → optimistic → `DELETE /tables/{id}` → `Actions::deleteTable`.
- Note: table **capacity** (used by floor "Seats N" and analytics) is NOT editable in this UI.

---

## 10. Floor plan — live (`GET /floor`, perm `manage:tables`)

- Data: `Queries::getFloorTables()` (by number): id, number, name?, capacity, status, state, session|null {id, openedAt, customerCount, customerName?, waiterName?, currentBill (sum of session order totals), orderCount}; `Queries::getWaiterOptions()` (active employees id/name); constants `STATES = AVAILABLE, RESERVED, OCCUPIED, WAITING_PAYMENT, CLEANING, OUT_OF_SERVICE`, `PAYMENT_METHODS = Cash, Credit Card, Debit Card, UPI, Wallet, Mixed`.
- **Realtime / polling** (must replicate, e.g. Firestore listeners):
  - Polls `GET /floor/version` every **5 s** (skipped when `document.hidden`); response `{v}` = concat of MAX(updatedAt)#COUNT for Table, TableSession, Order + Payment count. When `v` changes → `GET /floor/data` → replace tables (and keep open modal in sync).
  - Safety-net full refresh every **60 s**.
  - Duration clock re-render every **30 s**.
  - (The original Next.js app used SSE `/api/floor-stream`, still available: emits `data: connected`, then every 4 s `data: refresh` or `: ping`; stream ends after `FLOOR_STREAM_MAX_SECONDS` default 120.)
- **Live stats bar**: Total, Available (success), Occupied (danger), Reserved (warn), Awaiting Pay (`#b45309`, = WAITING_PAYMENT), Cleaning (info), Out of Service (muted); **Refresh** button (refresh-cw).
- Empty: **"No tables yet — add tables in Table Management."**
- **Table cards** (2–5 cols, coloured per state: card border/bg + badge): "Table N", name, state badge (labels: Available, Reserved, Occupied, Waiting Payment, Cleaning, Out of Service). With session: `users` "N guests · Waiter", `clock` "<duration> · N orders" (duration `Xh Ym` or `Ym`), `receipt` current bill. Without session: "Seats {capacity}". Hover lift.
- **Table modal** (title "Table N"):
  - State badge; "name · seats N".
  - **"Open POS · $bill"** (accent) → `/pos/{id}`; **History** → `/table-history/{id}`.
  - With session: grid Guests, Waiter (—), Duration, Orders, Customer (—), Current bill. "CLOSE & PAY" box: payment method select; **"Close table · $bill"** → `POST /floor/sessions/{sessionId}/close {paymentMethod}` → `Actions::closeTableSession` (authz operate:floor) → refresh + close modal; **"Awaiting payment"** (hidden if already) → set state WAITING_PAYMENT.
  - Without session: "OPEN TABLE": Guests (number min 1, default 2), Waiter select ("— None —" + waiters), Customer name (optional, placeholder "Walk-in"); **"Open & seat"** (user-round icon) → `POST /floor/tables/{id}/open {customerCount, waiterId|null, customerName|null}` → `Actions::openTableSession` (no-op if already open; sets state OCCUPIED; audit `session.open`). Server validation customerCount int ≥1, customerName ≤120.
  - "SET STATE" chips for every other state (coloured as badges). **AVAILABLE and OUT_OF_SERVICE disabled while a session is open** (tooltip "Close the open session first"). Optimistic → `PATCH /floor/tables/{id}/state {state}` → `Actions::setTableState` (audit `table.state`).
- closeTableSession logic: computes total = subtotal − discount + tax + service + tip (≥0); remaining after partial payments; if remaining > 0.001 creates a Payment with selected method; session paymentMethod = single method or **"Mixed"** if multiple; session CLOSED/PAID; table → **CLEANING**; audit `session.close`.
- Errors → toast; refresh still happens.

---

## 11. POS (`GET /pos/{tableId}`, perm `manage:orders`)

- 404 if table not found. Data: `Queries::getTablePos(tableId)` → table {id, number, name?, capacity, state} + open session {id, openedAt, customerCount, customerName?, waiterName?, lines[{menuItemId,name,qty,price}] (aggregated across session orders), orders[], subtotal, discount, tax, serviceCharge, tip, total, payments[{amount,method,createdAt}], paid, remaining}; `getMenuItems()`; `getWaiterOptions()`; `getMergeTargets(tableId)` (other OPEN sessions: tableId, sessionId, number); PAYMENT_METHODS.
- Every mutation returns fresh `{table, session, mergeTargets}`; on error → toast + re-fetch `GET /pos/{tableId}/data`. Buttons disabled while pending.

### 11.1 No open session — "Open Table N"
- "← Back to floor" link. Card: "Open Table N", "Seat guests to start a session." Guests (default 2), Waiter select, "Customer (optional)" (placeholder "Walk-in"). Button **"Open & seat"** / "Opening…" → `POST /pos/{tableId}/open` → `Actions::openTableSession`.

### 11.2 Active session
- Header: "← Back to floor" + "Table N · name · X guests · Waiter".
- **Menu picker** (left): search "Search dishes…"; category chips `All` + distinct categories of **available** items; grid of available items (name, price, "In cart: n"). Click adds 1 to local cart.
- **New items cart** card (shown if cart not empty): lines with −/qty/+; button **"Send to kitchen · $cartTotal"** (chef-hat) → first opens **KOT print** for the cart lines, then `POST /pos/sessions/{sessionId}/orders {tableId, items:[{menuItemId, qty}]}` → `Actions::addSessionOrder` (creates a DINE_IN, channel POS, status PENDING order `ORD-#####` priced from live menu, customerName = session customer or "Table N"; recompute totals; audit `order.add`) → clears cart.
- **Merge table** card (if merge targets): select "Select a table…" / "Table N"; **Merge** (combine icon) → `POST /pos/sessions/{sessionId}/merge {tableId, fromSessionId}` → `Actions::mergeSessions(from, into)` (moves orders+payments, sums guests, closes source session with note "Merged into table …", source table → CLEANING, audit `session.merge`).
- **Bill** card:
  - Header "BILL" + **KOT** print link (prints all current lines).
  - Empty: "No items yet — add from the menu."
  - Lines: − / qty / + / name / line total. "+" → addSessionOrder qty 1; "−" → `POST /pos/sessions/{id}/decrement {tableId, menuItemId}` → `Actions::decrementSessionItem` (removes one unit from latest order containing it; deletes empty order; audit `order.void`).
  - Subtotal; editable **Discount, Tax, Service, Tip** ($ inputs, min 0, step 0.01; seeded from session); **"Save adjustments"** → `PATCH /pos/sessions/{id}/billing {tableId, discount, tax, serviceCharge, tip}` → `Actions::updateSessionBilling` (clamped ≥0, recompute). Total = live preview `max(0, subtotal − discount + tax + service + tip)`. If paid > 0: "Paid" (success) and "Remaining".
  - **Split / partial payment**: list of payments (method, amount); Amount input + method select + **Add** → (ignored if amount ≤ 0) `POST /pos/sessions/{id}/payments {tableId, amount, method}` → `Actions::addPayment` (audit `payment.add`). Server: amount > 0, method ≤50 chars.
  - **Print invoice** (receipt icon): popup with "Go4Foodie", "Table N · <now toLocaleString>", lines, Subtotal, Discount (−), Tax, Service, Tip (only non-zero), TOTAL.
  - Payment method select + **"Close & Pay"** (shows "· $remaining" if partially paid) → `POST /pos/sessions/{id}/close {discount, tax, serviceCharge, tip, paymentMethod}` → `updateSessionBilling` + `closeTableSession` → **always navigates to `/floor`** (even on error, after toast).
- Print documents: popup 400×680, Courier New 13px, 320px wide, dashed separators, auto `window.print()`. KOT = "KITCHEN ORDER", "Table N · <time>", rows "qty × name".

---

## 12. Table Analytics (`GET /table-analytics?days=1|7|30`, perm `view:reports`)

- `days` default **1** (invalid → 1). Data `Queries::getTableAnalytics(days)`; range = start of today (server-local) − (days−1) days; operating hours constants OPEN 10, CLOSE 22.
- **Period tabs** (links): Today / Last 7 Days / Last 30 Days.
- **Export**: "Export" label + **CSV** (`table-performance.csv`), **Excel** (HTML-table `.xls`, `table-performance.xls`, `application/vnd.ms-excel`), **PDF** (print popup "Go4Foodie — Table Performance", sub "N sessions · N customers · $X revenue", bordered table, auto print). Columns: `Table, Name, Sessions, Customers, Orders, Revenue, AvgBill, AvgDiningMin, OccupancyPct, UtilizationPct`.
- **Live stats** bar (current state counts, not period): Total, Available, Occupied, Reserved, Cleaning, Out of Service.
- **Summary (7 cards)**: Table Sessions, Customers, Orders, Revenue ($), Avg Bill ($), Avg Guests/Table (1 decimal), Avg Dining (`N min`).
- **Busy Hours** bar chart (Chart.js): hours 10AM..9PM labels like "10AM", sessions per hour opened; integer Y ticks (4 steps); accent bars rounded top; header shows `Peak <h:00 AM/PM>` (clock) and peak weekday (calendar-days) or "—".
- **Top Tables** (trophy, gold): Highest Revenue, Most Used, Most Customers, Highest Avg Bill, Longest Occupied, Fastest Turnover → "Table N · value" or "—" (only tables with sessions).
- **Needs Attention** (trending-down): Least Used, Lowest Revenue, Lowest Occupancy (across all tables).
- **Customers** card: Served, Avg Spend ($ = revenue/customers).
- **Favourite Items** (star): top 5 by qty; empty "No data yet."
- **Payment Methods** (wallet): counts by method (desc); empty "No payments yet."
- **Per-table table**: Table (link to `/table-history/{id}`, "Table N · name") · Sessions · Customers · Orders · Revenue · Avg Bill · Avg Dining (`N min`) · Occupancy (mini progress bar + %) · Utilization (%). Empty: "No tables yet."
- Metric definitions: occupancyPct = min(100, round(occupiedMin / ((22−10)·60·days) ·100)); utilizationPct = avg(min(1, guests/capacity))·100; avgDining = occupied minutes / sessions (open sessions count up to now).

## 13. Table History (`GET /table-history/{tableId}?days=`, perm `view:reports`)

- `days` default **30**. Data `Queries::getTableHistory(tableId, days)`. If table missing: "Table not found."
- Top: "← Analytics" link; **Export CSV** → `table-{number}-history.csv` with header `Date, Opened, Closed, Duration(min), Guests, Waiter, Items, Subtotal, Discount, Tax, Service, Tip, Total, Payment, Status` (Items as `"2x Name; 1x Other"`; times `toLocaleTimeString()`).
- Header card: "Table N · name"; totals "N sessions", "N guests", "$X revenue", "N min total occupied"; period pills Today / Last 7 Days / Last 30 Days.
- Empty: **"No sessions in this period."**
- Timeline (vertical, dot red if OPEN else accent): `EEE, MMM d · h:mm a – h:mm a` or "(open)", total ($); meta: guests, duration min, waiter, "Paid · method"; items `qty× name`; adjustments line "Subtotal $x · −$d disc · +$t tax · +$s svc · +$p tip" (only if any non-zero).

---

## 14. Staff (`GET /staff`, perm `manage:staff`)

- Data: `Queries::getEmployees()` (by name): id, name, role, outlet, email, phone?, active, status (ON_DUTY|ON_BREAK|ABSENT|OFF), createdAt. ROLES constant: `Super Admin, Manager, Cashier, Kitchen Staff, Waiter` (Employee roles — distinct from login User roles).
- **Stats**: Total Staff (`users`), Active (`user-check`), On Duty (`coffee`), Inactive (`user-x`).
- **Filters** (each resets page to 1): duty pills `All duty / On Duty / On Break / Absent / Off Shift`; select `All accounts / Active / Inactive`; select `All roles` + union(ROLES, existing roles); search **"Search staff…"** (name/email); **"Add Staff"**.
- **Table**: Staff (initials avatar coloured by row index, name, email) · Phone (—) · Role · Status (button pill Active/Inactive; tooltip "Click to deactivate"/"Click to activate") · Duty (inline select coloured by status) · Actions (Edit, Delete). Empty: **"No staff match your filters."**
- **Pagination**: client-side **12 per page**; footer "`N staff · page X of Y`", prev/next chevron buttons (disabled at ends).
- Toggle active: optimistic, rollback on error; `PATCH /staff/{id}/active {active}` → `Actions::setStaffActive`.
- Duty select: optimistic, rollback on error; `PATCH /staff/{id}/status {status}` → `Actions::setEmployeeStatus`.
- Delete: `confirm('Delete staff member "<name>"?')`, optimistic, rollback on error; `DELETE /staff/{id}` → `Actions::deleteStaff`.
- **Add/Edit modal** ("Add staff"/"Edit staff"): Name ("Jane Doe"), Email ("jane@email.com"), Phone ("+1 555 000 0000"), Role select (ROLES; default Waiter; unknown role on edit → Waiter), Password (type password; placeholder "Min 6 characters" or "••••••••" with label suffix "(leave blank to keep)" on edit), checkbox "Active (can be deactivated to disable the account)" default on. Buttons Cancel / "Add staff" | "Save changes" (disabled while saving).
  - Validation (client+server): name ≥2 "Name is required"; email regex / email "Enter a valid email"; password if given ≥6 "Min 6 characters"; role ∈ ROLES.
  - Add → `POST /staff` → `Actions::createStaff` (bcrypt password, outlet = first outlet) → response `employees` replaces list. Edit → `PUT /staff/{id}` → `Actions::updateStaff` (blank password keeps existing).
  - Errors → toast; modal stays open.

---

## 15. Customers (`GET /customers`, perm `manage:customers`)

- Data: `Queries::getCustomers()` (by name): id, name, email, phone?, address?, status ACTIVE|INACTIVE, orders[{number,total,status,date}], reservations[{reference,kind,status,date}], totalSpend (non-canceled orders), lastActivity, createdAt.
- **Stats**: Total Customers (`users`), Lifetime Value (`dollar-sign`, Σ totalSpend), Avg Spend (`trending-up`, round(lifetime/count)), Repeat Guests (`repeat`, visits>1 where visits = orders + reservations).
- **Toolbar**: pills `All / Active / Inactive`; search **"Search customers…"** (name/email/phone); **"Add Customer"**.
- **Table**: Customer (avatar, name, email) · Phone (—) · Address (1 line, —) · Status (dot badge) · Created (`MMM d, yyyy` or —) · Actions (View eye, Edit, Delete). Empty: **"No customers match your filters."** No pagination/export.
- **View modal** ("Customer"): avatar, name + status, mailto email, tel phone, address (map-pin); tiles Lifetime ($), Orders (count), Visits; "ORDER HISTORY" list (number, `MMM d`, total); "RESERVATIONS" list (reference, `MMM d`, Table/Event).
- **Add/Edit modal**: Name, Email, Phone, Address ("Street, City, State"), Status (Active/Inactive). Validation: name ≥2 "Name is required", email "Enter a valid email"; server status ∈ ACTIVE/INACTIVE. Add → `POST /customers` → `Actions::createCustomer` → returns full `customers`. Edit → `PUT /customers/{id}` → `Actions::updateCustomer`. Delete: `confirm('Delete customer "<name>"?')`, optimistic + rollback → `DELETE /customers/{id}` → `Actions::deleteCustomer`.

---

## 16. Gift Cards & Coupons (`GET /gift-cards`, perm `manage:coupons`)

- Data: `Queries::getGiftCards()` (newest first): id, code, kind GIFT_CARD|COUPON, customerName, customerEmail?, amount, message?, expiryDate? (YYYY-MM-DD), paymentStatus PENDING|PAID|FAILED, status PENDING_PAYMENT|PAID|ACTIVE|REDEEMED|EXPIRED|CANCELLED, paymentProvider?, razorpayPaymentId?, createdAt.
- **No "create" in admin** — purchases come from the public site (`POST /api/gift-cards`).
- **Stats**: Total Purchases (`gift`), Total Value (`dollar-sign`, Σ amount where paymentStatus PAID), Active (`circle-check`), Redeemed (`clock`).
- **Toolbar**: status pills `All, Pending Payment, Paid, Active, Redeemed, Expired, Cancelled`; type select `All types / Gift Cards / Coupons`; search **"Search code, name, email…"**; **Export** (download icon).
- **Export CSV** (of currently filtered rows) → `gift-cards-YYYY-MM-DD.csv`, header `Code, Type, Customer, Email, Amount (2dp), Payment, Status, Expiry, Created (YYYY-MM-DD)`.
- **Table**: Code (mono) · Customer (name + email/—) · Type · Amount · Payment · Status · Created (`MMM d, yyyy`) · Actions (View, Edit, Delete). Rows with REDEEMED/EXPIRED/CANCELLED rendered at **50% opacity**. Empty: **"No purchases match your filters."**
- **View modal** (title = code): kind pill, status badge; gold "CODE" panel (mono 2xl code + amount); detail grid Customer, Email (—), Payment, Expiry ("No expiry"), Created, "<Stripe|PayPal|Razorpay> Payment" id; Message (italic, quoted). "Update status" quick actions (excluding current status): **Activate** (ACTIVE), **Mark Redeemed** (REDEEMED), **Expire** (EXPIRED), **Cancel** (CANCELLED, danger). Optimistic + rollback → `PATCH /gift-cards/{id}/status` → `Actions::setGiftCardStatus`. **Side effect:** REDEEMED + email → "gift card redeemed" email.
- **Edit modal** ("Edit <code>"): Customer name, Customer email, Type (Gift Card/Coupon), Amount ($, step 0.01), Status (6 options), Payment (Pending/Paid/Failed), Expiry date (optional, date). Validation: name ≥2 "Name is required"; email optional "Invalid email"; amount > 0 "Amount must be positive"; server expiry `Y-m-d`. `PUT /gift-cards/{id}` → `Actions::updateGiftCard`.
- Delete: `confirm("Delete <code>?")`, optimistic + rollback → `DELETE /gift-cards/{id}` → `Actions::deleteGiftCard`.

---

## 17. Transactions (`GET /transactions`, perm `view:reports`) — read-only

- Data: `Queries::getTransactions()` = union, sorted by date desc: **Order** (orders with paymentMethod not null, latest 250; method = gateway label or paymentMethod; paymentId = razorpayPaymentId), **Gift Card** (paymentStatus PAID, latest 250; method gateway label or "Online"), **Table** (POS `Payment` rows, latest 250; reference "Table N"; customer session name or "—"; status PAID). Fields: id, source, reference, customer, amount, method, paymentId?, status, date.
- **Stats (computed on filtered rows)**: Transactions (`receipt`), Total Amount, Gateway Payments (`credit-card`, method ∈ Razorpay/Stripe/PayPal), Gateway Amount.
- **Filters**: source pills `All / Order / Gift Card / Table`; method select `All methods` + sorted distinct methods; search **"Search ref, customer, payment id…"**; **Export**.
- **Export CSV** (filtered) → `transactions-YYYY-MM-DD.csv`, header `Date (YYYY-MM-DD HH:MM:SS), Source, Reference, Customer, Method, Amount, Status, PaymentId`.
- **Table**: Source (pill: Order accent, Gift Card gold, Table info) · Reference (+ mono paymentId) · Customer · Method (gateway = blue pill) · Amount · Date (`MMM d, h:mm a`). Empty: **"No transactions match your filters."**

---

## 18. Inventory (`GET /inventory`, perm `manage:inventory`)

- Data: `Queries::getInventory()` (by name): id, name, category, unit, quantity, reorderLevel, costPerUnit, supplier. CATEGORIES constant: `Produce, Meat & Fish, Dairy, Beverage, Dry Goods, Bakery`.
- Stock status: `quantity <= 0` → OUT ("Out of Stock", danger); `quantity <= reorderLevel` → LOW ("Low Stock", warn); else IN_STOCK ("In Stock", success).
- **Stats**: Total Items (`package`), Low Stock (`triangle-alert`), Out of Stock (`circle-x`), Stock Value (`dollar-sign`, Σ qty·costPerUnit).
- **Toolbar**: category pills `All` + CATEGORIES; search **"Search items…"** (name/supplier); **"Add Item"**.
- **Table**: Item · Category · Supplier (—) · Stock (− button, "`qty unit`", + button; caption "reorder at N") · Status badge · Actions (Edit, Delete). OUT rows tinted `bg-danger-soft/30`. Empty: **"No inventory items match your filters."**
- **±1 adjust**: optimistic (min 0), rollback on error → `PATCH /inventory/{id}/adjust {delta: ±1}` → `Actions::adjustInventory`.
- Delete: `confirm('Remove this inventory item?')`, optimistic + rollback → `DELETE /inventory/{id}`.
- **Add/Edit modal** ("Add inventory item"/"Edit inventory item"): Name ("Sea Bass (whole)"), Category (default Dry Goods), Unit ("kg, L, units"; default kg), Quantity / Reorder at / Cost / unit (number step 0.01, default 0), Supplier ("Boston Seafood Co."). Validation: name ≥2 "Name is required"; unit ≥1 "Unit is required"; numbers ≥0 "Number must be greater than or equal to 0". Add → `POST /inventory` → `Actions::createInventoryItem` (response `items` replaces list); Edit → `PUT /inventory/{id}` → `Actions::updateInventoryItem`.
- Low-stock items feed the Notifications page and the bell count.

---

## 19. Reports (`GET /reports`, perm `view:reports`)

- Data: `Queries::getReportsData()` (all-time; **no date filter**). Canceled orders excluded from revenue/items/top items/category/payment mix (but `orders` count and order types include all). Fallback zeros if DB down.
- Top-right **"Export top items (CSV)"** → `top-items.csv` header `Item, Quantity, Revenue` (no-op when empty).
- **Stats**: Revenue ($), Orders, Items Sold (`boxes`), Avg Order ($, `receipt`).
- **Revenue by Outlet** (bar chart, 260px): x = outlet names with "Outlet " → "O" in ticks; nice Y axis `$v`; tooltip "Revenue : $x"; accent bars rounded top. Sorted by outlet name (en_US collation).
- **Category Mix** doughnut (radius 90, cutout 55, pie colour palette, drawn to match recharts orientation) + legend list "Category … $revenue · pct%". Tooltip "Category : $x".
- **Top Selling Items**: top 8 by qty; "name" + "N sold · $revenue" + progress bar width = qty/maxQty.
- **Order Types**: Dine-in / Delivery / Pick-up counts. **Payment Methods**: Cash / Card / Online counts.

---

## 20. Outlets (`GET /outlets`, perm `manage:outlets`) — hidden from navigation, read-only

- Data: `Queries::getOutlets()` (by name): id, name, location, address, phone, manager, isActive, weekly[{week "W1".., revenue, cost}] from OutletMetric ordered by periodStart. "Current" = last week entry. margin = round((rev−cost)/rev·100) (0 if rev 0).
- **Stats**: Total Outlets (`store`), Active, Weekly Revenue (Σ current revenue, `$`), Avg Margin (`percent`, aggregate).
- **Cards**: name, map-pin location, badge Active/"Closed", tiles Revenue / Op. Cost, manager (user icon), margin pill `+x% margin` (green ≥0 else red). Click → modal.
- **Modal** (title = name): location, margin pill; rows Address / Phone / Manager; "Revenue vs Operational Cost" line chart (180px; Revenue `#3a3a3a`, Cost accent; tooltip "Revenue : $x"; nice axis `$xK`). Chart destroyed on close, redrawn on theme change.
- No create/edit in the web admin (public/mobile API has `POST /api/outlets`).

---

## 21. Notifications (`GET /notifications`, any signed-in user)

- Data: `Queries::getNotifications()` sorted by time desc (centered max-w-2xl card list):
  - `order` (shopping-bag, info): latest 6 orders → "New order {number}" / "{customer} · $total".
  - `reservation` (calendar-clock, accent): latest 6 REQUESTED → "Reservation request {ref}" / "{name} · Table booking|Private event".
  - `stock` (package-x, danger): items with qty ≤ reorder → "Low stock: {name}" / "{qty} {unit} left (reorder at {n})".
  - `table` (layout-dashboard, warn): CLEANING → "Table N needs cleaning" / "Mark available once cleaned."; WAITING_PAYMENT → "Table N payment pending" / "Awaiting checkout."; open session > 120 min → "Table N occupied 2h+" / "Open since <h:mm:ss AM>"; open session total ≥ 300 → "Large bill at Table N" / "$x running".
- Time column: `M j, g:i A` (server local tz).
- Empty: **"You’re all caught up."** No mark-as-read, no filters, no realtime.

---

## 22. Audit Log (`GET /audit`, perm `manage:settings` → OWNER)

- Data: `Queries::getAuditLogs(200)` newest first.
- **Table**: When (`M j, g:i A`) · Action (pill; colour by suffix after `.`: open success, close accent, add info, void danger, merge warn, state muted, payment info) · Entity · Detail (—) · By (userName or "System"). Empty: **"No activity logged yet."** No filters/pagination/export.
- Logged actions (from `Actions::logAudit`): `session.open` (TableSession, "N guests"), `order.add` (Order, "N item(s)"), `order.void` ("Removed item"), `session.merge` ("Merged from …"), `payment.add` ("<method> <amount>"), `session.close` ("<method> · total <n>"), `table.state` (state).

---

## 23. Settings (`GET /settings`, perm `manage:settings` → OWNER)

Grid 2 columns:
1. **Restaurant Profile** — "Brand name, currency, and contact details." Data `Queries::getProfile()` (fallback name "Go4Foodie", USD, America/New_York, "245 Harbor View Avenue, Boston, MA", "+1 617 482 6060", "hello@go4foodie.com"). Fields: Restaurant name, Currency (placeholder USD), Timezone (placeholder America/New_York), Address, Phone, Email. Validation: name ≥2 "Restaurant name is required"; email optional "Enter a valid email"; server currency/timezone required. **Save changes** (spinner) → `PUT /settings/profile` → `Actions::updateProfile`; success shows inline green "✓ Saved"; error toast.
2. **Change Password** — "Update your account password." Current password ("Current password is required"), New password (min 6 "New password must be at least 6 characters"). **Update password** → `POST /settings/password` → `Actions::changePassword` returns `{ok, error?}`: success banner "Password updated" (form cleared); errors "Current password is incorrect", "User not found", "Unauthorized", network → "Something went wrong", default "Failed".
3. **Team** — "Signed in as {name} ({ROLE})." List of `Queries::getUsers()` (admin login users): name, email, role badge (OWNER accent, MANAGER info, STAFF muted). Read-only (no invite/edit of admin users anywhere in the UI).
4. **Roles & Permissions** — "What each role can access." Read-only matrix Module × OWNER/MANAGER/STAFF with check / "—" for: Dashboard, Orders, Menu, Reservations, Outlets, Staff, Customers, Inventory, Reports, Settings (computed with `Rbac::can`).

---

## 24. Cross-cutting behaviour checklist

- **Optimistic updates without rollback** (toast only): orders status, menu availability/category/edit/add, reservations status/edit, tables status/edit/delete, floor state.
- **Optimistic with rollback**: staff (active, duty, delete), customers delete, gift cards (status, delete), inventory (adjust, delete).
- **Confirm dialogs** (native `confirm`): menu delete, table delete, staff delete, customer delete, gift-card delete, inventory delete.
- **Exports**: Gift cards CSV, Transactions CSV, Reports top-items CSV, Table analytics CSV/XLS/PDF(print), Table history CSV. **Prints**: Table QR, POS KOT (cart and full bill), POS invoice, analytics PDF.
- **QR**: client-generated from `WEBSITE_URL/order?table=<code>`.
- **Realtime**: only Floor (5 s version poll + 60 s refresh + 30 s clock). Everything else is load-time data (bell count per page load).
- **Email side effects**: order COMPLETED, reservation COMPLETED, gift card REDEEMED (only if email present; failures logged, never block).
- **Audit side effects**: all floor/POS session actions.
- **Charts** (Chart.js, no animation, theme-aware): dashboard line + semicircle doughnut + SVG gauge, table-analytics bar, reports bar + doughnut, outlet line.
- **Fallbacks when DB down**: dashboard mock data, reports zeros, settings default profile, other lists empty arrays (pages render empty states).
- **Non-functional UI elements to reproduce as-is (or decide)**: topbar search `?q=` + ⌘F hint; dashboard "Weekly"/"Today's" filter pills, recent-orders search, arrow-up-right buttons, "View Details"; hard-coded KPI deltas (+10, +7.5, −3.5, +7.5) and POS +12%.
- **Stale footer copy** on Orders/Menu/Reservations referencing "until the MySQL data layer is connected".
