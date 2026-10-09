<?php

namespace App\Http\Controllers\Api\Mobile;

use App\Http\Controllers\Api\Support\MobileCtx;
use App\Http\Controllers\Api\Support\MobileRouter;
use App\Http\Controllers\Api\Support\Z;
use App\Http\Controllers\Controller;
use App\Services\Actions as A;
use App\Services\Queries as Q;
use App\Services\Validation;
use App\Support\HttpError;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Restaurant + Owner app API — /api/mobile/staff/* (bearer token, kinds user|employee).
 * Port of app/api/mobile/staff/[...path]/route.ts: thin REST wrappers over Queries (reads)
 * and Actions (writes); each route declares the same RBAC action as the admin page.
 */
class StaffController extends Controller
{
    private const ORDER_STATUSES = ['PENDING', 'PREPARING', 'READY', 'COMPLETED', 'CANCELED'];

    private const RES_STATUSES = ['REQUESTED', 'CONFIRMED', 'SEATED', 'COMPLETED', 'CANCELED', 'NO_SHOW'];

    private const TABLE_STATES = ['AVAILABLE', 'RESERVED', 'OCCUPIED', 'WAITING_PAYMENT', 'CLEANING', 'OUT_OF_SERVICE'];

    private const DUTY = ['ON_DUTY', 'ON_BREAK', 'ABSENT', 'OFF'];

    private const COUPON_STATUSES = ['PENDING_PAYMENT', 'PAID', 'ACTIVE', 'REDEEMED', 'EXPIRED', 'CANCELLED'];

    public function handle(Request $req, string $path)
    {
        return $this->router()->dispatch($req, $path);
    }

    // ---- helpers (str / num / days of the TS) ----

    private static function str(mixed $v): string
    {
        return is_string($v) ? $v : '';
    }

    /** Number(v ?? 0) || 0 */
    private static function num(mixed $v): int|float
    {
        $n = Z::jsNumber($v ?? 0);

        return is_nan((float) $n) || $n == 0 ? 0 : $n;
    }

    /** Math.min(365, Math.max(1, Number(v) || d)) */
    private static function days(?string $v, int $d): int
    {
        $n = Z::jsNumber($v); // Number(null) === 0 → default
        $n = (is_nan((float) $n) || $n == 0) ? $d : $n;

        return (int) min(365, max(1, $n));
    }

    /** body field with "undefined" semantics */
    private static function field(MobileCtx $ctx, string $k): mixed
    {
        return Z::get($ctx->body(), $k);
    }

    private static function enum(array $options, mixed $v): string
    {
        return Z::parse(Z::enum($options), $v);
    }

    private static function sessionTable(string $sessionId): string
    {
        $tableId = DB::table('TableSession')->where('id', $sessionId)->value('tableId');
        if (! $tableId) {
            throw new HttpError(404, 'Session not found');
        }

        return $tableId;
    }

    /** Fresh POS view for a table — returned after every POS mutation. */
    private static function pos(string $tableId): array
    {
        $data = Q::getTablePos($tableId);
        if (! $data['table']) {
            throw new HttpError(404, 'Table not found');
        }
        $menu = array_values(array_filter(Q::getMenuItems(), fn ($m) => ! empty($m['available'])));

        return $data + ['menu' => $menu, 'mergeTargets' => Q::getMergeTargets($tableId), 'waiters' => Q::getWaiterOptions()];
    }

