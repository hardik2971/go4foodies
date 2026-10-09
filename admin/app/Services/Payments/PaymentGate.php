<?php

namespace App\Services\Payments;

/**
 * Unified payment gate across providers — port of admin/src/lib/payment.ts.
 * Routes call accepted() before fulfilling an order or issuing a gift card.
 *
 * $payment is the parsed paymentSchema value:
 *   {provider:'razorpay', orderId, paymentId, signature} | {provider:'stripe', paymentIntentId} | {provider:'paypal', orderId}
 */
final class PaymentGate
{
    public static function configured(): bool
    {
        return Razorpay::configured() || Stripe::configured() || PayPal::configured();
    }

    /** The reference id we persist for a verified payment (paymentRef). */
    public static function ref(?array $payment): ?string
    {
        if (! $payment) {
            return null;
        }

        return match ($payment['provider'] ?? null) {
            'razorpay' => $payment['paymentId'],
            'stripe' => $payment['paymentIntentId'],
            default => $payment['orderId'] ?? null, // paypal
        };
    }

    /**
     * Gate a paid action (paymentAccepted).
     *  - No gateway configured → allowed (dev/simulated fallback).
     *  - Configured → a valid, provider-verified payment is required.
     *
     * @return array{ok:bool, reason?:string, provider?:string, ref?:string}
     */
    public static function accepted(?array $payment): array
    {
        if (! self::configured()) {
            return ['ok' => true];
        }
        if (! $payment) {
            return ['ok' => false, 'reason' => 'Payment required'];
        }
        $fail = ['ok' => false, 'reason' => 'Payment verification failed'];

        switch ($payment['provider'] ?? null) {
            case 'razorpay':
                return Razorpay::verifySignature($payment['orderId'], $payment['paymentId'], $payment['signature'])
                    ? ['ok' => true, 'provider' => 'razorpay', 'ref' => $payment['paymentId']] : $fail;
            case 'stripe':
                return Stripe::verifyPayment($payment['paymentIntentId'])
                    ? ['ok' => true, 'provider' => 'stripe', 'ref' => $payment['paymentIntentId']] : $fail;
            case 'paypal':
                return PayPal::verifyPayment($payment['orderId'])
                    ? ['ok' => true, 'provider' => 'paypal', 'ref' => $payment['orderId']] : $fail;
        }

        return ['ok' => false, 'reason' => 'Unknown payment provider'];
    }
}
