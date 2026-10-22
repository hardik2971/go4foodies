# Firestore schema (replaces MySQL `restaurant_db`)

One collection per MySQL table. **Document id = the original row id** (cuid strings), so every
reference (`outletId`, `tableId`, `sessionId`, …) still resolves. Field names are the same
camelCase column names.

| MySQL table | Collection | Notes |
|---|---|---|
| AuditLog | `auditLogs` | |
| Category | `categories` | `name` unique (enforced in functions) |
| Customer | `customers` | + `emailLower`; **no `password`** (see credentials) |
| DashboardConfig | `dashboardConfig/default` | single doc |
| Employee | `employees` | + `emailLower`; no `password` |
| GiftCard | `giftCards` | `code` unique |
| InventoryItem | `inventoryItems` | |
| MenuItem | `menuItems` | `categoryId` → categories |
| Order + OrderItem | `orders` | **OrderItems embedded** as `items: [{id, menuItemId, name, qty, price}]` |
| Outlet | `outlets` | `name` unique |
| OutletMetric | `outletMetrics` | |
| Payment | `payments` | `sessionId` → tableSessions |
| Reservation | `reservations` | `reference` unique |
| RestaurantProfile | `restaurantProfile/default` | single doc |
| Table | `tables` | `number`, `code` unique |
| TableSession | `tableSessions` | |
| User | `users` | admin web logins; no `password` |
| — | `credentials/{kind}_{id}` | `{kind: user\|employee\|customer, refId, email (lowercase), passwordHash (bcrypt)}` — **never readable by clients** |

## Types
- `datetime(3)` → Firestore `Timestamp` (UTC). API responses render them as JS ISO strings.
- `decimal` / `double` / `int` → number. `tinyint(1)` → boolean. `NULL` → `null` (fields are always present).
- Enums stay as the same strings (`PENDING`, `DINE_IN`, …).

## Relational rules applied in code (Firestore has no foreign keys)
| MySQL FK | Behaviour in functions |
|---|---|
| OrderItem.menuItemId RESTRICT | deleting an ordered menu item → 409 |
| MenuItem.categoryId RESTRICT | categories are never deleted |
| Order/Reservation/GiftCard/TableSession.customerId SET NULL | `deleteCustomer` nulls them |
| TableSession.waiterId SET NULL | `deleteStaff` nulls them |
| TableSession.tableId CASCADE (→ Payment CASCADE, Order.sessionId SET NULL), Order.tableId SET NULL | `deleteTable` |
| Unique keys | checked before insert (`uniqueOrderNumber`, table number, customer email, …) |

## Access
- All business reads/writes go through the `api` Cloud Function (Admin SDK, bypasses rules).
- The Flutter admin signs in with a Firebase custom token (uid `user:<id>`, claims `kind`, `refId`, `role`, `outletId`)
  and may **listen** (read-only) to `tables`, `tableSessions`, `orders`, `reservations` for live updates.
- Everything else is denied to clients by `firestore.rules`.

## Migration
`firebase/migration/migrate.mjs` reads the mysqldump and writes every row (idempotent; re-runnable).
