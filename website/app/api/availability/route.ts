import { NextResponse } from 'next/server';
import { ADMIN_API_URL } from '@/lib/admin-api';

// GET /api/availability?date=YYYY-MM-DD — proxy dine-in slot availability from
// the admin API so the storefront only offers bookable 30-minute slots.
export async function GET(req: Request) {
  const { searchParams } = new URL(req.url);
  const date = searchParams.get('date') ?? '';
  try {
    const res = await fetch(
      `${ADMIN_API_URL}/api/reservations/availability?date=${encodeURIComponent(date)}`,
      { cache: 'no-store' },
    );
    const data = await res.json().catch(() => ({ error: 'Unexpected response from server' }));
    return NextResponse.json(data, { status: res.status });
  } catch (err) {
    console.error('Availability proxy failed', err);
    return NextResponse.json({ error: 'Availability unavailable' }, { status: 502 });
  }
}
