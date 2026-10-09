<?php

namespace App\Services;

use App\Models\AuditLog;
use App\Models\Category;
use App\Models\Customer;
use App\Models\DashboardConfig;
use App\Models\Employee;
use App\Models\GiftCard;
use App\Models\InventoryItem;
use App\Models\MenuItem;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Outlet;
use App\Models\Payment;
use App\Models\Reservation;
use App\Models\RestaurantProfile;
use App\Models\RestaurantTable;
use App\Models\TableSession;
use App\Models\User;
use App\Support\CurrentUser;
use App\Support\Format;
use App\Support\Iso;
use Carbon\Carbon;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use RuntimeException;

/**
 * Write operations — port of admin/src/lib/actions.ts ('use server' actions).
 * Every action authorizes with the same RBAC action as the TS (throws
 * ForbiddenException), validates with the ported zod schemas (throws
 * ValidationException) and keeps the same side effects: audit log entries,
 * session total recomputation, transactions and the completion emails.
 * Missing rows on update/delete throw ModelNotFoundException (Prisma P2025).
 */
final class Actions
{
    // Record an audit-trail entry. Never throws — logging must not break an action.
    private static function logAudit(string $action, string $entity, array $opts = []): void
    {
        try {
            $user = CurrentUser::get();
            AuditLog::query()->create([
                'action' => $action,
                'entity' => $entity,
                'entityId' => $opts['entityId'] ?? null,
                'detail' => $opts['detail'] ?? null,
                'userId' => $user['id'] ?? null,
                'userName' => $user['name'] ?? null,
            ]);
        } catch (\Throwable) {
            // ignore
        }
    }

    /** Prisma-style update: always writes and bumps @updatedAt, even if nothing changed. */
    private static function save(Model $m, array $data): Model
    {
        $m->fill($data);
        if ($m->usesTimestamps() && $m->getUpdatedAtColumn()) {
            $m->setUpdatedAt($m->freshTimestamp());
        }
        $m->save();

        return $m;
    }

    /** JS `v || null`. */
    private static function orNull(mixed $v): mixed
    {
        return ($v === null || $v === '' || $v === false || $v === 0 || $v === 0.0) ? null : $v;
    }

    /** `new Date(s)` → UTC Carbon: date-only strings are UTC midnight, date-times are server-local. */
    private static function jsDate(string $s): Carbon
    {
        return preg_match('/^\d{4}-\d{2}-\d{2}$/', $s)
            ? Carbon::parse($s.' 00:00:00', 'UTC')
            : Carbon::parse($s, Format::localTz())->utc();
    }

    /** bcryptjs-compatible hash (cost 10, "$2b$" prefix like the Node admin writes). */
    private static function hashPassword(string $plain): string
    {
        $h = password_hash($plain, PASSWORD_BCRYPT, ['cost' => 10]);

        return str_starts_with($h, '$2y$') ? '$2b$'.substr($h, 4) : $h;
    }

    // ---- Menu ----

    private static function categoryId(string $name): string
    {
        return Category::query()->firstOrCreate(['name' => $name])->id;
    }

    private static function menuData(array $data): array
    {
        $row = [
            'name' => $data['name'],
            'description' => $data['description'],
            'price' => $data['price'],
            'rating' => $data['rating'],
            'imageUrl' => $data['imageUrl'],
            'available' => $data['available'],
            'categoryId' => self::categoryId($data['category']),
        ];
        if (array_key_exists('tag', $data)) { // undefined tag leaves the column untouched
            $row['tag'] = $data['tag'];
        }

        return $row;
    }

    public static function createMenuItem(array $input): void
    {
        CurrentUser::authorize('manage:menu');
        $data = Validation::menuItem($input);
        MenuItem::query()->create(self::menuData($data));
    }

    public static function updateMenuItem(string $id, array $input): void
    {
        CurrentUser::authorize('manage:menu');
        $data = Validation::menuItem($input);
        self::save(MenuItem::query()->findOrFail($id), self::menuData($data));
    }

    public static function deleteMenuItem(string $id): void
    {
        CurrentUser::authorize('manage:menu');
        MenuItem::query()->findOrFail($id)->delete();
    }

    public static function setMenuAvailability(string $id, bool $available): void
    {
        CurrentUser::authorize('manage:menu');
        self::save(MenuItem::query()->findOrFail($id), ['available' => $available]);
    }

