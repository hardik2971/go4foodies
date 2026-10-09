'use client';

import { useMemo, useState } from 'react';
import type { CartLine, OrderMenuItem } from '@/lib/order';

function Qty({ qty, onAdd, onRemove }: { qty: number; onAdd: () => void; onRemove: () => void }) {
  if (qty === 0) {
    return (
      <button
        type="button"
        onClick={onAdd}
        className="rounded-pill border border-gold/50 px-4 py-1.5 text-xs font-semibold uppercase tracking-wide text-gold transition-colors hover:bg-gold hover:text-white"
      >
        Add
      </button>
    );
  }
  return (
    <div className="flex items-center gap-2">
      <button
        type="button"
        onClick={onRemove}
        aria-label="Remove one"
        className="grid h-7 w-7 place-items-center rounded-full border border-cream/25 text-cream transition-colors hover:border-gold hover:text-gold"
      >
        −
      </button>
      <span className="w-5 text-center text-sm font-semibold text-cream">{qty}</span>
      <button
        type="button"
        onClick={onAdd}
        aria-label="Add one"
        className="grid h-7 w-7 place-items-center rounded-full border border-gold bg-gold text-white"
      >
        +
      </button>
    </div>
  );
}

export default function MenuStep({
  menu,
  categories,
  cart,
  lines,
  subtotal,
  onAdd,
  onRemove,
  onNext,
}: {
  menu: OrderMenuItem[];
  categories: string[];
  cart: Record<string, number>;
  lines: CartLine[];
  subtotal: number;
  onAdd: (id: string) => void;
  onRemove: (id: string) => void;
  onNext: () => void;
}) {
  const [active, setActive] = useState('All');
  const [query, setQuery] = useState('');
  const cats = ['All', ...categories];

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return menu.filter((m) => {
      const inCat = active === 'All' || m.category === active;
      const inQuery = !q || m.name.toLowerCase().includes(q) || m.description.toLowerCase().includes(q);
      return inCat && inQuery;
    });
  }, [menu, active, query]);

  const count = lines.reduce((n, l) => n + l.qty, 0);

  return (
    <div className="animate-fade-up">
      <h3 className="font-display text-2xl text-cream">Build your order</h3>
      <p className="mt-1 text-sm text-cream/55">Add dishes to your bag, then choose a pickup time.</p>

      {/* Search + categories */}
      <div className="mt-6 flex flex-wrap items-center gap-3">
        <input
          type="search"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search dishes…"
          className="w-full rounded-pill border border-cream/15 bg-ink px-4 py-2.5 text-sm text-cream outline-none placeholder:text-cream/40 focus:border-gold sm:w-64"
        />
        <div className="flex flex-wrap gap-2">
          {cats.map((c) => (
            <button
              key={c}
              type="button"
              onClick={() => setActive(c)}
              className={`rounded-pill px-3.5 py-1.5 text-xs font-semibold uppercase tracking-wide transition-colors ${
                active === c ? 'bg-gold text-white' : 'border border-cream/20 text-cream/70 hover:border-gold/60'
              }`}
            >
              {c}
            </button>
          ))}
        </div>
      </div>

      <div className="mt-7 grid gap-8 lg:grid-cols-[1fr_320px]">
        {/* Dishes */}
        <div>
          {filtered.length === 0 ? (
            <p className="py-16 text-center text-sm text-cream/50">No dishes match your search.</p>
          ) : (
            <ul className="grid gap-4 sm:grid-cols-2">
              {filtered.map((m) => (
                <li
                  key={m.id}
                  className="flex gap-3 rounded-2xl border border-cream/10 bg-ink/40 p-3 transition-colors hover:border-gold/30"
                >
                  <div className="h-20 w-20 flex-none overflow-hidden rounded-xl bg-ink">
                    {/* Menu images come from arbitrary admin-set hosts — use a plain
                        img to avoid next/image's host allowlist. */}
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img
                      src={m.imageUrl}
                      alt={m.name}
                      loading="lazy"
                      className="h-full w-full object-cover"
                    />
                  </div>
                  <div className="flex min-w-0 flex-1 flex-col">
                    <p className="truncate font-display text-sm font-bold uppercase tracking-tight text-cream">
                      {m.name}
                    </p>
                    <p className="mt-1 line-clamp-2 text-xs leading-relaxed text-cream/55">{m.description}</p>
                    <div className="mt-auto flex items-center justify-between pt-2">
                      <span className="font-display text-sm font-semibold text-cream">${m.price.toFixed(2)}</span>
                      <Qty qty={cart[m.id] ?? 0} onAdd={() => onAdd(m.id)} onRemove={() => onRemove(m.id)} />
                    </div>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </div>

        {/* Cart summary */}
        <aside className="lg:sticky lg:top-24 lg:self-start">
          <div className="rounded-2xl border border-cream/10 bg-ink-soft p-5">
            <h4 className="font-display text-lg text-cream">Your bag</h4>
            {lines.length === 0 ? (
              <p className="mt-4 text-sm text-cream/50">Your bag is empty. Add a dish to get started.</p>
            ) : (
              <ul className="mt-4 space-y-3">
                {lines.map((l) => (
                  <li key={l.item.id} className="flex items-start justify-between gap-3 text-sm">
                    <span className="text-cream/85">
                      <span className="font-semibold text-cream">{l.qty}×</span> {l.item.name}
                    </span>
                    <span className="whitespace-nowrap text-cream/70">${(l.qty * l.item.price).toFixed(2)}</span>
                  </li>
                ))}
              </ul>
            )}

            <div className="mt-5 flex items-center justify-between border-t border-cream/10 pt-4">
              <span className="text-sm text-cream/60">Subtotal</span>
              <span className="font-display text-xl font-semibold text-cream">${subtotal.toFixed(2)}</span>
            </div>

            <button
              type="button"
              disabled={count === 0}
              onClick={onNext}
              className="btn-primary mt-5 w-full disabled:cursor-not-allowed disabled:opacity-40"
            >
              Continue{count > 0 ? ` · ${count} item${count > 1 ? 's' : ''}` : ''}
            </button>
          </div>
        </aside>
      </div>
    </div>
  );
}
