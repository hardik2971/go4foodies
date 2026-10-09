'use client';

import { useState, useEffect } from 'react';
import Image from 'next/image';
import Link from 'next/link';

const TABLE_STEPS = ['Date & Guests', 'Your Details', 'Confirm'] as const;
const PRIVATE_STEPS = ['Event', 'Your Details', 'Confirm'] as const;

const TIME_SLOTS = [
  '17:00', '17:30', '18:00', '18:30', '19:00',
  '19:30', '20:00', '20:30', '21:00', '21:30',
];
const GUEST_OPTIONS = [1, 2, 3, 4, 5, 6, 7, 8];
const OCCASIONS = ['Casual Dining', 'Birthday', 'Anniversary', 'Business', 'Date Night', 'Celebration'];

const EVENT_TYPES = ['Birthday', 'Corporate Dinner', 'Wedding / Engagement', 'Cocktail Party', 'Holiday Party', 'Other'];
const GUEST_RANGES = ['10–20', '20–40', '40–70', '70–120', '120+'];
const SPACES = ['Main Dining', 'Private Room', 'Bar Area', 'Full Buyout'];

interface TableForm {
  date: string;
  time: string;
  guests: number;
  name: string;
  email: string;
  phone: string;
  occasion: string;
  requests: string;
}
const initialTable: TableForm = {
  date: '', time: '', guests: 2, name: '', email: '', phone: '', occasion: 'Casual Dining', requests: '',
};

interface PrivateForm {
  eventType: string;
  date: string;
  guestRange: string;
  space: string;
  name: string;
  email: string;
  phone: string;
  company: string;
  message: string;
}
const initialPrivate: PrivateForm = {
  eventType: EVENT_TYPES[0], date: '', guestRange: '', space: SPACES[0],
  name: '', email: '', phone: '', company: '', message: '',
};

const fieldClass =
  'w-full rounded-xl border border-cream/15 bg-ink-soft px-4 py-3 text-sm text-cream outline-none transition-colors placeholder:text-cream/35 focus:border-gold';
const labelClass = 'mb-2 block text-xs font-semibold uppercase tracking-[0.2em] text-cream/60';

function Stepper({ steps, step }: { steps: readonly string[]; step: number }) {
  return (
    <ol className="flex items-center">
      {steps.map((label, i) => {
        const done = i < step;
        const current = i === step;
        return (
          <li key={label} className="flex flex-1 items-center last:flex-none">
            <div className="flex items-center gap-3">
              <span
                className={`grid h-9 w-9 place-items-center rounded-full border text-sm font-semibold transition-colors ${
                  done ? 'border-gold bg-gold text-white' : current ? 'border-gold text-gold' : 'border-cream/25 text-cream/50'
                }`}
              >
                {done ? (
                  <svg viewBox="0 0 24 24" className="h-4 w-4" aria-hidden="true">
                    <path d="M5 13l4 4L19 7" stroke="currentColor" strokeWidth="2.5" fill="none" strokeLinecap="round" strokeLinejoin="round" />
                  </svg>
                ) : (
                  i + 1
                )}
              </span>
              <span className={`hidden text-xs font-semibold uppercase tracking-[0.15em] sm:block ${current || done ? 'text-cream' : 'text-cream/40'}`}>
                {label}
              </span>
            </div>
            {i < steps.length - 1 && <span className={`mx-3 h-px flex-1 ${done ? 'bg-gold' : 'bg-cream/15'}`} />}
          </li>
        );
      })}
    </ol>
  );
}

function Pills<T extends string | number>({ options, value, onChange, pill = false }: { options: readonly T[]; value: T; onChange: (v: T) => void; pill?: boolean }) {
  return (
    <div className="flex flex-wrap gap-2.5">
      {options.map((o) => (
        <button
          key={o}
          type="button"
          onClick={() => onChange(o)}
          className={`border text-sm font-medium transition-colors ${pill ? 'rounded-pill px-4 py-2' : 'rounded-xl px-4 py-2.5'} ${
            value === o ? 'border-gold bg-gold text-white' : 'border-cream/20 text-cream hover:border-gold/60'
          }`}
        >
          {o}
        </button>
      ))}
    </div>
  );
}

