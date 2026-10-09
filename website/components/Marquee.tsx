import { MARQUEE_ITEMS } from '@/lib/content';

function Dot() {
  return <span className="text-gold" aria-hidden="true">✦</span>;
}

export default function Marquee() {
  // Duplicate the list so the -50% translate loops seamlessly (§3).
  const loop = [...MARQUEE_ITEMS, ...MARQUEE_ITEMS];

  return (
    <section
      aria-label="What we serve"
      className="group border-y border-cream/10 bg-gold/5 py-5"
    >
      <div className="relative flex overflow-hidden">
        {/* edge fades */}
        <div className="pointer-events-none absolute inset-y-0 left-0 z-10 w-16 bg-gradient-to-r from-ink to-transparent" />
        <div className="pointer-events-none absolute inset-y-0 right-0 z-10 w-16 bg-gradient-to-l from-ink to-transparent" />

        <ul className="flex shrink-0 animate-marquee items-center gap-10 pr-10 group-hover:[animation-play-state:paused]">
          {loop.map((item, i) => (
            <li
              key={i}
              className="flex items-center gap-10 whitespace-nowrap font-display text-xl text-cream/85 md:text-2xl"
              aria-hidden={i >= MARQUEE_ITEMS.length}
            >
              {item}
              <Dot />
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}
