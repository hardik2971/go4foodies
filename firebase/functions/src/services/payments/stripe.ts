import { env, phpRound, rawurlencode, request } from './util';

/**
 * Stripe (server side) — port of Services/Payments/Stripe.php. REST API directly (no SDK) with
 * the Secret Key. The browser confirms the PaymentIntent; the server verifies `succeeded`.
 */
const secret = (): string => env('STRIPE_SECRET_KEY');
export const publishableKey = (): string => env('STRIPE_PUBLISHABLE_KEY');
const currency = (): string => env('STRIPE_CURRENCY', 'usd').toLowerCase();

export const configured = (): boolean => secret() !== '' && publishableKey() !== '';

/** Create a PaymentIntent. `amount` is in major units (e.g. 49.99). */
export async function createPaymentIntent(amount: number, description: string): Promise<{ paymentIntentId: string; clientSecret: string }> {
  const res = await request('https://api.stripe.com/v1/payment_intents', {
    method: 'POST',
    headers: { Authorization: `Bearer ${secret()}`, 'Content-Type': 'application/x-www-form-urlencoded', Accept: 'application/json' },
    body: new URLSearchParams({
      amount: String(phpRound(amount * 100)),
      currency: currency(),
      description,
      'automatic_payment_methods[enabled]': 'true',
    }).toString(),
  });
  if (!res.ok) throw new Error(`Stripe intent failed (${res.status}): ${res.body}`);
  return { paymentIntentId: res.json.id, clientSecret: res.json.client_secret };
}

/** Verify a PaymentIntent reached `succeeded` (retrieved fresh from Stripe). */
export async function verifyPayment(paymentIntentId: string): Promise<boolean> {
  if (secret() === '' || paymentIntentId === '') return false;
  try {
    const res = await request('https://api.stripe.com/v1/payment_intents/' + rawurlencode(paymentIntentId), {
      headers: { Authorization: `Bearer ${secret()}`, Accept: 'application/json' },
    });
    return res.ok && res.json?.status === 'succeeded';
  } catch {
    return false;
  }
}
