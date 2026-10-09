<?php

namespace App\Services\Payments;

use Illuminate\Support\Facades\Http;

/**
 * Stripe (server side) — port of admin/src/lib/stripe.ts. REST API directly (no SDK) with
 * the Secret Key. The browser confirms the PaymentIntent; the server verifies `succeeded`.
 */
final class Stripe
{
    private static function secret(): string
    {
        return (string) config('go4foodie.stripe.secret_key');
    }

    public static function publishableKey(): string
    {
        return (string) config('go4foodie.stripe.publishable_key');
    }

    private static function currency(): string
    {
        return strtolower((string) config('go4foodie.stripe.currency'));
    }

    public static function configured(): bool
    {
        return self::secret() !== '' && self::publishableKey() !== '';
    }

    /**
     * Create a PaymentIntent. `amount` is in major units (e.g. 49.99).
     *
     * @return array{paymentIntentId:string,clientSecret:string}
     */
    public static function createPaymentIntent(float $amount, string $description): array
    {
        $res = Http::withToken(self::secret())
            ->asForm()
            ->post('https://api.stripe.com/v1/payment_intents', [
                'amount' => (string) (int) round($amount * 100),
                'currency' => self::currency(),
                'description' => $description,
                'automatic_payment_methods[enabled]' => 'true',
            ]);
        if (! $res->successful()) {
            throw new \RuntimeException("Stripe intent failed ({$res->status()}): {$res->body()}");
        }
        $pi = $res->json();

        return ['paymentIntentId' => $pi['id'], 'clientSecret' => $pi['client_secret']];
    }

    /** Verify a PaymentIntent reached `succeeded` (retrieved fresh from Stripe). */
    public static function verifyPayment(string $paymentIntentId): bool
    {
        if (self::secret() === '' || $paymentIntentId === '') {
            return false;
        }
        try {
            $res = Http::withToken(self::secret())
                ->get('https://api.stripe.com/v1/payment_intents/'.rawurlencode($paymentIntentId));
        } catch (\Throwable) {
            return false;
        }

        return $res->successful() && $res->json('status') === 'succeeded';
    }
}
