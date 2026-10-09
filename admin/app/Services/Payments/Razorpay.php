<?php

namespace App\Services\Payments;

use Illuminate\Support\Facades\Http;

/**
 * Razorpay (server side) — port of admin/src/lib/razorpay.ts. Order creation + signature
 * verification use the Key Secret, which must NEVER reach the browser.
 */
final class Razorpay
{
    public static function keyId(): string
    {
        return (string) config('go4foodie.razorpay.key_id');
    }

    private static function secret(): string
    {
        return (string) config('go4foodie.razorpay.key_secret');
    }

    private static function currency(): string
    {
        return (string) config('go4foodie.razorpay.currency');
    }

    public static function configured(): bool
    {
        return self::keyId() !== '' && self::secret() !== '';
    }

    /**
     * Create a Razorpay order. `amount` is in major units (e.g. 49.99).
     *
     * @return array{id:string,amount:int,currency:string}
     */
    public static function createOrder(float $amount, string $receipt): array
    {
        $res = Http::withBasicAuth(self::keyId(), self::secret())
            ->asJson()
            ->post('https://api.razorpay.com/v1/orders', [
                'amount' => (int) round($amount * 100),
                'currency' => self::currency(),
                'receipt' => $receipt,
            ]);
        if (! $res->successful()) {
            throw new \RuntimeException("Razorpay order failed ({$res->status()}): {$res->body()}");
        }
        $d = $res->json();

        return ['id' => $d['id'], 'amount' => $d['amount'], 'currency' => $d['currency']];
    }

    /** Verify the checkout signature: HMAC_SHA256(order_id|payment_id, secret). */
    public static function verifySignature(string $orderId, string $paymentId, string $signature): bool
    {
        $secret = self::secret();
        if ($secret === '' || $orderId === '' || $paymentId === '' || $signature === '') {
            return false;
        }
        $expected = hash_hmac('sha256', "$orderId|$paymentId", $secret);

        return hash_equals($expected, $signature);
    }
}