// Subtle ornamental damask backdrop (matches the menu page).
function OrnamentPattern() {
  return (
    <svg aria-hidden="true" className="pointer-events-none absolute inset-0 h-full w-full text-gold/15">
      <defs>
        <pattern id="reservation-damask" width="96" height="96" patternUnits="userSpaceOnUse">
          <g fill="none" stroke="currentColor" strokeWidth="1">
            <path d="M48 14c10 8 10 22 0 30-10-8-10-22 0-30z" />
            <path d="M14 48c8-10 22-10 30 0-8 10-22 10-30 0z" />
            <path d="M52 48c8-10 22-10 30 0-8 10-22 10-30 0z" />
            <path d="M48 52c10 8 10 22 0 30-10-8-10-22 0-30z" />
            <circle cx="48" cy="48" r="3" />
          </g>
        </pattern>
      </defs>
      <rect width="100%" height="100%" fill="url(#reservation-damask)" />
    </svg>
  );
}

type CSSVars = React.CSSProperties & Record<`--${string}`, string | number>;

const CONFETTI_COLORS = ['#f5761e', '#ffb067', '#e0541a', '#f7f1e8', '#e2470f'];

// Deterministic firecracker burst (avoids SSR/random mismatches).
const CONFETTI = Array.from({ length: 56 }, (_, i) => {
  const angle = (i / 56) * Math.PI * 2;
  const radius = 130 + (i % 6) * 34;
  return {
    dx: Math.cos(angle) * radius,
    dy: Math.sin(angle) * radius + 220,
    rot: (i % 2 ? 1 : -1) * (360 + (i % 4) * 200),
    color: CONFETTI_COLORS[i % CONFETTI_COLORS.length],
    delay: (i % 7) * 55,
    w: 6 + (i % 3) * 3,
    h: 9 + (i % 4) * 3,
  };
});

function Confetti() {
  return (
    <div className="pointer-events-none absolute inset-0 overflow-hidden" aria-hidden="true">
      {CONFETTI.map((c, i) => (
        <span
          key={i}
          className="absolute left-1/2 top-[28%] animate-confetti rounded-[1px]"
          style={
            {
              '--dx': `${c.dx}px`,
              '--dy': `${c.dy}px`,
              '--rot': `${c.rot}deg`,
              width: `${c.w}px`,
              height: `${c.h}px`,
              background: c.color,
              animationDelay: `${c.delay}ms`,
            } as CSSVars
          }
        />
      ))}
    </div>
  );
}

type Mode = '' | 'table' | 'private';

const PANEL_COPY: Record<Mode, { eyebrow: string; title: string; bullets: string[] }> = {
  '': {
    eyebrow: 'Go4Foodie · Reservations',
    title: 'Reserve a table, or host your moment.',
    bullets: ['Seasonal, wood-fired cooking', 'Curated natural wine pairings', 'Open Tue–Sun · 5:00 pm til late'],
  },
  table: {
    eyebrow: 'Go4Foodie · Table Booking',
    title: 'Reserve your table, savor the evening.',
    bullets: ['Seasonal, wood-fired tasting menu', 'Curated natural wine pairings', 'Open Tue–Sun · 5:00 pm til late'],
  },
  private: {
    eyebrow: 'Go4Foodie · Private Events',
    title: 'Host an unforgettable private event.',
    bullets: ['Intimate rooms to full buyouts', 'Bespoke menus & beverage packages', 'A dedicated events coordinator'],
  },
};

