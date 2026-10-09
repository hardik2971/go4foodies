# Go4Foodie — Admin (Laravel)

Laravel 12 port of the Next.js admin in `../admin`. It runs **side by side** with it:
same MySQL database (`restaurant_db`), same admin logins and passwords, same `/api/*`
JSON contract — so the public website and the Flutter app can use either backend, and
mobile login tokens work on both.

| | Next.js admin (`../admin`) | Laravel admin (this folder) |
|---|---|---|
| Port (dev) | 33664 | 33665 |
| Stack | Next 16, Prisma 6, NextAuth | Laravel 12 (PHP 8.2), Eloquent, Blade + Alpine + Tailwind v4 |

## Requirements
- PHP 8.2+ with pdo_mysql, openssl, mbstring, curl, fileinfo (XAMPP's PHP works — run it from the **F:** drive, its php.ini uses drive-relative paths)
- Composer, Node 18+
- Access to the database (on a dev PC: SSH tunnel on 127.0.0.1:33663)

## Run locally
```bash
# 1. database tunnel (uses the SSH settings in ../admin/.env)
cd ../admin && npm run tunnel          # keep running

# 2. this app
cd ../admin-laravel
composer install
npm install && npm run build
php artisan serve --host=0.0.0.0 --port=33665
```
Open http://localhost:33665 — sign in with an existing admin account (e.g. `george@merchant.test` / `admin123`).

## Configuration (`.env`)
- `DB_*` — the shared `restaurant_db` (dev: `127.0.0.1:33663` via tunnel; server: `3306`).
- `AUTH_SECRET` — **must equal** the Next admin's `AUTH_SECRET` so mobile JWTs are interchangeable.
- `RAZORPAY_*`, `STRIPE_*`, `PAYPAL_*`, `MAIL_*`, `WEBSITE_URL` — same values as `../admin/.env`.
- `HASH_VERIFY=false` — existing passwords are bcryptjs (`$2b$`) hashes; PHP verifies them fine but
  Laravel's strict algorithm check would reject them.
- Session/cache are file-based on purpose: **no Laravel tables are created in the shared database.**

## ⚠ Never run migrations
There are deliberately no migrations. The schema is owned by `../admin/prisma/schema.prisma`;
don't run `php artisan migrate` against `restaurant_db`.

## Structure
See [docs/PORTING.md](docs/PORTING.md) — models, services (`Queries`/`Actions` = ports of
`queries.ts`/`actions.ts`), routes, UI conventions.

## Switching the website / app to this backend
- Website: set `ADMIN_API_URL=http://127.0.0.1:33665` in `../website/.env.local`.
- Flutter app: Server address (tune icon) → `http://<pc-ip>:33665`.
