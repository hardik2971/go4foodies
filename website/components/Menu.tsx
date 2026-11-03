'use client';

import Image from 'next/image';
import Link from 'next/link';
import MenuCard from './MenuCard';
import Reveal from './Reveal';
import { MENU_ITEMS } from '@/lib/content';
import { useLiveMenu } from '@/lib/menu-api';

export default function Menu() {
  // Show the first 6 items from the live admin menu (the static site menu is
  // shown until it loads, and stays if the admin is unreachable).
  const items = useLiveMenu()?.items ?? MENU_ITEMS;
  const featured = items.slice(0, 6);

  return (
    <section id="menu" className="section bg-ink">
      <div className="container">
        {/* Header row */}
        <div className="flex flex-col items-start justify-between gap-6 md:flex-row md:items-end">
          <div>
            <Reveal>
              <p className="font-display text-sm font-semibold uppercase tracking-[0.15em] text-gold-deep">
                {"Our Menu"}
              </p>
            </Reveal>
            <Reveal delay={1}>
              <h2 className="mt-4 max-w-xl font-display text-[clamp(2.2rem,4.5vw,3.5rem)] font-bold uppercase leading-[0.95] tracking-tight text-cream">
                Discover the Art
                <br />
                of Taste
              </h2>
            </Reveal>
          </div>
          <Reveal delay={2}>
            <Link
              href="/menu"
              className="group inline-flex shrink-0 items-center gap-3 rounded-pill border border-cream/20 bg-ink-soft py-2 pl-6 pr-2 text-xs font-semibold uppercase tracking-[0.15em] text-cream hover:text-[#f5761e] transition-colors hover:border-[#f5761e]/50"
            >
              View All Menu
              <span className="flex h-8 w-8 items-center justify-center rounded-full bg-[#f5761e] text-white transition-transform duration-300 group-hover:translate-x-0.5">
                <Image
                  src="/arrow.png"
                  alt=""
                  width={16}
                  height={16}
                  className="h-4 w-4 object-contain invert"
                />
              </span>
            </Link>
          </Reveal>
        </div>

        {/* Divider under header */}
        <div className="mt-8 h-px w-full bg-cream/15" />

        {/* Responsive grid (§5): 1 → 2 → 3 columns */}
        <div className="mt-12 grid grid-cols-1 gap-x-6 gap-y-12 sm:grid-cols-2 lg:grid-cols-3">
          {featured.map((item, i) => (
            <Reveal
              key={item.id}
              delay={(i % 3) + 1}
              className="relative hover:z-30"
            >
              <MenuCard item={item} />
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  );
}
