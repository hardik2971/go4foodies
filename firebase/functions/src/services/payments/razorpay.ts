import { createHmac, timingSafeEqual } from 'node:crypto';
import { basic, env, phpRound, request } from './util';

/**
 * Razorpay (server side) — port of Services/Payments/Razorpay.php. Order creation + signature
 * verification use the Key Secret, which must NEVER reach the browser.
 */
export const keyId = (): string => env('RAZORPAY_KEY_ID');
const secret = (): string => env('RAZORPAY_KEY_SECRET');
const currency = (): string => env('RAZORPAY_CURRENCY', 'INR');

export const configured = (): boolean => keyId() !== '' && secret() !== '';

/** Create a Razorpay order. `amount` is in major units (e.g. 49.99). */
export async function createOrder(amount: number, receipt: string): Promise<{ id: string; amount: number; currency: string }> {
  const res = await request('https://api.razorpay.com/v1/orders', {
    method: 'POST',
    headers: { Authorization: basic(keyId(), secret()), 'Content-Type': 'application/json', Accept: 'application/json' },
    body: JSON.stringify({ amount: phpRound(amount * 100), currency: currency(), receipt }),
  });
  if (!res.ok) throw new Error(`Razorpay order failed (${res.status}): ${res.body}`);
  const d = res.json;
  return { id: d.id, amount: d.amount, currency: d.currency };
}

/** Verify the checkout signature: HMAC_SHA256(order_id|payment_id, secret). */
export function verifySignature(orderId: string, paymentId: string, signature: string): boolean {
  const s = secret();
  if (s === '' || orderId === '' || paymentId === '' || signature === '') return false;
  const expected = Buffer.from(createHmac('sha256', s).update(`${orderId}|${paymentId}`).digest('hex'));
  const given = Buffer.from(signature);
  return given.length === expected.length && timingSafeEqual(expected, given);
}