    private function router(): MobileRouter
    {
        $r = new MobileRouter;

        // ---- Overview ----
        $r->add('GET', 'dashboard', 'view:dashboard', function () {
            $dashboard = Q::getDashboardData();
            $attention = Q::getAttentionCount();
            $floor = Q::getFloorTables();
            $count = fn (string $s) => count(array_filter($floor, fn ($t) => $t['state'] === $s));

            return $dashboard + [
                'attention' => $attention,
                'floor' => [
                    'total' => count($floor),
                    'available' => $count('AVAILABLE'),
                    'occupied' => $count('OCCUPIED'),
                    'reserved' => $count('RESERVED'),
                    'waitingPayment' => $count('WAITING_PAYMENT'),
                    'cleaning' => $count('CLEANING'),
                ],
            ];
        });
        $r->add('GET', 'notifications', 'view:dashboard', fn () => ['notifications' => Q::getNotifications()]);

        // Own duty status (employees clock on/off from the Restaurant app).
        $r->add('PATCH', 'me/duty', null, function (MobileCtx $ctx) {
            $status = self::enum(self::DUTY, self::field($ctx, 'status'));
            if ($ctx->user['kind'] !== 'employee') {
                throw new HttpError(422, 'Duty status applies to staff accounts');
            }
            DB::table('Employee')->where('id', $ctx->user['id'])->update(['status' => $status]);

            return ['status' => $status];
        });

        // ---- Orders (kitchen / service board) ----
        $r->add('GET', 'orders', 'manage:orders', fn () => ['orders' => array_slice(Q::getOrders(), 0, 300)]);
        $r->add('PATCH', 'orders/:id/status', 'manage:orders', function (MobileCtx $ctx) {
            A::setOrderStatus($ctx->params['id'], self::enum(self::ORDER_STATUSES, self::field($ctx, 'status')));

            return ['ok' => true];
        });

        // ---- Floor plan & POS ----
        $r->add('GET', 'floor', 'manage:orders', fn () => ['tables' => Q::getFloorTables(), 'waiters' => Q::getWaiterOptions()]);
        $r->add('PATCH', 'tables/:id/state', 'operate:floor', function (MobileCtx $ctx) {
            A::setTableState($ctx->params['id'], self::enum(self::TABLE_STATES, self::field($ctx, 'state')));

            return ['ok' => true];
        });
        $r->add('GET', 'pos/:tableId', 'manage:orders', fn (MobileCtx $ctx) => self::pos($ctx->params['tableId']));
        $r->add('POST', 'pos/:tableId/open', 'operate:floor', function (MobileCtx $ctx) {
            $b = $ctx->body();
            A::openTableSession($ctx->params['tableId'], array_filter([
                'customerCount' => max(1, self::num($b['customerCount'] ?? null)),
                'waiterId' => self::str($b['waiterId'] ?? null) ?: null,
                'customerName' => self::str($b['customerName'] ?? null) ?: null,
            ], fn ($v) => $v !== null));

            return self::pos($ctx->params['tableId']);
        });
        $r->add('POST', 'sessions/:id/items', 'manage:orders', function (MobileCtx $ctx) {
            $items = Z::parse(Z::array(Z::object([
                'menuItemId' => Z::string(['min' => [1]]),
                'qty' => Z::number(['coerce' => true, 'int' => true, 'min' => [1], 'max' => [50]]),
            ]), [1]), self::field($ctx, 'items'));
            A::addSessionOrder($ctx->params['id'], $items);

            return self::pos(self::sessionTable($ctx->params['id']));
        });
        $r->add('POST', 'sessions/:id/void', 'manage:orders', function (MobileCtx $ctx) {
            A::decrementSessionItem($ctx->params['id'], Z::parse(Z::string(['min' => [1]]), self::field($ctx, 'menuItemId')));

            return self::pos(self::sessionTable($ctx->params['id']));
        });
        $r->add('PUT', 'sessions/:id/billing', 'manage:orders', function (MobileCtx $ctx) {
            $b = $ctx->body();
            A::updateSessionBilling($ctx->params['id'], [
                'discount' => self::num($b['discount'] ?? null),
                'tax' => self::num($b['tax'] ?? null),
                'serviceCharge' => self::num($b['serviceCharge'] ?? null),
                'tip' => self::num($b['tip'] ?? null),
            ]);

            return self::pos(self::sessionTable($ctx->params['id']));
        });
        $r->add('POST', 'sessions/:id/payments', 'manage:orders', function (MobileCtx $ctx) {
            $b = $ctx->body();
            if (! (self::num($b['amount'] ?? null) > 0)) {
                throw new HttpError(400, 'Enter an amount');
            }
            A::addPayment($ctx->params['id'], ['amount' => self::num($b['amount']), 'method' => self::str($b['method'] ?? null) ?: 'Cash']);

            return self::pos(self::sessionTable($ctx->params['id']));
        });
        $r->add('POST', 'sessions/:id/close', 'operate:floor', function (MobileCtx $ctx) {
            $tableId = self::sessionTable($ctx->params['id']);
            $pm = self::str(self::field($ctx, 'paymentMethod'));
            A::closeTableSession($ctx->params['id'], $pm !== '' ? ['paymentMethod' => $pm] : []);

            return self::pos($tableId);
        });
        $r->add('POST', 'sessions/:id/merge', 'manage:orders', function (MobileCtx $ctx) {
            $tableId = self::sessionTable($ctx->params['id']);
            // Merge THIS table's session into the chosen target session.
            $into = Z::parse(Z::string(['min' => [1]]), self::field($ctx, 'intoSessionId'));
            A::mergeSessions($ctx->params['id'], $into);

            return self::pos($tableId);
        });

        // ---- Tables (QR) ----
        $r->add('GET', 'tables', 'manage:tables', fn () => ['tables' => Q::getTables(), 'websiteUrl' => (string) (config('go4foodie.website_url') ?? '')]);
        $r->add('POST', 'tables', 'manage:tables', fn (MobileCtx $ctx) => ['table' => A::createTable($ctx->body())]);
        $r->add('PUT', 'tables/:id', 'manage:tables', function (MobileCtx $ctx) {
            A::updateTable($ctx->params['id'], $ctx->body());

            return ['ok' => true];
        });
        $r->add('DELETE', 'tables/:id', 'manage:tables', function (MobileCtx $ctx) {
            A::deleteTable($ctx->params['id']);

            return ['ok' => true];
        });
        $r->add('GET', 'table-analytics', 'view:reports', fn (MobileCtx $ctx) => ['analytics' => Q::getTableAnalytics(self::days($ctx->query('days'), 1))]);
        $r->add('GET', 'table-history/:tableId', 'view:reports', fn (MobileCtx $ctx) => [
            'history' => Q::getTableHistory($ctx->params['tableId'], self::days($ctx->query('days'), 30)),
        ]);

        // ---- Reservations ----
        $r->add('GET', 'reservations', 'manage:reservations', fn () => ['reservations' => Q::getReservations()]);
        $r->add('PATCH', 'reservations/:id/status', 'manage:reservations', function (MobileCtx $ctx) {
            A::setReservationStatus($ctx->params['id'], self::enum(self::RES_STATUSES, self::field($ctx, 'status')));

            return ['ok' => true];
        });
        $r->add('PUT', 'reservations/:id', 'manage:reservations', function (MobileCtx $ctx) {
            $b = $ctx->body();
            $in = [];
            if (($d = self::str($b['date'] ?? null)) !== '') {
                $in['date'] = $d;
            }
            if (array_key_exists('time', $b)) {
                $in['time'] = self::str($b['time']);
            }
            if (array_key_exists('guests', $b)) {
                $in['guests'] = max(1, self::num($b['guests']));
            }
            if (array_key_exists('occasion', $b)) {
                $in['occasion'] = self::str($b['occasion']);
            }
            if (array_key_exists('requests', $b)) {
                $in['requests'] = self::str($b['requests']);
            }
            A::updateReservation($ctx->params['id'], $in);

            return ['ok' => true];
        });

        // ---- Menu ----
        // Read access for anyone on the floor (item availability); edits need manage:menu.
        $r->add('GET', 'menu', 'manage:orders', fn () => ['items' => Q::getMenuItems(), 'categories' => Q::getMenuCategories()]);
        $r->add('POST', 'menu', 'manage:menu', function (MobileCtx $ctx) {
            A::createMenuItem($ctx->body());

            return ['ok' => true];
        });
        $r->add('PUT', 'menu/:id', 'manage:menu', function (MobileCtx $ctx) {
            A::updateMenuItem($ctx->params['id'], $ctx->body());

            return ['ok' => true];
        });
        $r->add('DELETE', 'menu/:id', 'manage:menu', function (MobileCtx $ctx) {
            A::deleteMenuItem($ctx->params['id']);

            return ['ok' => true];
        });
        $r->add('PATCH', 'menu/:id/availability', 'manage:menu', function (MobileCtx $ctx) {
            A::setMenuAvailability($ctx->params['id'], ($ctx->body()['available'] ?? null) === true);

            return ['ok' => true];
        });
        $r->add('PATCH', 'categories/:id', 'manage:menu', function (MobileCtx $ctx) {
            A::setCategoryActive($ctx->params['id'], ($ctx->body()['active'] ?? null) === true);

            return ['ok' => true];
        });

        // ---- Inventory ----
        $r->add('GET', 'inventory', 'manage:inventory', fn () => ['items' => Q::getInventory()]);
        $r->add('POST', 'inventory', 'manage:inventory', function (MobileCtx $ctx) {
            A::createInventoryItem($ctx->body());

            return ['ok' => true];
        });
        $r->add('PUT', 'inventory/:id', 'manage:inventory', function (MobileCtx $ctx) {
            A::updateInventoryItem($ctx->params['id'], $ctx->body());

            return ['ok' => true];
        });
        $r->add('POST', 'inventory/:id/adjust', 'manage:inventory', function (MobileCtx $ctx) {
            A::adjustInventory($ctx->params['id'], (float) self::num($ctx->body()['delta'] ?? null));

            return ['ok' => true];
        });
        $r->add('DELETE', 'inventory/:id', 'manage:inventory', function (MobileCtx $ctx) {
            A::deleteInventoryItem($ctx->params['id']);

            return ['ok' => true];
        });

        // ---- Staff ----
        $r->add('GET', 'staff', 'manage:staff', fn () => ['employees' => Q::getEmployees(), 'roles' => Validation::STAFF_ROLES]);
        $r->add('POST', 'staff', 'manage:staff', function (MobileCtx $ctx) {
            A::createStaff($ctx->body());

            return ['ok' => true];
        });
        $r->add('PUT', 'staff/:id', 'manage:staff', function (MobileCtx $ctx) {
            A::updateStaff($ctx->params['id'], $ctx->body());

            return ['ok' => true];
        });
        $r->add('PATCH', 'staff/:id/status', 'manage:staff', function (MobileCtx $ctx) {
            A::setEmployeeStatus($ctx->params['id'], self::enum(self::DUTY, self::field($ctx, 'status')));

            return ['ok' => true];
        });
        $r->add('PATCH', 'staff/:id/active', 'manage:staff', function (MobileCtx $ctx) {
            A::setStaffActive($ctx->params['id'], ($ctx->body()['active'] ?? null) === true);

            return ['ok' => true];
        });
        $r->add('DELETE', 'staff/:id', 'manage:staff', function (MobileCtx $ctx) {
            A::deleteStaff($ctx->params['id']);

            return ['ok' => true];
        });

        // ---- Customers ----
        $r->add('GET', 'customers', 'manage:customers', fn () => ['customers' => Q::getCustomers()]);
        $r->add('POST', 'customers', 'manage:customers', function (MobileCtx $ctx) {
            A::createCustomer($ctx->body());

            return ['ok' => true];
        });
        $r->add('PUT', 'customers/:id', 'manage:customers', function (MobileCtx $ctx) {
            A::updateCustomer($ctx->params['id'], $ctx->body());

            return ['ok' => true];
        });
        $r->add('DELETE', 'customers/:id', 'manage:customers', function (MobileCtx $ctx) {
            A::deleteCustomer($ctx->params['id']);

            return ['ok' => true];
        });

        // ---- Gift cards & coupons ----
        $r->add('GET', 'gift-cards', 'manage:coupons', fn () => ['giftCards' => Q::getGiftCards()]);
        $r->add('PATCH', 'gift-cards/:id/status', 'manage:coupons', function (MobileCtx $ctx) {
            A::setGiftCardStatus($ctx->params['id'], self::enum(self::COUPON_STATUSES, self::field($ctx, 'status')));

            return ['ok' => true];
        });
        $r->add('DELETE', 'gift-cards/:id', 'manage:coupons', function (MobileCtx $ctx) {
            A::deleteGiftCard($ctx->params['id']);

            return ['ok' => true];
        });

        // ---- Reports & finance ----
        $r->add('GET', 'reports', 'view:reports', fn () => ['reports' => Q::getReportsData()]);
        $r->add('GET', 'transactions', 'view:reports', fn () => ['transactions' => array_slice(Q::getTransactions(), 0, 300)]);
        $r->add('GET', 'outlets', 'manage:outlets', fn () => ['outlets' => Q::getOutlets()]);

        // ---- Settings & audit (owner) ----
        $r->add('GET', 'settings', 'manage:settings', fn () => ['profile' => Q::getProfile(), 'team' => Q::getUsers()]);
        $r->add('PUT', 'settings', 'manage:settings', function (MobileCtx $ctx) {
            A::updateProfile($ctx->body());

            return ['profile' => Q::getProfile()];
        });
        $r->add('GET', 'audit', 'manage:settings', function (MobileCtx $ctx) {
            $n = Z::jsNumber($ctx->query('limit') ?? null);
            $limit = (is_nan((float) $n) || $n == 0) ? 150 : $n;

            return ['logs' => Q::getAuditLogs((int) min(500, $limit))];
        });

        return $r;
    }
}
