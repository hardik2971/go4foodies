'use client';

import { useMemo, useState } from 'react';
import { MENU_ITEMS, MENU_CATEGORIES, type MenuItem } from '@/lib/content';
import MenuCard from './MenuCard';
import Reveal from './Reveal';

export default function MenuExplorer({
  items = MENU_ITEMS,
  categories = [...MENU_CATEGORIES],
}: {
  items?: MenuItem[];
  categories?: string[];
}) {
  const [query, setQuery] = useState('');
  const [active, setActive] = useState('All');
  const CATEGORIES = ['All', ...categories];

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return items.filter((item) => {
      const inCategory = active === 'All' || item.category === active;
      const inQuery =
        !q ||
        item.name.toLowerCase().includes(q) ||
        item.desc.toLowerCase().includes(q);
      return inCategory && inQuery;
    });
  }, [items, query, active]);

  return (
    <>
      {/* Search + category bar */}
      <div className="border-b border-cream/10 bg-ink-soft">
        <div className="container flex flex-wrap items-center justify-center gap-3 py-5 lg:flex-nowrap">
          {/* Search */}
          <label className="relative flex w-full items-center sm:w-72">
            <svg viewBox="0 0 24 24" className="pointer-events-none absolute left-4 h-4 w-4 text-cream/40" aria-hidden="true">
              <path fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" d="M21 21l-4.3-4.3M11 18a7 7 0 1 1 0-14 7 7 0 0 1 0 14z" />
            </svg>
            <input
              type="search"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Search dishes..."
              className="w-full rounded-pill border border-cream/15 bg-ink py-2.5 pl-11 pr-4 text-sm text-cream outline-none transition-colors placeholder:text-cream/40 focus:border-brand"
            />
          </label>

          {/* Category pills */}
          <div className="flex flex-wrap justify-center gap-2">
            {CATEGORIES.map((cat) => {
              const isActive = cat === active;
              return (
                <button
                  key={cat}
                  type="button"
                  onClick={() => setActive(cat)}
                  aria-pressed={isActive}
                  className={`rounded-pill px-4 py-2 text-xs font-semibold uppercase tracking-wide transition-colors duration-200 ${
                    isActive
                      ? 'bg-gold text-black'
                      : 'border border-cream/20 bg-ink text-cream/70 hover:border-cream/40 hover:text-cream'
                  }`}
                >
                  {cat}
                </button>
              );
            })}
          </div>
        </div>
      </div>

      {/* Dishes grid */}
      <div className="bg-ink">
        <div className="container py-14">
          {filtered.length === 0 ? (
            <p className="py-20 text-center text-muted">
              No dishes match “{query}” in {active}.
            </p>
          ) : (
            <div className="grid grid-cols-1 gap-x-6 gap-y-12 sm:grid-cols-2 lg:grid-cols-3">
              {filtered.map((item, i) => (
                <Reveal key={item.id} delay={(i % 3) + 1} className="relative hover:z-30">
                  <MenuCard item={item} />
                </Reveal>
              ))}
            </div>
          )}
        </div>
      </div>
    </>
  );
}
