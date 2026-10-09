// Online ordering — shared config, types & helpers for the storefront flow
// (TASK 1). Scheduling rules here MIRROR the admin authority in
// `admin/src/lib/scheduling.ts`; keep the two in sync if business hours change.

export const BUSINESS_HOURS = {
  openHour: 10, // first slot 10:00
  closeHour: 22, // last slot 21:30
  slotMinutes: 30,
};

/** Minutes a guest must order/book ahead of a slot ("cutoff time"). */
export const LEAD_MINUTES = 30;

/** Default prep time used to estimate an ASAP take-away pickup. */
export const PREP_MINUTES = 25;

/** How many days ahead a guest may schedule. */
export const SCHEDULE_DAYS = 14;

export type OrderMode = 'TAKE_AWAY' | 'DINE_IN';
export type ScheduleType = 'NOW' | 'LATER';

export interface OrderMenuItem {
  id: string;
  name: string;
  description: string;
  price: number;
  rating: number;
  tag: string;
  category: string;
  imageUrl: string;
}

export interface CartLine {
  item: OrderMenuItem;
  qty: number;
}

export interface AvailabilitySlot {
  time: string; // "HH:mm"
  available: boolean;
  remaining: number;
}

// ---- Slot + date helpers ----

/** All bookable "HH:mm" slots for a service day. */
export function allSlots(): string[] {
  const slots: string[] = [];
  const { openHour, closeHour, slotMinutes } = BUSINESS_HOURS;
  for (let m = openHour * 60; m < closeHour * 60; m += slotMinutes) {
    const h = Math.floor(m / 60);
    const min = m % 60;
    slots.push(`${String(h).padStart(2, '0')}:${String(min).padStart(2, '0')}`);
  }
  return slots;
}

/** Convert "18:30" → "6:30 PM". */
export function to12h(time: string): string {
  const [hStr, mStr] = time.split(':');
  const h = Number(hStr);
  const period = h < 12 ? 'AM' : 'PM';
  const h12 = h % 12 || 12;
  return `${h12}:${mStr} ${period}`;
}

/** Local "YYYY-MM-DD" for a Date. */
export function isoDate(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

/** The next `SCHEDULE_DAYS` calendar days from today (for the date picker). */
export function upcomingDays(count = SCHEDULE_DAYS): { iso: string; label: string; weekday: string }[] {
  const out: { iso: string; label: string; weekday: string }[] = [];
  const base = new Date();
  for (let i = 0; i < count; i++) {
    const d = new Date(base.getFullYear(), base.getMonth(), base.getDate() + i);
    out.push({
      iso: isoDate(d),
      label: d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' }),
      weekday: i === 0 ? 'Today' : d.toLocaleDateString('en-US', { weekday: 'short' }),
    });
  }
  return out;
}

/** Slots still orderable today after the lead-time cutoff (client-side filter). */
export function slotPassesCutoff(dateIso: string, time: string, now = new Date()): boolean {
  const [y, m, d] = dateIso.split('-').map(Number);
  const [hh, mm] = time.split(':').map(Number);
  const when = new Date(y, m - 1, d, hh, mm, 0, 0);
  return when.getTime() >= now.getTime() + LEAD_MINUTES * 60_000;
}

/** Estimated ASAP pickup label, e.g. "in ~25 min (6:40 PM)". */
export function asapEstimate(now = new Date()): { minutes: number; clock: string } {
  const when = new Date(now.getTime() + PREP_MINUTES * 60_000);
  return {
    minutes: PREP_MINUTES,
    clock: when.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' }),
  };
}

export const GUEST_OPTIONS = [1, 2, 3, 4, 5, 6, 7, 8] as const;
