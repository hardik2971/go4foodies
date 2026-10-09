<?php

namespace App\Services\Payments;

use Illuminate\Support\Facades\Http;

/**
 * PayPal (server side) — port of admin/src/lib/paypal.ts. Orders v2 REST API with OAuth2
 * client-credentials. Sandbox by default; PAYPAL_ENV=live for production.
 */
final class PayPal
{
    public static function clientId(): string
    {
        return (string) config('go4foodie.paypal.client_id');
    }

    private static function clientSecret(): string
    {
        return (string) config('go4foodie.paypal.client_secret');
    }

    public static function currency(): string
    {
        return strtoupper((string) config('go4foodie.paypal.currency'));
    }

    private static function base(): string
    {
        return strtolower((string) config('go4foodie.paypal.env')) === 'live'
            ? 'https://api-m.paypal.com'
            : 'https://api-m.sandbox.paypal.com';
    }

    public static function configured(): bool
    {
        return self::clientId() !== '' && self::clientSecret() !== '';
    }

    private static function accessToken(): string
    {
        $res = Http::withBasicAuth(self::clientId(), self::clientSecret())
            ->asForm()
            ->post(self::base().'/v1/oauth2/token', ['grant_type' => 'client_credentials']);
        if (! $res->successful()) {
            throw new \RuntimeException("PayPal auth failed ({$res->status()}): {$res->body()}");
        }

        return (string) $res->json('access_token');
    }

    /**
     * Create a PayPal order. `amount` is in major units.
     *
     * @return array{orderId:string}
     */
    public static function createOrder(float $amount, string $description): array
    {
        $token = self::accessToken();
        $res = Http::withToken($token)->asJson()->post(self::base().'/v2/checkout/orders', [
            'intent' => 'CAPTURE',
            'purchase_units' => [[
                // JS amount.toFixed(2)
                'amount' => ['currency_code' => self::currency(), 'value' => number_format($amount, 2, '.', '')],
                'description' => mb_substr($description, 0, 127),
            ]],
        ]);
        if (! $res->successful()) {
            throw new \RuntimeException("PayPal order failed ({$res->status()}): {$res->body()}");
        }

        return ['orderId' => (string) $res->json('id')];
    }

    /**
     * Capture an approved PayPal order. Returns its final status (COMPLETED on success).
     *
     * @return array{status:string}
     */
    public static function captureOrder(string $orderId): array
    {
        $token = self::accessToken();
        $res = Http::withToken($token)
            ->withBody('', 'application/json')
            ->post(self::base().'/v2/checkout/orders/'.rawurlencode($orderId).'/capture');
        if (! $res->successful()) {
            throw new \RuntimeException("PayPal capture failed ({$res->status()}): {$res->body()}");
        }

        return ['status' => (string) $res->json('status')];
    }

    /** Verify an order reached COMPLETED (retrieved fresh from PayPal). */
    public static function verifyPayment(string $orderId): bool
    {
        if (! self::configured() || $orderId === '') {
            return false;
        }
        try {
            $token = self::accessToken();
            $res = Http::withToken($token)->get(self::base().'/v2/checkout/orders/'.rawurlencode($orderId));

            return $res->successful() && $res->json('status') === 'COMPLETED';
        } catch (\Throwable) {
            return false;
        }
    }
}
