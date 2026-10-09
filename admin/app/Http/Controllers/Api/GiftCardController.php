<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Api\Support\Body;
use App\Http\Controllers\Api\Support\Json;
use App\Http\Controllers\Api\Support\Schemas;
use App\Http\Controllers\Api\Support\Z;
use App\Http\Controllers\Controller;
use App\Models\Customer;
use App\Models\GiftCard;
use App\Services\Mailer;
use App\Services\Payments\PaymentGate;
use App\Support\Format;
use Illuminate\Http\Request;

/** POST /api/gift-cards — the public website's gift card / coupon purchase flow. */
class GiftCardController extends Controller
{
    private static function genCode(string $kind): string
    {
        $prefix = $kind === 'COUPON' ? 'COUPON' : 'GIFT';
        $alphabet = '0123456789ABCDEFGHJKMNPQRSTUVWXYZ';
        $body = '';
        for ($i = 0; $i < 6; $i++) {
            $body .= $alphabet[random_int(0, 32)];
        }

        return "$prefix-$body";
    }

    public function store(Request $req)
    {
        return self::purchase(Body::json($req));
    }

    /** Shared with the Customer app (/api/mobile/customer/gift-cards). */
    public static function purchase(mixed $body)
    {
        [$data, $issues] = Z::safeParse(Schemas::giftCardPurchase(), $body);
        if ($issues) {
            return Json::error('Invalid purchase', 400, ['issues' => $issues]);
        }
        $email = ($data['email'] ?? '') ?: '';
        $payment = $data['payment'] ?? null;

        // Payment gate (enforced once a gateway is configured).
        $pay = PaymentGate::accepted($payment);
        if (! $pay['ok']) {
            return Json::error($pay['reason'] ?? 'Payment required', 402);
        }

        try {
            // Coupons expire in a year; gift cards never expire.
            $expiryDate = $data['kind'] === 'COUPON' ? now()->addMilliseconds(365 * 24 * 60 * 60 * 1000) : null;

            // Link/create a customer when we have an email.
            $customerId = null;
            if ($email) {
                $c = Customer::where('email', $email)->first();
                if ($c) {
                    $c->name = $data['name'];
                    $c->updatedAt = now();
                    $c->save();
                } else {
                    $c = Customer::create(['name' => $data['name'], 'email' => $email]);
                }
                $customerId = $c->id;
            }

            // Generate a unique code (retry on the rare collision).
            $created = null;
            for ($attempt = 0; $attempt < 5 && ! $created; $attempt++) {
                try {
                    $created = GiftCard::create([
                        'code' => self::genCode($data['kind']),
                        'kind' => $data['kind'],
                        'customerName' => $data['name'],
                        'customerEmail' => $email,
                        'customerId' => $customerId,
                        'amount' => $data['amount'],
                        'message' => $data['message'] ?? null,
                        'expiryDate' => $expiryDate,
                        'paymentStatus' => 'PAID',
                        'paymentProvider' => $payment['provider'] ?? null,
                        'razorpayPaymentId' => PaymentGate::ref($payment),
                        'status' => 'ACTIVE',
                    ]);
                } catch (\Illuminate\Database\QueryException) {
                    // unique-constraint collision on code → retry
                }
            }
            if (! $created) {
                return Json::error('Could not generate a code, please retry', 503);
            }

            if ($email) {
                try {
                    $mail = Mailer::giftCardConfirmationEmail(array_filter([
                        'code' => $created->code,
                        'kind' => $data['kind'],
                        'amount' => $data['amount'],
                        'name' => $data['name'],
                        'message' => $data['message'] ?? null,
                        'expiryLabel' => $expiryDate ? Format::local($expiryDate)->format('M j, Y') : null,
                    ], fn ($v) => $v !== null));
                    Mailer::sendMail(['to' => $email, 'subject' => $mail['subject'], 'html' => $mail['html'], 'text' => $mail['text']]);
                } catch (\Throwable $mailErr) {
                    report($mailErr);
                }
            }

            return Json::response(['code' => $created->code, 'id' => $created->id, 'amount' => $data['amount'], 'kind' => $data['kind']], 201);
        } catch (\Throwable $e) {
            report($e);

            return Json::error('Could not complete purchase', 503);
        }
    }
}
