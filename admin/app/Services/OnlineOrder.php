<?php

namespace App\Services;

use App\Http\Controllers\Api\ReservationController;
use App\Http\Controllers\Api\Support\Json;
use App\Models\Customer;
use App\Models\MenuItem;
use App\Models\Order;
use App\Models\RestaurantTable;
use App\Models\TableSession;
use App\Services\Payments\PaymentGate;
use App\Support\Format;
use App\Support\Iso;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;

/**
 * Shared online-order placement — port of admin/src/lib/online-order.ts, used by
 * POST /api/orders (website) and POST /api/mobile/customer/orders (Customer app).
 *  - TAKE_AWAY: pickup order with optional scheduling → persisted as PICKUP.
 *  - DINE_IN:   table QR order → persisted as DINE_IN tied to a table (+ open session).
 * Prices always come from live menu rows. With $payAtRestaurant (app customer settling
 * at the counter/table) the gateway gate is skipped and the order is stored unpaid.
 *
 * $data is the parsed onlineOrderSchema value (see Api\Support\Schemas::onlineOrder()).
 */
final class OnlineOrder
{
    public static function placeOnlineOrder(array $data, bool $payAtRestaurant = false): JsonResponse
    {
        $payment = $data['payment'] ?? null;
        $payLater = $payAtRestaurant && ! $payment;

        // Payment gate (enforced once a gateway is configured).
        if (! $payLater) {
            $pay = PaymentGate::accepted($payment);
            if (! $pay['ok']) {
                return Json::error($pay['reason'] ?? 'Payment required', 402);
            }
        }
        $paymentProvider = $payment['provider'] ?? null;
        $razorpayPaymentId = PaymentGate::ref($payment);

        // Cutoff / business-hours validation for scheduled (LATER) pickups.
        if ($data['type'] === 'TAKE_AWAY' && $data['scheduleType'] === 'LATER') {
            $check = Scheduling::validateSlot($data['scheduleDate'] ?? '', $data['scheduleTime'] ?? '');
            if (! $check['ok']) {
                return Json::error($check['reason'], 422);
            }
        }

        try {
            // Resolve & price the cart from live menu rows (never trust client prices).
            // Match by id first, then by name (covers content-seeded storefront ids).
            $ids = array_column($data['items'], 'menuItemId');
            $names = array_values(array_filter(array_map(fn ($i) => $i['name'] ?? null, $data['items'])));
            $menuRows = MenuItem::query()
                ->where(fn ($q) => $q->whereIn('id', $ids)->orWhereIn('name', $names))
                ->get();
            $byId = [];
            $byName = [];
            foreach ($menuRows as $m) {
                $byId[$m->id] = $m;
                $byName[$m->name] = $m; // Map semantics: last row wins
            }

            $lines = array_map(function ($i) use ($byId, $byName) {
                $mi = $byId[$i['menuItemId']] ?? (! empty($i['name']) ? ($byName[$i['name']] ?? null) : null);
                if (! $mi) {
                    throw new \RuntimeException('Item not found: '.(($i['name'] ?? null) ?: $i['menuItemId']));
                }
                if (! $mi->available) {
                    throw new \RuntimeException("Item unavailable: {$mi->name}");
                }

                return ['menuItemId' => $mi->id, 'name' => $mi->name, 'qty' => (int) $i['qty'], 'price' => (float) $mi->price];
            }, $data['items']);
            $total = 0;
            foreach ($lines as $l) {
                $total += $l['price'] * $l['qty'];
            }

            // Single-outlet fallback keeps the required outletId satisfied.
            $outletId = DB::table('Outlet')->value('id') ?? 'online';
            $number = 'ORD-'.random_int(10000, 99999);
            $email = ($data['email'] ?? '') ?: null;
            $phone = ($data['phone'] ?? '') ?: null;

            // Link/create a customer when we have an email (table orders may omit it).
            $customerId = null;
            if ($email) {
                $c = Customer::where('email', $email)->first();
                if ($c) {
                    $c->name = $data['name'];
                    if ($phone) {
                        $c->phone = $phone;
                    }
                    $c->updatedAt = now();
                    $c->save();
                } else {
                    $c = Customer::create(['name' => $data['name'], 'email' => $email, 'phone' => $phone]);
                }
                $customerId = $c->id;
            }

            $mailItems = array_map(fn ($l) => ['name' => $l['name'], 'qty' => $l['qty'], 'price' => $l['price']], $lines);

            // -------- DINE_IN: table QR order --------
            if ($data['type'] === 'DINE_IN') {
                $table = RestaurantTable::where('code', $data['tableCode'])->where('status', 'ACTIVE')->first(['id', 'number']);
                if (! $table) {
                    return Json::error('Table not found or inactive', 422);
                }

                // Attach to the table's open session (auto-open one on QR self-seat).
                $session = TableSession::where('tableId', $table->id)->where('status', 'OPEN')->first(['id']);
                if (! $session) {
                    $session = TableSession::create(['tableId' => $table->id, 'customerName' => $data['name']]);
                    RestaurantTable::whereKey($table->id)->update(['state' => 'OCCUPIED', 'updatedAt' => now()]);
                }

                $order = self::createOrder([
                    'number' => $number,
                    'type' => 'DINE_IN',
                    'status' => 'PENDING',
                    'channel' => 'ONLINE',
                    'paymentMethod' => $payment ? 'ONLINE' : null,
                    'paymentProvider' => $paymentProvider,
                    'razorpayPaymentId' => $razorpayPaymentId,
                    'total' => $total,
                    'outletId' => $outletId,
                    'customerName' => $data['name'],
                    'customerEmail' => $email,
                    'customerPhone' => $phone,
                    'customerId' => $customerId,
                    'tableId' => $table->id,
                    'tableNumber' => $table->number,
                    'sessionId' => $session->id,
                    'notes' => $data['notes'] ?? null,
                ], $lines);

                // Optional receipt email if the guest provided one.
                if ($email) {
                    self::mail($email, [
                        'number' => $order->number,
                        'customerName' => $data['name'],
                        'items' => $mailItems,
                        'total' => $total,
                        'pickupLabel' => "Dine-in · Table {$table->number}",
                        'notes' => $data['notes'] ?? null,
                    ]);
                }

                return Json::response(['number' => $order->number, 'id' => $order->id, 'total' => $total, 'tableNumber' => $table->number], 201);
            }

            // -------- TAKE_AWAY: pickup order --------
            $later = $data['scheduleType'] === 'LATER';
            $pickup = Scheduling::estimatePickup($data['scheduleType'], $data['scheduleDate'] ?? null, $data['scheduleTime'] ?? null);
            $order = self::createOrder([
                'number' => $number,
                'type' => 'PICKUP', // "Take Away"
                'status' => 'PENDING',
                'channel' => 'ONLINE',
                'paymentMethod' => $payLater ? null : 'ONLINE',
                'paymentProvider' => $paymentProvider,
                'razorpayPaymentId' => $razorpayPaymentId,
                'total' => $total,
                'outletId' => $outletId,
                'customerName' => $data['name'],
                'customerEmail' => $email,
                'customerPhone' => $data['phone'],
                'customerId' => $customerId,
                'scheduleType' => $data['scheduleType'],
                'scheduleDate' => $later ? ReservationController::jsDate((string) $data['scheduleDate']) : null,
                'scheduleTime' => $later ? $data['scheduleTime'] : null,
                'notes' => $data['notes'] ?? null,
            ], $lines);

            $local = Format::local($pickup);
            $pickupLabel = $later
                ? $local->format('D, M j, g:i A')
                : 'As soon as possible (around '.$local->format('g:i A').')';
            if ($email) {
                self::mail($email, [
                    'number' => $order->number,
                    'customerName' => $data['name'],
                    'items' => $mailItems,
                    'total' => $total,
                    'pickupLabel' => $pickupLabel,
                    'notes' => $data['notes'] ?? null,
                ]);
            }

            return Json::response(['number' => $order->number, 'id' => $order->id, 'total' => $total, 'estimatedPickup' => Iso::of($pickup)], 201);
        } catch (\Throwable $e) {
            $message = $e instanceof \RuntimeException && ! $e instanceof \Illuminate\Database\QueryException
                ? $e->getMessage() : 'Could not place order';
            $isClient = (bool) preg_match('/not found|unavailable/i', $message);
            report($e);

            return Json::error($isClient ? $message : 'Could not place order', $isClient ? 422 : 503);
        }
    }

    /** Order + nested items (Prisma nested create is atomic). */
    private static function createOrder(array $attrs, array $lines): Order
    {
        return DB::transaction(function () use ($attrs, $lines) {
            $order = Order::create($attrs);
            foreach ($lines as $l) {
                $order->items()->create(['menuItemId' => $l['menuItemId'], 'name' => $l['name'], 'qty' => $l['qty'], 'price' => $l['price']]);
            }

            return $order;
        });
    }

    /** Confirmation email — never fail the order if mail/SMTP errors. */
    private static function mail(string $to, array $input): void
    {
        try {
            $mail = Mailer::orderConfirmationEmail(array_filter($input, fn ($v) => $v !== null));
            Mailer::sendMail(['to' => $to, 'subject' => $mail['subject'], 'html' => $mail['html'], 'text' => $mail['text']]);
        } catch (\Throwable $e) {
            report($e);
        }
    }
}
