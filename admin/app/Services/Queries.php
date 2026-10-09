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
use App\Support\Format;
use App\Support\Iso;
use Carbon\Carbon;
use Collator;

/**
 * Server-side data access — port of admin/src/lib/queries.ts. Maps rows to the
 * exact view shapes (TS interfaces) the web admin and the mobile API return:
 * same keys and nesting, numbers as numbers, optional (`?:`) fields omitted
 * when absent, dates as JS ISO strings.
 *
 * "Server local time" (startOfToday, getHours(), toLocaleTimeString()) uses
 * Format::localTz() — the app timezone (UTC) unless config('app.local_timezone') is set.
 */
final class Queries
{
    /** TYPE_LABELS from orders-data.ts. */
    public const TYPE_LABELS = ['DINE_IN' => 'Dine-in', 'DELIVERY' => 'Delivery', 'PICKUP' => 'Pick-up'];

    private const OPEN_HOUR = 10;

    private const CLOSE_HOUR = 22;

    private const OCCUPIED_TOO_LONG_MIN = 120;

    private const LARGE_BILL_THRESHOLD = 300;

    /** Drop null entries — mirrors `x ?? undefined` (JSON.stringify omits undefined). */
    private static function def(array $row): array
    {
        return array_filter($row, fn ($v) => $v !== null);
    }

    /** "YYYY-MM-DD HH:MM:SS.mmm" UTC bound for a DB datetime comparison (Prisma sends UTC). */
    private static function dbTime(Carbon $d): string
    {
        return $d->copy()->utc()->format('Y-m-d H:i:s.v');
    }

    /**
     * `arr.sort((a, b) => (a[key] < b[key] ? 1 : -1))` exactly as V8 runs it:
     * descending, and — because that comparator never returns 0 — ties end up
     * in reverse input order.
     */
    private static function sortDescByKey(array $items, string $key): array
    {
        $items = array_reverse($items);
        usort($items, fn ($a, $b) => strcmp($b[$key], $a[$key]));

        return $items;
    }

    /** startOfToday - (days - 1) days, in server-local time (queries.ts rangeStart). */
    private static function rangeStart(Carbon $now, int $days): Carbon
    {
        $startOfToday = $now->copy()->startOfDay();

        return $startOfToday->copy()->subMilliseconds(($days - 1) * 86_400_000);
    }

    /** @return array<string,string> outlet id → name */
    private static function outletNameMap(): array
    {
        return Outlet::query()->pluck('name', 'id')->all();
    }

    public static function getInventory(): array
    {
        return InventoryItem::query()->orderBy('name')->get()->map(fn (InventoryItem $r) => [
            'id' => $r->id,
            'name' => $r->name,
            'category' => $r->category,
            'unit' => $r->unit,
            'quantity' => (float) $r->quantity,
            'reorderLevel' => (float) $r->reorderLevel,
            'costPerUnit' => (float) $r->costPerUnit,
            'supplier' => $r->supplier ?? '',
        ])->all();
    }

    public static function getMenuItems(): array
    {
        return MenuItem::query()->with('category')->orderBy('name')->get()->map(fn (MenuItem $r) => [
            'id' => $r->id,
            'name' => $r->name,
            'description' => $r->description,
            'price' => (float) $r->price,
            'rating' => (float) $r->rating,
            'tag' => $r->tag ?? '',
            'category' => $r->category->name,
            'imageUrl' => $r->imageUrl,
            'available' => (bool) $r->available,
        ])->all();
    }

    /** @return array{trendingItemId:?string, topCategories:?array} */
    public static function getDashboardConfig(): array
    {
        $c = DashboardConfig::query()->find('default');
        $topCategories = null;
        if ($c && $c->topCategories !== null && $c->topCategories !== '') {
            $parsed = json_decode($c->topCategories, true);
            $topCategories = json_last_error() === JSON_ERROR_NONE ? $parsed : null;
        }

        return ['trendingItemId' => $c?->trendingItemId, 'topCategories' => $topCategories];
    }

    public static function getMenuCategories(): array
    {
        return Category::query()->withCount('items')->orderBy('name')->get()->map(fn (Category $c) => [
            'id' => $c->id,
            'name' => $c->name,
            'active' => (bool) $c->active,
            'itemCount' => (int) $c->items_count,
        ])->all();
    }

    public static function getOrders(): array
    {
        $names = self::outletNameMap();

        return Order::query()->with('items')->orderByDesc('createdAt')->get()->map(fn (Order $o) => self::def([
            'id' => $o->id,
            'number' => $o->number,
            'type' => $o->type,
            'status' => $o->status,
            'channel' => $o->channel,
            'paymentMethod' => $o->paymentMethod ?? 'CASH',
            'outlet' => $names[$o->outletId] ?? $o->outletId,
            'customer' => $o->customerName,
            'customerEmail' => $o->customerEmail,
            'customerPhone' => $o->customerPhone,
            'items' => self::lines($o->items),
            'total' => (float) $o->total,
            'scheduleType' => $o->scheduleType,
            'scheduleDate' => $o->scheduleDate ? Iso::of($o->scheduleDate) : null,
            'scheduleTime' => $o->scheduleTime,
            'notes' => $o->notes,
            'tableNumber' => $o->tableNumber,
            'paymentProvider' => $o->paymentProvider,
            'razorpayPaymentId' => $o->razorpayPaymentId,
            'createdAt' => Iso::of($o->createdAt),
        ]))->all();
    }

    /** OrderItems → [{name, qty, price}]. */
    private static function lines(iterable $items): array
    {
        $out = [];
        foreach ($items as $it) {
            $out[] = ['name' => $it->name, 'qty' => (int) $it->qty, 'price' => (float) $it->price];
        }

        return $out;
    }

