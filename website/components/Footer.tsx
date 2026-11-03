import Image from 'next/image';
import Reveal from './Reveal';

const galleryImg = (id: string, w = 500): string =>
  `https://images.unsplash.com/photo-${id}?auto=format&fit=crop&w=${w}&q=70`;

const GALLERY = [
  { id: '1517248135467-4c7edcad34c4', alt: 'Warmly lit dining room' },
  { id: '1559339352-11d035aa65de', alt: 'Chef plating a dish' },
  { id: '1414235077428-338989a2e8c0', alt: 'Guests dining' },
  { id: '1565299624946-b28f40a0ae38', alt: 'Signature plate' },
  { id: '1551183053-bf91a1d81141', alt: 'House-made pasta' },
  { id: '1510812431401-41d2bd2722f3', alt: 'The wine cellar' },
  { id: '1466978913421-dad2ebd01d17', alt: 'Craft cocktails' },
  { id: '1504674900247-0877df9cc836', alt: 'Freshly plated course' },
];

export default function Footer({ showGallery = true }: { showGallery?: boolean }) {
  return (
    <footer id="footer" className="bg-ink">
      {/* Photo gallery */}
      {showGallery && (
      <div className="container pt-16">
        <Reveal className="text-center">
          <p className="eyebrow justify-center">Gallery</p>
          <h2 className="mx-auto mt-4 max-w-2xl text-display-md">
            Moments from Go4Foodie
          </h2>
        </Reveal>

        <div className="mt-10 grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
          {GALLERY.map((photo) => (
            <div
              key={photo.id}
              className="group relative aspect-square overflow-hidden rounded-card border border-cream/10"
            >
              <Image
                src={galleryImg(photo.id)}
                alt={photo.alt}
                fill
                sizes="(max-width: 640px) 50vw, (max-width: 1024px) 33vw, 25vw"
                loading="lazy"
                className="object-cover transition-transform duration-500 ease-out group-hover:scale-110"
              />
              <div className="absolute inset-0 bg-ink/0 transition-colors duration-300 group-hover:bg-ink/25" />
            </div>
          ))}
        </div>
      </div>
      )}

      {/* Centered brand footer */}
      <div className="container flex flex-col items-center gap-7 py-16 text-center">
        {/* Emblem */}
        <Image
          src="/go4foodie-logo-light.png"
          alt="Go4Foodie"
          width={1200}
          height={336}
          className="h-24 w-auto"
        />

        {/* Social icons (match hero) */}
        <div className="flex items-center justify-center gap-3">
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

        {/* Address */}
        <address className="font-display text-lg not-italic text-cream/90">
          245 Harbor View Avenue, Boston, MA 02127
        </address>
      </div>

      <div className="border-t border-cream/10">
        <div className="container flex flex-col items-center justify-between gap-3 py-6 text-xs text-muted sm:flex-row">
          <p>© {2026} Go4Foodie. All rights reserved.</p>
          <div className="flex gap-6">
            <a href="/privacy" className="transition-colors hover:text-gold">Privacy</a>
            <a href="/terms" className="transition-colors hover:text-gold">Terms</a>
            <a href="/delete-account" className="transition-colors hover:text-gold">Delete account</a>
          </div>
        </div>
      </div>
    </footer>
  );
}
