import Image from 'next/image';
import Reveal from './Reveal';
import Stars from './Stars';
import Link from 'next/link';

interface Review {
  name: string;
  role: string;
  text: string;
  avatar: string;
}

const img = (id: string, w = 120): string =>
  `https://images.unsplash.com/photo-${id}?auto=format&fit=crop&w=${w}&q=70`;

const REVIEWS: Review[] = [
  {
    name: 'Sakura Tanaka',
    role: 'Business Executive',
    text: 'The flavors at Dinevo are simply unforgettable! Every single dish feels like a journey through authentic taste.',
    avatar: img('1438761681033-6461ffad8d80'),
  },
  {
    name: 'Aiko Matsuda',
    role: 'Culinary Reviewer',
    text: 'The talented chefs at Dinevo truly know how to perfectly balance authentic flavor with modern style and experience.',
    avatar: img('1507003211169-0a1dd7228f2d'),
  },
  {
    name: 'Emi Suzuki',
    role: 'Food Photographer',
    text: 'From the warm ambiance to the friendly staff, Dinevo made our evening truly memorable and special experience.',
    avatar: img('1494790108377-be9c29b29330'),
  },
];

function GoogleG({ className = 'h-5 w-5' }: { className?: string }) {
  return (
    <svg viewBox="0 0 48 48" className={className} aria-label="Google review">
      <path fill="#4285F4" d="M45.12 24.5c0-1.56-.14-3.06-.4-4.5H24v8.51h11.84c-.51 2.75-2.06 5.08-4.39 6.64v5.52h7.11c4.16-3.83 6.56-9.47 6.56-16.17z" />
      <path fill="#34A853" d="M24 46c5.94 0 10.92-1.97 14.56-5.33l-7.11-5.52c-1.97 1.32-4.49 2.1-7.45 2.1-5.73 0-10.58-3.87-12.31-9.07H4.34v5.7C7.96 41.07 15.4 46 24 46z" />
      <path fill="#FBBC05" d="M11.69 28.18C11.25 26.86 11 25.45 11 24s.25-2.86.69-4.18v-5.7H4.34C2.85 17.09 2 20.45 2 24s.85 6.91 2.34 9.88l7.35-5.7z" />
      <path fill="#EA4335" d="M24 10.75c3.23 0 6.13 1.11 8.41 3.29l6.31-6.31C34.91 4.18 29.93 2 24 2 15.4 2 7.96 6.93 4.34 14.12l7.35 5.7c1.73-5.2 6.58-9.07 12.31-9.07z" />
    </svg>
  );
}

const CARD = 'rounded-2xl bg-white p-6 shadow-[0_22px_55px_-30px_rgba(0,0,0,0.18)]';

function PersonCard({ review }: { review: Review }) {
  return (
    <div className={`flex items-center gap-3 ${CARD}`}>
      <Image
        src={review.avatar}
        alt={review.name}
        width={48}
        height={48}
        className="h-12 w-12 rounded-lg object-cover"
      />
      <div>
        <p className="font-display text-base font-bold text-ink">{review.name}</p>
        <p className="text-xs text-ink/55">{review.role}</p>
      </div>
    </div>
  );
}

function QuoteCard({ review }: { review: Review }) {
  return (
    <div className={`flex flex-col ${CARD}`}>
      <div className="flex items-start justify-between">
        <span className="font-serif text-6xl leading-none text-ink/15" aria-hidden="true">
          &ldquo;
        </span>
        <GoogleG className="h-6 w-6" />
      </div>
      <Stars rating={5} showValue={false} className="mt-6 text-gold-deep" />
      <p className="mt-4 text-sm leading-relaxed text-ink/80">{review.text}</p>
    </div>
  );
}

export default function Testimonials() {
  return (
    <section id="testimonials" className="section bg-[#fff1e4]">
      <div className="container">
        {/* Header */}
        <div className="flex flex-col items-start justify-between gap-6 md:flex-row md:items-end">
          <div>
            <Reveal>
              <p className="font-display text-sm font-semibold uppercase tracking-[0.15em] text-gold-deep">
                {"Our Testimonials"}
              </p>
            </Reveal>
            <Reveal delay={1}>
              <h2 className="mt-4 font-display text-[clamp(2.2rem,4.5vw,3.5rem)] font-bold uppercase leading-[0.95] tracking-tight text-ink">
                Discover the Art
                <br />
                of Taste
              </h2>
            </Reveal>
          </div>
          <Reveal delay={2}>
            <Link
              href="/table-reservation"
              className="group inline-flex shrink-0 items-center gap-3 rounded-pill border border-cream/20 bg-ink-soft py-2 pl-6 pr-2 text-xs font-semibold uppercase tracking-[0.15em] text-cream hover:text-[#f5761e] transition-colors hover:border-[#f5761e]/50"
            >
              Book a Table
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
          </Reveal>
        </div>

        {/* Review columns */}
        <div className="mt-14 grid grid-cols-1 items-start gap-4 md:grid-cols-3">
          {REVIEWS.map((review, i) => {
            // Uniform order on mobile (quote → person); the middle column
            // flips to person → quote only on desktop.
            const reverseOnDesktop = i === 1;
            return (
              <Reveal
                key={review.name}
                delay={(i % 3) + 1}
                className={`flex flex-col gap-0.5 ${reverseOnDesktop ? 'md:flex-col-reverse' : ''}`}
              >
                <QuoteCard review={review} />
                <PersonCard review={review} />
              </Reveal>
            );
          })}
        </div>
      </div>
    </section>
  );
}