    public static function getTables(): array
    {
        return RestaurantTable::query()->withCount('orders')->orderBy('number')->get()->map(fn (RestaurantTable $t) => self::def([
            'id' => $t->id,
            'number' => $t->number,
            'name' => $t->name,
            'code' => $t->code,
            'status' => $t->status,
            'orderCount' => (int) $t->orders_count,
            'createdAt' => Iso::of($t->createdAt),
        ]))->all();
    }

    public static function getGiftCards(): array
    {
        return GiftCard::query()->orderByDesc('createdAt')->get()->map(fn (GiftCard $g) => self::def([
            'id' => $g->id,
            'code' => $g->code,
            'kind' => $g->kind,
            'customerName' => $g->customerName,
            'customerEmail' => $g->customerEmail,
            'amount' => (float) $g->amount,
            'message' => $g->message,
            'expiryDate' => $g->expiryDate ? Iso::date($g->expiryDate) : null,
            'paymentStatus' => $g->paymentStatus,
            'status' => $g->status,
            'paymentProvider' => $g->paymentProvider,
            'razorpayPaymentId' => $g->razorpayPaymentId,
            'createdAt' => Iso::of($g->createdAt),
        ]))->all();
    }

    // ---- Floor plan / table sessions (POS Phase 1) ----

    public static function getFloorTables(): array
    {
        $tables = RestaurantTable::query()->orderBy('number')->get();
        // Latest OPEN session per table (Prisma: sessions where OPEN, orderBy openedAt desc, take 1).
        $open = TableSession::query()
            ->where('status', 'OPEN')
            ->whereIn('tableId', $tables->pluck('id'))
            ->with(['waiter:id,name', 'orders:id,sessionId,total'])
            ->orderByDesc('openedAt')
            ->get();
        $latest = [];
        foreach ($open as $s) {
            $latest[$s->tableId] ??= $s;
        }

        return $tables->map(function (RestaurantTable $t) use ($latest) {
            $s = $latest[$t->id] ?? null;
            $row = self::def([
                'id' => $t->id,
                'number' => $t->number,
                'name' => $t->name,
                'capacity' => (int) $t->capacity,
                'status' => $t->status,
                'state' => $t->state,
            ]);
            $row['session'] = $s ? self::def([
                'id' => $s->id,
                'openedAt' => Iso::of($s->openedAt),
                'customerCount' => (int) $s->customerCount,
                'customerName' => $s->customerName,
                'waiterName' => $s->waiter?->name,
                'currentBill' => $s->orders->reduce(fn ($sum, $o) => $sum + (float) $o->total, 0),
                'orderCount' => $s->orders->count(),
            ]) : null;

            return $row;
        })->all();
    }

    public static function getTablePos(string $tableId): array
    {
        $table = RestaurantTable::query()->find($tableId);
        if (! $table) {
            return ['table' => null, 'session' => null];
        }

        $s = TableSession::query()
            ->where('tableId', $tableId)
            ->where('status', 'OPEN')
            ->with([
                'waiter:id,name',
                'orders' => fn ($q) => $q->orderBy('createdAt'),
                'orders.items',
                'payments' => fn ($q) => $q->orderBy('createdAt'),
            ])
            ->first();

        $posTable = self::def([
            'id' => $table->id,
            'number' => $table->number,
            'name' => $table->name,
            'capacity' => (int) $table->capacity,
            'state' => $table->state,
        ]);

        if (! $s) {
            return ['table' => $posTable, 'session' => null];
        }

        // Aggregate identical items (by menu item) across all session orders.
        $byItem = [];
        foreach ($s->orders as $o) {
            foreach ($o->items as $it) {
                if (isset($byItem[$it->menuItemId])) {
                    $byItem[$it->menuItemId]['qty'] += (int) $it->qty;
                } else {
                    $byItem[$it->menuItemId] = ['menuItemId' => $it->menuItemId, 'name' => $it->name, 'qty' => (int) $it->qty, 'price' => (float) $it->price];
                }
            }
        }

        $payments = $s->payments->map(fn (Payment $p) => [
            'amount' => (float) $p->amount,
            'method' => $p->method,
            'createdAt' => Iso::of($p->createdAt),
        ])->all();
        $paid = array_reduce($payments, fn ($sum, $p) => $sum + $p['amount'], 0);
        $total = (float) $s->total;

        return [
            'table' => $posTable,
            'session' => self::def([
                'id' => $s->id,
                'openedAt' => Iso::of($s->openedAt),
                'customerCount' => (int) $s->customerCount,
                'customerName' => $s->customerName,
                'waiterName' => $s->waiter?->name,
                'lines' => array_values($byItem),
                'orders' => $s->orders->map(fn (Order $o) => [
                    'id' => $o->id,
                    'number' => $o->number,
                    'createdAt' => Iso::of($o->createdAt),
                    'items' => self::lines($o->items),
                ])->all(),
                'subtotal' => (float) $s->subtotal,
                'discount' => (float) $s->discount,
                'tax' => (float) $s->tax,
                'serviceCharge' => (float) $s->serviceCharge,
                'tip' => (float) $s->tip,
                'total' => $total,
                'payments' => $payments,
                'paid' => $paid,
                'remaining' => max(0, $total - $paid),
            ]),
        ];
    }

    // ---- Table analytics (POS Phase 4) ----

