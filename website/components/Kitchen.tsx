import Image from 'next/image';
import Link from 'next/link';
import Reveal from './Reveal';

const img = (id: string, w = 700): string =>
  `https://images.unsplash.com/photo-${id}?auto=format&fit=crop&w=${w}&q=70`;

const CATEGORIES = [
  {
    title: 'Breakfast',
    desc: 'Enjoy delicious food, great company, & unforgettable moments. Create cherished memories.',
    image: img('1504754524776-8f4f37790ca0'),
  },
  {
    title: 'Main Dishes',
    desc: 'We believe that food should not only taste amazing but also be made with care. That’s why we source the best.',
    image: img('1414235077428-338989a2e8c0'),
  },
  {
    title: 'Drinks',
    desc: 'We offer a selection of healthy menu options, including salads, grilled dishes, and low-calorie choices.',
    image: img('1514362545857-3bc16c4c7d1b'),
  },
  {
    title: 'Desserts',
    desc: 'Savor the flavors of the Mediterranean with our Grilled Lamb Chops, marinated in a blend of herbs and spices.',
    image: img('1551024601-bec78aea704b'),
  },
];

// Progressive vertical offset → descending staircase layout (lg+).
const OFFSETS = ['lg:mt-0', 'lg:mt-16', 'lg:mt-32', 'lg:mt-48'];

export default function Kitchen() {
  return (
    <section className="section bg-[#fff1e4]">
      <div className="container">
        {/* Header */}
        <div className="text-center">
          <Reveal>
            <p className="font-display text-sm font-semibold uppercase tracking-[0.15em] text-gold-deep">
              {'A Taste of Our Kitchen'}
            </p>
          </Reveal>
          <Reveal delay={1}>
            <h2 className="mx-auto mt-5 max-w-4xl font-display text-[clamp(2.2rem,6vw,4.5rem)] font-bold uppercase leading-[0.95] tracking-tight text-ink">
              A Symphony of Tradition and Modern Taste.
            </h2>
          </Reveal>
        </div>

        {/* Staircase of category cards */}
        <div className="mt-16 flex flex-col gap-8 lg:flex-row lg:items-start lg:gap-6">
          {CATEGORIES.map((cat, i) => (
            <Reveal
              key={cat.title}
              delay={(i % 4) + 1}
              className={`flex-1`}
            >
              <div className="rounded-[1.75rem] bg-white p-7 text-center shadow-[0_30px_60px_-30px_rgba(0,0,0,0.18)] transition-transform duration-300 ease-out hover:scale-105 hover:shadow-[0_40px_80px_-30px_rgba(0,0,0,0.25)]">
                <h3 className="font-display text-2xl font-bold uppercase tracking-tight text-ink">
                  {cat.title}
                </h3>

                <div className="relative mt-6 aspect-[16/11] overflow-hidden rounded-xl">
                  <Image
                    src={cat.image}
                    alt={cat.title}
                    fill
                    sizes="(max-width: 1024px) 100vw, 320px"
                    loading="lazy"
                    className="object-cover"
                  />
                </div>

                <p className="mt-6 text-sm leading-relaxed text-ink/70">
                  {cat.desc}
                </p>

                <Link
                  href="/menu"
                  className="mt-6 inline-block text-xs font-semibold uppercase tracking-[0.15em] text-ink underline underline-offset-4 transition-colors hover:text-gold-deep"
                >
                  Explore All Menu
                </Link>
              </div>
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  );
}
