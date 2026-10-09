'use client';

import { useMemo, useState, type CSSProperties } from 'react';
import Link from 'next/link';
import {
  to12h,
  type OrderMenuItem,
  type OrderMode,
  type ScheduleType,
} from '@/lib/order';
import { FIELD_CLASS, LABEL_CLASS } from './styles';
import { pay } from '@/lib/payment';
import MenuStep from './MenuStep';
import ScheduleStep from './ScheduleStep';
import DineInStep from './DineInStep';

const TAKE_AWAY_STEPS = ['Menu', 'Pickup', 'Details'] as const;
const DINE_IN_STEPS = ['Reservation', 'Details'] as const;

type CSSVars = CSSProperties & Record<`--${string}`, string | number>;

// Subtle ornamental damask backdrop (matches the menu & reservation pages).
function OrnamentPattern() {
  return (
    <svg aria-hidden="true" className="pointer-events-none absolute inset-0 h-full w-full text-gold/12">
      <defs>
        <pattern id="order-damask" width="96" height="96" patternUnits="userSpaceOnUse">
          <g fill="none" stroke="currentColor" strokeWidth="1">
            <path d="M48 14c10 8 10 22 0 30-10-8-10-22 0-30z" />
            <path d="M14 48c8-10 22-10 30 0-8 10-22 10-30 0z" />
            <path d="M52 48c8-10 22-10 30 0-8 10-22 10-30 0z" />
            <path d="M48 52c10 8 10 22 0 30-10-8-10-22 0-30z" />
            <circle cx="48" cy="48" r="3" />
          </g>
        </pattern>
      </defs>
      <rect width="100%" height="100%" fill="url(#order-damask)" />
    </svg>
  );
}

// Deterministic firecracker burst (avoids SSR/random mismatches).
const CONFETTI_COLORS = ['#f5761e', '#ffb067', '#e0541a', '#f7f1e8', '#e2470f'];
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
          className="absolute left-1/2 top-[26%] animate-confetti rounded-[1px]"
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

interface SubmitResult {
  number?: string;
  reference?: string;
  estimatedPickup?: string;
  total?: number;
}

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
                {done ? '✓' : i + 1}
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

