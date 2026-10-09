import Image from 'next/image';
import Reveal from './Reveal';

const FIND_US = [
  {
    label: '2-5-9 Itabashi, Tokyo',
    href: 'https://maps.google.com/?q=2-5-9 Itabashi, Tokyo',
    icon: (
      <path
        fill="currentColor"
        d="M12 2a7 7 0 0 0-7 7c0 5.25 7 13 7 13s7-7.75 7-13a7 7 0 0 0-7-7zm0 9.5A2.5 2.5 0 1 1 12 6.5a2.5 2.5 0 0 1 0 5z"
      />
    ),
  },
  {
    label: '(555) 555-5555',
    href: 'tel:+15555555555',
    icon: (
      <path
        fill="currentColor"
        d="M6.62 10.79a15.5 15.5 0 0 0 6.59 6.59l2.2-2.2a1 1 0 0 1 1.02-.24 11.4 11.4 0 0 0 3.57.57 1 1 0 0 1 1 1V20a1 1 0 0 1-1 1A17 17 0 0 1 3 4a1 1 0 0 1 1-1h3.5a1 1 0 0 1 1 1c0 1.25.2 2.45.57 3.57a1 1 0 0 1-.25 1.02l-2.2 2.2z"
      />
    ),
  },
  {
    label: 'dinevo.help@gmail.com',
    href: 'mailto:dinevo.help@gmail.com',
    icon: (
      <path
        fill="currentColor"
        d="M20 4H4a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V6a2 2 0 0 0-2-2zm0 4-8 5-8-5V6l8 5 8-5v2z"
      />
    ),
  },
];

const HOURS = [
  'Mon: CLOSED',
  'Tue to Fri: 11 AM – 10 PM',
  'Sat to Sun: 12 PM – 7 PM',
];

export default function Contact() {
  return (
    <section id="contact" className="section bg-white">
      <div className="container">
        <div className="relative overflow-hidden rounded-[2rem]">
          {/* Background dish image */}
          <Image
            src="https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1600&q=75"
            alt="Freshly plated dish"
            fill
            sizes="100vw"
            className="object-cover"
          />

          {/* Cream content card */}
          <div className="relative p-4 sm:p-6">
            <Reveal className="max-w-xl rounded-2xl bg-[#fff1e4] p-8 shadow-float sm:p-10">
              <p className="font-display text-sm font-semibold uppercase tracking-[0.15em] text-gold-deep">
                {'Get in Touch'}
              </p>
              <h2 className="mt-5 font-display text-[clamp(2rem,4.5vw,3.25rem)] font-bold uppercase leading-[0.95] tracking-tight text-ink">
                Flavors that Bring Joy to Every Bite
              </h2>
              <p className="mt-5 text-sm text-ink/65">
                Our dishes are made with only fresh and local ingredients.
              </p>

              <div className="mt-8 grid grid-cols-1 gap-4 sm:grid-cols-2">
                {/* Find us */}
                <div className="rounded-xl bg-white p-6">
                  <h3 className="font-display text-lg font-bold uppercase tracking-tight text-ink">
                    Find Us
                  </h3>
                  <ul className="mt-4 space-y-3">
                    {FIND_US.map((row) => (
                      <li key={row.label} className="border-b border-dashed border-ink/15 pb-3 last:border-0 last:pb-0">
                        <a href={row.href} className="flex items-center gap-2.5 text-sm text-ink/80 transition-colors hover:text-gold-deep">
                          <svg viewBox="0 0 24 24" className="h-4 w-4 shrink-0 text-ink" aria-hidden="true">
                            {row.icon}
                          </svg>
                          <span className="underline underline-offset-4">{row.label}</span>
                        </a>
                      </li>
                    ))}
                  </ul>
                </div>

                {/* Opening hours */}
                <div className="rounded-xl bg-white p-6">
                  <h3 className="font-display text-lg font-bold uppercase tracking-tight text-ink">
                    Opening Hours
                  </h3>
                  <ul className="mt-4 space-y-3">
                    {HOURS.map((row) => (
                      <li key={row} className="border-b border-dashed border-ink/15 pb-3 text-sm text-ink/80 last:border-0 last:pb-0">
                        {row}
                      </li>
                    ))}
                  </ul>
                </div>
              </div>
            </Reveal>
          </div>
        </div>
      </div>
    </section>
  );
}