    public static function getTableAnalytics(int $days = 1): array
    {
        $now = Format::now();
        $nowMs = Format::ms($now);
        $rangeStart = self::dbTime(self::rangeStart($now, $days));

        $tables = RestaurantTable::query()->get(['id', 'number', 'name', 'capacity', 'state']);
        $sessions = TableSession::query()->where('openedAt', '>=', $rangeStart)->withCount('orders')->get();
        $orderItems = OrderItem::query()
            ->whereHas('order.session', fn ($q) => $q->where('openedAt', '>=', $rangeStart))
            ->get(['name', 'qty']);
        $payments = Payment::query()
            ->whereHas('session', fn ($q) => $q->where('openedAt', '>=', $rangeStart))
            ->get(['method']);

        // Live state counts
        $live = ['total' => $tables->count(), 'available' => 0, 'occupied' => 0, 'reserved' => 0, 'cleaning' => 0, 'outOfService' => 0];
        foreach ($tables as $t) {
            match ($t->state) {
                'AVAILABLE' => $live['available']++,
                'OCCUPIED' => $live['occupied']++,
                'RESERVED' => $live['reserved']++,
                'CLEANING' => $live['cleaning']++,
                'OUT_OF_SERVICE' => $live['outOfService']++,
                default => null,
            };
        }

        $durationMin = fn (TableSession $s) => max(0, (($s->closedAt ? Format::ms($s->closedAt) : $nowMs) - Format::ms($s->openedAt)) / 60000);

        // Per-table aggregation
        $tableById = $tables->keyBy('id');
        $agg = [];
        foreach ($sessions as $s) {
            $cur = $agg[$s->tableId] ?? ['sessions' => 0, 'customers' => 0, 'orders' => 0, 'revenue' => 0, 'occupiedMin' => 0, 'seatRatioSum' => 0];
            $cap = $tableById[$s->tableId]->capacity ?? 4;
            $cur['sessions'] += 1;
            $cur['customers'] += (int) $s->customerCount;
            $cur['orders'] += (int) $s->orders_count;
            $cur['revenue'] += (float) $s->total;
            $cur['occupiedMin'] += $durationMin($s);
            $cur['seatRatioSum'] += min(1, $s->customerCount / max(1, $cap));
            $agg[$s->tableId] = $cur;
        }

        $operatingMin = (self::CLOSE_HOUR - self::OPEN_HOUR) * 60 * $days;
        $perTable = $tables->map(function (RestaurantTable $t) use ($agg, $operatingMin) {
            $a = $agg[$t->id] ?? null;
            $n = $a['sessions'] ?? 0;
            $revenue = $a['revenue'] ?? 0;

            return self::def([
                'id' => $t->id,
                'number' => $t->number,
                'name' => $t->name,
                'sessions' => $n,
                'customers' => $a['customers'] ?? 0,
                'orders' => $a['orders'] ?? 0,
                'revenue' => $revenue,
                'avgBill' => $n ? Format::round($revenue / $n) : 0,
                'avgDiningMinutes' => $n ? Format::round($a['occupiedMin'] / $n) : 0,
                'occupiedMinutes' => Format::round($a['occupiedMin'] ?? 0),
                'occupancyPct' => min(100, Format::round((($a['occupiedMin'] ?? 0) / $operatingMin) * 100)),
                'utilizationPct' => $n ? Format::round(($a['seatRatioSum'] / $n) * 100) : 0,
            ]);
        })->all();

        // Summary
        $totalSessions = $sessions->count();
        $customers = $sessions->reduce(fn ($s, $x) => $s + (int) $x->customerCount, 0);
        $orders = $sessions->reduce(fn ($s, $x) => $s + (int) $x->orders_count, 0);
        $revenue = $sessions->reduce(fn ($s, $x) => $s + (float) $x->total, 0);
        $diningTotal = $sessions->reduce(fn ($s, $x) => $s + $durationMin($x), 0);
        $summary = [
            'sessions' => $totalSessions,
            'customers' => $customers,
            'orders' => $orders,
            'revenue' => $revenue,
            'avgBill' => $totalSessions ? Format::round($revenue / $totalSessions) : 0,
            'avgCustomersPerTable' => $totalSessions ? Format::round(($customers / $totalSessions) * 10) / 10 : 0,
            'avgDiningMinutes' => $totalSessions ? Format::round($diningTotal / $totalSessions) : 0,
        ];

        // Rankings
        $withSessions = array_values(array_filter($perTable, fn ($t) => $t['sessions'] > 0));
        $pick = function (array $arr, callable $key, callable $fmt, bool $max = true): ?array {
            if (! $arr) {
                return null;
            }
            $best = $arr[0];
            foreach (array_slice($arr, 1) as $t) {
                if ($max ? $key($t) > $key($best) : $key($t) < $key($best)) {
                    $best = $t;
                }
            }

            return ['number' => $best['number'], 'value' => $fmt($best)];
        };
        $money = fn ($n) => '$'.Format::locale($n);
        $top = [
            'highestRevenue' => $pick($withSessions, fn ($t) => $t['revenue'], fn ($t) => $money($t['revenue'])),
            'mostUsed' => $pick($withSessions, fn ($t) => $t['sessions'], fn ($t) => "{$t['sessions']} sessions"),
            'mostCustomers' => $pick($withSessions, fn ($t) => $t['customers'], fn ($t) => "{$t['customers']} guests"),
            'highestAvgBill' => $pick($withSessions, fn ($t) => $t['avgBill'], fn ($t) => $money($t['avgBill'])),
            'longestOccupied' => $pick($withSessions, fn ($t) => $t['occupiedMinutes'], fn ($t) => "{$t['occupiedMinutes']} min"),
            'fastestTurnover' => $pick($withSessions, fn ($t) => $t['avgDiningMinutes'], fn ($t) => "{$t['avgDiningMinutes']} min", false),
        ];
        $least = [
            'leastUsed' => $pick($perTable, fn ($t) => $t['sessions'], fn ($t) => "{$t['sessions']} sessions", false),
            'lowestRevenue' => $pick($perTable, fn ($t) => $t['revenue'], fn ($t) => $money($t['revenue']), false),
            'lowestOccupancy' => $pick($perTable, fn ($t) => $t['occupancyPct'], fn ($t) => "{$t['occupancyPct']}%", false),
        ];

        // Busy hours + peak day (server-local hour / weekday)
        $hourCounts = array_fill(0, 24, 0);
        $dayCounts = array_fill(0, 7, 0);
        foreach ($sessions as $s) {
            $local = Format::local($s->openedAt);
            $hourCounts[$local->hour]++;
            $dayCounts[$local->dayOfWeek]++;
        }
        $busyHours = [];
        for ($h = self::OPEN_HOUR; $h < self::CLOSE_HOUR; $h++) {
            $period = $h < 12 ? 'AM' : 'PM';
            $busyHours[] = ['hour' => $h, 'label' => ($h % 12 ?: 12).$period, 'sessions' => $hourCounts[$h]];
        }
        $peakH = self::OPEN_HOUR;
        for ($h = 0; $h < 24; $h++) {
            if ($hourCounts[$h] > $hourCounts[$peakH]) {
                $peakH = $h;
            }
        }
        $DAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
        $peakD = 0;
        for ($d = 0; $d < 7; $d++) {
            if ($dayCounts[$d] > $dayCounts[$peakD]) {
                $peakD = $d;
            }
        }
        $peakHour = $totalSessions ? ($peakH % 12 ?: 12).':00 '.($peakH < 12 ? 'AM' : 'PM') : '—';
        $peakDay = $totalSessions ? $DAYS[$peakD] : '—';

        // Customer analytics
        $itemQty = [];
        foreach ($orderItems as $it) {
            $itemQty[$it->name] = ($itemQty[$it->name] ?? 0) + (int) $it->qty;
        }
        $favouriteItems = [];
        foreach ($itemQty as $name => $qty) {
            $favouriteItems[] = ['name' => (string) $name, 'qty' => $qty];
        }
        usort($favouriteItems, fn ($a, $b) => $b['qty'] <=> $a['qty']);
        $favouriteItems = array_slice($favouriteItems, 0, 5);

        $methodCount = [];
        foreach ($payments as $p) {
            $methodCount[$p->method] = ($methodCount[$p->method] ?? 0) + 1;
        }
        $paymentMix = [];
        foreach ($methodCount as $method => $count) {
            $paymentMix[] = ['method' => (string) $method, 'count' => $count];
        }
        usort($paymentMix, fn ($a, $b) => $b['count'] <=> $a['count']);

        $customer = [
            'served' => $customers,
            'avgSpend' => $customers ? Format::round($revenue / $customers) : 0,
            'favouriteItems' => $favouriteItems,
            'paymentMix' => $paymentMix,
        ];

        return [
            'days' => $days,
            'live' => $live,
            'summary' => $summary,
            'perTable' => $perTable,
            'top' => $top,
            'least' => $least,
            'busyHours' => $busyHours,
            'peakHour' => $peakHour,
            'peakDay' => $peakDay,
            'customer' => $customer,
        ];
    }