export default function OrderFlow({ menu, categories }: { menu: OrderMenuItem[]; categories: string[] }) {
  const [mode, setMode] = useState<OrderMode | ''>('');
  const [step, setStep] = useState(0);

  // Cart (take away)
  const [cart, setCart] = useState<Record<string, number>>({});
  const addItem = (id: string) => setCart((c) => ({ ...c, [id]: (c[id] ?? 0) + 1 }));
  const removeItem = (id: string) =>
    setCart((c) => {
      const next = { ...c };
      const q = (next[id] ?? 0) - 1;
      if (q <= 0) delete next[id];
      else next[id] = q;
      return next;
    });

  const lines = useMemo(
    () => menu.filter((m) => cart[m.id]).map((item) => ({ item, qty: cart[item.id] })),
    [menu, cart],
  );
  const subtotal = useMemo(() => lines.reduce((s, l) => s + l.qty * l.item.price, 0), [lines]);

  // Take-away scheduling
  const [scheduleType, setScheduleType] = useState<ScheduleType>('NOW');
  const [schedDate, setSchedDate] = useState('');
  const [schedTime, setSchedTime] = useState('');

  // Dine-in reservation
  const [dineDate, setDineDate] = useState('');
  const [dineTime, setDineTime] = useState('');
  const [guests, setGuests] = useState(2);
  const [dineNotes, setDineNotes] = useState('');

  // Contact (shared)
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [phone, setPhone] = useState('');
  const [orderNotes, setOrderNotes] = useState('');

  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');
  const [result, setResult] = useState<SubmitResult | null>(null);

  const steps = mode === 'DINE_IN' ? DINE_IN_STEPS : TAKE_AWAY_STEPS;
  const successStep = steps.length; // step index of the success screen
  const contactValid = name.trim().length >= 2 && /.+@.+\..+/.test(email) && phone.trim().length >= 5;

  const scheduleValid = scheduleType === 'NOW' || (!!schedDate && !!schedTime);
  const dineValid = !!dineDate && !!dineTime && guests > 0;

  const reset = () => {
    setMode('');
    setStep(0);
    setCart({});
    setScheduleType('NOW');
    setSchedDate('');
    setSchedTime('');
    setDineDate('');
    setDineTime('');
    setGuests(2);
    setDineNotes('');
    setName('');
    setEmail('');
    setPhone('');
    setOrderNotes('');
    setError('');
    setResult(null);
  };

  async function submit() {
    setSubmitting(true);
    setError('');
    try {
      if (mode === 'TAKE_AWAY') {
        const payment = await pay({
          amount: subtotal,
          description: `Take Away order · $${subtotal.toFixed(2)}`,
          name,
          email,
          phone,
        });
        const res = await fetch('/api/orders', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            type: 'TAKE_AWAY',
            scheduleType,
            scheduleDate: scheduleType === 'LATER' ? schedDate : undefined,
            scheduleTime: scheduleType === 'LATER' ? schedTime : undefined,
            items: lines.map((l) => ({ menuItemId: l.item.id, name: l.item.name, qty: l.qty })),
            name,
            email,
            phone,
            notes: orderNotes || undefined,
            payment: payment ?? undefined,
          }),
        });
        const data = await res.json();
        if (!res.ok) throw new Error(data.error || 'Could not place your order.');
        setResult({ number: data.number, estimatedPickup: data.estimatedPickup, total: data.total });
      } else {
        const res = await fetch('/api/reservations', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            kind: 'TABLE',
            date: dineDate,
            time: dineTime,
            guests,
            name,
            email,
            phone,
            requests: dineNotes || undefined,
          }),
        });
        const data = await res.json();
        if (!res.ok) throw new Error(data.error || 'Could not book your table.');
        setResult({ reference: data.reference });
      }
      setStep(successStep);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Something went wrong. Please try again.');
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <section className="relative min-h-screen overflow-hidden bg-ink pb-20 pt-28">
      <OrnamentPattern />
      <div className="pointer-events-none absolute -right-40 top-10 h-96 w-96 rounded-full bg-gold/10 blur-[130px]" />
      <div className="pointer-events-none absolute -left-40 bottom-10 h-96 w-96 rounded-full bg-brand/5 blur-[130px]" />
      <div className="container relative">
        <div className="rounded-[2rem] border border-cream/10 bg-ink-soft/60 p-7 sm:p-10">
          {/* ---- Choose order type ---- */}
          {mode === '' && (
            <div className="animate-fade-up">
              <p className="font-display text-xs font-semibold uppercase tracking-[0.3em] text-gold">
                Go4Foodie · Order Online
              </p>
              <h2 className="mt-3 font-display text-3xl text-cream">How would you like to order?</h2>
              <p className="mt-1 text-sm text-cream/55">Choose take away or reserve a table to dine in.</p>

              <div className="mt-7 grid gap-4 sm:grid-cols-2">
                <button
                  type="button"
                  onClick={() => { setMode('TAKE_AWAY'); setStep(0); }}
                  className="group rounded-2xl border border-cream/15 bg-ink/40 p-6 text-left transition-all duration-300 hover:-translate-y-1 hover:border-gold/50"
                >
                  <span className="grid h-12 w-12 place-items-center rounded-xl bg-gold/15 text-gold ring-1 ring-gold/30">
                    <svg viewBox="0 0 24 24" className="h-6 w-6" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                      <path d="M6 2l1.5 3M18 2l-1.5 3M4 7h16l-1.2 12.2A2 2 0 0 1 16.8 21H7.2a2 2 0 0 1-2-1.8L4 7zM9 11v6M15 11v6" />
                    </svg>
                  </span>
                  <h3 className="mt-5 font-display text-xl font-bold uppercase tracking-tight text-cream">Take Away</h3>
                  <p className="mt-2 text-sm leading-relaxed text-cream/60">
                    Order ahead and pick up — now, or scheduled for later.
                  </p>
                </button>

                <button
                  type="button"
                  onClick={() => { setMode('DINE_IN'); setStep(0); }}
                  className="group rounded-2xl border border-cream/15 bg-ink/40 p-6 text-left transition-all duration-300 hover:-translate-y-1 hover:border-gold/50"
                >
                  <span className="grid h-12 w-12 place-items-center rounded-xl bg-gold/15 text-gold ring-1 ring-gold/30">
                    <svg viewBox="0 0 24 24" className="h-6 w-6" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                      <path d="M5 4v6a2 2 0 0 0 2 2M9 4v6a2 2 0 0 1-2 2M7 4v16M16 4c-1.4 0-2.4 2-2.4 4.5S14.6 13 16 13v7" />
                    </svg>
                  </span>
                  <h3 className="mt-5 font-display text-xl font-bold uppercase tracking-tight text-cream">Dine-In</h3>
                  <p className="mt-2 text-sm leading-relaxed text-cream/60">
                    Reserve a table — choose your date, time and party size.
                  </p>
                </button>
              </div>

              <p className="mt-8 text-center text-xs text-cream/40">
                Hosting a celebration?{' '}
                <Link href="/table-reservation" className="text-gold underline underline-offset-4">
                  Plan a private event
                </Link>
              </p>
            </div>
          )}

          {/* ---- Active flow (steps before success) ---- */}
          {mode !== '' && step < successStep && (
            <>
              <Stepper steps={steps} step={step} />

              {/* TAKE AWAY */}
              {mode === 'TAKE_AWAY' && step === 0 && (
                <div className="mt-9">
                  <MenuStep
                    menu={menu}
                    categories={categories}
                    cart={cart}
                    lines={lines}
                    subtotal={subtotal}
                    onAdd={addItem}
                    onRemove={removeItem}
                    onNext={() => setStep(1)}
                  />
                </div>
              )}

              {mode === 'TAKE_AWAY' && step === 1 && (
                <>
                  <ScheduleStep
                    scheduleType={scheduleType}
                    setScheduleType={setScheduleType}
                    date={schedDate}
                    setDate={setSchedDate}
                    time={schedTime}
                    setTime={setSchedTime}
                  />
                  <div className="mt-9 flex items-center justify-between">
                    <button type="button" onClick={() => setStep(0)} className="btn-ghost">Back</button>
                    <button type="button" disabled={!scheduleValid} onClick={() => setStep(2)} className="btn-primary disabled:cursor-not-allowed disabled:opacity-40">Continue</button>
                  </div>
                </>
              )}

              {/* DINE IN */}
              {mode === 'DINE_IN' && step === 0 && (
                <>
                  <DineInStep
                    date={dineDate}
                    setDate={setDineDate}
                    time={dineTime}
                    setTime={setDineTime}
                    guests={guests}
                    setGuests={setGuests}
                    notes={dineNotes}
                    setNotes={setDineNotes}
                  />
                  <div className="mt-9 flex items-center justify-between">
                    <button type="button" onClick={() => setMode('')} className="btn-ghost">Back</button>
                    <button type="button" disabled={!dineValid} onClick={() => setStep(1)} className="btn-primary disabled:cursor-not-allowed disabled:opacity-40">Continue</button>
                  </div>
                </>
              )}

              {/* DETAILS (shared, last step before success) */}
              {step === steps.length - 1 && (
                <div className="mt-9 animate-fade-up">
                  <h3 className="font-display text-2xl text-cream">Your details</h3>

                  {/* Order summary */}
                  {mode === 'TAKE_AWAY' ? (
                    <div className="mt-6 overflow-hidden rounded-2xl border border-cream/10 bg-ink/40 text-sm">
                      <div className="flex items-center justify-between border-b border-cream/10 px-5 py-3.5">
                        <span className="text-xs font-semibold uppercase tracking-[0.18em] text-gold">Order summary</span>
                        <span className="rounded-full bg-gold/10 px-3 py-1 text-xs font-medium text-gold ring-1 ring-gold/20">
                          Take Away · {scheduleType === 'NOW' ? 'ASAP' : 'Scheduled'}
                        </span>
                      </div>
                      <ul className="divide-y divide-cream/5 px-5">
                        {lines.map((l) => (
                          <li key={l.item.id} className="flex items-start gap-4 py-4">
                            {l.item.imageUrl && (
                              // eslint-disable-next-line @next/next/no-img-element
                              <img
                                src={l.item.imageUrl}
                                alt={l.item.name}
                                className="h-14 w-14 flex-none rounded-xl object-cover ring-1 ring-cream/10"
                              />
                            )}
                            <div className="min-w-0 flex-1">
                              <p className="font-display text-[15px] text-cream">
                                <span className="text-gold">{l.qty}×</span> {l.item.name}
                              </p>
                              {l.item.description && (
                                <p className="mt-1 text-xs leading-relaxed text-cream/50">{l.item.description}</p>
                              )}
                              <p className="mt-1.5 text-xs text-cream/40">${l.item.price.toFixed(2)} each</p>
                            </div>
                            <span className="whitespace-nowrap font-display text-[15px] font-semibold text-cream">
                              ${(l.qty * l.item.price).toFixed(2)}
                            </span>
                          </li>
                        ))}
                      </ul>
                      <div className="space-y-2 border-t border-cream/10 px-5 py-4">
                        {scheduleType === 'LATER' && (
                          <div className="flex items-center justify-between text-cream/55">
                            <span>Pickup</span>
                            <span className="text-cream/80">{schedDate} · {to12h(schedTime)}</span>
                          </div>
                        )}
                        <div className="flex items-center justify-between">
                          <span className="text-cream/60">Subtotal</span>
                          <span className="font-display text-lg font-semibold text-cream">${subtotal.toFixed(2)}</span>
                        </div>
                      </div>
                    </div>
                  ) : (
                    <div className="mt-6 rounded-2xl border border-cream/10 bg-ink/40 p-5 text-sm">
                      <div className="flex items-center justify-between">
                        <span className="text-cream/60">Dine-In · {guests} {guests === 1 ? 'guest' : 'guests'}</span>
                        <span className="text-cream">{dineDate} · {to12h(dineTime)}</span>
                      </div>
                    </div>
                  )}

                  <div className="mt-6 grid gap-5 sm:grid-cols-2">
                    <div className="sm:col-span-2">
                      <label className={LABEL_CLASS}>Full name</label>
                      <input value={name} onChange={(e) => setName(e.target.value)} placeholder="Jane Doe" className={FIELD_CLASS} />
                    </div>
                    <div>
                      <label className={LABEL_CLASS}>Email</label>
                      <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="jane@email.com" className={FIELD_CLASS} />
                    </div>
                    <div>
                      <label className={LABEL_CLASS}>Phone</label>
                      <input type="tel" value={phone} onChange={(e) => setPhone(e.target.value)} placeholder="+1 555 000 0000" className={FIELD_CLASS} />
                    </div>
                    {mode === 'TAKE_AWAY' && (
                      <div className="sm:col-span-2">
                        <label className={LABEL_CLASS}>Order notes <span className="font-normal text-cream/35">optional</span></label>
                        <textarea value={orderNotes} onChange={(e) => setOrderNotes(e.target.value)} rows={2} placeholder="Allergies, utensils, special instructions…" className={`${FIELD_CLASS} resize-none`} />
                      </div>
                    )}
                  </div>

                  {error && (
                    <p className="mt-5 rounded-xl border border-brand/40 bg-brand/10 px-4 py-3 text-sm text-cream">{error}</p>
                  )}

                  <div className="mt-8 flex items-center justify-between">
                    <button type="button" onClick={() => setStep(step - 1)} className="btn-ghost">Back</button>
                    <button
                      type="button"
                      disabled={!contactValid || submitting}
                      onClick={submit}
                      className="btn-primary disabled:cursor-not-allowed disabled:opacity-40"
                    >
                      {submitting ? 'Submitting…' : mode === 'TAKE_AWAY' ? 'Place Order' : 'Confirm Reservation'}
                    </button>
                  </div>
                </div>
              )}
            </>
          )}

          {/* ---- Success ---- */}
          {mode !== '' && step === successStep && result && (
            <div className="relative flex min-h-[480px] flex-col items-center justify-center overflow-hidden text-center animate-fade-up">
              <Confetti />
              <span className="relative grid h-20 w-20 place-items-center rounded-full bg-gold/15 text-gold ring-1 ring-gold/40">
                <svg viewBox="0 0 24 24" className="h-9 w-9" aria-hidden="true">
                  <path d="M5 13l4 4L19 7" stroke="currentColor" strokeWidth="2.5" fill="none" strokeLinecap="round" strokeLinejoin="round" />
                </svg>
              </span>

              {mode === 'TAKE_AWAY' ? (
                <>
                  <h3 className="mt-6 font-display text-3xl text-cream">Order placed</h3>
                  <p className="mt-3 max-w-sm text-sm leading-relaxed text-cream/70">
                    Thanks, {name.split(' ')[0] || 'guest'} — it&rsquo;s gone to the kitchen. We&rsquo;ve sent a confirmation to{' '}
                    <span className="text-cream">{email}</span>.
                  </p>
                  <div className="mt-7 rounded-2xl border border-cream/10 bg-ink/40 px-7 py-5 text-sm">
                    <p className="text-xs uppercase tracking-[0.2em] text-cream/50">Order number</p>
                    <p className="mt-1 font-display text-2xl tracking-wide text-gold">{result.number}</p>
                    <p className="mt-2 text-cream/70">
                      {result.estimatedPickup
                        ? `Pickup around ${new Date(result.estimatedPickup).toLocaleString('en-US', { weekday: 'short', hour: 'numeric', minute: '2-digit' })}`
                        : 'We will text you when it is ready.'}
                    </p>
                  </div>
                </>
              ) : (
                <>
                  <h3 className="mt-6 font-display text-3xl text-cream">Table reserved</h3>
                  <p className="mt-3 max-w-sm text-sm leading-relaxed text-cream/70">
                    Thanks, {name.split(' ')[0] || 'guest'}. We&rsquo;ve sent a confirmation to{' '}
                    <span className="text-cream">{email}</span>. We can&rsquo;t wait to host you.
                  </p>
                  <div className="mt-7 rounded-2xl border border-cream/10 bg-ink/40 px-7 py-5 text-sm">
                    <p className="text-xs uppercase tracking-[0.2em] text-cream/50">Confirmation</p>
                    <p className="mt-1 font-display text-2xl tracking-wide text-gold">{result.reference}</p>
                    <p className="mt-2 text-cream/70">{guests} {guests === 1 ? 'guest' : 'guests'} · {dineDate} · {to12h(dineTime)}</p>
                  </div>
                </>
              )}

              <div className="mt-8 flex flex-wrap justify-center gap-4">
                <Link href="/" className="btn-ghost">Back to Home</Link>
                <button type="button" onClick={reset} className="btn-primary">New Order</button>
              </div>
            </div>
          )}
        </div>
      </div>
    </section>
  );
}
