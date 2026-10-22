import { randomInt } from 'node:crypto';
import type { DateTime } from 'luxon';
import { C, db, iso, now, ref, ts, type Row } from '../lib/db';
import { cuid } from '../lib/cuid';
import { local } from '../lib/format';
import { jsDate } from './actions';
import { upsertCustomerByEmail } from './customers';
import { reservationConfirmationEmail } from './emailTemplates';
import { error, response, type ApiResult } from './json';
import { sendMail } from './mailer';
import * as Scheduling from './scheduling';
import { reservationSchema, safeParse } from './zod';

/** Reservation logic of Api/ReservationController.php — shared with the Customer app. */

/** Carbon::parse("YYYY-MM-DD 00:00:00", tz): out-of-range days roll over; month > 12 / day > 31 throw. */
function localMidnight(date: string): DateTime {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(date);
  if (!m || +m[2] > 12 || +m[3] > 31) throw new Error('Invalid date');
  return Scheduling.localWallClock(+m[1], +m[2], +m[3]);
}

/** `new Date("YYYY-MM-DDT00:00:00")` / `T23:59:59` — server-local day bounds as UTC. */
export function dayBounds(date: string): [Date, Date] {
  const start = localMidnight(date);
  return [start.toJSDate(), start.set({ hour: 23, minute: 59, second: 59 }).toJSDate()];
}

/** Non-cancelled TABLE reservations dated within [start, end] (inclusive, like whereBetween). */
async function tableBookings(start: Date, end: Date): Promise<Row[]> {
  const snap = await db.collection(C.reservations).where('date', '>=', ts(start)).where('date', '<=', ts(end)).get();
  return snap.docs
    .map((d) => ({ id: d.id, ...d.data() }) as Row)
    .filter((r) => r.kind === 'TABLE' && !['CANCELED', 'NO_SHOW'].includes(r.status));
}

/** GET /api/reservations/availability?date=YYYY-MM-DD */
export async function availability(date: unknown): Promise<ApiResult> {
  if (typeof date !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(date)) return error('A valid date (YYYY-MM-DD) is required', 400);
  try {
    const [dayStart, dayEnd] = dayBounds(date);
    const used: Record<string, number> = {};
    for (const r of await tableBookings(dayStart, dayEnd)) if (r.time) used[r.time] = (used[r.time] ?? 0) + 1;

    const nowMs = Date.now();
    const slots = Scheduling.allSlots().map((time) => {
      const u = used[time] ?? 0;
      const when = Scheduling.slotDateTime(date, time);
      const pastCutoff = when ? when.getTime() < nowMs + Scheduling.LEAD_MINUTES * 60000 : true;
      const remaining = Math.max(0, Scheduling.SLOT_CAPACITY - u);
      return { time, available: remaining > 0 && !pastCutoff, remaining };
    });
    return response({ date, slots });
  } catch (e) {
    console.error(e);
    return error('Availability unavailable', 503);
  }
}

/** POST /api/reservations — shared with the Customer app (/api/mobile/customer/reservations). */
export async function create(body: unknown): Promise<ApiResult> {
  const [data, issues] = safeParse(reservationSchema, body);
  if (!data) return error('Invalid payload', 400, { issues });

  const prefix = data.kind === 'PRIVATE_EVENT' ? 'EV' : 'SV';
  const reference = `${prefix}-${randomInt(100000, 1000000)}`;

  // Dine-in (TABLE) bookings get slot + double-booking validation.
  if (data.kind === 'TABLE') {
    const check = Scheduling.validateSlot(data.date, data.time);
    if (!check.ok) return error(check.reason!, 422);
  }

  try {
    if (data.kind === 'TABLE') {
      const [dayStart, dayEnd] = dayBounds(data.date);
      const taken = (await tableBookings(dayStart, dayEnd)).filter((r) => r.time === data.time).length;
      if (taken >= Scheduling.SLOT_CAPACITY) return error('That time slot is fully booked — please choose another.', 409);
    }

    // Link/create a customer record by email so reservations roll up into CRM.
    const customerId = await upsertCustomerByEmail(data.email, { name: data.name, phone: data.phone });

    const fields =
      data.kind === 'TABLE'
        ? { time: data.time, guests: data.guests, occasion: data.occasion ?? null, requests: data.requests ?? null, eventType: null, guestRange: null, space: null, company: null, message: null }
        : { time: null, guests: null, occasion: null, requests: null, eventType: data.eventType, guestRange: data.guestRange, space: data.space, company: data.company ?? null, message: data.message ?? null };

    const date = jsDate(data.date);
    const id = cuid();
    await db.runTransaction(async (tx) => {
      // Reservation.reference is a unique key — a clash fails the insert (→ 503) like MySQL did.
      const clash = await tx.get(db.collection(C.reservations).where('reference', '==', reference).limit(1));
      if (!clash.empty) throw new Error('Duplicate reservation reference');
      const t = now();
      tx.create(ref(C.reservations, id), {
        reference,
        kind: data.kind,
        status: 'REQUESTED',
        date: ts(date),
        name: data.name,
        email: data.email,
        phone: data.phone,
        ...fields,
        outletId: null,
        customerId,
        createdAt: t,
        updatedAt: t,
      });
    });

    // Branded confirmation email — never fail the booking if mail/SMTP errors.
    try {
      const day = /^\d{4}-\d{2}-\d{2}$/.test(data.date) ? localMidnight(data.date) : local(date);
      const dateLabel = day.setLocale('en-US').toFormat('ccc, LLL d, yyyy');
      const mail = reservationConfirmationEmail({
        reference,
        name: data.name,
        kind: data.kind,
        dateLabel,
        ...(data.kind === 'TABLE'
          ? { time: data.time, guests: data.guests, occasion: data.occasion ?? null, requests: data.requests ?? null }
          : { eventType: data.eventType, guestRange: data.guestRange, space: data.space, message: data.message ?? null }),
      });
      await sendMail(data.email, mail);
    } catch (e) {
      console.error(e);
    }

    return response({ reference, id }, 201);
  } catch (e) {
    console.error(e);
    return error('Database unavailable', 503);
  }
}

/** Reservation → the Customer app view (customer/[...path] reservationView). */
export function view(r: Row): Record<string, unknown> {
  const out: Record<string, unknown> = {
    id: r.id,
    reference: r.reference,
    kind: r.kind,
    status: r.status,
    date: iso(r.date),
    time: r.time,
    guests: r.guests == null ? null : Math.trunc(Number(r.guests)),
    occasion: r.occasion,
    requests: r.requests,
    eventType: r.eventType,
    guestRange: r.guestRange,
    space: r.space,
    company: r.company,
    message: r.message,
    createdAt: iso(r.createdAt),
  };
  // `?? undefined` keys are dropped by JSON.stringify
  for (const k of Object.keys(out)) if (out[k] === null || out[k] === undefined) delete out[k];
  return out;
}

