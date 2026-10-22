import { z } from 'zod';

/**
 * Public + mobile API schemas — Api/Support/Schemas.php (a hand-rolled zod v3 look-alike, Z.php)
 * mapped back to real zod v3: same rules, defaults and messages, so 400 bodies keep the exact
 * `{error, issues}` shape of the Next.js admin.
 */

/** schemas/order.ts paymentSchema (optional union). */
export const paymentSchema = z
  .union([
    z.object({ provider: z.literal('razorpay'), orderId: z.string(), paymentId: z.string(), signature: z.string() }),
    z.object({ provider: z.literal('stripe'), paymentIntentId: z.string() }),
    z.object({ provider: z.literal('paypal'), orderId: z.string() }),
  ])
  .optional();
export type PaymentResult = NonNullable<z.infer<typeof paymentSchema>>;

const orderItemSchema = z.object({
  menuItemId: z.string().min(1),
  name: z.string().optional(),
  qty: z.coerce.number().int().min(1).max(50),
});

/** z.string().email().optional().or(z.literal('')) */
const optionalEmailOrEmpty = () => z.string().email().optional().or(z.literal(''));

/** schemas/order.ts onlineOrderSchema (discriminated on `type`). */
export const onlineOrderSchema = z.discriminatedUnion('type', [
  z.object({
    type: z.literal('TAKE_AWAY'),
    scheduleType: z.enum(['NOW', 'LATER']),
    scheduleDate: z.string().optional(),
    scheduleTime: z.string().optional(),
    items: z.array(orderItemSchema).min(1, 'Add at least one item'),
    name: z.string().min(2),
    email: z.string().email(),
    phone: z.string().min(5),
    notes: z.string().max(500).optional(),
    payment: paymentSchema,
  }),
  z.object({
    type: z.literal('DINE_IN'),
    tableCode: z.string().min(1),
    items: z.array(orderItemSchema).min(1, 'Add at least one item'),
    name: z.string().min(1),
    email: optionalEmailOrEmpty(),
    phone: z.string().optional().or(z.literal('')),
    notes: z.string().max(500).optional(),
    payment: paymentSchema,
  }),
]);
export type OnlineOrderInput = z.infer<typeof onlineOrderSchema>;

/** schemas/reservation.ts reservationSchema (discriminated on `kind`). */
export const reservationSchema = z.discriminatedUnion('kind', [
  z.object({
    kind: z.literal('TABLE'),
    date: z.string().min(1),
    time: z.string().min(1),
    guests: z.coerce.number().int().min(1),
    name: z.string().min(2),
    email: z.string().email(),
    phone: z.string().min(5),
    occasion: z.string().optional(),
    requests: z.string().optional(),
  }),
  z.object({
    kind: z.literal('PRIVATE_EVENT'),
    eventType: z.string().min(1),
    date: z.string().min(1),
    guestRange: z.string().min(1),
    space: z.string().min(1),
    name: z.string().min(2),
    email: z.string().email(),
    phone: z.string().min(5),
    company: z.string().optional(),
    message: z.string().optional(),
  }),
]);
export type ReservationInput = z.infer<typeof reservationSchema>;

/** schemas/giftcard.ts giftCardPurchaseSchema. */
export const giftCardPurchaseSchema = z.object({
  kind: z.enum(['GIFT_CARD', 'COUPON']).default('GIFT_CARD'),
  amount: z.coerce.number().positive('Choose an amount').max(100000),
  name: z.string().min(2, 'Name is required'),
  email: optionalEmailOrEmpty(),
  message: z.string().max(500).optional(),
  payment: paymentSchema,
});
export type GiftCardPurchaseInput = z.infer<typeof giftCardPurchaseSchema>;

/** Z::safeParse — [data, null] or [null, issues] (zod issue objects, as the 400 bodies carry them). */
export function safeParse<S extends z.ZodTypeAny>(schema: S, value: unknown): [z.output<S>, null] | [null, z.ZodIssue[]] {
  const r = schema.safeParse(value ?? null);
  return r.success ? [r.data, null] : [null, r.error.issues];
}

export { z };
