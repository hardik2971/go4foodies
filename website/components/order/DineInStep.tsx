'use client';

import { useEffect, useMemo, useState } from 'react';
import {
  allSlots,
  slotPassesCutoff,
  to12h,
  upcomingDays,
  GUEST_OPTIONS,
  type AvailabilitySlot,
} from '@/lib/order';
import { LABEL_CLASS } from './styles';

export default function DineInStep({
  date,
  setDate,
  time,
  setTime,
  guests,
  setGuests,
  notes,
  setNotes,
}: {
  date: string;
  setDate: (v: string) => void;
  time: string;
  setTime: (v: string) => void;
  guests: number;
  setGuests: (v: number) => void;
  notes: string;
  setNotes: (v: string) => void;
}) {
  const days = useMemo(() => upcomingDays(), []);
  const [slots, setSlots] = useState<AvailabilitySlot[] | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  // Pull live availability for the chosen date so we never offer a full slot.
  useEffect(() => {
    if (!date) return;
    let cancelled = false;
    setLoading(true);
    setError('');
    fetch(`/api/availability?date=${date}`)
      .then((r) => r.json())
      .then((data) => {
        if (cancelled) return;
        if (Array.isArray(data.slots)) {
          setSlots(data.slots as AvailabilitySlot[]);
        } else {
          // Fall back to local slots (cutoff only) if availability is unavailable.
          setSlots(allSlots().map((t) => ({ time: t, available: slotPassesCutoff(date, t), remaining: 1 })));
          setError('Showing standard times — live availability is offline.');
        }
      })
      .catch(() => {
        if (cancelled) return;
        setSlots(allSlots().map((t) => ({ time: t, available: slotPassesCutoff(date, t), remaining: 1 })));
        setError('Showing standard times — live availability is offline.');
      })
      .finally(() => !cancelled && setLoading(false));
    return () => {
      cancelled = true;
    };
  }, [date]);

  return (
    <div className="mt-9 animate-fade-up">
      <h3 className="font-display text-2xl text-cream">Reserve your table</h3>
      <p className="mt-1 text-sm text-cream/55">Pick a date and time — we hold tables in 30-minute slots.</p>

      {/* Party size */}
      <div className="mt-7">
        <p className={LABEL_CLASS}>Party size</p>
        <div className="flex flex-wrap gap-2.5">
          {GUEST_OPTIONS.map((g) => (
            <button
              key={g}
              type="button"
              onClick={() => setGuests(g)}
              className={`h-11 w-11 rounded-full border text-sm font-semibold transition-colors ${
                guests === g ? 'border-gold bg-gold text-white' : 'border-cream/20 text-cream hover:border-gold/60'
              }`}
            >
              {g}
            </button>
          ))}
        </div>
      </div>

      {/* Date */}
      <div className="mt-7">
        <p className={LABEL_CLASS}>Date</p>
        <div className="flex gap-2 overflow-x-auto pb-2 no-scrollbar">
          {days.map((d) => (
            <button
              key={d.iso}
              type="button"
              onClick={() => {
                setDate(d.iso);
                setTime('');
              }}
              className={`flex-none rounded-xl border px-4 py-2.5 text-center transition-colors ${
                date === d.iso ? 'border-gold bg-gold text-white' : 'border-cream/20 text-cream hover:border-gold/60'
              }`}
            >
              <span className="block text-[10px] font-semibold uppercase tracking-wide opacity-80">{d.weekday}</span>
              <span className="block text-sm font-semibold">{d.label}</span>
            </button>
          ))}
        </div>
      </div>

      {/* Time slots */}
      <div className="mt-7">
        <p className={LABEL_CLASS}>Time</p>
        {!date ? (
          <p className="text-sm text-cream/50">Choose a date to see available times.</p>
        ) : loading ? (
          <p className="text-sm text-cream/50">Checking availability…</p>
        ) : (
          <>
            <div className="flex flex-wrap gap-2.5">
              {(slots ?? []).map((s) => (
                <button
                  key={s.time}
                  type="button"
                  disabled={!s.available}
                  onClick={() => setTime(s.time)}
                  className={`rounded-pill border px-4 py-2 text-sm font-medium transition-colors ${
                    time === s.time
                      ? 'border-gold bg-gold text-white'
                      : s.available
                        ? 'border-cream/20 text-cream hover:border-gold/60'
                        : 'cursor-not-allowed border-cream/10 text-cream/25 line-through'
                  }`}
                  title={s.available ? undefined : 'Fully booked'}
                >
                  {to12h(s.time)}
                </button>
              ))}
            </div>
            {slots && slots.every((s) => !s.available) && (
              <p className="mt-3 text-sm text-cream/50">No tables left on this date — please try another day.</p>
            )}
            {error && <p className="mt-3 text-xs text-gold/70">{error}</p>}
          </>
        )}
      </div>

      {/* Notes */}
      <div className="mt-7">
        <label className={LABEL_CLASS} htmlFor="dine-notes">
          Notes <span className="font-normal text-cream/35">optional</span>
        </label>
        <textarea
          id="dine-notes"
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
          rows={3}
          placeholder="Allergies, seating preference, celebrations…"
          className="w-full resize-none rounded-xl border border-cream/15 bg-ink-soft px-4 py-3 text-sm text-cream outline-none transition-colors placeholder:text-cream/35 focus:border-gold"
        />
      </div>
    </div>
  );
}