    public static function getTableHistory(string $tableId, int $days = 30): array
    {
        $table = RestaurantTable::query()->find($tableId, ['id', 'number', 'name']);
        if (! $table) {
            return ['table' => null, 'sessions' => []];
        }

        $now = Format::now();
        $nowMs = Format::ms($now);
        $rangeStart = self::dbTime(self::rangeStart($now, $days));

        $rows = TableSession::query()
            ->where('tableId', $tableId)
            ->where('openedAt', '>=', $rangeStart)
            ->orderByDesc('openedAt')
            ->with(['waiter:id,name', 'orders.items'])
            ->get();

        $sessions = $rows->map(function (TableSession $s) use ($nowMs) {
            $byName = [];
            foreach ($s->orders as $o) {
                foreach ($o->items as $it) {
                    if (isset($byName[$it->name])) {
                        $byName[$it->name]['qty'] += (int) $it->qty;
                    } else {
                        $byName[$it->name] = ['name' => $it->name, 'qty' => (int) $it->qty, 'price' => (float) $it->price];
                    }
                }
            }
            $end = $s->closedAt ? Format::ms($s->closedAt) : $nowMs;

            return self::def([
                'id' => $s->id,
                'openedAt' => Iso::of($s->openedAt),
                'closedAt' => $s->closedAt ? Iso::of($s->closedAt) : null,
                'durationMinutes' => max(0, Format::round(($end - Format::ms($s->openedAt)) / 60000)),
                'customerCount' => (int) $s->customerCount,
                'customerName' => $s->customerName,
                'waiterName' => $s->waiter?->name,
                'items' => array_values($byName),
                'subtotal' => (float) $s->subtotal,
                'discount' => (float) $s->discount,
                'tax' => (float) $s->tax,
                'serviceCharge' => (float) $s->serviceCharge,
                'tip' => (float) $s->tip,
                'total' => (float) $s->total,
                'paymentMethod' => $s->paymentMethod,
                'status' => $s->status,
            ]);
        })->all();

        return ['table' => self::def(['id' => $table->id, 'number' => $table->number, 'name' => $table->name]), 'sessions' => $sessions];
    }

    public static function getMergeTargets(string $excludeTableId): array
    {
        return TableSession::query()
            ->join('Table', 'Table.id', '=', 'TableSession.tableId')
            ->where('TableSession.status', 'OPEN')
            ->where('TableSession.tableId', '!=', $excludeTableId)
            ->orderBy('Table.number')
            ->get(['TableSession.id as sessionId', 'TableSession.tableId as tableId', 'Table.number as number'])
            ->map(fn ($s) => ['tableId' => $s->tableId, 'sessionId' => $s->sessionId, 'number' => $s->number])
            ->all();
    }

    public static function getWaiterOptions(): array
    {
        return Employee::query()->where('active', true)->orderBy('name')->get(['id', 'name'])
            ->map(fn (Employee $e) => ['id' => $e->id, 'name' => $e->name])->all();
    }

