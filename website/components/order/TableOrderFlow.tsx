'use client';

import { useMemo, useState } from 'react';
import Link from 'next/link';
import type { OrderMenuItem } from '@/lib/order';
import { FIELD_CLASS, LABEL_CLASS } from './styles';
import { pay } from '@/lib/payment';
import MenuStep from './MenuStep';

export interface TableInfo {
  id: string;
  number: string;
  name?: string;
  code: string;
}

const STEPS = ['Menu', 'Details'] as const;

function Stepper({ step }: { step: number }) {
  return (
    <ol className="flex items-center">
      {STEPS.map((label, i) => {
        const done = i < step;
        const current = i === step;
        return (
          <li key={label} className="flex flex-1 items-center last:flex-none">
            <div className="flex items-center gap-3">
              <span className={`grid h-9 w-9 place-items-center rounded-full border text-sm font-semibold ${done ? 'border-gold bg-gold text-white' : current ? 'border-gold text-gold' : 'border-cream/25 text-cream/50'}`}>
                {done ? '✓' : i + 1}
              </span>
              <span className={`hidden text-xs font-semibold uppercase tracking-[0.15em] sm:block ${current || done ? 'text-cream' : 'text-cream/40'}`}>{label}</span>
            </div>
            {i < STEPS.length - 1 && <span className={`mx-3 h-px flex-1 ${done ? 'bg-gold' : 'bg-cream/15'}`} />}
          </li>
        );
      })}
    </ol>
  );
}

