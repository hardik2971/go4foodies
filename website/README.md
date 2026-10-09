# Savora — Restaurant Landing Page

A modern, fully responsive fine-dining landing page built with **Next.js 14 (App Router)** + **Tailwind CSS** + **Framer-ready animation utilities**. Dark, editorial aesthetic with a warm gold accent.

## Quick start

```bash
npm install
npm run dev      # http://localhost:3000
npm run build    # production build
npm start        # serve production build
```

> Images are served from Unsplash via `next/image` (allow-listed in `next.config.mjs`). An internet connection is needed for image previews; everything else runs offline.

---

## Project structure

```
app/
  layout.js        Fonts (next/font), SEO metadata, JSON-LD, skip link
  page.js          Section composition (semantic <main>)
  globals.css      Design system: tokens, components, scroll-reveal, reduced-motion
  sitemap.js       /sitemap.xml
  robots.js        /robots.txt
components/
  Header.js        §1  Sticky navbar + responsive mobile drawer
  Hero.js          §2  Split hero, bg image, floating dish card, gradient overlays
  Marquee.js       §3  Infinite CSS marquee strip (pauses on hover)
  About.js         §4  Floating image cluster + centered content (light section)
  Menu.js          §5  Responsive menu grid
  MenuCard.js      §5  Reusable card: image, tag, rating, price, hover
  Stories.js       §6  Reels: video cards, play overlay, engagement stats
  Footer.js        Reservation CTA band + footer columns
  Reveal.js        Scroll-reveal wrapper (IntersectionObserver)
  Stars.js         Rating UI primitive (full / half / empty)
lib/
  content.js       Single source of truth for all section data
tailwind.config.js Design tokens (color, type, spacing, radius, shadow, keyframes)
```

---

## §7 Design System

| Token group | Where | Notes |
|---|---|---|
| **Colors** | `tailwind.config.js → colors` | `ink` (warm charcoal bg), `cream` (light bg/text), `gold` (accent), `sage`, `muted` |
| **Typography** | `fontFamily` + `fontSize` | Display: *Fraunces* (serif). Body: *Manrope*. Fluid `display-xl/lg/md` via `clamp()` |
| **Spacing** | `spacing` | Adds `18`, `section` (7rem), `section-sm` (4.5rem) on top of Tailwind's scale |
| **Radius** | `borderRadius` | `card` (1.25rem), `pill` (999px) |
| **Shadows** | `boxShadow` | `card`, `float`, `glow` (gold ring) |
| **Container** | `container` | Centered, max `1200px` (`xl`), responsive gutters |

Reusable component classes live in `globals.css` under `@layer components`: `.btn-primary/.btn-ghost/.btn-dark`, `.eyebrow`, `.stars`, `.section`.

## §8 Responsive breakpoints

Tailwind defaults: `sm 640 · md 768 · lg 1024 · xl 1200`.

- **Desktop (≥1024):** multi-column hero, 3-col menu grid, 4-up reels grid, full nav.
- **Tablet (768–1023):** stacked hero, 2-col menu, horizontal-scroll reels, full nav.
- **Mobile (<768):** single column everywhere, hamburger drawer, horizontal scrollers, condensed spacing (`section-sm`).

## §9 Animation guide

| Effect | Implementation |
|---|---|
| Entrance | `.animate-fade-up` keyframe on hero copy |
| Scroll reveal | `Reveal.js` toggles `.is-visible`; CSS transition in `globals.css`. `delay={1..4}` staggers children |
| Hover scale | Card image `group-hover:scale-110`, card lift `hover:-translate-y` |
| Marquee | `animate-marquee` (CSS `translateX(-50%)`), list duplicated for seamless loop |
| Floating card | `animate-floaty` (gentle Y bob) on hero dish + about image |
| Reduced motion | `@media (prefers-reduced-motion)` disables all of the above |

## §10 SEO & performance

- **Metadata + OpenGraph/Twitter + JSON-LD** `Restaurant` schema in `layout.js`.
- **`sitemap.js` / `robots.js`** auto-generated routes.
- **`next/image`** everywhere: AVIF/WebP, responsive `sizes`, `priority` on the LCP hero image, `loading="lazy"` below the fold.
- **Semantic HTML:** `<header> <main> <section> <article> <nav> <footer> <address> <dl>`, skip-link, `aria-*` on interactive controls.
- **Fonts:** `next/font` self-hosts with `display: swap` (no layout shift, no render-blocking).

---

## §11 Developer checklist (build order)

1. ✅ Scaffold project — `package.json`, `next.config.mjs`, `postcss`, `tailwind.config.js`, `jsconfig.json`.
2. ✅ Design system — `globals.css` tokens + component classes; fonts in `layout.js`.
3. ✅ Primitives — `Reveal.js`, `Stars.js`; data in `lib/content.js`.
4. ✅ Header/Navbar — sticky + mobile drawer.
5. ✅ Hero — split layout, bg image, floating card, overlays, CTAs.
6. ✅ Marquee strip.
7. ✅ About — floating images + centered content.
8. ✅ Menu — reusable `MenuCard` + responsive grid.
9. ✅ Stories/Reels — video cards, play overlay, stats.
10. ✅ Footer — reservation CTA + columns.
11. ✅ SEO/perf — metadata, sitemap, robots, image optimization.
12. ▢ Hook "Book a Table" / "Add to order" to a real reservation/cart backend.
13. ▢ Replace Unsplash URLs + `/og.jpg` with brand assets; update address/phone/JSON-LD.

## Customization

All copy, images, menu items, and reels live in **`lib/content.js`** — edit there, no component changes needed. Brand colors/type/spacing live in **`tailwind.config.js`**.
