import type { Metadata, Viewport } from 'next';
import { Fraunces, Manrope, Julius_Sans_One, Forum } from 'next/font/google';
import './globals.css';
import { siteUrl, ogImage } from '@/lib/site';

// Display serif for headings, modern grotesque for body (Typography §7)
const display = Fraunces({
  subsets: ['latin'],
  weight: ['400', '500', '600', '700'],
  style: ['normal', 'italic'],
  variable: '--font-display-src',
  display: 'swap',
});

const sans = Manrope({
  subsets: ['latin'],
  weight: ['400', '500', '600', '700'],
  variable: '--font-sans-src',
  display: 'swap',
});

// Elegant geometric sans for the hero headline
const julius = Julius_Sans_One({
  subsets: ['latin'],
  weight: ['400'],
  variable: '--font-julius-src',
  display: 'swap',
});

// Refined serif used across the hero section
const forum = Forum({
  subsets: ['latin'],
  weight: ['400'],
  variable: '--font-forum-src',
  display: 'swap',
});

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: {
    default: 'Go4Foodie — Modern Fine Dining & Table Reservations',
    template: '%s · Go4Foodie',
  },
  description:
    'Go4Foodie is a seasonal fine-dining restaurant serving wood-fired plates and curated wine. Reserve your table for an unforgettable evening.',
  keywords: ['restaurant', 'fine dining', 'book a table', 'reservations', 'wood-fired', 'seasonal menu'],
  authors: [{ name: 'Go4Foodie' }],
  openGraph: {
    type: 'website',
    url: siteUrl,
    locale: 'en_US',
    title: 'Go4Foodie — Modern Fine Dining',
    description: 'Seasonal plates, curated wine, and a table waiting for you.',
    siteName: 'Go4Foodie',
    images: [
      {
        url: ogImage,
        width: 1200,
        height: 630,
        type: 'image/png',
        alt: 'Go4Foodie dining room',
      },
    ],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Go4Foodie — Modern Fine Dining',
    description: 'Seasonal plates, curated wine, and a table waiting for you.',
    images: [
      {
        url: ogImage,
        width: 1200,
        height: 630,
        alt: 'Go4Foodie dining room',
      },
    ],
  },
  robots: { index: true, follow: true },
  alternates: { canonical: siteUrl },
};

export const viewport: Viewport = {
  themeColor: '#0a1c18',
  width: 'device-width',
  initialScale: 1,
};

// Structured data for rich results (§10 SEO)
const jsonLd = {
  '@context': 'https://schema.org',
  '@type': 'Restaurant',
  name: 'Go4Foodie',
  servesCuisine: 'Seasonal / Wood-fired',
  priceRange: '$$$',
  acceptsReservations: 'True',
  url: siteUrl,
  telephone: '+1-617-482-6060',
  address: {
    '@type': 'PostalAddress',
    streetAddress: '245 Harbor View Avenue',
    addressLocality: 'Boston',
    addressRegion: 'MA',
    postalCode: '02127',
    addressCountry: 'US',
  },
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en" className={`${display.variable} ${sans.variable} ${julius.variable} ${forum.variable}`}>
      <body>
        <a
          href="#main"
          className="sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-[100] focus:rounded-pill focus:bg-gold focus:px-5 focus:py-2 focus:text-white"
        >
          Skip to content
        </a>
        {children}
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
        />
      </body>
    </html>
  );
}