    // Enable/disable a whole category — disabled categories (and their items) are
    // hidden from the public storefront menu.
    public static function setCategoryActive(string $id, bool $active): void
    {
        CurrentUser::authorize('manage:menu');
        self::save(Category::query()->findOrFail($id), ['active' => $active]);
    }

    // ---- Floor plan / table sessions (POS Phase 1) ----

    /** @param array{customerCount:int|float, waiterId?:?string, customerName?:?string} $input */
    public static function openTableSession(string $tableId, array $input): void
    {
        CurrentUser::authorize('operate:floor');
        $existing = TableSession::query()->where('tableId', $tableId)->where('status', 'OPEN')->first();
        if ($existing) {
            return; // already occupied — no-op
        }
        $count = $input['customerCount'] ?? 0;
        DB::transaction(function () use ($tableId, $input, $count) {
            TableSession::query()->create([
                'tableId' => $tableId,
                'status' => 'OPEN',
                'openedAt' => Carbon::now('UTC'),
                'customerCount' => max(1, (int) $count),
                'waiterId' => self::orNull($input['waiterId'] ?? null),
                'customerName' => self::orNull($input['customerName'] ?? null),
            ]);
            self::save(RestaurantTable::query()->findOrFail($tableId), ['state' => 'OCCUPIED']);
        });
        self::logAudit('session.open', 'TableSession', ['entityId' => $tableId, 'detail' => (is_numeric($count) ? Format::js($count + 0) : (string) $count).' guests']);
    }

    // Recompute a session's subtotal from its orders and the total from the stored
    // discount / tax / service / tip adjustments.
    private static function recomputeSessionTotals(string $sessionId): void
    {
        $s = TableSession::query()->with('orders:id,sessionId,total')->find($sessionId);
        if (! $s) {
            return;
        }
        $subtotal = $s->orders->reduce(fn ($sum, $o) => $sum + (float) $o->total, 0);
        $total = $subtotal - (float) $s->discount + (float) $s->tax + (float) $s->serviceCharge + (float) $s->tip;
        self::save($s, ['subtotal' => $subtotal, 'total' => max(0, $total)]);
    }

    /**
     * Add items to an open table session (POS waiter entry) — creates a DINE_IN
     * POS order linked to the session, priced from the live menu.
     *
     * @param  array<array{menuItemId:string, qty:int}>  $items
     */
    public static function addSessionOrder(string $sessionId, array $items): void
    {
        CurrentUser::authorize('manage:orders');
        if (! count($items)) {
            return;
        }
        $session = TableSession::query()->with('table:id,number')->find($sessionId);
        if (! $session || $session->status === 'CLOSED') {
            throw new RuntimeException('Session is closed');
        }

        $ids = array_map(fn ($i) => $i['menuItemId'], $items);
        $byId = MenuItem::query()->whereIn('id', $ids)->get()->keyBy('id');
        $lines = array_map(function ($i) use ($byId) {
            $mi = $byId[$i['menuItemId']] ?? null;
            if (! $mi) {
                throw new RuntimeException('Item not found');
            }

            return ['menuItemId' => $mi->id, 'name' => $mi->name, 'qty' => (int) $i['qty'], 'price' => (float) $mi->price];
        }, $items);
        $total = array_reduce($lines, fn ($s, $l) => $s + $l['price'] * $l['qty'], 0);
        $outletId = Outlet::query()->value('id');

        DB::transaction(function () use ($session, $lines, $total, $outletId) {
            $order = Order::query()->create([
                'number' => 'ORD-'.random_int(10000, 99999),
                'type' => 'DINE_IN',
                'status' => 'PENDING',
                'channel' => 'POS',
                'scheduleType' => 'NOW',
                'total' => $total,
                'outletId' => $outletId ?? 'pos',
                'customerName' => $session->customerName ?? "Table {$session->table->number}",
                'tableId' => $session->tableId,
                'tableNumber' => $session->table->number,
                'sessionId' => $session->id,
            ]);
            foreach ($lines as $l) {
                OrderItem::query()->create(['orderId' => $order->id] + $l);
            }
        });
        self::recomputeSessionTotals($session->id);
        self::logAudit('order.add', 'Order', ['entityId' => $session->id, 'detail' => count($items).' item(s)']);
    }

