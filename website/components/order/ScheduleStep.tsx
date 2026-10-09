'use client';

import { useMemo } from 'react';
import {
  allSlots,
  asapEstimate,
  slotPassesCutoff,
  to12h,
  upcomingDays,
  type ScheduleType,
} from '@/lib/order';

export default function ScheduleStep({
  scheduleType,
  setScheduleType,
  date,
  setDate,
  time,
  setTime,
}: {
  scheduleType: ScheduleType;
  setScheduleType: (v: ScheduleType) => void;
  date: string;
  setDate: (v: string) => void;
  time: string;
  setTime: (v: string) => void;
}) {
  const days = useMemo(() => upcomingDays(), []);
  const asap = useMemo(() => asapEstimate(), []);

  // Only slots that still clear the cutoff for the chosen day.
  const slots = useMemo(
    () => allSlots().filter((t) => date && slotPassesCutoff(date, t)),
    [date],
  );

  return (
    <div className="mt-9 animate-fade-up">
      <h3 className="font-display text-2xl text-cream">When would you like it?</h3>

      {/* Now vs Later */}
      <div className="mt-6 grid gap-4 sm:grid-cols-2">
        <button
          type="button"
          onClick={() => setScheduleType('NOW')}
          className={`rounded-2xl border p-5 text-left transition-all ${
            scheduleType === 'NOW' ? 'border-gold bg-gold/10' : 'border-cream/15 bg-ink/40 hover:border-gold/50'
          }`}
        >
          <p className="font-display text-lg font-bold uppercase tracking-tight text-cream">Schedule Now</p>
          <p className="mt-1.5 text-sm leading-relaxed text-cream/60">
            Sent straight to the kitchen. Ready in about {asap.minutes} min (around {asap.clock}).
          </p>
        </button>

        <button
          type="button"
          onClick={() => setScheduleType('LATER')}
          className={`rounded-2xl border p-5 text-left transition-all ${
            scheduleType === 'LATER' ? 'border-gold bg-gold/10' : 'border-cream/15 bg-ink/40 hover:border-gold/50'
          }`}
        >
          <p className="font-display text-lg font-bold uppercase tracking-tight text-cream">Schedule Later</p>
          <p className="mt-1.5 text-sm leading-relaxed text-cream/60">
            Pick a date and pickup time within our opening hours.
          </p>
        </button>
      </div>

      {/* Date + slot picker */}
      {scheduleType === 'LATER' && (
        <div className="mt-7 animate-fade-up">
          <p className="mb-2 block text-xs font-semibold uppercase tracking-[0.2em] text-cream/60">Pickup date</p>
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

          <p className="mb-2 mt-6 block text-xs font-semibold uppercase tracking-[0.2em] text-cream/60">
            Pickup time
          </p>
          {!date ? (
            <p className="text-sm text-cream/50">Choose a date first.</p>
          ) : slots.length === 0 ? (
            <p className="text-sm text-cream/50">No more pickup slots today — please pick another date.</p>
          ) : (
            <div className="flex flex-wrap gap-2.5">
              {slots.map((t) => (
                <button
                  key={t}
                  type="button"
                  onClick={() => setTime(t)}
                  className={`rounded-pill border px-4 py-2 text-sm font-medium transition-colors ${
                    time === t ? 'border-gold bg-gold text-white' : 'border-cream/20 text-cream hover:border-gold/60'
                  }`}
                >
                  {to12h(t)}
                </button>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
