<?php

namespace App\Http\Controllers\Api\Support;

/** Ports of admin/src/schemas/*.ts used by the public + mobile API (zod v3 semantics). */
final class Schemas
{
    /** schemas/order.ts paymentSchema (optional union). */
    public static function payment(): \Closure
    {
        return Z::optional(Z::union([
            Z::object(['provider' => Z::literal('razorpay'), 'orderId' => Z::string(), 'paymentId' => Z::string(), 'signature' => Z::string()]),
            Z::object(['provider' => Z::literal('stripe'), 'paymentIntentId' => Z::string()]),
            Z::object(['provider' => Z::literal('paypal'), 'orderId' => Z::string()]),
        ]));
    }

    private static function orderItem(): \Closure
    {
        return Z::object([
            'menuItemId' => Z::string(['min' => [1]]),
            'name' => Z::optional(Z::string()),
            'qty' => Z::number(['coerce' => true, 'int' => true, 'min' => [1], 'max' => [50]]),
        ]);
    }

    /** z.string().email().optional().or(z.literal('')) */
    private static function optionalEmailOrEmpty(): \Closure
    {
        return Z::union([Z::optional(Z::string(['email' => null])), Z::literal('')]);
    }

    /** schemas/order.ts onlineOrderSchema (discriminated on `type`). */
    public static function onlineOrder(): \Closure
    {
        return Z::discriminated('type', [
            'TAKE_AWAY' => Z::object([
                'type' => Z::literal('TAKE_AWAY'),
                'scheduleType' => Z::enum(['NOW', 'LATER']),
                'scheduleDate' => Z::optional(Z::string()),
                'scheduleTime' => Z::optional(Z::string()),
                'items' => Z::array(self::orderItem(), [1, 'Add at least one item']),
                'name' => Z::string(['min' => [2]]),
                'email' => Z::string(['email' => null]),
                'phone' => Z::string(['min' => [5]]),
                'notes' => Z::optional(Z::string(['max' => [500]])),
                'payment' => self::payment(),
            ]),
            'DINE_IN' => Z::object([
                'type' => Z::literal('DINE_IN'),
                'tableCode' => Z::string(['min' => [1]]),
                'items' => Z::array(self::orderItem(), [1, 'Add at least one item']),
                'name' => Z::string(['min' => [1]]),
                'email' => self::optionalEmailOrEmpty(),
                'phone' => Z::union([Z::optional(Z::string()), Z::literal('')]),
                'notes' => Z::optional(Z::string(['max' => [500]])),
                'payment' => self::payment(),
            ]),
        ]);
    }

    /** schemas/reservation.ts reservationSchema (discriminated on `kind`). */
    public static function reservation(): \Closure
    {
        return Z::discriminated('kind', [
            'TABLE' => Z::object([
                'kind' => Z::literal('TABLE'),
                'date' => Z::string(['min' => [1]]),
                'time' => Z::string(['min' => [1]]),
                'guests' => Z::number(['coerce' => true, 'int' => true, 'min' => [1]]),
                'name' => Z::string(['min' => [2]]),
                'email' => Z::string(['email' => null]),
                'phone' => Z::string(['min' => [5]]),
                'occasion' => Z::optional(Z::string()),
                'requests' => Z::optional(Z::string()),
            ]),
            'PRIVATE_EVENT' => Z::object([
                'kind' => Z::literal('PRIVATE_EVENT'),
                'eventType' => Z::string(['min' => [1]]),
                'date' => Z::string(['min' => [1]]),
                'guestRange' => Z::string(['min' => [1]]),
                'space' => Z::string(['min' => [1]]),
                'name' => Z::string(['min' => [2]]),
                'email' => Z::string(['email' => null]),
                'phone' => Z::string(['min' => [5]]),
                'company' => Z::optional(Z::string()),
                'message' => Z::optional(Z::string()),
            ]),
        ]);
    }

    /** schemas/giftcard.ts giftCardPurchaseSchema. */
    public static function giftCardPurchase(): \Closure
    {
        return Z::object([
            'kind' => Z::default(Z::enum(['GIFT_CARD', 'COUPON']), 'GIFT_CARD'),
            'amount' => Z::number(['coerce' => true, 'positive' => 'Choose an amount', 'max' => [100000]]),
            'name' => Z::string(['min' => [2, 'Name is required']]),
            'email' => self::optionalEmailOrEmpty(),
            'message' => Z::optional(Z::string(['max' => [500]])),
            'payment' => self::payment(),
        ]);
    }
}