    /** @param array{discount:float, tax:float, serviceCharge:float, tip:float} $b */
    public static function updateSessionBilling(string $sessionId, array $b): void
    {
        CurrentUser::authorize('manage:orders');
        self::save(TableSession::query()->findOrFail($sessionId), [
            'discount' => max(0, $b['discount'] ?? 0),
            'tax' => max(0, $b['tax'] ?? 0),
            'serviceCharge' => max(0, $b['serviceCharge'] ?? 0),
            'tip' => max(0, $b['tip'] ?? 0),
        ]);
        self::recomputeSessionTotals($sessionId);
    }

    // Remove one unit of an item from the session bill (void).
    public static function decrementSessionItem(string $sessionId, string $menuItemId): void
    {
        CurrentUser::authorize('manage:orders');
        $item = OrderItem::query()
            ->join('Order', 'Order.id', '=', 'OrderItem.orderId')
            ->where('OrderItem.menuItemId', $menuItemId)
            ->where('Order.sessionId', $sessionId)
            ->orderByDesc('Order.createdAt')
            ->select('OrderItem.*')
            ->first();
        if (! $item) {
            return;
        }
        if ($item->qty > 1) {
            $item->update(['qty' => $item->qty - 1]);
        } else {
            $item->delete();
        }
        $order = Order::query()->with('items')->find($item->orderId);
        if ($order) {
            if ($order->items->count() === 0) {
                $order->delete();
            } else {
                $total = $order->items->reduce(fn ($s, $it) => $s + (float) $it->price * (int) $it->qty, 0);
                self::save($order, ['total' => $total]);
            }
        }
        self::recomputeSessionTotals($sessionId);
        self::logAudit('order.void', 'Order', ['entityId' => $sessionId, 'detail' => 'Removed item']);
    }

    // Merge one open session's orders + payments into another, then free the source table.
    public static function mergeSessions(string $fromSessionId, string $intoSessionId): void
    {
        CurrentUser::authorize('manage:orders');
        if ($fromSessionId === $intoSessionId) {
            return;
        }
        $from = TableSession::query()->find($fromSessionId);
        $into = TableSession::query()->find($intoSessionId);
        if (! $from || ! $into || $from->status === 'CLOSED' || $into->status === 'CLOSED') {
            return;
        }
        Order::query()->where('sessionId', $fromSessionId)->update(['sessionId' => $intoSessionId]);
        Payment::query()->where('sessionId', $fromSessionId)->update(['sessionId' => $intoSessionId]);
        self::save($into, ['customerCount' => $into->customerCount + $from->customerCount]);
        self::save($from, ['status' => 'CLOSED', 'closedAt' => Carbon::now('UTC'), 'notes' => "Merged into table {$into->tableId}"]);
        self::save(RestaurantTable::query()->findOrFail($from->tableId), ['state' => 'CLEANING']);
        self::recomputeSessionTotals($intoSessionId);
        self::logAudit('session.merge', 'TableSession', ['entityId' => $intoSessionId, 'detail' => "Merged from {$from->tableId}"]);
    }

    /**
     * Record a partial payment against a session (split bills / mixed tender).
     *
     * @param  array{amount:float, method:string}  $input
     */
    public static function addPayment(string $sessionId, array $input): void
    {
        CurrentUser::authorize('manage:orders');
        $amount = $input['amount'] ?? null;
        if (! (is_numeric($amount) && $amount > 0)) {
            return;
        }
        Payment::query()->create(['sessionId' => $sessionId, 'amount' => $amount, 'method' => $input['method']]);
        self::logAudit('payment.add', 'Payment', ['entityId' => $sessionId, 'detail' => "{$input['method']} ".Format::js($amount + 0)]);
    }

