import { DateTime } from 'luxon';
import { localTz } from '../lib/format';

/**
 * Scheduling rules for online ordering & dine-in reservations — port of Services/Scheduling.php.
 * Server-side authority for business hours, cutoff and pickup estimates. The website mirrors this
 * config in `website/lib/order.ts` for the UI — keep the two in sync if hours change.
 * "Server local time" is localTz(), so a "18:30" slot is 18:30 in that zone.
 */
export const BUSINESS_HOURS = {
  openHour: 10, // first slot 10:00
  closeHour: 22, // kitchen closes 22:00 → last slot 21:30
  slotMinutes: 30,
} as const;

/** Minutes a guest must book ahead of a slot ("cutoff time"). */
export const LEAD_MINUTES = 30;

/** Default prep time used to estimate an ASAP take-away pickup. */
export const PREP_MINUTES = 25;

/** Max simultaneous dine-in reservations per 30-min slot (double-booking guard). */
export const SLOT_CAPACITY = 6;

const pad = (n: number) => String(n).padStart(2, '0');

/** All bookable "HH:mm" slots for a service day. */
export function allSlots(): string[] {
  const slots: string[] = [];
  const { openHour, closeHour, slotMinutes } = BUSINESS_HOURS;
  for (let m = openHour * 60; m < closeHour * 60; m += slotMinutes) slots.push(`${pad(Math.floor(m / 60))}:${pad(m % 60)}`);
  return slots;
}

/** Wall-clock parts in the local zone; out-of-range parts roll over like the JS Date constructor. */
export function localWallClock(y: number, mo: number, d: number, h = 0, mi = 0, s = 0): DateTime {
  const w = new Date(Date.UTC(y, mo - 1, d, h, mi, s));
  if (y >= 0 && y < 100) w.setUTCFullYear(y); // Date.UTC maps 0–99 to 1900–1999
  return DateTime.fromObject(
    { year: w.getUTCFullYear(), month: w.getUTCMonth() + 1, day: w.getUTCDate(), hour: w.getUTCHours(), minute: w.getUTCMinutes(), second: w.getUTCSeconds() },
    { zone: localTz() },
  );
}

/**
 * Combine a "YYYY-MM-DD" date and "HH:mm" time into a date (server local time).
 * Out-of-range parts roll over exactly like the JS Date constructor.
 */
export function slotDateTime(date: string, time: string): Date | null {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(date);
  const t = /^(\d{1,2}):(\d{2})$/.exec(time);
  if (!m || !t) return null;
  return localWallClock(+m[1], +m[2], +m[3], +t[1], +t[2]).toJSDate();
}

/** Validate a scheduled date+time: real slot, within hours, past the cutoff. */
export function validateSlot(date: string, time: string, now: Date = new Date()): { ok: boolean; reason: string | null } {
  if (!allSlots().includes(time)) return { ok: false, reason: 'Outside business hours' };
  const when = slotDateTime(date, time);
  if (!when) return { ok: false, reason: 'Invalid date or time' };
  if (when.getTime() < now.getTime() + LEAD_MINUTES * 60_000) {
    return { ok: false, reason: 'That time is too soon — please pick a later slot' };
  }
  return { ok: true, reason: null };
}

/** Estimated pickup time for a take-away order ('NOW' | 'LATER'). */
export function estimatePickup(scheduleType: string, date?: string | null, time?: string | null, now: Date = new Date()): Date {
  const asap = new Date(now.getTime() + PREP_MINUTES * 60_000);
  if (scheduleType === 'LATER' && date && time) return slotDateTime(date, time) ?? asap;
  return asap;
}