export default function TableOrderFlow({
  table,
  menu,
  categories,
}: {
  table: TableInfo;
  menu: OrderMenuItem[];
  categories: string[];
}) {
  const [step, setStep] = useState(0);
  const [cart, setCart] = useState<Record<string, number>>({});
  const [name, setName] = useState('');
  const [phone, setPhone] = useState('');
  const [email, setEmail] = useState('');
  const [notes, setNotes] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');
  const [orderNumber, setOrderNumber] = useState('');

  const addItem = (id: string) => setCart((c) => ({ ...c, [id]: (c[id] ?? 0) + 1 }));
  const removeItem = (id: string) =>
    setCart((c) => {
      const next = { ...c };
      const q = (next[id] ?? 0) - 1;
      if (q <= 0) delete next[id];
      else next[id] = q;
      return next;
    });

  const lines = useMemo(() => menu.filter((m) => cart[m.id]).map((item) => ({ item, qty: cart[item.id] })), [menu, cart]);
  const subtotal = useMemo(() => lines.reduce((s, l) => s + l.qty * l.item.price, 0), [lines]);
  const nameValid = name.trim().length >= 1;

  async function submit() {
    setSubmitting(true);
    setError('');
    try {
      const payment = await pay({
        amount: subtotal,
        description: `Table ${table.number} order · $${subtotal.toFixed(2)}`,
        name,
        email: email || undefined,
        phone: phone || undefined,
      });
      const res = await fetch('/api/orders', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          type: 'DINE_IN',
          tableCode: table.code,
          items: lines.map((l) => ({ menuItemId: l.item.id, name: l.item.name, qty: l.qty })),
          name,
          phone: phone || undefined,
          email: email || undefined,
          notes: notes || undefined,
          payment: payment ?? undefined,
        }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Could not send your order.');
      setOrderNumber(data.number);
      setStep(STEPS.length);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Something went wrong. Please try again.');
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <section className="relative min-h-screen overflow-hidden bg-ink pb-20 pt-28">
      <div className="pointer-events-none absolute -right-40 top-10 h-96 w-96 rounded-full bg-gold/10 blur-[130px]" />
      <div className="container relative">
        {/* Table banner */}
        <div className="mb-5 flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-gold/30 bg-gold/10 px-5 py-3">
          <p className="font-display text-sm uppercase tracking-[0.2em] text-gold">
            Dine-in · Table {table.number}{table.name ? ` · ${table.name}` : ''}
          </p>
          <p className="text-xs text-cream/60">Your order goes straight to the kitchen for this table.</p>
        </div>

        <div className="rounded-[2rem] border border-cream/10 bg-ink-soft/60 p-7 sm:p-10">
          {step < STEPS.length && <Stepper step={step} />}

          {/* Menu */}
          {step === 0 && (
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

          {/* Details */}
          {step === 1 && (
            <div className="mt-9 animate-fade-up">
              <h3 className="font-display text-2xl text-cream">Almost there</h3>
              <div className="mt-6 rounded-2xl border border-cream/10 bg-ink/40 p-5 text-sm">
                <div className="flex items-center justify-between">
                  <span className="text-cream/60">Table {table.number} · {lines.reduce((n, l) => n + l.qty, 0)} items</span>
                  <span className="font-display text-lg font-semibold text-cream">${subtotal.toFixed(2)}</span>
                </div>
                <ul className="mt-3 space-y-1 text-cream/70">
                  {lines.map((l) => (
                    <li key={l.item.id}>{l.qty}× {l.item.name}</li>
                  ))}
                </ul>
              </div>

              <div className="mt-6 grid gap-5 sm:grid-cols-2">
                <div className="sm:col-span-2">
                  <label className={LABEL_CLASS}>Your name</label>
                  <input value={name} onChange={(e) => setName(e.target.value)} placeholder="Name for the order" className={FIELD_CLASS} />
                </div>
                <div>
                  <label className={LABEL_CLASS}>Phone <span className="font-normal text-cream/35">optional</span></label>
                  <input type="tel" value={phone} onChange={(e) => setPhone(e.target.value)} placeholder="+1 555 000 0000" className={FIELD_CLASS} />
                </div>
                <div>
                  <label className={LABEL_CLASS}>Email <span className="font-normal text-cream/35">optional</span></label>
                  <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="for a receipt" className={FIELD_CLASS} />
                </div>
                <div className="sm:col-span-2">
                  <label className={LABEL_CLASS}>Notes <span className="font-normal text-cream/35">optional</span></label>
                  <textarea value={notes} onChange={(e) => setNotes(e.target.value)} rows={2} placeholder="Allergies, special instructions…" className={`${FIELD_CLASS} resize-none`} />
                </div>
              </div>

              {error && <p className="mt-5 rounded-xl border border-brand/40 bg-brand/10 px-4 py-3 text-sm text-cream">{error}</p>}

              <div className="mt-8 flex items-center justify-between">
                <button type="button" onClick={() => setStep(0)} className="btn-ghost">Back</button>
                <button type="button" disabled={!nameValid || submitting} onClick={submit} className="btn-primary disabled:cursor-not-allowed disabled:opacity-40">
                  {submitting ? 'Sending…' : 'Send to Kitchen'}
                </button>
              </div>
            </div>
          )}

          {/* Success */}
          {step === STEPS.length && (
            <div className="flex min-h-[440px] flex-col items-center justify-center text-center animate-fade-up">
              <span className="grid h-20 w-20 place-items-center rounded-full bg-gold/15 text-gold ring-1 ring-gold/40">
                <svg viewBox="0 0 24 24" className="h-9 w-9" aria-hidden="true">
                  <path d="M5 13l4 4L19 7" stroke="currentColor" strokeWidth="2.5" fill="none" strokeLinecap="round" strokeLinejoin="round" />
                </svg>
              </span>
              <h3 className="mt-6 font-display text-3xl text-cream">Order sent!</h3>
              <p className="mt-3 max-w-sm text-sm leading-relaxed text-cream/70">
                Thanks, {name.split(' ')[0] || 'guest'} — your order is on its way to the kitchen for{' '}
                <span className="text-cream">Table {table.number}</span>.
              </p>
              <div className="mt-7 rounded-2xl border border-cream/10 bg-ink/40 px-7 py-5 text-sm">
                <p className="text-xs uppercase tracking-[0.2em] text-cream/50">Order number</p>
                <p className="mt-1 font-display text-2xl tracking-wide text-gold">{orderNumber}</p>
              </div>
              <Link href="/" className="btn-ghost mt-8">Back to Home</Link>
            </div>
          )}
        </div>
      </div>
    </section>
  );
}