    /** @param array{paymentMethod?:?string} $opts */
    public static function closeTableSession(string $sessionId, array $opts = []): void
    {
        CurrentUser::authorize('operate:floor');
        $s = TableSession::query()->with(['orders:id,sessionId,total', 'payments'])->find($sessionId);
        if (! $s || $s->status === 'CLOSED') {
            return;
        }
        $subtotal = $s->orders->reduce(fn ($sum, $o) => $sum + (float) $o->total, 0);
        $total = max(0, $subtotal - (float) $s->discount + (float) $s->tax + (float) $s->serviceCharge + (float) $s->tip);
        $paid = $s->payments->reduce(fn ($sum, $p) => $sum + (float) $p->amount, 0);
        $remaining = Format::round(($total - $paid) * 100) / 100;

        $methods = [];
        foreach ($s->payments as $p) {
            $methods[$p->method] = true; // Set: insertion-ordered, unique
        }
        $finalMethod = $opts['paymentMethod'] ?? 'Cash';
        if ($remaining > 0.001) {
            $methods[$finalMethod] = true;
        }
        $methods = array_map('strval', array_keys($methods));
        $method = count($methods) > 1 ? 'Mixed' : ($methods[0] ?? $opts['paymentMethod'] ?? null);

        DB::transaction(function () use ($s, $sessionId, $remaining, $finalMethod, $subtotal, $total, $method) {
            if ($remaining > 0.001) {
                Payment::query()->create(['sessionId' => $sessionId, 'amount' => $remaining, 'method' => $finalMethod]);
            }
            self::save($s, [
                'status' => 'CLOSED',
                'closedAt' => Carbon::now('UTC'),
                'subtotal' => $subtotal,
                'total' => $total,
                'paymentStatus' => 'PAID',
                'paymentMethod' => $method,
            ]);
            self::save(RestaurantTable::query()->findOrFail($s->tableId), ['state' => 'CLEANING']);
        });
        self::logAudit('session.close', 'TableSession', ['entityId' => $sessionId, 'detail' => ($method ?? '').' · total '.Format::js($total)]);
    }

    /** @param string $state AVAILABLE|RESERVED|OCCUPIED|WAITING_PAYMENT|CLEANING|OUT_OF_SERVICE */
    public static function setTableState(string $tableId, string $state): void
    {
        CurrentUser::authorize('operate:floor');
        self::save(RestaurantTable::query()->findOrFail($tableId), ['state' => $state]);
        self::logAudit('table.state', 'Table', ['entityId' => $tableId, 'detail' => $state]);
    }

    // ---- Dashboard widget overrides (editable Trending / Top Categories) ----

    private static function dashboardConfig(): DashboardConfig
    {
        return DashboardConfig::query()->find('default') ?? new DashboardConfig(['id' => 'default']);
    }

    public static function setTrendingItem(?string $itemId): void
    {
        CurrentUser::authorize('manage:menu');
        self::save(self::dashboardConfig(), ['trendingItemId' => $itemId]);
    }

    /** @param array<array{name:string, percent:int|float}>|null $categories */
    public static function setTopCategories(?array $categories): void
    {
        CurrentUser::authorize('manage:menu');
        $json = $categories ? json_encode(array_slice(array_values($categories), 0, 3), JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE) : null;
        self::save(self::dashboardConfig(), ['topCategories' => $json]);
    }

    // ---- Orders ----

    /** @param string $status PENDING|PREPARING|READY|COMPLETED|CANCELED */
    public static function setOrderStatus(string $id, string $status): void
    {
        CurrentUser::authorize('manage:orders');
        $order = self::save(Order::query()->findOrFail($id), ['status' => $status]);
        $order->load('items');

        // On completion, send the customer a branded thank-you email (online orders
        // capture an email). Never let a mail failure block the status update.
        if ($status === 'COMPLETED' && $order->customerEmail) {
            try {
                $mail = EmailTemplates::orderCompletedEmail([
                    'number' => $order->number,
                    'customerName' => $order->customerName,
                    'items' => $order->items->map(fn ($it) => ['name' => $it->name, 'qty' => (int) $it->qty, 'price' => (float) $it->price])->all(),
                    'total' => (float) $order->total,
                ]);
                Mailer::send($order->customerEmail, $mail);
            } catch (\Throwable $mailErr) {
                Log::error('Order completion email failed (status still updated): '.$mailErr->getMessage());
            }
        }
    }

    // ---- Reservations ----

    /** @param string $status REQUESTED|CONFIRMED|SEATED|COMPLETED|CANCELED|NO_SHOW */
    public static function setReservationStatus(string $id, string $status): void
    {
        CurrentUser::authorize('manage:reservations');
        $r = self::save(Reservation::query()->findOrFail($id), ['status' => $status]);

        // On completion, thank the guest with a branded email. Never let a mail
        // failure block the status update.
        if ($status === 'COMPLETED' && $r->email) {
            try {
                $mail = EmailTemplates::reservationCompletedEmail([
                    'reference' => $r->reference,
                    'name' => $r->name,
                    'kind' => $r->kind,
                ]);
                Mailer::send($r->email, $mail);
            } catch (\Throwable $mailErr) {
                Log::error('Reservation completion email failed (status still updated): '.$mailErr->getMessage());
            }
        }
    }

