<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Api\Support\Body;
use App\Http\Controllers\Api\Support\Json;
use App\Http\Controllers\Api\Support\Z;
use App\Http\Controllers\Controller;
use App\Services\Payments\PayPal;
use App\Services\Payments\Razorpay;
use App\Services\Payments\Stripe;
use Illuminate\Http\Request;

/** /api/payment (+ /capture) — port of app/api/payment/**. */
class PaymentController extends Controller
{
    /** GET /api/payment — which gateways are configured (drives the storefront chooser). */
    public function index()
    {
        return Json::noStore([
            'razorpay' => Razorpay::configured(),
            'stripe' => Stripe::configured(),
            'paypal' => PayPal::configured(),
        ]);
    }

    /** POST /api/payment — start a payment with the chosen provider. */
    public function store(Request $req)
    {
        $body = Body::json($req);
        $b = is_array($body) ? $body : [];
        $provider = ($b['provider'] ?? null) === 'stripe' ? 'stripe' : (($b['provider'] ?? null) === 'paypal' ? 'paypal' : 'razorpay');
        $amount = Z::jsNumber(array_key_exists('amount', $b) ? $b['amount'] : Z::$U);
        $description = is_string($b['description'] ?? null) ? $b['description'] : 'Order payment';

        if (! ($amount > 0)) {
            return Json::error('Invalid amount', 400);
        }

        try {
            if ($provider === 'stripe') {
                if (! Stripe::configured()) {
                    return Json::error('Stripe not configured', 503);
                }
                $intent = Stripe::createPaymentIntent((float) $amount, $description);

                return Json::noStore(['provider' => 'stripe', 'publishableKey' => Stripe::publishableKey(), 'clientSecret' => $intent['clientSecret']]);
            }

            if ($provider === 'paypal') {
                if (! PayPal::configured()) {
                    return Json::error('PayPal not configured', 503);
                }
                $order = PayPal::createOrder((float) $amount, $description);

                return Json::noStore(['provider' => 'paypal', 'clientId' => PayPal::clientId(), 'orderId' => $order['orderId'], 'currency' => PayPal::currency()]);
            }

            if (! Razorpay::configured()) {
                return Json::error('Razorpay not configured', 503);
            }
            $order = Razorpay::createOrder((float) $amount, 'rcpt_'.(int) floor(microtime(true) * 1000));

            return Json::noStore(['provider' => 'razorpay', 'keyId' => Razorpay::keyId(), 'orderId' => $order['id'], 'amount' => $order['amount'], 'currency' => $order['currency']]);
        } catch (\Throwable $e) {
            report($e);

            return Json::error('Could not start payment', 502);
        }
    }

    /** POST /api/payment/capture — capture an approved PayPal order. */
    public function capture(Request $req)
    {
        if (! PayPal::configured()) {
            return Json::error('PayPal not configured', 503);
        }
        $body = Body::json($req);
        $orderId = is_array($body) && is_string($body['orderId'] ?? null) ? $body['orderId'] : '';
        if ($orderId === '') {
            return Json::error('Missing orderId', 400);
        }
        try {
            $result = PayPal::captureOrder($orderId);

            return Json::noStore(['status' => $result['status']]);
        } catch (\Throwable $e) {
            report($e);

            return Json::error('Could not capture payment', 502);
        }
    }
}
