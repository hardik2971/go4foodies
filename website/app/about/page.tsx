import type { Metadata } from 'next';
import Image from 'next/image';
import Link from 'next/link';
import Header from '@/components/Header';
import Footer from '@/components/Footer';
import Reveal from '@/components/Reveal';

export const metadata: Metadata = {
  title: 'About Us',
  description:
    'The story of Go4Foodie - seasonal, wood-fired cooking, natural wine, and a room built for lingering in the heart of Boston.',
};

const STATS = [
  { value: '1980', label: 'Serving Since' },
  { value: '90+', label: 'Seasonal Dishes' },
  { value: '250k', label: 'Guests Hosted' },
  { value: '12', label: 'Culinary Awards' },
];

const VALUES = [
  {
    title: 'Wood-Fired Craft',
    desc: 'Every plate passes over open flame - char, smoke, and patience coax flavor that only fire can give.',
    icon: (
      <path d="M12 3c2 3 4 4.5 4 8a4 4 0 1 1-8 0c0-1.6.7-2.7 1.5-3.6C10 8.6 11 7 12 3z" />
    ),
  },
  {
    title: 'Locally Sourced',
    desc: 'We partner with New England farms, fishers, and foragers - menus shift with what the season offers.',
    icon: <path d="M12 21c0-6 4-10 8-11-1 6-4 10-8 11zm0 0c0-6-4-10-8-11 1 6 4 10 8 11z" />,
  },
  {
    title: 'Natural Wine',
    desc: 'A cellar of low-intervention bottles, poured by sommeliers who love a good story as much as a great pairing.',
    icon: <path d="M8 3h8l-1 7a3 3 0 0 1-6 0L8 3zM12 13v6m-3 0h6" />,
  },
];

interface PressItem {
  title: string;
  subtitle?: string;
  desc: string;
}

const PRESS: PressItem[] = [
  {
    title: 'The Voice of Downtown Boston',
    subtitle: 'Cool Cocktails & Farm-Fresh Dishes',
    desc: 'Escape the city heat with a savory little brasserie in the Financial District, tucked away from the summer rush.',
  },
  {
    title: 'HuffPost Taste',
    subtitle: 'One of Boston’s best raw bars',
    desc: 'They say we serve the “freshest oysters on offer.”',
  },
  {
    title: 'Vacation Idea',
    subtitle: 'A Best Romantic Restaurant',
    desc: 'Featured as a spot for a romantic evening out - sample new flavors and unwind with a glass of wine.',
  },
  {
    title: 'Thrillist: Best New Bar',
    desc: 'Thrillist names Go4Foodie one of Boston’s best new bars, with a huge selection.',
  },
  {
    title: 'Phantom Gourmet',
    desc: 'The Phantom Gourmet goes behind the scenes with our head chef to show how Go4Foodie consistently puts out amazing food.',
  },
  {
    title: 'Paleo Fondue',
    desc: 'The personality and feel of Go4Foodie strike me as alluring yet welcoming - comfortable, energetic, inspired, and classy.',
  },
  {
    title: 'Improper Bostonian',
    subtitle: 'Best Bar: South Boston',
    desc: 'Strong menu, great cocktails, a huge beer list, and a commerce-friendly atmosphere.',
  },
  {
    title: 'Boston Barhopper',
    desc: 'Boston Barhopper shares a glowing write-up of their first visit to Go4Foodie.',
  },
  {
    title: 'Thrillist: New Restaurants',
    desc: 'Thrillist says Go4Foodie is one of Boston’s best new restaurants.',
  },
  {
    title: 'Zagat',
    desc: 'Zagat features Go4Foodie in a list of 25 new Boston restaurants - and wrote a First Look about us.',
  },
  {
    title: 'Trip Expert',
    desc: 'Winner of the 2018 Expert Choice Award from Trip Expert, plus an award for Best in Boston.',
  },
  {
    title: 'CN Traveler',
    desc: 'Readers rank Boston among the best cities for foodies - and Go4Foodie makes the short list.',
  },
];

