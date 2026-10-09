'use client';

import { useEffect, useState } from 'react';
import Image from 'next/image';
import Link from 'next/link';
import { NAV_LINKS } from '@/lib/content';

const INLINE_LINKS = [
  { label: 'Menu', href: '/menu' },
  { label: 'About', href: '/about' },
];

function Logo() {
  return (
    <Link href="/" className="group flex items-center" aria-label="Go4Foodie home">
      <Image
        src="/go4foodie-logo-light.png"
        alt="Go4Foodie"
        width={1200}
        height={336}
        priority
        className="h-12 w-auto"
      />
    </Link>
  );
}

export default function Header() {
  const [visible, setVisible] = useState(false);
  const [open, setOpen] = useState(false);

  // Show the header only once the hero scrolls out of view.
  // Pages without a hero (e.g. /menu) show the header immediately.
  useEffect(() => {
    const hero = document.querySelector('[data-hero]');
    if (!hero) {
      setVisible(true);
      return;
    }
    const io = new IntersectionObserver(
      ([entry]) => setVisible(!entry.isIntersecting),
      { rootMargin: '-72px 0px 0px 0px', threshold: 0 }
    );
    io.observe(hero);
    return () => io.disconnect();
  }, []);

  // Lock body scroll when the drawer is open
  useEffect(() => {
    document.body.style.overflow = open ? 'hidden' : '';
    return () => {
      document.body.style.overflow = '';
    };
  }, [open]);

  // QR code for the "Scan for Menu" option (resolved on the client).
  const [menuUrl, setMenuUrl] = useState('https://go4foodie.com/menu');
  useEffect(() => {
    setMenuUrl(`${window.location.origin}/menu`);
  }, []);
  const qrSrc = `https://api.qrserver.com/v1/create-qr-code/?size=160x160&margin=0&data=${encodeURIComponent(
    menuUrl
  )}`;

  return (
    <>
      <header
      className={`fixed inset-x-0 top-0 z-50 transition-all duration-500 ${
        visible && !open ? 'translate-y-0 opacity-100' : 'pointer-events-none -translate-y-full opacity-0'
      }`}
    >
      <div className="sm:container sm:pt-2">
        <nav
          aria-label="Primary"
          className="flex items-center justify-between gap-4 sm:rounded-2xl border border-cream/15 bg-ink/85 px-4 py-3 shadow-[0_25px_60px_-30px_rgba(0,0,0,0.9)] backdrop-blur-md"
        >
          {/* Left: hamburger + logo */}
          <div className="flex items-center gap-1">
            <button
              type="button"
              onClick={() => setOpen((v) => !v)}
              className="grid h-10 w-10 place-items-center rounded-lg border border-cream/25 bg-cream/5 text-cream transition-colors hover:border-gold hover:text-gold"
              aria-label={open ? 'Close menu' : 'Open menu'}
              aria-expanded={open}
              aria-controls="site-menu"
            >
              <span className="relative block h-4 w-5">
                <span className={`absolute left-0 h-0.5 w-5 bg-current transition-all duration-300 ${open ? 'top-1.5 rotate-45' : 'top-0'}`} />
                <span className={`absolute left-0 top-1.5 h-0.5 w-5 bg-current transition-all duration-300 ${open ? 'opacity-0' : 'opacity-100'}`} />
                <span className={`absolute left-0 h-0.5 w-5 bg-current transition-all duration-300 ${open ? 'top-1.5 -rotate-45' : 'top-3'}`} />
              </span>
            </button>
            <Logo />
          </div>

          {/* Right: inline links + book a table */}
          <div className="flex items-center gap-5 md:gap-8">
            <ul className="hidden items-center gap-8 md:flex">
              {INLINE_LINKS.map((link) => (
                <li key={link.href}>
                  <a
                    href={link.href}
                    className="font-display text-sm font-semibold uppercase tracking-[0.15em] text-cream/85 transition-colors hover:text-gold"
                  >
                    {link.label}
                  </a>
                </li>
              ))}
            </ul>

            <a
              href="/table-reservation"
              className="rounded-xl border border-cream/30 px-5 py-2.5 text-[11px] font-semibold uppercase tracking-[0.18em] text-cream transition-colors hover:border-gold hover:bg-gold hover:text-white"
            >
              Book a Table
            </a>
          </div>
        </nav>
      </div>
      </header>

      {/* Slide-in drawer (full navigation) */}
      <div
        id="site-menu"
        className={open ? 'pointer-events-auto' : 'pointer-events-none'}
      >
        <div
          className={`fixed inset-0 z-40 bg-ink/95 backdrop-blur-lg transition-opacity duration-300 ${open ? 'opacity-100' : 'opacity-0'}`}
          onClick={() => setOpen(false)}
        />
        <nav
          className={`fixed right-0 top-0 z-50 flex h-full w-[85%] max-w-sm flex-col overflow-y-auto border-l border-cream/10 bg-ink-soft px-7 py-6 transition-transform duration-300 ${open ? 'translate-x-0' : 'translate-x-full'}`}
          aria-label="Full menu"
        >
          {/* Top: logo + close */}
          <div className="flex items-center justify-between">
            <Link href="/" onClick={() => setOpen(false)} aria-label="Go4Foodie home">
              <Image src="/go4foodie-logo-light.png" alt="Go4Foodie" width={1200} height={336} className="h-9 w-auto" />
            </Link>
            <button
              type="button"
              onClick={() => setOpen(false)}
              aria-label="Close menu"
              className="grid h-10 w-10 place-items-center rounded-lg border border-cream/25 bg-cream/5 text-cream transition-colors hover:border-gold hover:text-gold"
            >
              <svg viewBox="0 0 24 24" className="h-4 w-4" aria-hidden="true">
                <path d="M6 6l12 12M18 6L6 18" stroke="currentColor" strokeWidth="2" fill="none" strokeLinecap="round" />
              </svg>
            </button>
          </div>

          {/* Links */}
          <div className="mt-9 flex flex-col">
            {NAV_LINKS.map((link) => (
              <a
                key={link.href}
                href={link.href}
                onClick={() => setOpen(false)}
                className="border-b border-cream/10 py-4 font-display text-2xl text-cream transition-colors hover:text-gold"
              >
                {link.label}
              </a>
            ))}
          </div>

          {/* Actions */}
          <div className="mt-8 flex flex-col gap-3">
            <button
              type="button"
              onClick={() => {
                setOpen(false);
                window.dispatchEvent(new CustomEvent('open-giftcard'));
              }}
              className="btn-primary w-full"
            >
              Buy a Gift Card
            </button>
            <Link
              href="/order"
              onClick={() => setOpen(false)}
              className="btn-ghost w-full"
            >
              Order Online
            </Link>
          </div>

          {/* Scan for menu */}
          <div className="mt-auto flex items-center gap-4 rounded-xl border border-cream/10 bg-ink/50 p-4">
            <span className="rounded-md bg-white p-1.5">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={qrSrc} alt="Scan to view the menu" width={64} height={64} className="h-16 w-16" />
            </span>
            <div>
              <p className="font-display text-sm font-bold uppercase tracking-wide text-cream">
                Scan for Menu
              </p>
              <p className="mt-1 text-xs leading-relaxed text-cream/50">
                Point your camera to open the full menu.
              </p>
            </div>
          </div>
        </nav>
      </div>
    </>
  );
}
