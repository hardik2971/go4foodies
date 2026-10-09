import { NextResponse } from 'next/server';
import { ADMIN_API_URL } from '@/lib/admin-api';

// GET /api/payment — proxy the configured-gateways check (drives the chooser).
export async function GET() {
  const none = { razorpay: false, stripe: false, paypal: false };
  try {
    const res = await fetch(`${ADMIN_API_URL}/api/payment`, { cache: 'no-store' });
    const data = await res.json().catch(() => none);
    return NextResponse.json(data, { status: res.status });
  } catch {
    return NextResponse.json(none);
  }
}

// POST /api/payment — proxy gateway order/intent creation to the admin (which
// holds the secrets). Returns the public key + order/client secret for checkout.
export async function POST(req: Request) {
  const body = await req.text();
  try {
    const res = await fetch(`${ADMIN_API_URL}/api/payment`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body,
      cache: 'no-store',
    });
    const data = await res.json().catch(() => ({ error: 'Unexpected response from server' }));
    return NextResponse.json(data, { status: res.status });
  } catch (err) {
    console.error('Payment proxy failed', err);
    return NextResponse.json({ error: 'Payment is temporarily unavailable.' }, { status: 502 });
  }
}
