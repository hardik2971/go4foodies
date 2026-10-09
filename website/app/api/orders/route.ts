import { NextResponse } from 'next/server';
import { ADMIN_API_URL } from '@/lib/admin-api';

// POST /api/orders — proxy the storefront's online order to the admin API so
// it syncs into the Orders module + dashboard. Keeps the browser same-origin.
export async function POST(req: Request) {
  const body = await req.text();
  try {
    const res = await fetch(`${ADMIN_API_URL}/api/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body,
      cache: 'no-store',
    });
    const data = await res.json().catch(() => ({ error: 'Unexpected response from server' }));
    return NextResponse.json(data, { status: res.status });
  } catch (err) {
    console.error('Order proxy failed', err);
    return NextResponse.json(
      { error: 'Ordering is temporarily unavailable. Please try again shortly.' },
      { status: 502 },
    );
  }
}
