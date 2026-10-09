<?php

namespace App\Http\Controllers\Api\Mobile;

use App\Http\Controllers\Api\GiftCardController;
use App\Http\Controllers\Api\ReservationController;
use App\Http\Controllers\Api\Support\Json;
use App\Http\Controllers\Api\Support\MobileCtx;
use App\Http\Controllers\Api\Support\MobileRouter;
use App\Http\Controllers\Api\Support\Schemas;
use App\Http\Controllers\Api\Support\Z;
use App\Http\Controllers\Controller;
use App\Models\Customer;
use App\Services\OnlineOrder;
use App\Services\Queries;
use App\Services\Scheduling;
use App\Support\Format;
use App\Support\HttpError;
use App\Support\Iso;
use Carbon\Carbon;
use Illuminate\Database\Query\Builder;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Customer app API — /api/mobile/customer/* (bearer token, kind = customer).
 * Port of app/api/mobile/customer/[...path]/route.ts. Ordering, reservations and gift
 * cards reuse the website's public flows with the signed-in customer's identity injected.
 */
class CustomerController extends Controller
{
    private const ACTIVE_ORDER = ['PENDING', 'PREPARING', 'READY'];

    public function handle(Request $req, string $path)
    {
        return $this->router()->dispatch($req, $path);
    }

    private static function me(MobileCtx $ctx): Customer
    {
        $c = Customer::find($ctx->user['id']);
        if (! $c) {
            throw new HttpError(401, 'Account not found');
        }

        return $c;
    }

    /** Orders placed in the app or earlier as a website guest with the same email. */
    private static function mine(MobileCtx $ctx): \Closure
    {
        return fn (Builder $q) => $q->where('o.customerId', $ctx->user['id'])->orWhere('o.customerEmail', $ctx->user['email']);
    }

    private static function ownsReservation(MobileCtx $ctx): \Closure
    {
        return fn (Builder $q) => $q->where('customerId', $ctx->user['id'])->orWhere('email', $ctx->user['email']);
    }

    /** Orders (+ items + session.payments) → orderView[] in the given row order. */
    private static function orderViews(\Illuminate\Support\Collection $orders): array
    {
        if ($orders->isEmpty()) {
            return [];
        }
        $items = DB::table('OrderItem')->whereIn('orderId', $orders->pluck('id')->all())->orderBy('id')->get()->groupBy('orderId');
        $sessionIds = $orders->pluck('sessionId')->filter()->unique()->values()->all();
        $sessions = $sessionIds ? DB::table('TableSession')->whereIn('id', $sessionIds)->get()->keyBy('id') : collect();
        $payments = $sessionIds ? DB::table('Payment')->whereIn('sessionId', $sessionIds)->get()->groupBy('sessionId') : collect();

        return $orders->map(function ($o) use ($items, $sessions, $payments) {
            $s = $o->sessionId ? ($sessions[$o->sessionId] ?? null) : null;
            $paid = 0;
            if ($s) {
                foreach ($payments[$s->id] ?? [] as $p) {
                    $paid += (float) $p->amount;
                }
            }
            $createdAt = Carbon::parse($o->createdAt, 'UTC');
            $scheduleDateIso = Iso::of($o->scheduleDate);

            $view = [
                'id' => $o->id,
                'number' => $o->number,
                'type' => $o->type,
                'status' => $o->status,
                'channel' => $o->channel,
                'total' => (float) $o->total,
                'paid' => $o->paymentMethod === 'ONLINE' || (bool) $o->razorpayPaymentId,
                'paymentProvider' => $o->paymentProvider,
                'scheduleType' => $o->scheduleType,
                'scheduleDate' => $scheduleDateIso,
                'scheduleTime' => $o->scheduleTime,
                'estimatedPickup' => $o->type === 'PICKUP'
                    ? Iso::of(Scheduling::estimatePickup($o->scheduleType, $scheduleDateIso ? substr($scheduleDateIso, 0, 10) : null, $o->scheduleTime, $createdAt))
                    : null,
                'tableNumber' => $o->tableNumber,
                'notes' => $o->notes,
                'items' => ($items[$o->id] ?? collect())->map(fn ($i) => ['name' => $i->name, 'qty' => (int) $i->qty, 'price' => (float) $i->price])->values()->all(),
                'session' => $s ? [
                    'id' => $s->id,
                    'status' => $s->status,
                    'total' => (float) $s->total,
                    'paid' => $paid,
                    'remaining' => max(0, Format::round(((float) $s->total - $paid) * 100) / 100),
                ] : null,
                'createdAt' => Iso::of($createdAt),
            ];

            // `?? undefined` / `?.toISOString()` keys vanish from JSON.stringify output
            return array_filter($view, fn ($v) => $v !== null);
        })->values()->all();
    }

    private static function orderQuery(): Builder
    {
        return DB::table('Order as o')->select('o.*');
    }

