import type { Metadata } from 'next';
import Header from '@/components/Header';
import Footer from '@/components/Footer';
import LiveMenuExplorer from '@/components/LiveMenuExplorer';

export const metadata: Metadata = {
  title: 'Menu',
  description:
    'Explore the full menu at Go4Foodie — seasonal, wood-fired plates, house-made pasta, and curated wine.',
};

function OrnamentPattern() {
  return (
    <svg
      aria-hidden="true"
      className="pointer-events-none absolute inset-0 h-full w-full text-gold/20"
    >
      <defs>
        <pattern id="menu-damask" width="96" height="96" patternUnits="userSpaceOnUse">
          <g fill="none" stroke="currentColor" strokeWidth="1">
            <path d="M48 14c10 8 10 22 0 30-10-8-10-22 0-30z" />
            <path d="M14 48c8-10 22-10 30 0-8 10-22 10-30 0z" />
            <path d="M52 48c8-10 22-10 30 0-8 10-22 10-30 0z" />
            <path d="M48 52c10 8 10 22 0 30-10-8-10-22 0-30z" />
            <circle cx="48" cy="48" r="3" />
          </g>
        </pattern>
      </defs>
      <rect width="100%" height="100%" fill="url(#menu-damask)" />
    </svg>
  );
}

export default function MenuPage() {
  return (
    <>
      <Header />
      <main id="main">
        {/* Ornamental heading banner */}
        <section className="relative overflow-hidden bg-ink pb-16 pt-36 text-center">
          <OrnamentPattern />
          <div className="container relative">
            <p className="font-display text-xs font-semibold uppercase tracking-[0.35em] text-gold">
              Go4Foodie · Fine Dining
            </p>
            <h1 className="mt-5 font-display text-[clamp(2.75rem,7vw,5rem)] leading-none text-cream">
              Our Menu
            </h1>

            {/* Divider with sparkle */}
            <div className="mt-6 flex items-center justify-center gap-3">
              <span className="h-px w-16 bg-cream/25" />
              <svg viewBox="0 0 24 24" className="h-3.5 w-3.5 text-gold" aria-hidden="true">
                <path fill="currentColor" d="M12 2l2 8 8 2-8 2-2 8-2-8-8-2 8-2z" />
              </svg>
              <span className="h-px w-16 bg-cream/25" />
            </div>

            <p className="mx-auto mt-6 max-w-xl text-sm leading-relaxed text-cream/60">
              Seven categories, seasonal dishes - the full breadth of our kitchen,
              wood-fired and made by hand, on one menu.
            </p>
          </div>
        </section>

        {/* Search, filters & dishes — live from the admin menu */}
        <LiveMenuExplorer />
      </main>
      <Footer />
    </>
  );
}