    /** Unified payments feed: paid orders, gift-card purchases, and POS session payments. */
    public static function getTransactions(): array
    {
        $orders = Order::query()->whereNotNull('paymentMethod')->orderByDesc('createdAt')->take(250)->get();
        $gifts = GiftCard::query()->where('paymentStatus', 'PAID')->orderByDesc('createdAt')->take(250)->get();
        $payments = Payment::query()->with('session.table:id,number')->orderByDesc('createdAt')->take(250)->get();

        $gatewayLabel = fn (?string $p) => match ($p) {
            'razorpay' => 'Razorpay',
            'stripe' => 'Stripe',
            'paypal' => 'PayPal',
            default => null,
        };

        $txns = [];
        foreach ($orders as $o) {
            $txns[] = self::def([
                'id' => "o-{$o->id}",
                'source' => 'Order',
                'reference' => $o->number,
                'customer' => $o->customerName,
                'amount' => (float) $o->total,
                'method' => $gatewayLabel($o->paymentProvider) ?? ($o->paymentMethod ?? '—'),
                'paymentId' => $o->razorpayPaymentId,
                'status' => $o->status,
                'date' => Iso::of($o->createdAt),
            ]);
        }
        foreach ($gifts as $g) {
            $txns[] = self::def([
                'id' => "g-{$g->id}",
                'source' => 'Gift Card',
                'reference' => $g->code,
                'customer' => $g->customerName,
                'amount' => (float) $g->amount,
                'method' => $gatewayLabel($g->paymentProvider) ?? 'Online',
                'paymentId' => $g->razorpayPaymentId,
                'status' => $g->status,
                'date' => Iso::of($g->createdAt),
            ]);
        }
        foreach ($payments as $p) {
            $txns[] = [
                'id' => "p-{$p->id}",
                'source' => 'Table',
                'reference' => 'Table '.$p->session->table->number,
                'customer' => $p->session->customerName ?? '—',
                'amount' => (float) $p->amount,
                'method' => $p->method,
                'status' => 'PAID',
                'date' => Iso::of($p->createdAt),
            ];
        }

        return self::sortDescByKey($txns, 'date');
    }

    public static function getReservations(): array
    {
        return Reservation::query()->orderByDesc('createdAt')->get()->map(fn (Reservation $r) => self::def([
            'id' => $r->id,
            'reference' => $r->reference,
            'kind' => $r->kind,
            'status' => $r->status,
            'date' => Iso::date($r->date),
            'name' => $r->name,
            'email' => $r->email,
            'phone' => $r->phone,
            'time' => $r->time,
            'guests' => $r->guests !== null ? (int) $r->guests : null,
            'occasion' => $r->occasion,
            'requests' => $r->requests,
            'eventType' => $r->eventType,
            'guestRange' => $r->guestRange,
            'space' => $r->space,
            'company' => $r->company,
            'message' => $r->message,
            'createdAt' => Iso::of($r->createdAt),
        ]))->all();
    }

    public static function getOutlets(): array
    {
        return Outlet::query()
            ->with(['metrics' => fn ($q) => $q->orderBy('periodStart')])
            ->orderBy('name')
            ->get()
            ->map(fn (Outlet $o) => [
                'id' => $o->id,
                'name' => $o->name,
                'location' => $o->location ?? '',
                'address' => $o->address ?? '',
                'phone' => $o->phone ?? '',
                'manager' => $o->manager ?? '',
                'isActive' => (bool) $o->isActive,
                'weekly' => $o->metrics->values()->map(fn ($m, $i) => [
                    'week' => 'W'.($i + 1),
                    'revenue' => (float) $m->revenue,
                    'cost' => (float) $m->operationalCost,
                ])->all(),
            ])->all();
    }

    public static function getEmployees(): array
    {
        $names = self::outletNameMap();

        return Employee::query()->orderBy('name')->get()->map(fn (Employee $e) => self::def([
            'id' => $e->id,
            'name' => $e->name,
            'role' => $e->role,
            'outlet' => $names[$e->outletId] ?? $e->outletId,
            'email' => $e->email ?? '',
            'phone' => $e->phone,
            'active' => (bool) $e->active,
            'status' => $e->status,
            'createdAt' => Iso::of($e->createdAt),
        ]))->all();
    }

    public static function getCustomers(): array
    {
        return Customer::query()->with(['orders', 'reservations'])->orderBy('name')->get()->map(function (Customer $c) {
            $orders = $c->orders->map(fn (Order $o) => [
                'number' => $o->number,
                'total' => (float) $o->total,
                'status' => $o->status,
                'date' => Iso::of($o->createdAt),
            ])->all();
            $reservations = $c->reservations->map(fn (Reservation $r) => [
                'reference' => $r->reference,
                'kind' => $r->kind,
                'status' => $r->status,
                'date' => Iso::of($r->date),
            ])->all();
            $totalSpend = 0;
            foreach ($orders as $o) {
                if ($o['status'] !== 'CANCELED') {
                    $totalSpend += $o['total'];
                }
            }
            $dates = array_merge(array_column($orders, 'date'), array_column($reservations, 'date'));
            sort($dates, SORT_STRING);
            $lastActivity = $dates ? end($dates) : '';

            return self::def([
                'id' => $c->id,
                'name' => $c->name,
                'email' => $c->email,
                'phone' => $c->phone,
                'address' => $c->address,
                'status' => $c->status,
                'orders' => $orders,
                'reservations' => $reservations,
                'totalSpend' => $totalSpend,
                'lastActivity' => $lastActivity,
                'createdAt' => Iso::of($c->createdAt),
            ]);
        })->all();
    }

    // ---- Dashboard aggregation ----

    private static function pct(float|int $part, float|int $total): int|float
    {
        return $total ? Format::round(($part / $total) * 100) : 0;
    }

    private static function formatHour(int $h): string
    {
        $period = $h < 12 ? 'AM' : 'PM';

        return ($h % 12 ?: 12).".00 {$period}";
    }

