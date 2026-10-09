import { NextResponse } from 'next/server';
import { ADMIN_API_URL } from '@/lib/admin-api';

// POST /api/payment/capture — proxy PayPal order capture to the admin.
export async function POST(req: Request) {
  const body = await req.text();
  try {
    const res = await fetch(`${ADMIN_API_URL}/api/payment/capture`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body,
      cache: 'no-store',
    });
    const data = await res.json().catch(() => ({ error: 'Unexpected response from server' }));
    return NextResponse.json(data, { status: res.status });
  } catch (err) {
    console.error('Capture proxy failed', err);
    return NextResponse.json({ error: 'Payment is temporarily unavailable.' }, { status: 502 });
  }
}