    private function router(): MobileRouter
    {
        return (new MobileRouter)
            // Home: restaurant info + live order / upcoming booking cards.
            ->add('GET', 'home', null, function (MobileCtx $ctx) {
                $active = self::orderQuery()->where(self::mine($ctx))->whereIn('o.status', self::ACTIVE_ORDER)
                    ->orderByDesc('o.createdAt')->limit(5)->get();
                // new Date(new Date().toDateString()) — today's local midnight
                $today = Format::now()->startOfDay()->utc();
                $upcoming = DB::table('Reservation')->where(self::ownsReservation($ctx))
                    ->whereIn('status', ['REQUESTED', 'CONFIRMED'])
                    ->where('date', '>=', $today->format('Y-m-d H:i:s.v'))
                    ->orderBy('date')->limit(3)->get();

                return [
                    'profile' => Queries::getProfile(),
                    'activeOrders' => self::orderViews($active),
                    'upcomingReservations' => $upcoming->map(fn ($r) => ReservationController::view($r))->all(),
                ];
            })

            // ---- Orders ----
            ->add('GET', 'orders', null, function (MobileCtx $ctx) {
                $rows = self::orderQuery()->where(self::mine($ctx))->orderByDesc('o.createdAt')->limit(100)->get();

                return ['orders' => self::orderViews($rows)];
            })
            ->add('GET', 'orders/:id', null, function (MobileCtx $ctx) {
                $o = self::orderQuery()->where(self::mine($ctx))->where('o.id', $ctx->params['id'])->limit(1)->get();
                if ($o->isEmpty()) {
                    throw new HttpError(404, 'Order not found');
                }

                return ['order' => self::orderViews($o)[0]];
            })
            // Place a Take Away or table (QR) order. `payAtRestaurant: true` skips the
            // online gateway; otherwise `payment` must carry a verified gateway result.
            ->add('POST', 'orders', null, function (MobileCtx $ctx) {
                $c = self::me($ctx);
                $body = $ctx->body();
                $bodyPhone = $body['phone'] ?? null;
                [$data, $issues] = Z::safeParse(Schemas::onlineOrder(), [
                    'name' => $c->name,
                    'email' => $c->email,
                    'phone' => $c->phone ?: ($bodyPhone ?: ''),
                ] + $body);
                if ($issues) {
                    return Json::error($issues[0]['message'] ?? 'Invalid order', 400, ['issues' => $issues]);
                }

                return OnlineOrder::placeOnlineOrder($data, ($body['payAtRestaurant'] ?? null) === true);
            })

            // ---- Reservations ----
            ->add('GET', 'reservations', null, function (MobileCtx $ctx) {
                $rows = DB::table('Reservation')->where(self::ownsReservation($ctx))->orderByDesc('date')->get();

                return ['reservations' => $rows->map(fn ($r) => ReservationController::view($r))->all()];
            })
            ->add('POST', 'reservations', null, function (MobileCtx $ctx) {
                $c = self::me($ctx);
                $body = $ctx->body();

                return ReservationController::create(array_merge($body, [
                    'name' => $c->name,
                    'email' => $c->email,
                    'phone' => $c->phone ?: (($body['phone'] ?? null) ?: ''),
                ]));
            })
            ->add('POST', 'reservations/:id/cancel', null, function (MobileCtx $ctx) {
                $r = DB::table('Reservation')->where('id', $ctx->params['id'])->where(self::ownsReservation($ctx))->first();
                if (! $r) {
                    throw new HttpError(404, 'Reservation not found');
                }
                if (! in_array($r->status, ['REQUESTED', 'CONFIRMED'], true)) {
                    throw new HttpError(422, 'This booking can no longer be cancelled');
                }
                DB::table('Reservation')->where('id', $r->id)->update(['status' => 'CANCELED', 'updatedAt' => now()->format('Y-m-d H:i:s.v')]);

                return ['reservation' => ReservationController::view(DB::table('Reservation')->where('id', $r->id)->first())];
            })

            // ---- Gift cards ----
            ->add('GET', 'gift-cards', null, function (MobileCtx $ctx) {
                $rows = DB::table('GiftCard')
                    ->where(fn (Builder $q) => $q->where('customerId', $ctx->user['id'])->orWhere('customerEmail', $ctx->user['email']))
                    ->orderByDesc('createdAt')->get();

                return ['giftCards' => $rows->map(fn ($g) => array_filter([
                    'id' => $g->id,
                    'code' => $g->code,
                    'kind' => $g->kind,
                    'amount' => (float) $g->amount,
                    'message' => $g->message,
                    'status' => $g->status,
                    'paymentStatus' => $g->paymentStatus,
                    'expiryDate' => Iso::of($g->expiryDate),
                    'createdAt' => Iso::of($g->createdAt),
                ], fn ($v) => $v !== null))->all()];
            })
            ->add('POST', 'gift-cards', null, function (MobileCtx $ctx) {
                $c = self::me($ctx);
                $body = Z::parse(Z::object([
                    'kind' => Z::default(Z::enum(['GIFT_CARD', 'COUPON']), 'GIFT_CARD'),
                    'amount' => Z::number(['coerce' => true, 'positive' => true]),
                    'message' => Z::optional(Z::string(['max' => [500]])),
                    'payment' => Z::optional(Z::unknown()),
                ]), $ctx->body());

                // The public flow links the card to the customer by email.
                return GiftCardController::purchase(array_merge($body, ['name' => $c->name, 'email' => $c->email]));
            })

            // ---- Table QR ----
            ->add('GET', 'tables/:code', null, function (MobileCtx $ctx) {
                $t = DB::table('Table')->where('code', $ctx->params['code'])->where('status', 'ACTIVE')->first();
                if (! $t) {
                    throw new HttpError(404, 'Table not found or not accepting orders');
                }

                return ['table' => array_filter(['id' => $t->id, 'number' => $t->number, 'name' => $t->name, 'code' => $t->code], fn ($v) => $v !== null)];
            });
    }
}
