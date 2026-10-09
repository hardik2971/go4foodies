'use client';

import { useState, useEffect } from 'react';
import Image from 'next/image';
import { useRouter } from 'next/navigation';

// Build a wavy (stamp-like) seal outline: radius gently waves in and out.
function scallopPath(
  cx: number,
  cy: number,
  base: number,
  amp: number,
  bumps: number,
  steps = 360
): string {
  let d = '';
  for (let i = 0; i <= steps; i++) {
    const a = (i / steps) * Math.PI * 2;
    const r = base + amp * Math.cos(bumps * a);
    const x = cx + r * Math.cos(a);
    const y = cy + r * Math.sin(a);
    d += `${i === 0 ? 'M' : 'L'}${x.toFixed(2)} ${y.toFixed(2)}`;
  }
  return d + 'Z';
}

const SCALLOP = scallopPath(50, 50, 39, 5, 12);

// Each card is a slide: its thumbnail switches the hero background + headline.
const SLIDES = [
  {
    label: "Our Restaurant",
    href: "/about",
    headline: "Great Moments With Great Tastes",
    thumb:
      "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=600&q=70",
    alt: "Warmly lit restaurant interior",
    bg: { type: "video", src: "/our-restaurant.mp4" },
  },
  {
    label: "Menu",
    href: "/menu",
    headline: "A Menu Crafted To Remember",
    thumb:
      "https://images.unsplash.com/photo-1525755662778-989d0524087e?auto=format&fit=crop&w=600&q=70",
    alt: "Chef plating a signature dish",
    bg: { type: "video", src: "/menu.mp4" },
  },
  {
    label: "Reservation",
    href: "/table-reservation",
    headline: "Reserve A Table, Savor The Evening",
    thumb:
      "https://images.unsplash.com/photo-1559339352-11d035aa65de?auto=format&fit=crop&w=600&q=70",
    alt: "Guest enjoying wine at the table",
    bg: { type: "video", src: "/reservation.mp4" },
  },
];

