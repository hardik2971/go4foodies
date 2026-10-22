import { basic, env, phpRound, rawurlencode, request } from './util';

/**
 * PayPal (server side) — port of Services/Payments/PayPal.php. Orders v2 REST API with OAuth2
 * client-credentials. Sandbox by default; PAYPAL_ENV=live for production.
 */
export const clientId = (): string => env('PAYPAL_CLIENT_ID');
const clientSecret = (): string => env('PAYPAL_CLIENT_SECRET');
export const currency = (): string => env('PAYPAL_CURRENCY', 'USD').toUpperCase();
const base = (): string => (env('PAYPAL_ENV', 'sandbox').toLowerCase() === 'live' ? 'https://api-m.paypal.com' : 'https://api-m.sandbox.paypal.com');

export const configured = (): boolean => clientId() !== '' && clientSecret() !== '';

async function accessToken(): Promise<string> {
  const res = await request(base() + '/v1/oauth2/token', {
    method: 'POST',
    headers: { Authorization: basic(clientId(), clientSecret()), 'Content-Type': 'application/x-www-form-urlencoded', Accept: 'application/json' },
    body: new URLSearchParams({ grant_type: 'client_credentials' }).toString(),
  });
  if (!res.ok) throw new Error(`PayPal auth failed (${res.status}): ${res.body}`);
  return String(res.json?.access_token ?? '');
}

/** Create a PayPal order. `amount` is in major units. */
export async function createOrder(amount: number, description: string): Promise<{ orderId: string }> {
  const token = await accessToken();
  const res = await request(base() + '/v2/checkout/orders', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json', Accept: 'application/json' },
    body: JSON.stringify({
      intent: 'CAPTURE',
      purchase_units: [
        {
          // JS amount.toFixed(2) (number_format in the PHP port)
          amount: { currency_code: currency(), value: (phpRound(amount * 100) / 100).toFixed(2) },
          description: Array.from(description).slice(0, 127).join(''),
        },
      ],
    }),
  });
  if (!res.ok) throw new Error(`PayPal order failed (${res.status}): ${res.body}`);
  return { orderId: String(res.json?.id ?? '') };
}

/** Capture an approved PayPal order. Returns its final status (COMPLETED on success). */
export async function captureOrder(orderId: string): Promise<{ status: string }> {
  const token = await accessToken();
  const res = await request(base() + '/v2/checkout/orders/' + rawurlencode(orderId) + '/capture', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json', Accept: 'application/json' },
    body: '',
  });
  if (!res.ok) throw new Error(`PayPal capture failed (${res.status}): ${res.body}`);
  return { status: String(res.json?.status ?? '') };
}

/** Verify an order reached COMPLETED (retrieved fresh from PayPal). */
export async function verifyPayment(orderId: string): Promise<boolean> {
  if (!configured() || orderId === '') return false;
  try {
    const token = await accessToken();
    const res = await request(base() + '/v2/checkout/orders/' + rawurlencode(orderId), {
      headers: { Authorization: `Bearer ${token}`, Accept: 'application/json' },
    });
    return res.ok && res.json?.status === 'COMPLETED';
  } catch {
    return false;
  }
}