export default function ReservationFlow() {
  const [mode, setMode] = useState<Mode>('');
  const [step, setStep] = useState(0);
  const [tableForm, setTableForm] = useState<TableForm>(initialTable);
  const [privateForm, setPrivateForm] = useState<PrivateForm>(initialPrivate);
  const [reference, setReference] = useState('');
  const [today, setToday] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');

  // Default both date fields to today (and block past dates) on the client.
  useEffect(() => {
    const d = new Date();
    const iso = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
    setToday(iso);
    setTableForm((f) => (f.date ? f : { ...f, date: iso }));
    setPrivateForm((f) => (f.date ? f : { ...f, date: iso }));
  }, []);

  const setT = <K extends keyof TableForm>(k: K, v: TableForm[K]) => setTableForm((f) => ({ ...f, [k]: v }));
  const setP = <K extends keyof PrivateForm>(k: K, v: PrivateForm[K]) => setPrivateForm((f) => ({ ...f, [k]: v }));

  const t0Valid = tableForm.date !== '' && tableForm.time !== '' && tableForm.guests > 0;
  const t1Valid = tableForm.name.trim() !== '' && tableForm.email.trim() !== '' && tableForm.phone.trim() !== '';
  const p0Valid = privateForm.date !== '' && privateForm.guestRange !== '';
  const p1Valid = privateForm.name.trim() !== '' && privateForm.email.trim() !== '' && privateForm.phone.trim() !== '';

  // Submit the booking to the admin (via the storefront proxy) so it syncs to
  // the admin Reservations module and triggers a confirmation email.
  const confirm = async () => {
    setSubmitting(true);
    setError('');
    try {
      const payload =
        mode === 'table'
          ? {
              kind: 'TABLE' as const,
              date: tableForm.date,
              time: tableForm.time,
              guests: tableForm.guests,
              name: tableForm.name,
              email: tableForm.email,
              phone: tableForm.phone,
              occasion: tableForm.occasion || undefined,
              requests: tableForm.requests || undefined,
            }
          : {
              kind: 'PRIVATE_EVENT' as const,
              eventType: privateForm.eventType,
              date: privateForm.date,
              guestRange: privateForm.guestRange,
              space: privateForm.space,
              name: privateForm.name,
              email: privateForm.email,
              phone: privateForm.phone,
              company: privateForm.company || undefined,
              message: privateForm.message || undefined,
            };
      const res = await fetch('/api/reservations', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Could not complete your reservation. Please try again.');
      setReference(data.reference);
      setStep(3);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Something went wrong. Please try again.');
    } finally {
      setSubmitting(false);
    }
  };

  const resetAll = () => {
    setTableForm(initialTable);
    setPrivateForm(initialPrivate);
    setReference('');
    setStep(0);
    setMode('');
    setError('');
  };

  const copy = PANEL_COPY[mode];

  return (
    <section className="relative min-h-screen overflow-hidden bg-ink pb-20 pt-28">
      <div className="pointer-events-none absolute -right-40 top-10 h-96 w-96 rounded-full bg-gold/10 blur-[130px]" />
      <OrnamentPattern />
      <div className="container relative">
        <div className="grid overflow-hidden rounded-[2rem] border border-cream/10 bg-ink-soft/60 lg:grid-cols-[0.85fr_1fr]">
          {/* ---- Left: visual panel ---- */}
          <aside className="relative hidden min-h-[640px] lg:block">
            <Image
              src="https://images.unsplash.com/photo-1414235077428-338989a2e8c0?auto=format&fit=crop&w=1200&q=75"
              alt="Elegant dining room at Go4Foodie"
              fill
              sizes="40vw"
              className="object-cover"
            />
            <div className="absolute inset-0 bg-gradient-to-t from-ink via-ink/60 to-ink/30" />
            <div className="absolute inset-0 flex flex-col justify-between p-10">
              <div>
                <p className="font-display text-xs font-semibold uppercase tracking-[0.3em] text-gold">{copy.eyebrow}</p>
                <h2 className="mt-4 max-w-xs font-display text-4xl leading-tight text-cream">{copy.title}</h2>
              </div>
              <ul className="space-y-3 text-sm text-cream/80">
                {copy.bullets.map((b) => (
                  <li key={b} className="flex items-center gap-3">
                    <span className="h-1.5 w-1.5 rounded-full bg-gold" />
                    {b}
                  </li>
                ))}
              </ul>
            </div>
          </aside>

          {/* ---- Right: flow ---- */}
          <div className="p-7 sm:p-10">
            {/* Choose flow type */}
            {mode === '' && (
              <div className="animate-fade-up">
                <h3 className="font-display text-2xl text-cream">How can we host you?</h3>
                <p className="mt-1 text-sm text-cream/55">Choose the experience you&rsquo;re planning.</p>

                <div className="mt-7 grid gap-4 sm:grid-cols-2">
                  <button
                    type="button"
                    onClick={() => { setMode('table'); setStep(0); }}
                    className="group rounded-2xl border border-cream/15 bg-ink/40 p-6 text-left transition-all duration-300 hover:-translate-y-1 hover:border-gold/50"
                  >
                    <span className="grid h-12 w-12 place-items-center rounded-xl bg-gold/15 text-gold ring-1 ring-gold/30">
                      <svg viewBox="0 0 24 24" className="h-6 w-6" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                        <path d="M5 4v6a2 2 0 0 0 2 2M9 4v6a2 2 0 0 1-2 2M7 4v16M16 4c-1.4 0-2.4 2-2.4 4.5S14.6 13 16 13v7" />
                      </svg>
                    </span>
                    <h4 className="mt-5 font-display text-xl font-bold uppercase tracking-tight text-cream">Table Booking</h4>
                    <p className="mt-2 text-sm leading-relaxed text-cream/60">Reserve a table for dinner, drinks, or a special occasion.</p>
                    <span className="mt-4 inline-flex items-center gap-1.5 text-xs font-semibold uppercase tracking-[0.15em] text-gold">
                      Continue
                      <svg viewBox="0 0 24 24" className="h-4 w-4 transition-transform group-hover:translate-x-0.5" aria-hidden="true">
                        <path d="M4 12h15M13 6l6 6-6 6" stroke="currentColor" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round" />
                      </svg>
                    </span>
                  </button>

                  <button
                    type="button"
                    onClick={() => { setMode('private'); setStep(0); }}
                    className="group rounded-2xl border border-cream/15 bg-ink/40 p-6 text-left transition-all duration-300 hover:-translate-y-1 hover:border-gold/50"
                  >
                    <span className="grid h-12 w-12 place-items-center rounded-xl bg-gold/15 text-gold ring-1 ring-gold/30">
                      <svg viewBox="0 0 24 24" className="h-6 w-6" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                        <path d="M17 20a5 5 0 0 0-10 0M12 12a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7M21 20a4 4 0 0 0-5-3.4M18.6 10.8a3 3 0 0 0 0-5.6" />
                      </svg>
                    </span>
                    <h4 className="mt-5 font-display text-xl font-bold uppercase tracking-tight text-cream">Private Event</h4>
                    <p className="mt-2 text-sm leading-relaxed text-cream/60">Plan a celebration, corporate dinner, or full buyout with our team.</p>
                    <span className="mt-4 inline-flex items-center gap-1.5 text-xs font-semibold uppercase tracking-[0.15em] text-gold">
                      Continue
                      <svg viewBox="0 0 24 24" className="h-4 w-4 transition-transform group-hover:translate-x-0.5" aria-hidden="true">
                        <path d="M4 12h15M13 6l6 6-6 6" stroke="currentColor" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round" />
                      </svg>
                    </span>
                  </button>
                </div>
              </div>
            )}

            {/* ---------- TABLE BOOKING FLOW ---------- */}
            {mode === 'table' && step < 3 && (
              <>
                <Stepper steps={TABLE_STEPS} step={step} />

                {step === 0 && (
                  <div className="mt-9 animate-fade-up">
                    <h3 className="font-display text-2xl text-cream">When are you joining us?</h3>

                    <div className="mt-7">
                      <p className={labelClass}>Party size</p>
                      <div className="flex flex-wrap gap-2.5">
                        {GUEST_OPTIONS.map((g) => (
                          <button
                            key={g}
                            type="button"
                            onClick={() => setT('guests', g)}
                            className={`h-11 w-11 rounded-full border text-sm font-semibold transition-colors ${
                              tableForm.guests === g ? 'border-gold bg-gold text-white' : 'border-cream/20 text-cream hover:border-gold/60'
                            }`}
                          >
                            {g}
                          </button>
                        ))}
                      </div>
                    </div>

                    <div className="mt-7">
                      <label className={labelClass}>Date</label>
                      <input type="date" min={today} value={tableForm.date} onChange={(e) => setT('date', e.target.value)} className={`${fieldClass} [color-scheme:dark] sm:max-w-xs`} />
                    </div>

                    <div className="mt-7">
                      <p className={labelClass}>Time</p>
                      <Pills options={TIME_SLOTS} value={tableForm.time} onChange={(v) => setT('time', v)} pill />
                    </div>

                    <div className="mt-9 flex items-center justify-between">
                      <button type="button" onClick={() => setMode('')} className="btn-ghost">Back</button>
                      <button type="button" disabled={!t0Valid} onClick={() => setStep(1)} className="btn-primary disabled:cursor-not-allowed disabled:opacity-40">Continue</button>
                    </div>
                  </div>
                )}

                {step === 1 && (
                  <div className="mt-9 animate-fade-up">
                    <h3 className="font-display text-2xl text-cream">Tell us about you</h3>
                    <div className="mt-7 grid gap-5 sm:grid-cols-2">
                      <div className="sm:col-span-2">
                        <label className={labelClass}>Full name</label>
                        <input value={tableForm.name} onChange={(e) => setT('name', e.target.value)} placeholder="Jane Doe" className={fieldClass} />
                      </div>
                      <div>
                        <label className={labelClass}>Email</label>
                        <input type="email" value={tableForm.email} onChange={(e) => setT('email', e.target.value)} placeholder="jane@email.com" className={fieldClass} />
                      </div>
                      <div>
                        <label className={labelClass}>Phone</label>
                        <input type="tel" value={tableForm.phone} onChange={(e) => setT('phone', e.target.value)} placeholder="+1 555 000 0000" className={fieldClass} />
                      </div>
                      <div className="sm:col-span-2">
                        <label className={labelClass}>Occasion</label>
                        <select value={tableForm.occasion} onChange={(e) => setT('occasion', e.target.value)} className={`${fieldClass} appearance-none`}>
                          {OCCASIONS.map((o) => <option key={o} value={o} className="bg-ink-soft">{o}</option>)}
                        </select>
                      </div>
                      <div className="sm:col-span-2">
                        <label className={labelClass}>Special requests</label>
                        <textarea value={tableForm.requests} onChange={(e) => setT('requests', e.target.value)} rows={3} placeholder="Allergies, seating preference, celebrations…" className={`${fieldClass} resize-none`} />
                      </div>
                    </div>
                    <div className="mt-9 flex items-center justify-between">
                      <button type="button" onClick={() => setStep(0)} className="btn-ghost">Back</button>
                      <button type="button" disabled={!t1Valid} onClick={() => setStep(2)} className="btn-primary disabled:cursor-not-allowed disabled:opacity-40">Review</button>
                    </div>
                  </div>
                )}

                {step === 2 && (
                  <div className="mt-9 animate-fade-up">
                    <h3 className="font-display text-2xl text-cream">Review your reservation</h3>
                    <dl className="mt-7 divide-y divide-cream/10 rounded-2xl border border-cream/10 bg-ink/40 px-6">
                      {[
                        ['Guests', `${tableForm.guests} ${tableForm.guests === 1 ? 'person' : 'people'}`],
                        ['Date', tableForm.date],
                        ['Time', tableForm.time],
                        ['Name', tableForm.name],
                        ['Email', tableForm.email],
                        ['Phone', tableForm.phone],
                        ['Occasion', tableForm.occasion],
                        ['Requests', tableForm.requests || '—'],
                      ].map(([k, v]) => (
                        <div key={k} className="flex items-center justify-between gap-6 py-3.5 text-sm">
                          <dt className="text-cream/55">{k}</dt>
                          <dd className="text-right font-medium text-cream">{v}</dd>
                        </div>
                      ))}
                    </dl>
                    {error && (
                      <p className="mt-5 rounded-xl border border-brand/40 bg-brand/10 px-4 py-3 text-sm text-cream">{error}</p>
                    )}
                    <div className="mt-9 flex items-center justify-between">
                      <button type="button" onClick={() => setStep(1)} className="btn-ghost" disabled={submitting}>Back</button>
                      <button type="button" onClick={confirm} disabled={submitting} className="btn-primary disabled:cursor-not-allowed disabled:opacity-60">
                        {submitting ? 'Confirming…' : 'Confirm Reservation'}
                      </button>
                    </div>
                  </div>
                )}
              </>
            )}

            {/* ---------- PRIVATE EVENT FLOW ---------- */}
            {mode === 'private' && step < 3 && (
              <>
                <Stepper steps={PRIVATE_STEPS} step={step} />

                {step === 0 && (
                  <div className="mt-9 animate-fade-up">
                    <h3 className="font-display text-2xl text-cream">Tell us about your event</h3>

                    <div className="mt-7">
                      <p className={labelClass}>Event type</p>
                      <Pills options={EVENT_TYPES} value={privateForm.eventType} onChange={(v) => setP('eventType', v)} />
                    </div>

                    <div className="mt-7 grid gap-5 sm:grid-cols-2">
                      <div>
                        <label className={labelClass}>Preferred date</label>
                        <input type="date" min={today} value={privateForm.date} onChange={(e) => setP('date', e.target.value)} className={`${fieldClass} [color-scheme:dark]`} />
                      </div>
                      <div>
                        <label className={labelClass}>Preferred space</label>
                        <select value={privateForm.space} onChange={(e) => setP('space', e.target.value)} className={`${fieldClass} appearance-none`}>
                          {SPACES.map((s) => <option key={s} value={s} className="bg-ink-soft">{s}</option>)}
                        </select>
                      </div>
                    </div>

                    <div className="mt-7">
                      <p className={labelClass}>Estimated guests</p>
                      <Pills options={GUEST_RANGES} value={privateForm.guestRange} onChange={(v) => setP('guestRange', v)} pill />
                    </div>

                    <div className="mt-9 flex items-center justify-between">
                      <button type="button" onClick={() => setMode('')} className="btn-ghost">Back</button>
                      <button type="button" disabled={!p0Valid} onClick={() => setStep(1)} className="btn-primary disabled:cursor-not-allowed disabled:opacity-40">Continue</button>
                    </div>
                  </div>
                )}

                {step === 1 && (
                  <div className="mt-9 animate-fade-up">
                    <h3 className="font-display text-2xl text-cream">Your contact details</h3>
                    <div className="mt-7 grid gap-5 sm:grid-cols-2">
                      <div>
                        <label className={labelClass}>Full name</label>
                        <input value={privateForm.name} onChange={(e) => setP('name', e.target.value)} placeholder="Jane Doe" className={fieldClass} />
                      </div>
                      <div>
                        <label className={labelClass}>Company <span className="font-normal text-cream/35">optional</span></label>
                        <input value={privateForm.company} onChange={(e) => setP('company', e.target.value)} placeholder="Company name" className={fieldClass} />
                      </div>
                      <div>
                        <label className={labelClass}>Email</label>
                        <input type="email" value={privateForm.email} onChange={(e) => setP('email', e.target.value)} placeholder="jane@email.com" className={fieldClass} />
                      </div>
                      <div>
                        <label className={labelClass}>Phone</label>
                        <input type="tel" value={privateForm.phone} onChange={(e) => setP('phone', e.target.value)} placeholder="+1 555 000 0000" className={fieldClass} />
                      </div>
                      <div className="sm:col-span-2">
                        <label className={labelClass}>What are you planning? <span className="font-normal text-cream/35">optional</span></label>
                        <textarea value={privateForm.message} onChange={(e) => setP('message', e.target.value)} rows={3} placeholder="Tell us about the occasion, menu ideas, budget, timing…" className={`${fieldClass} resize-none`} />
                      </div>
                    </div>
                    <div className="mt-9 flex items-center justify-between">
                      <button type="button" onClick={() => setStep(0)} className="btn-ghost">Back</button>
                      <button type="button" disabled={!p1Valid} onClick={() => setStep(2)} className="btn-primary disabled:cursor-not-allowed disabled:opacity-40">Review</button>
                    </div>
                  </div>
                )}

                {step === 2 && (
                  <div className="mt-9 animate-fade-up">
                    <h3 className="font-display text-2xl text-cream">Review your request</h3>
                    <dl className="mt-7 divide-y divide-cream/10 rounded-2xl border border-cream/10 bg-ink/40 px-6">
                      {[
                        ['Event', privateForm.eventType],
                        ['Preferred date', privateForm.date],
                        ['Estimated guests', privateForm.guestRange],
                        ['Space', privateForm.space],
                        ['Name', privateForm.name],
                        ...(privateForm.company ? [['Company', privateForm.company] as [string, string]] : []),
                        ['Email', privateForm.email],
                        ['Phone', privateForm.phone],
                        ['Details', privateForm.message || '—'],
                      ].map(([k, v]) => (
                        <div key={k} className="flex items-center justify-between gap-6 py-3.5 text-sm">
                          <dt className="text-cream/55">{k}</dt>
                          <dd className="text-right font-medium text-cream">{v}</dd>
                        </div>
                      ))}
                    </dl>
                    {error && (
                      <p className="mt-5 rounded-xl border border-brand/40 bg-brand/10 px-4 py-3 text-sm text-cream">{error}</p>
                    )}
                    <div className="mt-9 flex items-center justify-between">
                      <button type="button" onClick={() => setStep(1)} className="btn-ghost" disabled={submitting}>Back</button>
                      <button type="button" onClick={confirm} disabled={submitting} className="btn-primary disabled:cursor-not-allowed disabled:opacity-60">
                        {submitting ? 'Submitting…' : 'Submit Request'}
                      </button>
                    </div>
                  </div>
                )}
              </>
            )}

            {/* ---------- SUCCESS (shared) ---------- */}
            {mode !== '' && step === 3 && (
              <div className="relative flex min-h-[560px] flex-col items-center justify-center text-center animate-fade-up">
                <Confetti />
                <span className="relative grid h-20 w-20 place-items-center rounded-full bg-gold/15 text-gold ring-1 ring-gold/40">
                  <svg viewBox="0 0 24 24" className="h-9 w-9" aria-hidden="true">
                    <path d="M5 13l4 4L19 7" stroke="currentColor" strokeWidth="2.5" fill="none" strokeLinecap="round" strokeLinejoin="round" />
                  </svg>
                </span>

                {mode === 'table' ? (
                  <>
                    <h3 className="mt-6 font-display text-3xl text-cream">Table reserved</h3>
                    <p className="mt-3 max-w-sm text-sm leading-relaxed text-cream/70">
                      Thank you, {tableForm.name.split(' ')[0] || 'guest'}. We&rsquo;ve sent a confirmation to{' '}
                      <span className="text-cream">{tableForm.email}</span>. We can&rsquo;t wait to host you.
                    </p>
                    <div className="mt-7 rounded-2xl border border-cream/10 bg-ink/40 px-7 py-5 text-sm">
                      <p className="text-xs uppercase tracking-[0.2em] text-cream/50">Confirmation</p>
                      <p className="mt-1 font-display text-2xl tracking-wide text-gold">{reference}</p>
                      <p className="mt-2 text-cream/70">{tableForm.guests} {tableForm.guests === 1 ? 'guest' : 'guests'} · {tableForm.date} · {tableForm.time}</p>
                    </div>
                  </>
                ) : (
                  <>
                    <h3 className="mt-6 font-display text-3xl text-cream">Request received</h3>
                    <p className="mt-3 max-w-sm text-sm leading-relaxed text-cream/70">
                      Thank you, {privateForm.name.split(' ')[0] || 'guest'}. Our events team will reach out to{' '}
                      <span className="text-cream">{privateForm.email}</span> within 24 hours to craft your event.
                    </p>
                    <div className="mt-7 rounded-2xl border border-cream/10 bg-ink/40 px-7 py-5 text-sm">
                      <p className="text-xs uppercase tracking-[0.2em] text-cream/50">Inquiry reference</p>
                      <p className="mt-1 font-display text-2xl tracking-wide text-gold">{reference}</p>
                      <p className="mt-2 text-cream/70">{privateForm.eventType} · {privateForm.guestRange} guests · {privateForm.date}</p>
                    </div>
                  </>
                )}

                <div className="mt-8 flex flex-wrap justify-center gap-4">
                  <Link href="/" className="btn-ghost">Back to Home</Link>
                  <button type="button" onClick={resetAll} className="btn-primary">New Reservation</button>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>
    </section>
  );
}