export default function Hero() {
  const router = useRouter();
  // Start on the "Our Restaurant" slide (current video + current headline).
  const [active, setActive] = useState(SLIDES.length - 1);

  const goTo = (href: string) => {
    if (href.startsWith('/')) router.push(href);
    else window.location.hash = href;
  };

  // Auto-advance to the next slide every 7 seconds (resets on manual change).
  useEffect(() => {
    const id = setTimeout(() => {
      setActive((prev) => (prev + 1) % SLIDES.length);
    }, 7000);
    return () => clearTimeout(id);
  }, [active]);

  // QR code points at this site's /menu page (resolved on the client).
  const [menuUrl, setMenuUrl] = useState('https://go4foodie.com/menu');
  useEffect(() => {
    setMenuUrl(`${window.location.origin}/menu`);
  }, []);
  const qrSrc = `https://api.qrserver.com/v1/create-qr-code/?size=160x160&margin=0&data=${encodeURIComponent(
    menuUrl
  )}`;

  return (
    <section className="relative isolate h-screen min-h-[640px] w-full overflow-hidden bg-ink" id="book" data-hero>
      {/* Background layers — crossfade between slides */}
      {SLIDES.map((slide, i) => (
        <div
          key={slide.label}
          className={`absolute inset-0 -z-10 transition-opacity duration-700 ${
            i === active ? 'opacity-100' : 'opacity-0'
          }`}
          aria-hidden="true"
        >
          {slide.bg.type === 'video' ? (
            <video
              className="h-full w-full object-cover"
              src={slide.bg.src}
              autoPlay
              muted
              loop
              playsInline
              preload="auto"
            />
          ) : (
            <Image
              src={slide.bg.src}
              alt=""
              fill
              priority={i === SLIDES.length - 1}
              sizes="100vw"
              className="object-cover"
            />
          )}
        </div>
      ))}

      {/* Legibility overlay */}
      <div className="absolute inset-0 -z-10 bg-ink/45" />

      {/* Centered logo + headline — re-animates on slide change */}
      <div className="flex h-full w-full flex-col items-center justify-center gap-5 px-6 pb-52 sm:gap-6 sm:pb-32 lg:pb-28">
        <Image
          src="/go4foodie-logo-light.png"
          alt="Go4Foodie"
          width={1200}
          height={336}
          priority
          className="h-16 w-auto drop-shadow-[0_2px_18px_rgba(0,0,0,0.55)] sm:h-24 md:h-28"
        />
        <h1
          key={active}
          className="animate-fade-up text-center font-forum font-normal uppercase text-cream text-[clamp(2.9rem,8vw,4.25rem)] leading-tight drop-shadow-[0_2px_18px_rgba(0,0,0,0.55)]"
        >
          {SLIDES[active].headline}
        </h1>
        <div className="mt-2 flex flex-wrap items-center justify-center gap-4">
          {/* Buy a gift card */}
          <button
            type="button"
            onClick={() => window.dispatchEvent(new CustomEvent('open-giftcard'))}
            className="group inline-flex items-center gap-2.5 rounded-pill bg-gradient-to-r from-gold via-gold to-gold-deep px-7 py-3.5 text-sm font-semibold uppercase tracking-[0.15em] text-white shadow-glow ring-1 ring-white/30 transition-transform duration-300 hover:-translate-y-0.5"
          >
            <svg viewBox="0 0 24 24" className="h-4 w-4" aria-hidden="true">
              <path
                fill="none"
                stroke="currentColor"
                strokeWidth="1.8"
                strokeLinejoin="round"
                d="M20 12v9H4v-9M2 7h20v5H2zM12 21V7m0 0H8.5a2.5 2.5 0 1 1 2.5-2.5V7zm0 0h3.5a2.5 2.5 0 1 0-2.5-2.5V7z"
              />
            </svg>
            Buy a Gift Card
          </button>

          {/* Order online — internal Take Away / Dine-In flow */}
          <button
            type="button"
            onClick={() => router.push('/order')}
            className="group inline-flex items-center gap-2.5 rounded-pill border border-cream/40 bg-cream/5 px-7 py-3.5 text-sm font-semibold uppercase tracking-[0.15em] text-cream backdrop-blur-md transition-all duration-300 hover:border-gold hover:bg-cream/10 hover:text-gold"
          >
            <svg viewBox="0 0 24 24" className="h-4 w-4" aria-hidden="true">
              <path
                fill="none"
                stroke="currentColor"
                strokeWidth="1.8"
                strokeLinecap="round"
                strokeLinejoin="round"
                d="M6 2L4 6v14a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V6l-2-4H6zM4 6h16M16 10a4 4 0 0 1-8 0"
              />
            </svg>
            Order Online
          </button>
        </div>
      </div>

      {/* Bottom-left: location */}
      <div className="absolute bottom-32 left-6 z-10 text-cream md:left-10 lg:bottom-8">
        <p className="mb-2 font-forum text-xs uppercase tracking-[0.25em] text-cream/80">
          / Find Us
        </p>
        <address className="not-italic text-sm leading-relaxed text-cream/90">
          245 Harbor View Avenue
          <br />
          Boston, MA 02127
        </address>
        <div className="mt-5 hidden items-center gap-3 sm:flex">
          {/* Facebook */}
          <a
            href="https://www.facebook.com/Go4Foodie"
            target="_blank"
            rel="noopener noreferrer"
            aria-label="Facebook"
            className="grid h-10 w-10 place-items-center rounded-full border border-cream/40 bg-cream/5 text-cream backdrop-blur-md transition-all duration-300 hover:border-gold hover:bg-cream/10 hover:text-gold"
          >
            <svg viewBox="0 0 24 24" className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinejoin="round" aria-hidden="true">
              <path d="M17 2h-3a4 4 0 0 0-4 4v3H7v4h3v8h4v-8h3l1-4h-4V6a1 1 0 0 1 1-1h3z" />
            </svg>
          </a>
          {/* Twitter */}
          <a
            href="https://x.com/go4foodie"
            target="_blank"
            rel="noopener noreferrer"
            aria-label="Twitter"
            className="grid h-10 w-10 place-items-center rounded-full border border-cream/40 bg-cream/5 text-cream backdrop-blur-md transition-all duration-300 hover:border-gold hover:bg-cream/10 hover:text-gold"
          >
            <svg viewBox="0 0 24 24" className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinejoin="round" aria-hidden="true">
              <path d="M22 5.8c-.7.3-1.5.5-2.3.6.8-.5 1.4-1.3 1.7-2.2-.8.5-1.6.8-2.5 1a3.9 3.9 0 0 0-6.7 3.6A11 11 0 0 1 4 4.8a3.9 3.9 0 0 0 1.2 5.2c-.6 0-1.2-.2-1.7-.5v.1a3.9 3.9 0 0 0 3.1 3.8c-.5.2-1.1.2-1.7.1a3.9 3.9 0 0 0 3.6 2.7A7.8 7.8 0 0 1 3 17.9 11 11 0 0 0 9 19.6c7.2 0 11.1-6 11.1-11.1v-.5c.8-.6 1.4-1.3 1.9-2.2z" />
            </svg>
          </a>
          {/* Instagram */}
          <a
            href="https://www.instagram.com/go4foodie"
            target="_blank"
            rel="noopener noreferrer"
            aria-label="Instagram"
            className="grid h-10 w-10 place-items-center rounded-full border border-cream/40 bg-cream/5 text-cream backdrop-blur-md transition-all duration-300 hover:border-gold hover:bg-cream/10 hover:text-gold"
          >
            <svg viewBox="0 0 24 24" className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth="1.6" aria-hidden="true">
              <rect x="3" y="3" width="18" height="18" rx="5" />
              <circle cx="12" cy="12" r="4" />
              <circle cx="17.3" cy="6.7" r="1.1" fill="currentColor" stroke="none" />
            </svg>
          </a>
        </div>
      </div>

      {/* Bottom-center: slider cards */}
      <div className="pointer-events-none absolute bottom-8 left-1/2 z-10 block w-full max-w-3xl -translate-x-1/2 px-4 sm:px-6">
        <div className="pointer-events-auto grid grid-cols-3 gap-2 sm:gap-4">
          {SLIDES.map((slide, i) => {
            const isActive = i === active;
            return (
              <button
                key={slide.label}
                type="button"
                onClick={() => goTo(slide.href)}
                aria-pressed={isActive}
                className={`group relative block aspect-[16/10] overflow-hidden rounded-card text-left transition-all duration-300 ${
                  isActive
                    ? "shadow-[0_35px_70px_-15px_rgba(0,0,0,0.85)] ring-2 ring-gold/40"
                    : "opacity-100 hover:opacity-100"
                }`}
              >
                <Image
                  src={slide.thumb}
                  alt={slide.alt}
                  fill
                  sizes="(max-width: 1024px) 33vw, 240px"
                  className="object-cover transition-transform duration-500 group-hover:scale-105 cursor-pointer"
                />
                {/* Dark rounded tab pinned to the bottom-right corner */}
                <div className="absolute bottom-0 right-0 flex items-center gap-1.5 rounded-tl-card bg-ink py-1.5 pl-3 pr-2.5 sm:gap-3 sm:py-2 sm:pl-4 sm:pr-4">
                  {/* Concave fillet above the tab (right edge) */}
                  <svg
                    className="absolute bottom-full right-0 h-5 w-5"
                    viewBox="0 0 24 24"
                    aria-hidden="true"
                  >
                    <path d="M24 0 A24 24 0 0 1 0 24 L24 24 Z" fill="#0a1c18" />
                  </svg>
                  {/* Concave fillet left of the tab (bottom edge) */}
                  <svg
                    className="absolute right-full bottom-0 h-5 w-5"
                    viewBox="0 0 24 24"
                    aria-hidden="true"
                  >
                    <path d="M24 0 A24 24 0 0 1 0 24 L24 24 Z" fill="#0a1c18" />
                  </svg>
                  <span
                    className={`truncate font-forum text-[10px] uppercase tracking-[0.12em] cursor-pointer transition-colors duration-300 sm:text-sm sm:tracking-[0.18em] ${isActive ? "text-gold" : "text-cream"}`}
                  >
                    {slide.label}
                  </span>
                  <span
                    role="link"
                    tabIndex={0}
                    aria-label={`Open ${slide.label}`}
                    onClick={(e) => {
                      e.stopPropagation();
                      goTo(slide.href);
                    }}
                    onKeyDown={(e) => {
                      if (e.key === "Enter" || e.key === " ") {
                        e.stopPropagation();
                        goTo(slide.href);
                      }
                    }}
                    className={`flex h-6 w-6 shrink-0 cursor-pointer items-center justify-center rounded-full border transition-colors duration-300 sm:h-7 sm:w-7 ${
                      isActive
                        ? "border-gold text-gold"
                        : "border-cream/50 text-cream group-hover:border-gold group-hover:text-gold"
                    }`}
                  >
                    <svg
                      viewBox="0 0 24 24"
                      className="h-3.5 w-3.5"
                      aria-hidden="true"
                    >
                      <path
                        d="M5 12h14m-6-6l6 6-6 6"
                        stroke="currentColor"
                        strokeWidth="2"
                        fill="none"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                      />
                    </svg>
                  </span>
                </div>
              </button>
            );
          })}
        </div>
      </div>

      {/* Bottom-right: QR (scan for menu) + established badge */}
      <div className="absolute bottom-32 right-6 z-10 flex items-end gap-3 md:right-10 lg:bottom-8 lg:gap-4">
        {/* Scan-to-menu QR code */}
        <a
          href="/menu"
          className="flex flex-col items-center gap-1.5 rounded-xl bg-cream/95 p-2 shadow-lg transition-transform duration-300 hover:-translate-y-0.5"
          aria-label="Scan or tap to view the menu"
        >
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={qrSrc} alt="QR code linking to the menu" width={64} height={64} className="h-12 w-12 sm:h-16 sm:w-16" />
          <span className="font-forum text-[9px] uppercase tracking-[0.18em] text-ink">
            Scan · Menu
          </span>
        </a>
      </div>
    </section>
  );
}
