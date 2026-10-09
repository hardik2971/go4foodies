import type { MenuItem } from '@/lib/content';
import Stars from './Stars';

/**
 * Menu card (§5).
 * Default state shows image, name, price and a rating row.
 * On hover a white preview card lifts in over the item with the full detail.
 */
export default function MenuCard({ item }: { item: MenuItem }) {
  return (
    <article className="group/card relative">
      {/* ---- Base card (dims to 50% while the preview is open) ---- */}
      <div className="transition-opacity duration-300 group-hover/card:opacity-50">
        <div className="relative aspect-[4/4] overflow-hidden rounded-card">
          {/* Menu images come from arbitrary admin-set hosts — plain img avoids
              next/image's host allowlist. */}
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={item.image}
            alt={item.name}
            loading="lazy"
            className="h-full w-full object-cover transition-transform duration-700 ease-out group-hover/card:scale-110"
          />
        </div>

        <h3 className="mt-4 font-display text-xl font-bold uppercase tracking-tight text-cream">
          {item.name}
        </h3>
        <p className="mt-2 font-display text-lg font-semibold text-cream">
          ${item.price.toFixed(2)}
        </p>

        <div className="mt-4 h-px w-full bg-white/10" />

        <div className="mt-3 flex items-center gap-2 text-sm">
          <Stars
            rating={item.rating}
            showValue={false}
            className="text-gold-deep"
          />
          <span className="text-cream/75">
            {item.rating.toFixed(1)} Stars{" "}
            <span className="text-cream/45">(40 reviews)</span>
          </span>
        </div>
      </div>

      {/* ---- Hover preview popup ---- */}
      <div className="pointer-events-none absolute left-1/2 top-1/2 z-30 w-[300px] max-w-[88vw] -translate-x-1/2 -translate-y-1/2 scale-95 opacity-0 transition-all duration-300 ease-out group-hover/card:scale-100 group-hover/card:opacity-100 group-hover/card:pointer-events-auto">
        <div className="rounded-[1.75rem] bg-white p-7 text-center text-ink shadow-float">
          <h4 className="font-display text-2xl font-bold uppercase tracking-tight text-ink">
            {item.name}
          </h4>
          <p className="mt-2 text-sm leading-relaxed text-ink/70">
            {item.desc}
          </p>

          <div className="relative mx-auto mt-5 aspect-[4/3] overflow-hidden rounded-2xl">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={item.image} alt={item.name} className="h-full w-full object-cover" />
          </div>

          <p className="mt-6 font-display text-2xl font-bold text-ink">
            ${item.price.toFixed(2)}
          </p>
          <div className="mt-2 flex items-center justify-center gap-3 text-sm">
            <a
              href="/order"
              className="font-semibold text-gold-deep underline underline-offset-4 transition-colors hover:text-ink"
            >
              Order Online
            </a>
            <span className="text-ink/25">·</span>
            <a
              href="/table-reservation"
              className="text-ink underline underline-offset-4 transition-colors hover:text-gold-deep"
            >
              Book a Table
            </a>
          </div>

          <div className="mt-4 flex items-center justify-center gap-2 text-sm">
            <Stars
              rating={item.rating}
              showValue={false}
              className="text-gold-deep"
            />
            <span className="font-semibold text-ink/80">
              {item.rating.toFixed(1)} Stars{" "}
              <span className="font-normal text-ink/50">(40 reviews)</span>
            </span>
          </div>
        </div>
      </div>
    </article>
  );
}
