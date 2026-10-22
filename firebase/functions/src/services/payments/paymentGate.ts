import type { PaymentResult } from '../zod';
import * as Razorpay from './razorpay';
import * as Stripe from './stripe';
import * as PayPal from './paypal';

/**
 * Unified payment gate across providers — port of Services/Payments/PaymentGate.php.
 * Routes call accepted() before fulfilling an order or issuing a gift card.
 */
export const configured = (): boolean => Razorpay.configured() || Stripe.configured() || PayPal.configured();

/** The reference id we persist for a verified payment (paymentRef). */
export function ref(payment: PaymentResult | null | undefined): string | null {
  if (!payment) return null;
  switch (payment.provider) {
    case 'razorpay':
      return payment.paymentId;
    case 'stripe':
      return payment.paymentIntentId;
    default:
      return (payment as { orderId?: string }).orderId ?? null; // paypal
  }
}

/**
 * Gate a paid action (paymentAccepted).
 *  - No gateway configured → allowed (dev/simulated fallback).
 *  - Configured → a valid, provider-verified payment is required.
 */
export async function accepted(payment: PaymentResult | null | undefined): Promise<{ ok: boolean; reason?: string; provider?: string; ref?: string }> {
  if (!configured()) return { ok: true };
  if (!payment) return { ok: false, reason: 'Payment required' };
  const fail = { ok: false, reason: 'Payment verification failed' };

  switch (payment.provider) {
    case 'razorpay':
      return Razorpay.verifySignature(payment.orderId, payment.paymentId, payment.signature) ? { ok: true, provider: 'razorpay', ref: payment.paymentId } : fail;
    case 'stripe':
      return (await Stripe.verifyPayment(payment.paymentIntentId)) ? { ok: true, provider: 'stripe', ref: payment.paymentIntentId } : fail;
    case 'paypal':
      return (await PayPal.verifyPayment(payment.orderId)) ? { ok: true, provider: 'paypal', ref: payment.orderId } : fail;
  }
  return { ok: false, reason: 'Unknown payment provider' };
}