    public static function getDashboardData(): array
    {
        $orders = Order::query()->with('items')->orderByDesc('createdAt')->get();
        $menu = MenuItem::query()->with('category')->get();
        $outlets = Outlet::query()->with(['metrics' => fn ($q) => $q->orderBy('periodStart')])->orderBy('name')->get();
        $employeeGroups = Employee::query()->selectRaw('status, count(*) as c')->groupBy('status')->get();
        $dashCfg = DashboardConfig::query()->find('default');

        $menuByName = [];
        $menuById = [];
        foreach ($menu as $m) {
            $menuByName[$m->name] = $m; // Map semantics: last write wins
            $menuById[$m->id] = $m;
        }
        // First image per category across the whole menu (for override categories
        // that may have no orders yet).
        $catImageAll = [];
        foreach ($menu as $m) {
            $catImageAll[$m->category->name] ??= $m->imageUrl;
        }

        // KPIs
        $completed = $orders->where('status', 'COMPLETED');
        $canceled = $orders->where('status', 'CANCELED');
        $revenue = $completed->reduce(fn ($s, $o) => $s + (float) $o->total, 0);
        $kpis = [
            ['key' => 'orders', 'label' => 'Total Orders', 'value' => Format::locale($orders->count()), 'delta' => 10, 'accent' => true],
            ['key' => 'delivered', 'label' => 'Total Delivered', 'value' => Format::locale($completed->count()), 'delta' => 7.5],
            ['key' => 'canceled', 'label' => 'Canceled Order', 'value' => Format::locale($canceled->count()), 'delta' => -3.5],
            ['key' => 'revenue', 'label' => 'Total Revenue', 'value' => Format::formatCurrency($revenue), 'delta' => 7.5],
        ];

        // Trending — most-ordered menu item
        $qtyByItem = [];
        foreach ($orders as $o) {
            foreach ($o->items as $it) {
                $qtyByItem[$it->name] = ($qtyByItem[$it->name] ?? 0) + (int) $it->qty;
            }
        }
        $trendingName = $menu->first()?->name ?? '';
        $trendingQty = 0;
        foreach ($qtyByItem as $name => $q) {
            if ($q > $trendingQty) {
                $trendingQty = $q;
                $trendingName = (string) $name;
            }
        }
        $tItem = $menuByName[$trendingName] ?? null;
        $trending = [
            'name' => $trendingName,
            'subtitle' => $tItem ? ($tItem->tag ?? 'Popular') : 'Popular',
            'rating' => $tItem ? (float) $tItem->rating : 4.8,
            'orders' => $trendingQty,
            'price' => $tItem ? (float) $tItem->price : 0,
            'image' => $tItem?->imageUrl ?? '',
        ];
        // Manual override: feature a specific menu item as Trending.
        if ($dashCfg?->trendingItemId) {
            $mi = $menuById[$dashCfg->trendingItemId] ?? null;
            if ($mi) {
                $trending = [
                    'name' => $mi->name,
                    'subtitle' => $mi->tag ?? 'Featured',
                    'rating' => (float) $mi->rating,
                    'orders' => $qtyByItem[$mi->name] ?? 0,
                    'price' => (float) $mi->price,
                    'image' => $mi->imageUrl,
                ];
            }
        }

        // Outlet series (current week per outlet)
        $outletSeries = $outlets->map(function (Outlet $o) {
            $m = $o->metrics->last();

            return ['outlet' => $o->name, 'sells' => $m ? (float) $m->revenue : 0, 'cost' => $m ? (float) $m->operationalCost : 0];
        })->all();
        $revenueTotal = Format::formatCurrency(array_reduce($outletSeries, fn ($s, $o) => $s + $o['sells'], 0));

        // Top categories by ordered quantity
        $qtyByCat = [];
        $imageByCat = [];
        foreach ($orders as $o) {
            foreach ($o->items as $it) {
                $mi = $menuByName[$it->name] ?? null;
                if (! $mi) {
                    continue;
                }
                $cat = $mi->category->name;
                $qtyByCat[$cat] = ($qtyByCat[$cat] ?? 0) + (int) $it->qty;
                $imageByCat[$cat] ??= $mi->imageUrl;
            }
        }
        $totalCatQty = array_sum($qtyByCat);
        $entries = [];
        foreach ($qtyByCat as $name => $q) {
            $entries[] = [(string) $name, $q];
        }
        usort($entries, fn ($a, $b) => $b[1] <=> $a[1]);
        $topCategories = array_map(fn ($e) => [
            'name' => $e[0],
            'percent' => self::pct($e[1], $totalCatQty),
            'image' => $imageByCat[$e[0]] ?? '',
        ], array_slice($entries, 0, 3));
        // Manual override: pin specific categories + percentages.
        if ($dashCfg && $dashCfg->topCategories !== null && $dashCfg->topCategories !== '') {
            $parsed = json_decode($dashCfg->topCategories, true);
            if (json_last_error() === JSON_ERROR_NONE && is_array($parsed) && array_is_list($parsed) && count($parsed)) {
                $topCategories = array_map(fn ($p) => self::def([
                    'name' => $p['name'] ?? null,
                    'percent' => $p['percent'] ?? null,
                    'image' => $catImageAll[$p['name'] ?? ''] ?? '',
                ]), array_slice($parsed, 0, 3));
            }
        }

        // Employee status
        $countByStatus = [];
        $total = 0;
        foreach ($employeeGroups as $g) {
            $countByStatus[$g->status] = (int) $g->c;
            $total += (int) $g->c;
        }
        $employee = [
            'total' => $total,
            'segments' => [
                ['label' => 'On Duty', 'value' => $countByStatus['ON_DUTY'] ?? 0, 'color' => 'var(--color-success)'],
                ['label' => 'On Break', 'value' => $countByStatus['ON_BREAK'] ?? 0, 'color' => 'var(--color-warn)'],
                ['label' => 'Absent', 'value' => $countByStatus['ABSENT'] ?? 0, 'color' => 'var(--color-danger)'],
            ],
        ];

        // POS (peak hour in server-local time; Map order = first appearance)
        $hourCounts = [];
        foreach ($orders as $o) {
            $h = Format::local($o->createdAt)->hour;
            $hourCounts[$h] = ($hourCounts[$h] ?? 0) + 1;
        }
        $peak = 17;
        $peakN = -1;
        foreach ($hourCounts as $h => $n) {
            if ($n > $peakN) {
                $peakN = $n;
                $peak = $h;
            }
        }
        $cash = $orders->where('paymentMethod', 'CASH')->count();
        $card = $orders->where('paymentMethod', 'CARD')->count();
        $online = $orders->where('paymentMethod', 'ONLINE')->count();
        $payTotal = $cash + $card + $online;
        $ordersSum = $orders->reduce(fn ($s, $o) => $s + (float) $o->total, 0);
        $pos = [
            'totalSales' => Format::formatCurrency($revenue),
            'salesDelta' => 12,
            'totalBills' => $orders->count(),
            'avgValue' => Format::formatCurrency($orders->count() ? Format::round($ordersSum / $orders->count()) : 0),
            'peakHour' => self::formatHour($peak),
            'payment' => ['cash' => self::pct($cash, $payTotal), 'card' => self::pct($card, $payTotal), 'online' => self::pct($online, $payTotal)],
        ];

        // Recent orders (latest 3) — customer, number, type, real status, total,
        // with the first item's photo.
        $recentOrders = [];
        foreach ($orders->take(3)->values() as $i => $o) {
            $first = $o->items->first();
            $mi = $first ? ($menuByName[$first->name] ?? null) : null;
            $recentOrders[] = [
                'line' => str_pad((string) ($i + 1), 2, '0', STR_PAD_LEFT),
                'orderId' => $o->number,
                'customer' => $o->customerName,
                'type' => self::TYPE_LABELS[$o->type] ?? $o->type,
                'status' => $o->status,
                'price' => (float) $o->total,
                'image' => $mi?->imageUrl ?? '',
            ];
        }

        // Sales & order types
        $n = $orders->count();
        $salesTypes = [
            ['label' => 'Dine-in', 'percent' => self::pct($orders->where('type', 'DINE_IN')->count(), $n)],
            ['label' => 'Delivery', 'percent' => self::pct($orders->where('type', 'DELIVERY')->count(), $n)],
            ['label' => 'Pick-up', 'percent' => self::pct($orders->where('type', 'PICKUP')->count(), $n)],
        ];

        // outletSeries.reduce((max, o) => o.cost > (max?.cost ?? -1) ? o : max, outletSeries[0])?.outlet ?? ''
        $active = $outletSeries[0] ?? null;
        foreach ($outletSeries as $o) {
            if ($o['cost'] > ($active['cost'] ?? -1)) {
                $active = $o;
            }
        }

        return [
            'kpis' => $kpis,
            'trending' => $trending,
            'outletSeries' => $outletSeries,
            'outletActive' => $active['outlet'] ?? '',
            'revenueTotal' => $revenueTotal,
            'topCategories' => $topCategories,
            'employee' => $employee,
            'pos' => $pos,
            'recentOrders' => $recentOrders,
            'salesTypes' => $salesTypes,
        ];
    }

