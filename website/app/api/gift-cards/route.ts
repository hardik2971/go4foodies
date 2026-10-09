import { NextResponse } from 'next/server';
import { ADMIN_API_URL } from '@/lib/admin-api';

// POST /api/gift-cards — proxy a gift card / coupon purchase to the admin API
// so it generates a code, stores the purchase, and emails a confirmation.
export async function POST(req: Request) {
  const body = await req.text();
  try {
    const res = await fetch(`${ADMIN_API_URL}/api/gift-cards`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body,
      cache: 'no-store',
    });
    const data = await res.json().catch(() => ({ error: 'Unexpected response from server' }));
    return NextResponse.json(data, { status: res.status });
  } catch (err) {
    console.error('Gift card proxy failed', err);
    return NextResponse.json(
      { error: 'Gift cards are temporarily unavailable. Please try again shortly.' },
      { status: 502 },
    );
  }
}