const SUPPLIERS = [
  { name: 'Wards Berry Farm', location: 'Sharon, MA', product: 'Berries & squash' },
  { name: 'Atomic Coffee Roasters', location: 'Peabody, MA', product: 'Coffee' },
  { name: 'Evy’s Tea', location: 'Boston, MA', product: 'Cold-brewed iced tea' },
  { name: 'Murray’s Chicken', location: 'Pennsylvania', product: 'All-natural chicken' },
  { name: 'Crystal Valley Farms', location: 'Indiana', product: 'All-natural chicken' },
  { name: 'Painted Hills', location: 'Painted Hills, Oregon', product: 'All-natural beef' },
  { name: 'D’Artagnan', location: 'Union, New Jersey', product: 'Meat' },
  { name: 'A&J King Artisan Bakers', location: 'Salem, MA', product: 'Bread' },
];

export default function AboutPage() {
  return (
    <>
      <Header />
      <main id="main" className="bg-ink">
        {/* ---- Hero banner ---- */}
        <section className="relative overflow-hidden pb-20 pt-36 text-center">
          <div className="absolute inset-0 -z-10">
            <Image
              src="https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=1920&q=70"
              alt="Go4Foodie dining room"
              fill
              priority
              sizes="100vw"
              className="object-cover"
            />
            <div className="absolute inset-0 bg-gradient-to-b from-ink/80 via-ink/70 to-ink" />
          </div>
          <div className="container">
            <Reveal>
              <p className="font-display text-xs font-semibold uppercase tracking-[0.3em] text-gold-deep">
                Our Story
              </p>
            </Reveal>
            <Reveal delay={1}>
              <h1 className="mx-auto mt-5 max-w-3xl font-display text-[clamp(2.5rem,6vw,4.75rem)] font-bold uppercase leading-[0.95] tracking-tight text-cream">
                Where Fire Meets Craft
              </h1>
            </Reveal>
            <Reveal delay={2}>
              <p className="mx-auto mt-6 max-w-xl text-sm leading-relaxed text-cream/70">
                Since 1980, Go4Foodie has turned simple, seasonal
                ingredients into unforgettable evenings - wood-fired plates,
                natural wine, and a room built for lingering.
              </p>
            </Reveal>
          </div>
        </section>

        {/* ---- Story split ---- */}
        <section className="section">
          <div className="container grid items-center gap-12 lg:grid-cols-2">
            <Reveal className="relative aspect-[4/5] overflow-hidden rounded-[2rem] border border-cream/10">
              <Image
                src="/front-image.png"
                alt="Go4Foodie dining room"
                fill
                sizes="(max-width: 1024px) 100vw, 50vw"
                className="object-cover"
              />
            </Reveal>
            <div>
              <Reveal>
                <p className="font-display text-xs font-semibold uppercase tracking-[0.3em] text-gold-deep">
                  A Table Built for Lingering
                </p>
              </Reveal>
              <Reveal delay={1}>
                <h2 className="mt-4 font-display text-[clamp(2rem,4vw,3.25rem)] font-bold uppercase leading-[0.95] tracking-tight text-cream">
                  Four Decades by the Fire
                </h2>
              </Reveal>
              <Reveal delay={2}>
                <p className="mt-6 text-sm leading-relaxed text-cream/70">
                  What began as a small grill on Harbor View Avenue has grown into
                  one of Boston&rsquo;s most beloved dining rooms - yet our
                  philosophy has never changed. Cook honestly, source
                  thoughtfully, and treat every guest like family.
                </p>
              </Reveal>
              <Reveal delay={3}>
                <p className="mt-4 text-sm leading-relaxed text-cream/70">
                  Our open kitchen is the heart of the room. Watch flame catch
                  on dry-aged steak, smell rosemary smoke rise from the embers,
                  and settle in for an evening that&rsquo;s meant to be savored
                  slowly.
                </p>
              </Reveal>
            </div>
          </div>
        </section>

        {/* ---- An American Brasserie ---- */}
        <section className="section">
          <div className="container grid items-center gap-12 lg:grid-cols-2">
            <div>
              <Reveal>
                <h2 className="mt-4 font-display text-[clamp(2rem,4vw,3.25rem)] font-bold uppercase leading-[0.95] tracking-tight text-cream">
                  An American Brasserie
                </h2>
              </Reveal>
              <Reveal delay={1}>
                <p className="mt-6 text-sm leading-relaxed text-cream/70">
                  The brasserie originated in France in the mid-to-late 1800s.
                  The word literally translates to &ldquo;brewery&rdquo; -
                  historically a restaurant that brewed its own beer to serve
                  its guests. A brasserie is typically a large, informal
                  restaurant serving food and drink throughout the day.
                </p>
              </Reveal>
              <Reveal delay={2}>
                <p className="mt-6 text-sm leading-relaxed text-cream/70">
                  Go4Foodie borrows from these ideas. While we don&rsquo;t
                  brew our own beer, we pour a wide variety on draft, in bottle,
                  and in can. The bar is a major focal point - a convivial
                  atmosphere and top-notch product. Alongside 25+ beers on tap,
                  we offer an approachable, interesting wine list and a serious
                  craft cocktail program, including cocktails and wines on tap.
                </p>
              </Reveal>
              <Reveal delay={3}>
                <p className="mt-6 text-sm leading-relaxed text-cream/70">
                  The menu is designed for a quick bite or a full-course meal,
                  at lunch or dinner - and we serve late into the night for
                  friends and neighbors who need something after a long
                  evening&rsquo;s work.
                </p>
              </Reveal>
              <Reveal delay={4}>
                <p className="mt-6 text-sm leading-relaxed text-cream/70">
                  Go4Foodie sits at 245 Harbor View Ave. in South Boston, on
                  the edge of the Financial District. We&rsquo;re proud to be
                  part of the neighborhood&rsquo;s revitalization and strive to
                  be a true go-to. Our name pays homage to the area&rsquo;s
                  history and to &lsquo;London Harness,&rsquo; the previous
                  tenant who traded in this space for nearly 100 years.
                </p>
              </Reveal>
            </div>
            <Reveal className="relative aspect-[4/5] overflow-hidden rounded-[2rem] border border-cream/10">
              <Image
                src="/graphic_glass.jpg"
                alt="A signature cocktail on a Go4Foodie coaster"
                fill
                sizes="(max-width: 1024px) 100vw, 50vw"
                className="object-cover"
              />
            </Reveal>
          </div>
        </section>

        {/* ---- Farmers & Suppliers ---- */}
        <section className="section pt-0">
          <div className="container">
            <Reveal>
              <div className="border-b border-cream/15 pb-5">
                <h2 className="font-display text-[clamp(1.8rem,4vw,3rem)] font-bold uppercase tracking-tight text-cream">
                  Farmers &amp; Suppliers We Work With
                </h2>
              </div>
            </Reveal>

            <div className="mt-10 grid grid-cols-1 gap-x-8 gap-y-7 sm:grid-cols-2 lg:grid-cols-3">
              {SUPPLIERS.map((s, i) => (
                <Reveal key={s.name} delay={(i % 3) + 1}>
                  <p className="text-sm leading-relaxed">
                    <span className="font-display font-bold uppercase tracking-tight text-gold">
                      {s.name}
                    </span>{" "}
                    <span className="text-cream/80">{s.location}</span>
                  </p>
                  <p className="mt-0.5 text-sm text-cream/55">{s.product}</p>
                </Reveal>
              ))}
            </div>
          </div>
        </section>

        {/* ---- Stats strip ---- */}
        <section className="border-y border-cream/10 bg-ink-soft/50">
          <div className="container grid grid-cols-2 gap-8 py-14 lg:grid-cols-4">
            {STATS.map((s, i) => (
              <Reveal key={s.label} delay={(i % 4) + 1} className="text-center">
                <p className="font-display text-4xl font-bold text-gold md:text-5xl">
                  {s.value}
                </p>
                <p className="mt-2 text-xs font-semibold uppercase tracking-[0.2em] text-cream/60">
                  {s.label}
                </p>
              </Reveal>
            ))}
          </div>
        </section>

        {/* ---- Values ---- */}
        <section className="section">
          <div className="container">
            <div className="text-center">
              <Reveal>
                <p className="font-display text-xs font-semibold uppercase tracking-[0.3em] text-gold-deep">
                  What We Believe
                </p>
              </Reveal>
              <Reveal delay={1}>
                <h2 className="mx-auto mt-4 max-w-2xl font-display text-[clamp(2rem,4vw,3.25rem)] font-bold uppercase leading-[0.95] tracking-tight text-cream">
                  Craft in Every Detail
                </h2>
              </Reveal>
            </div>

            <div className="mt-14 grid grid-cols-1 gap-6 md:grid-cols-3">
              {VALUES.map((v, i) => (
                <Reveal key={v.title} delay={(i % 3) + 1}>
                  <div className="h-full rounded-[1.5rem] border border-cream/10 bg-ink-soft/60 p-8 transition-colors duration-300 hover:border-gold/40">
                    <span className="grid h-12 w-12 place-items-center rounded-full bg-gold/10 text-gold ring-1 ring-gold/30">
                      <svg
                        viewBox="0 0 24 24"
                        className="h-6 w-6"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="1.5"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        aria-hidden="true"
                      >
                        {v.icon}
                      </svg>
                    </span>
                    <h3 className="mt-6 font-display text-xl font-bold uppercase tracking-tight text-cream">
                      {v.title}
                    </h3>
                    <p className="mt-3 text-sm leading-relaxed text-cream/65">
                      {v.desc}
                    </p>
                  </div>
                </Reveal>
              ))}
            </div>
          </div>
        </section>

        {/* ---- Chef quote ---- */}
        <section className="section pt-0">
          <div className="container">
            <div className="relative overflow-hidden rounded-[2.5rem] border border-cream/10 bg-ink-soft/50">
              <div className="grid items-center gap-0 lg:grid-cols-2">
                <div className="relative min-h-[320px] lg:min-h-[460px]">
                  <Image
                    src="/restaurant-kitchen.png"
                    alt="Go4Foodie kitchen"
                    fill
                    sizes="(max-width: 1024px) 100vw, 50vw"
                    className="object-cover"
                  />
                </div>
                <div className="p-8 sm:p-12 lg:p-16">
                  <span
                    className="font-serif text-6xl leading-none text-gold/30"
                    aria-hidden="true"
                  >
                    &ldquo;
                  </span>
                  <Reveal>
                    <p className="-mt-4 font-display text-2xl leading-snug text-cream md:text-3xl">
                      We don&rsquo;t chase trends. We chase fire, season, and
                      the kind of meal you&rsquo;ll still be talking about next
                      week.
                    </p>
                  </Reveal>
                  <Reveal delay={1}>
                    <div className="mt-8">
                      <p className="font-display text-lg font-bold uppercase tracking-wide text-gold">
                        Ignacio Lopez
                      </p>
                      <p className="text-xs uppercase tracking-[0.2em] text-cream/55">
                        Executive Chef
                      </p>
                    </div>
                  </Reveal>
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* ---- Bio + Directions & Parking (two columns) ---- */}
        <section className="section pt-0">
          <div className="container grid gap-12 lg:grid-cols-2">
            {/* Bio */}
            <div>
              <Reveal>
                <div className="border-b border-cream/15 pb-5">
                  <h2 className="font-display text-[clamp(1.8rem,4vw,3rem)] font-bold uppercase tracking-tight text-cream">
                    Bio
                  </h2>
                </div>
              </Reveal>

              <Reveal delay={1}>
                <p className="mt-7 font-display text-sm font-semibold uppercase tracking-[0.25em] text-gold-deep">
                  Chef Ignacio Lopez
                </p>
              </Reveal>

              <Reveal delay={1} className="mt-5 space-y-4 text-sm leading-relaxed text-cream/70">
                <p>
                  Chef Ignacio Lopez brings a lifelong passion for food, cooking, and serving
                  his guests&rsquo; needs. His career is marked by accepting and excelling in
                  culinary positions across markets that range from casual dining to
                  ultra-luxury.
                </p>
                <p>
                  He began cooking professionally at the age of sixteen. After working his way
                  through fine-dining kitchens in San Diego, he landed his first Executive Sous
                  Chef position at the exclusive Fairbanks Ranch Country Club under Executive
                  Chef Francis Perrot. He has cooked alongside other legendary chefs - including
                  Jeff Jackson, Joachim Splichal, Timothy Au, Kerry Neff and Jean-Pierre Dubray
                  - learning many skills, most notably the market-to-table service he still uses
                  in every kitchen he leads.
                </p>
                <p>
                  After working in restaurants and resorts from New Hampshire to Connecticut to
                  California, he made his way back to the East Coast in 2011. He served as
                  Executive Sous Chef and Chef at notable Boston-area restaurants such as
                  Landana, Exchange Street Bistro, Beat Brasserie and Tuscan Kitchen before
                  joining Go4Foodie.
                </p>
              </Reveal>
            </div>

            {/* Directions & Parking */}
            <div>
              <Reveal>
                <div className="border-b border-cream/15 pb-5">
                  <h2 className="font-display text-[clamp(1.8rem,4vw,3rem)] font-bold uppercase tracking-tight text-cream">
                    Directions &amp; Parking
                  </h2>
                </div>
              </Reveal>

              <Reveal delay={1}>
                <a
                  href="https://www.google.com/maps/dir/?api=1&destination=245+Harbor+View+Avenue+Boston+MA+02127"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="mt-7 inline-flex items-center gap-1.5 text-sm font-semibold text-gold transition-colors hover:text-gold-deep"
                >
                  Get Directions »
                </a>
              </Reveal>

              <Reveal delay={2}>
                <ul className="mt-6 space-y-3.5 text-sm leading-relaxed text-cream/70">
                  {[
                    <>
                      <span className="font-semibold text-cream">Validated parking</span>{' '}
                      available at the 33 Arch Street Garage (reserve ahead of time), entrance on
                      Hawley Street.
                    </>,
                    <>
                      <span className="font-semibold text-cream">Daytime Parking</span> - 20%
                      discount on the posted rate.
                    </>,
                    <>
                      <span className="font-semibold text-cream">Nighttime Parking</span> (Mon–Fri
                      3:30pm–3:00am, up to 10 hours): $8 with validation.
                    </>,
                    <>
                      <span className="font-semibold text-cream">Weekend Parking</span> (all day
                      Saturday &amp; Sunday, up to 10 hours): $8 with validation.
                    </>,
                  ].map((item, i) => (
                    <li key={i} className="flex gap-3">
                      <span className="mt-2 h-1.5 w-1.5 shrink-0 rounded-full bg-gold" />
                      <span>{item}</span>
                    </li>
                  ))}
                </ul>
              </Reveal>
            </div>
          </div>
        </section>

        {/* ---- Awards / Press ---- */}
        <section className="section pt-0">
          <div className="container">
            <Reveal>
              <div className="flex items-end justify-between gap-6 border-b border-cream/15 pb-5">
                <h2 className="font-display text-[clamp(1.8rem,4vw,3rem)] font-bold uppercase tracking-tight text-cream">
                  Awards / Press
                </h2>
                <p className="hidden whitespace-nowrap text-xs uppercase tracking-[0.2em] text-cream/50 sm:block">
                  In the words of others
                </p>
              </div>
            </Reveal>

            {/* Featured: Diner's Choice */}
            <div className="mt-10 flex flex-col items-start justify-between gap-8 md:flex-row md:items-center">
              <Reveal className="max-w-lg">
                <h3 className="font-display text-xl font-bold uppercase tracking-tight text-gold">
                  OpenTable: Diner&rsquo;s Choice 2025
                </h3>
                <p className="mt-3 text-sm leading-relaxed text-cream/70">
                  Go4Foodie has been voted by OpenTable diners as one of the
                  best - selected from the feedback of guests who booked and
                  dined with us.
                </p>
              </Reveal>

              <Reveal delay={1} className="shrink-0">
                <div className="relative grid h-32 w-32 place-items-center rounded-full bg-[#e2470f] text-cream shadow-[0_22px_45px_-15px_rgba(226,71,15,0.65)]">
                  <span className="absolute inset-2 rounded-full border border-dashed border-cream/45" />
                  <span className="absolute top-4 h-2 w-2 rounded-full bg-cream" />
                  <span className="text-center font-serif text-xl italic leading-tight">
                    Diners&rsquo;
                    <br />
                    Choice
                  </span>
                </div>
              </Reveal>
            </div>

            {/* Press mentions grid */}
            <div className="mt-14 grid grid-cols-1 gap-x-8 gap-y-10 sm:grid-cols-2 lg:grid-cols-3">
              {PRESS.map((p, i) => (
                <Reveal key={p.title} delay={(i % 3) + 1}>
                  <article>
                    <h4 className="font-display text-base font-bold uppercase tracking-tight text-gold">
                      {p.title}
                    </h4>
                    {p.subtitle && (
                      <p className="mt-1 text-xs font-semibold uppercase tracking-wide text-cream/50">
                        {p.subtitle}
                      </p>
                    )}
                    <p className="mt-2 text-sm leading-relaxed text-cream/70">
                      {p.desc}
                    </p>
                  </article>
                </Reveal>
              ))}
            </div>
          </div>
        </section>
      </main>
      <Footer />
    </>
  );
}