    // ---- Reports & analytics ----

    public static function getReportsData(): array
    {
        $orders = Order::query()->with('items')->get();
        $menu = MenuItem::query()->with('category')->get();
        $outletName = self::outletNameMap();
        $catByItem = [];
        foreach ($menu as $m) {
            $catByItem[$m->name] = $m->category->name;
        }

        // Exclude canceled orders from sales analytics.
        $valid = $orders->filter(fn ($o) => $o->status !== 'CANCELED')->values();

        $revenue = $valid->reduce(fn ($s, $o) => $s + (float) $o->total, 0);
        $itemsSold = $valid->reduce(fn ($s, $o) => $s + $o->items->reduce(fn ($n, $it) => $n + (int) $it->qty, 0), 0);
        $summary = [
            'revenue' => $revenue,
            'orders' => $orders->count(),
            'itemsSold' => $itemsSold,
            'avgOrder' => $valid->count() ? Format::round($revenue / $valid->count()) : 0,
        ];

        $byOutlet = [];
        foreach ($valid as $o) {
            $name = $outletName[$o->outletId] ?? $o->outletId;
            $cur = $byOutlet[$name] ?? ['revenue' => 0, 'orders' => 0];
            $cur['revenue'] += (float) $o->total;
            $cur['orders'] += 1;
            $byOutlet[$name] = $cur;
        }
        $revenueByOutlet = [];
        foreach ($byOutlet as $outlet => $v) {
            $revenueByOutlet[] = ['outlet' => (string) $outlet] + $v;
        }
        $collator = class_exists(Collator::class) ? new Collator('en_US') : null;
        usort($revenueByOutlet, fn ($a, $b) => $collator ? $collator->compare($a['outlet'], $b['outlet']) : strcasecmp($a['outlet'], $b['outlet']));

        $itemAgg = [];
        $catAgg = [];
        foreach ($valid as $o) {
            foreach ($o->items as $it) {
                $lineRev = (int) $it->qty * (float) $it->price;
                $i = $itemAgg[$it->name] ?? ['qty' => 0, 'revenue' => 0];
                $i['qty'] += (int) $it->qty;
                $i['revenue'] += $lineRev;
                $itemAgg[$it->name] = $i;
                $cat = $catByItem[$it->name] ?? 'Other';
                $c = $catAgg[$cat] ?? ['qty' => 0, 'revenue' => 0];
                $c['qty'] += (int) $it->qty;
                $c['revenue'] += $lineRev;
                $catAgg[$cat] = $c;
            }
        }
        $topItems = [];
        foreach ($itemAgg as $name => $v) {
            $topItems[] = ['name' => (string) $name] + $v;
        }
        usort($topItems, fn ($a, $b) => $b['qty'] <=> $a['qty']);
        $topItems = array_slice($topItems, 0, 8);
        $categoryMix = [];
        foreach ($catAgg as $category => $v) {
            $categoryMix[] = ['category' => (string) $category] + $v;
        }
        usort($categoryMix, fn ($a, $b) => $b['revenue'] <=> $a['revenue']);

        $typeCount = fn (string $t) => $orders->where('type', $t)->count();
        $orderTypes = [
            ['type' => 'Dine-in', 'count' => $typeCount('DINE_IN')],
            ['type' => 'Delivery', 'count' => $typeCount('DELIVERY')],
            ['type' => 'Pick-up', 'count' => $typeCount('PICKUP')],
        ];
        $payCount = fn (string $m) => $valid->where('paymentMethod', $m)->count();
        $paymentMix = [
            ['method' => 'Cash', 'count' => $payCount('CASH')],
            ['method' => 'Card', 'count' => $payCount('CARD')],
            ['method' => 'Online', 'count' => $payCount('ONLINE')],
        ];

        return [
            'summary' => $summary,
            'revenueByOutlet' => $revenueByOutlet,
            'topItems' => $topItems,
            'categoryMix' => $categoryMix,
            'orderTypes' => $orderTypes,
            'paymentMix' => $paymentMix,
        ];
    }

