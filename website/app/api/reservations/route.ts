import { NextResponse } from 'next/server';
import { ADMIN_API_URL } from '@/lib/admin-api';

// POST /api/reservations — proxy a dine-in (or private event) booking to the
// admin API so it appears in the admin Reservations module immediately.
export async function POST(req: Request) {
  const body = await req.text();
  try {
    const res = await fetch(`${ADMIN_API_URL}/api/reservations`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body,
      cache: 'no-store',
    });
    const data = await res.json().catch(() => ({ error: 'Unexpected response from server' }));
    return NextResponse.json(data, { status: res.status });
  } catch (err) {
    console.error('Reservation proxy failed', err);
    return NextResponse.json(
      { error: 'Reservations are temporarily unavailable. Please try again shortly.' },
      { status: 502 },
    );
  }
}