    /** @param array{date?:string, time?:?string, guests?:?int, occasion?:?string, requests?:?string} $input date = "YYYY-MM-DD" */
    public static function updateReservation(string $id, array $input): void
    {
        CurrentUser::authorize('manage:reservations');
        $data = [];
        if (! empty($input['date'])) {
            $data['date'] = self::jsDate($input['date']);
        }
        foreach (['time', 'guests', 'occasion', 'requests'] as $k) {
            if (array_key_exists($k, $input)) {
                $data[$k] = $input[$k];
            }
        }
        self::save(Reservation::query()->findOrFail($id), $data);
    }

    // ---- Staff ----

    /** @param string $status ON_DUTY|ON_BREAK|ABSENT|OFF */
    public static function setEmployeeStatus(string $id, string $status): void
    {
        CurrentUser::authorize('manage:staff');
        self::save(Employee::query()->findOrFail($id), ['status' => $status]);
    }

    public static function createStaff(array $input): void
    {
        CurrentUser::authorize('manage:staff');
        $data = Validation::staff($input);
        $outletId = Outlet::query()->value('id');
        Employee::query()->create([
            'name' => $data['name'],
            'role' => $data['role'],
            'email' => $data['email'],
            'phone' => self::orNull($data['phone'] ?? null),
            'active' => $data['active'],
            'password' => ! empty($data['password']) ? self::hashPassword($data['password']) : null,
            'outletId' => $outletId ?? 'default',
        ]);
    }

    public static function updateStaff(string $id, array $input): void
    {
        CurrentUser::authorize('manage:staff');
        $data = Validation::staff($input);
        $row = [
            'name' => $data['name'],
            'role' => $data['role'],
            'email' => $data['email'],
            'phone' => self::orNull($data['phone'] ?? null),
            'active' => $data['active'],
        ];
        // Empty password on edit keeps the existing one.
        if (! empty($data['password'])) {
            $row['password'] = self::hashPassword($data['password']);
        }
        self::save(Employee::query()->findOrFail($id), $row);
    }

    public static function setStaffActive(string $id, bool $active): void
    {
        CurrentUser::authorize('manage:staff');
        self::save(Employee::query()->findOrFail($id), ['active' => $active]);
    }

    public static function deleteStaff(string $id): void
    {
        CurrentUser::authorize('manage:staff');
        Employee::query()->findOrFail($id)->delete();
    }

    // ---- Tables (QR ordering) ----

    /** @return array{id:string, number:string, name?:string, code:string, status:string, orderCount:int, createdAt:string} */
    public static function createTable(array $input): array
    {
        CurrentUser::authorize('manage:tables');
        $data = Validation::table($input);
        $t = RestaurantTable::query()->create([
            'number' => $data['number'],
            'name' => self::orNull($data['name'] ?? null),
            'status' => $data['status'],
        ]);

        return array_filter([
            'id' => $t->id,
            'number' => $t->number,
            'name' => $t->name,
            'code' => $t->code,
            'status' => $t->status,
            'orderCount' => 0,
            'createdAt' => Iso::of($t->createdAt),
        ], fn ($v) => $v !== null);
    }

    public static function updateTable(string $id, array $input): void
    {
        CurrentUser::authorize('manage:tables');
        $data = Validation::table($input);
        self::save(RestaurantTable::query()->findOrFail($id), [
            'number' => $data['number'],
            'name' => self::orNull($data['name'] ?? null),
            'status' => $data['status'],
        ]);
    }

    /** @param string $status ACTIVE|INACTIVE */
    public static function setTableStatus(string $id, string $status): void
    {
        CurrentUser::authorize('manage:tables');
        self::save(RestaurantTable::query()->findOrFail($id), ['status' => $status]);
    }

    public static function deleteTable(string $id): void
    {
        CurrentUser::authorize('manage:tables');
        RestaurantTable::query()->findOrFail($id)->delete();
    }

    // ---- Gift cards & coupons ----