    // ---- Settings & notifications ----

    public static function getProfile(): array
    {
        $p = RestaurantProfile::query()->find('default');

        return [
            'name' => $p?->name ?? 'Go4Foodie',
            'currency' => $p?->currency ?? 'USD',
            'timezone' => $p?->timezone ?? 'America/New_York',
            'address' => $p?->address ?? '',
            'phone' => $p?->phone ?? '',
            'email' => $p?->email ?? '',
        ];
    }

    public static function getUsers(): array
    {
        return User::query()->orderBy('name')->get()
            ->map(fn (User $u) => ['id' => $u->id, 'name' => $u->name, 'email' => $u->email, 'role' => $u->role])->all();
    }

    public static function getNotifications(): array
    {
        $nowIso = Iso::of(Carbon::now());
        $nowMs = Format::ms(Carbon::now());

        $orders = Order::query()->orderByDesc('createdAt')->take(6)->get();
        $reservations = Reservation::query()->where('status', 'REQUESTED')->orderByDesc('createdAt')->take(6)->get();
        $inventory = InventoryItem::query()->get();
        $stateTables = RestaurantTable::query()->whereIn('state', ['CLEANING', 'WAITING_PAYMENT'])->get(['id', 'number', 'state']);
        $openSessions = TableSession::query()->where('status', 'OPEN')->with('table:id,number')->get(['id', 'tableId', 'openedAt', 'total']);

        $tableAlerts = [];
        foreach ($stateTables as $t) {
            $cleaning = $t->state === 'CLEANING';
            $tableAlerts[] = [
                'id' => "t-{$t->id}",
                'type' => 'table',
                'title' => $cleaning ? "Table {$t->number} needs cleaning" : "Table {$t->number} payment pending",
                'detail' => $cleaning ? 'Mark available once cleaned.' : 'Awaiting checkout.',
                'time' => $nowIso,
            ];
        }
        foreach ($openSessions as $s) {
            if ($nowMs - Format::ms($s->openedAt) > self::OCCUPIED_TOO_LONG_MIN * 60_000) {
                $tableAlerts[] = [
                    'id' => "tl-{$s->id}",
                    'type' => 'table',
                    'title' => "Table {$s->table->number} occupied 2h+",
                    'detail' => 'Open since '.Format::localeTime($s->openedAt),
                    'time' => Iso::of($s->openedAt),
                ];
            }
        }
        foreach ($openSessions as $s) {
            if ((float) $s->total >= self::LARGE_BILL_THRESHOLD) {
                $tableAlerts[] = [
                    'id' => "tb-{$s->id}",
                    'type' => 'table',
                    'title' => "Large bill at Table {$s->table->number}",
                    'detail' => Format::formatCurrency((float) $s->total).' running',
                    'time' => $nowIso,
                ];
            }
        }

        $items = [];
        foreach ($orders as $o) {
            $items[] = [
                'id' => "o-{$o->id}",
                'type' => 'order',
                'title' => "New order {$o->number}",
                'detail' => "{$o->customerName} · ".Format::formatCurrency((float) $o->total),
                'time' => Iso::of($o->createdAt),
            ];
        }
        foreach ($reservations as $r) {
            $items[] = [
                'id' => "r-{$r->id}",
                'type' => 'reservation',
                'title' => "Reservation request {$r->reference}",
                'detail' => "{$r->name} · ".($r->kind === 'TABLE' ? 'Table booking' : 'Private event'),
                'time' => Iso::of($r->createdAt),
            ];
        }
        foreach ($inventory as $i) {
            if ((float) $i->quantity <= (float) $i->reorderLevel) {
                $items[] = [
                    'id' => "i-{$i->id}",
                    'type' => 'stock',
                    'title' => "Low stock: {$i->name}",
                    'detail' => Format::js((float) $i->quantity)." {$i->unit} left (reorder at ".Format::js((float) $i->reorderLevel).')',
                    'time' => Iso::of($i->updatedAt),
                ];
            }
        }
        array_push($items, ...$tableAlerts);

        return self::sortDescByKey($items, 'time');
    }

    public static function getAuditLogs(int $limit = 150): array
    {
        return AuditLog::query()->orderByDesc('createdAt')->take($limit)->get()->map(fn (AuditLog $r) => self::def([
            'id' => $r->id,
            'action' => $r->action,
            'entity' => $r->entity,
            'entityId' => $r->entityId,
            'detail' => $r->detail,
            'userName' => $r->userName,
            'createdAt' => Iso::of($r->createdAt),
        ]))->all();
    }

    public static function getAttentionCount(): int
    {
        $requested = Reservation::query()->where('status', 'REQUESTED')->count();
        $lowStock = InventoryItem::query()->get(['quantity', 'reorderLevel'])
            ->filter(fn ($i) => (float) $i->quantity <= (float) $i->reorderLevel)->count();
        $tableAttention = RestaurantTable::query()->whereIn('state', ['CLEANING', 'WAITING_PAYMENT'])->count();

        return $requested + $lowStock + $tableAttention;
    }
}
