import Image from 'next/image';
import Link from 'next/link';

const PANEL = 'flex flex-col items-center justify-center bg-[#ffffff] px-6 py-16 text-center';

export default function Visit() {
  return (
    <section id="visit" className="w-full">
      <div className="grid grid-cols-1 lg:grid-cols-2">
        {/* Top-left: food spread */}
        <div className="relative min-h-[320px] lg:min-h-[560px]">
          <Image
            src="https://images.unsplash.com/photo-1515169067868-5387ec356754?fm=jpg&q=60&w=3000&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D"
            alt="Guests toasting together at a restaurant event"
            fill
            sizes="(max-width: 1024px) 100vw, 50vw"
            className="object-cover"
          />
        </div>

        {/* Top-right: upcoming event */}
        <div className={PANEL}>
          <h3 className=" text-2xl uppercase tracking-wide text-black font-bold">
            Upcoming Event
          </h3>
          <span className="my-5 h-px w-12 bg-gold" />
          <div className="mx-auto w-full max-w-xl space-y-4 text-left">
            {/* World Cup */}
            <div className="group relative overflow-hidden rounded-2xl bg-ink p-5 shadow-[0_20px_45px_-22px_rgba(0,0,0,0.5)] transition-transform duration-300 hover:-translate-y-1">
              <div className="pointer-events-none absolute -right-8 -top-8 h-28 w-28 rounded-full bg-gold/20 opacity-0 blur-2xl transition-opacity duration-300 group-hover:opacity-100" />
              <div className="relative flex items-start gap-4">
                <span className="grid h-11 w-11 shrink-0 place-items-center rounded-xl bg-gold/15 text-gold ring-1 ring-gold/30">
                  <svg
                    viewBox="0 0 24 24"
                    className="h-5 w-5"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="1.6"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    aria-hidden="true"
                  >
                    <path d="M8 21h8m-4-3v3M6 4h12v3a6 6 0 0 1-12 0V4zM6 6.5H3.8A2 2 0 0 0 6 9.5M18 6.5h2.2A2 2 0 0 1 18 9.5" />
                  </svg>
                </span>
                <div>
                  <div className="flex items-center gap-2">
                    <h3 className="font-display text-lg font-bold uppercase tracking-tight text-cream">
                      World Cup
                    </h3>
                    <span className="inline-flex items-center gap-1.5 rounded-full bg-brand/15 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-brand">
                      <span className="relative flex h-1.5 w-1.5">
                        <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-brand opacity-75" />
                        <span className="relative inline-flex h-1.5 w-1.5 rounded-full bg-brand" />
                      </span>
                      Live
                    </span>
                  </div>
                  <p className="mt-1.5 text-sm leading-relaxed text-cream/70">
                    Showing this summer&rsquo;s World Cup matches live at
                    Go4Foodie. International beer &amp; food specials during the
                    games.{" "}
                    <a
                      href="#footer"
                      className="font-semibold text-gold underline underline-offset-2 transition-colors hover:text-gold-soft"
                    >
                      Contact us
                    </a>{" "}
                    for private-room availability. Catch all the action before
                    and after the City Hall FanFest, right up the street!
                  </p>
                </div>
              </div>
            </div>

            {/* $1 Oysters */}
            <div className="group relative overflow-hidden rounded-2xl bg-ink p-5 shadow-[0_20px_45px_-22px_rgba(0,0,0,0.5)] transition-transform duration-300 hover:-translate-y-1">
              <div className="pointer-events-none absolute -right-8 -top-8 h-28 w-28 rounded-full bg-gold/20 opacity-0 blur-2xl transition-opacity duration-300 group-hover:opacity-100" />
              <div className="relative flex items-start gap-4">
                <span className="grid h-11 w-11 shrink-0 place-items-center rounded-xl bg-gold/15 text-gold ring-1 ring-gold/30">
                  <svg
                    viewBox="0 0 24 24"
                    className="h-5 w-5"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="1.6"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    aria-hidden="true"
                  >
                    <path d="M3 13a9 9 0 0 1 18 0H3zM12 13V4.5M8 13l1.2-7M16 13l-1.2-7M5.4 13l2-5.4M18.6 13l-2-5.4" />
                  </svg>
                </span>
                <div>
                  <h3 className="font-display text-lg font-bold uppercase tracking-tight text-cream">
                    $1 Oysters
                  </h3>
                  <p className="mt-1.5 text-sm leading-relaxed text-cream/70">
                    Join us for $1 oysters every Monday &amp; Friday,
                    4pm&ndash;7pm.
                  </p>
                </div>
              </div>
            </div>
          </div>
          <Link
            href="/table-reservation"
            className="group inline-flex mt-8 shrink-0 items-center gap-3 rounded-pill border border-cream/20 bg-ink-soft py-2 pl-6 pr-2 text-xs font-semibold uppercase tracking-[0.15em] text-cream hover:text-[#f5761e] transition-colors hover:border-[#f5761e]/50"
          >
            Make a Reservation
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
        </div>

        {/* Bottom-left: restaurant info */}
        <div className={PANEL}>
          <h3 className=" text-2xl uppercase tracking-wide text-black font-bold">
            Go4Foodie
          </h3>
          <p className="mt-5 text-sm text-ink/80">
            245 Harbor View Avenue, Boston, MA 02127
          </p>
          <div className="mt-5 font-semibold text-ink">
            <p>617 · 482 · 6060</p>
          </div>
          <p className="mt-3 text-sm text-ink">info@infidec.com</p>
          <div className="mt-4 flex items-center gap-4 text-gold">
            <a
              href="mailto:info@infidec.com"
              aria-label="Email"
              className="transition-colors hover:text-gold-deep"
            >
              <svg viewBox="0 0 24 24" className="h-5 w-5" aria-hidden="true">
                <path
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="1.6"
                  d="M3 6h18v12H3z M3 7l9 6 9-6"
                />
              </svg>
            </a>
            <a
              href="tel:+16174826060"
              aria-label="Call"
              className="transition-colors hover:text-gold-deep"
            >
              <svg viewBox="0 0 24 24" className="h-5 w-5" aria-hidden="true">
                <path
                  fill="currentColor"
                  d="M6.62 10.79a15.5 15.5 0 0 0 6.59 6.59l2.2-2.2a1 1 0 0 1 1.02-.24 11.4 11.4 0 0 0 3.57.57 1 1 0 0 1 1 1V20a1 1 0 0 1-1 1A17 17 0 0 1 3 4a1 1 0 0 1 1-1h3.5a1 1 0 0 1 1 1c0 1.25.2 2.45.57 3.57a1 1 0 0 1-.25 1.02l-2.2 2.2z"
                />
              </svg>
            </a>
          </div>

          <h3 className="mt-9 font-display text-xl uppercase tracking-[0.2em] text-black font-bold">
            Opening Hours
          </h3>
          <p className="mt-3 text-sm text-ink">
            Mon–Fri <span className="font-bold">11:30am–11pm</span> · Sat{" "}
            <span className="font-bold">noon–11pm</span>
          </p>
          <p className="mt-2 text-xs text-ink/60">
            Serving Food · Mon–Fri until 10:30pm · Sat until 11:30pm
          </p>
        </div>

        {/* Bottom-right: map */}
        <div className="relative min-h-[320px] lg:min-h-[560px]">
          <iframe
            title="Restaurant location"
            src="https://www.google.com/maps/embed?pb=!4v1780991727003!6m8!1m7!1sCAoSLEFGMVFpcE5reVd4bEZGamEzNjJZWnAwMXZBaUsySmlEazV1MEZHQTVYV0F6!2m2!1d42.35582152265826!2d-71.05841910635053!3f316.02187003708883!4f-33.932939379091756!5f0.7820865974627469"
            className="absolute inset-0 h-full w-full border-0"
            allowFullScreen
            loading="lazy"
            referrerPolicy="no-referrer-when-downgrade"
          />
        </div>
      </div>
    </section>
  );
}
