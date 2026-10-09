# Porting guide — Next.js admin → Laravel admin

`admin/` (Next.js 16 + Prisma) is the **source of truth** and must not be modified.
`admin-laravel/` (Laravel 12, PHP 8.2) re-implements it against the **same live MySQL
database** (`restaurant_db`), the same logins, and the same JSON APIs.

## Golden rules
- **Never run `php artisan migrate`** (or any schema change) — the DB is shared and live.
  There are no migrations in this project on purpose. Session/cache are file-based.
- Don't write test data to the live DB from scripts. Exercising a mutation once through
  the UI/API to verify it is OK if you revert/clean it up (e.g. cancel the test order).
- Run PHP / artisan from the F: drive (XAMPP's php.ini uses drive-relative paths).
- Dev server: `php artisan serve --host=0.0.0.0 --port=33665` (Next.js admin stays on 33664).
  DB tunnel: `cd ../admin && npm run tunnel` (or the Next admin's `npm run start:local`).
- Assets: `npx vite build` after changing CSS/JS/Blade classes (Tailwind scans Blade).

## Layout of the code
| Concern | Location |
|---|---|
| Models (one per Prisma table) | `app/Models/*` — `RestaurantTable` = table `Table`. camelCase columns, string cuid ids (auto), decimals cast to float |
| Permissions | `App\Support\Rbac` (same map as rbac.ts) · `App\Support\CurrentUser::get()/can()/authorize()` |
| Reads (port of queries.ts) | `App\Services\Queries::<sameNameAsTs>()` → arrays with the TS interface shapes |
| Writes (port of actions.ts) | `App\Services\Actions::<sameNameAsTs>(...)` — authorize + audit inside |
| Scheduling / mail | `App\Services\Scheduling`, `App\Services\Mailer` |
| Dates in JSON | `App\Support\Iso::of($d)` (JS `toISOString()` format) |
| Errors | throw `App\Support\HttpError($status, $msg)` → `{error}`; `ForbiddenException` → 403 |
| Web routes | `routes/admin/<area>.php` (auto-loaded inside the `auth` group) |
| API routes | `routes/api/<area>.php` (auto-loaded, prefixed `/api`) |
| Controllers | `app/Http/Controllers/Admin/*` (pages), `app/Http/Controllers/Api/*` (JSON) |
| Views | `resources/views/<area>/*.blade.php`, extend `layouts.app`, `@section('content')` |

## Page conventions (Blade + Alpine + Tailwind v4)
- Every page: `@extends('layouts.app')` + `@section('content')`. The layout renders the sidebar,
  topbar (title/subtitle derived from the URL — override with `$pageTitle` / `$pageSubtitle`),
  toasts and flash messages (`->with('success'|'error', '...')`).
- Guard routes with `->middleware('perm:<action>')` using the same action as the Next page's
  `requirePermission(...)`.
- Design tokens/classes are identical to the Next admin: `bg-bg bg-surface bg-surface-2 border-border
  text-fg text-fg-muted text-accent bg-accent-soft text-success bg-danger-soft …`, `card`, `rounded-card`,
  `shadow-card/pop`, `font-display`. Helpers: `input`, `label`, `btn-primary`, `btn-ghost`, `btn-danger`,
  `table-base`. Dark mode is automatic.
- Icons: lucide names, `<i data-lucide="shopping-cart" class="h-4 w-4"></i>`. After Alpine inserts new
  icon markup call `renderIcons()`.
- Components: `<x-status :value="$o['status']" />`, `<x-modal name="…" title="…">`, `<x-kpi label value icon delta accent />`,
  `<x-empty icon title message />`.
- Mutations: simple ones as `<form method="POST">` + `@csrf` (+ `@method('PATCH')`) → controller calls
  `Actions::…` → `back()->with('success', …)`. Interactive screens (POS, floor, modals that must not reload)
  use `window.api(url, {method, body})` against JSON routes in the same `routes/admin/<area>.php`
  (they share the web session + CSRF), then `toast()`.
- Charts: Chart.js is global (`new Chart(ctx, …)`); colours via `themeColor('accent')` etc.
- Money: PHP `App\Support\Format::currency($n)` (port of formatCurrency); JS `money(n)`.
- Exports (CSV everywhere, reports also Excel .xls via HTML table, PDF via window.print) — same as Next.
- Match the Next.js UI 1:1 (same sections, filters, tabs, columns, modals, empty states, wording).
