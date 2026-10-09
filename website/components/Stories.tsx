import Image from 'next/image';
import { STORY_REELS } from '@/lib/content';
import type { StoryReel } from '@/lib/content';
import Reveal from './Reveal';
import Stars from './Stars';

function PlayButton() {
  return (
    <span className="grid h-14 w-14 place-items-center rounded-full bg-white/90 shadow-lg ring-1 ring-black/5 transition-transform duration-300 group-hover/reel:scale-110">
      <svg viewBox="0 0 24 24" className="h-5 w-5 translate-x-0.5 text-ink" aria-hidden="true">
        <path fill="currentColor" d="M8 5v14l11-7z" />
      </svg>
    </span>
  );
}

const INSTAGRAM_URL = 'https://www.instagram.com/go4foodie';

function ReelCard({ reel }: { reel: StoryReel }) {
  return (
    <a
      href={INSTAGRAM_URL}
      target="_blank"
      rel="noopener noreferrer"
      className="group/reel block w-[300px] shrink-0"
      aria-label={`${reel.title} — view on Instagram`}
    >
      <div className="relative aspect-[4/5] overflow-hidden rounded-2xl">
        <Image
          src={reel.image}
          alt={reel.title}
          fill
          sizes="300px"
          loading="lazy"
          className="object-cover transition-transform duration-700 ease-out group-hover/reel:scale-105"
        />
        {/* Instagram badge */}
        <span className="absolute right-3 top-3 grid h-8 w-8 place-items-center rounded-full bg-black/40 text-white backdrop-blur-sm">
          <svg viewBox="0 0 24 24" className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth="1.6" aria-hidden="true">
            <rect x="3" y="3" width="18" height="18" rx="5" />
            <circle cx="12" cy="12" r="4" />
            <circle cx="17.3" cy="6.7" r="1.1" fill="currentColor" stroke="none" />
          </svg>
        </span>
        <div className="absolute inset-0 grid place-items-center">
          <PlayButton />
        </div>
      </div>

      <h3 className="mt-4 font-display text-lg font-bold uppercase leading-tight text-ink">
        {reel.title}
      </h3>
      <Stars rating={5} showValue={false} className="mt-2 text-gold-deep" />

      <div className="mt-3 flex items-center gap-5 text-sm text-ink/70">
        <span className="flex items-center gap-1.5">
          <svg viewBox="0 0 24 24" className="h-4 w-4 text-ink" aria-hidden="true">
            <path fill="currentColor" d="M2 21h2V9H2v12zm20-11a2 2 0 0 0-2-2h-6.31l.95-4.57.03-.32a1.5 1.5 0 0 0-.44-1.06L13.17 1 6.59 7.59A2 2 0 0 0 6 9v10a2 2 0 0 0 2 2h9a2 2 0 0 0 1.84-1.22l3.02-7.05c.09-.23.14-.47.14-.73v-2z" />
          </svg>
          {reel.likes} Like
        </span>
        <span className="flex items-center gap-1.5">
          <svg viewBox="0 0 24 24" className="h-4 w-4 text-ink" aria-hidden="true">
            <path fill="none" stroke="currentColor" strokeWidth="2" strokeLinejoin="round" d="M4 4h16v12H7l-3 3V4z" />
          </svg>
          {reel.comments} Comment
        </span>
      </div>
    </a>
  );
}

export default function Stories() {
  // Duplicate so the -50% marquee translate loops seamlessly.
  const loop = [...STORY_REELS, ...STORY_REELS];

  return (
    <section id="stories" className="section overflow-hidden bg-white">
      <div className="container text-center">
        <Reveal>
          <p className="font-display text-sm font-semibold uppercase tracking-[0.15em] text-gold-deep">
            {"Go4Foodie Story"}
          </p>
        </Reveal>
        <Reveal delay={1}>
          <h2 className="mx-auto mt-4 max-w-3xl font-display text-[clamp(2.2rem,5.5vw,4rem)] font-bold uppercase leading-[0.95] tracking-tight text-ink">
            A Glimpse Into Go4Foodie
          </h2>
        </Reveal>
        <Reveal delay={2}>
          <p className="mx-auto mt-5 max-w-lg text-sm leading-relaxed text-ink/60">
            Our reels showcase more than food; they tell stories of craftsmanship,
            teamwork and the joy of creating flavors that connect people.
          </p>
        </Reveal>
        <Reveal delay={2}>
          <a
            href={INSTAGRAM_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="group mt-7 inline-flex items-center gap-2.5 rounded-pill bg-ink px-7 py-3 text-xs font-semibold uppercase tracking-[0.15em] text-cream transition-transform duration-300 hover:-translate-y-0.5"
          >
            <svg viewBox="0 0 24 24" className="h-4 w-4 text-gold" fill="none" stroke="currentColor" strokeWidth="1.6" aria-hidden="true">
              <rect x="3" y="3" width="18" height="18" rx="5" />
              <circle cx="12" cy="12" r="4" />
              <circle cx="17.3" cy="6.7" r="1.1" fill="currentColor" stroke="none" />
            </svg>
            Follow @go4foodie
          </a>
        </Reveal>
      </div>

      {/* Full-bleed continuous slider */}
      <div className="group relative mt-14 flex w-full overflow-hidden">
        <ul className="flex shrink-0 animate-marquee gap-6 pr-6">
          {loop.map((reel, i) => (
            <li key={i} aria-hidden={i >= STORY_REELS.length}>
              <ReelCard reel={reel} />
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}