    public static function updateGiftCard(string $id, array $input): void
    {
        CurrentUser::authorize('manage:coupons');
        $data = Validation::giftCardEdit($input);
        self::save(GiftCard::query()->findOrFail($id), [
            'customerName' => $data['customerName'],
            'customerEmail' => self::orNull($data['customerEmail'] ?? null) ?? '',
            'kind' => $data['kind'],
            'amount' => $data['amount'],
            'status' => $data['status'],
            'paymentStatus' => $data['paymentStatus'],
            'expiryDate' => ! empty($data['expiryDate']) ? self::jsDate($data['expiryDate']) : null,
        ]);
    }

    /** @param string $status PENDING_PAYMENT|PAID|ACTIVE|REDEEMED|EXPIRED|CANCELLED */
    public static function setGiftCardStatus(string $id, string $status): void
    {
        CurrentUser::authorize('manage:coupons');
        $g = self::save(GiftCard::query()->findOrFail($id), ['status' => $status]);

        // On redemption, thank the customer with a branded email. Never let a mail
        // failure block the status update.
        if ($status === 'REDEEMED' && $g->customerEmail) {
            try {
                $mail = EmailTemplates::giftCardRedeemedEmail([
                    'code' => $g->code,
                    'kind' => $g->kind,
                    'amount' => (float) $g->amount,
                    'name' => $g->customerName,
                ]);
                Mailer::send($g->customerEmail, $mail);
            } catch (\Throwable $mailErr) {
                Log::error('Gift card redeemed email failed (status still updated): '.$mailErr->getMessage());
            }
        }
    }

    public static function deleteGiftCard(string $id): void
    {
        CurrentUser::authorize('manage:coupons');
        GiftCard::query()->findOrFail($id)->delete();
    }

    // ---- Customers ----

    private static function customerData(array $data): array
    {
        return [
            'name' => $data['name'],
            'email' => $data['email'],
            'phone' => self::orNull($data['phone'] ?? null),
            'address' => self::orNull($data['address'] ?? null),
            'status' => $data['status'],
        ];
    }

    public static function createCustomer(array $input): void
    {
        CurrentUser::authorize('manage:customers');
        $data = Validation::customer($input);
        Customer::query()->create(self::customerData($data));
    }

    public static function updateCustomer(string $id, array $input): void
    {
        CurrentUser::authorize('manage:customers');
        $data = Validation::customer($input);
        self::save(Customer::query()->findOrFail($id), self::customerData($data));
    }

    public static function deleteCustomer(string $id): void
    {
        CurrentUser::authorize('manage:customers');
        Customer::query()->findOrFail($id)->delete();
    }

    // ---- Inventory ----

    public static function createInventoryItem(array $input): void
    {
        CurrentUser::authorize('manage:inventory');
        $data = Validation::inventoryItem($input);
        InventoryItem::query()->create($data);
    }

    public static function updateInventoryItem(string $id, array $input): void
    {
        CurrentUser::authorize('manage:inventory');
        $data = Validation::inventoryItem($input);
        self::save(InventoryItem::query()->findOrFail($id), $data);
    }

    public static function adjustInventory(string $id, float $delta): void
    {
        CurrentUser::authorize('manage:inventory');
        $item = InventoryItem::query()->find($id);
        if (! $item) {
            return;
        }
        self::save($item, ['quantity' => max(0, (float) $item->quantity + $delta)]);
    }

    public static function deleteInventoryItem(string $id): void
    {
        CurrentUser::authorize('manage:inventory');
        InventoryItem::query()->findOrFail($id)->delete();
    }

    // ---- Settings ----

    public static function updateProfile(array $input): void
    {
        CurrentUser::authorize('manage:settings');
        $data = Validation::profile($input);
        $p = RestaurantProfile::query()->find('default') ?? new RestaurantProfile(['id' => 'default']);
        self::save($p, $data);
    }

    /** @return array{ok:bool, error?:string} */
    public static function changePassword(array $input): array
    {
        $sessionUser = CurrentUser::get();
        if (! $sessionUser || $sessionUser['kind'] !== 'user') {
            return ['ok' => false, 'error' => 'Unauthorized'];
        }
        $data = Validation::password($input);
        $user = User::query()->find($sessionUser['id']);
        if (! $user) {
            return ['ok' => false, 'error' => 'User not found'];
        }
        if (! password_verify($data['currentPassword'], (string) $user->password)) {
            return ['ok' => false, 'error' => 'Current password is incorrect'];
        }
        self::save($user, ['password' => self::hashPassword($data['newPassword'])]);

        return ['ok' => true];
    }
}
