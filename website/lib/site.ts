/**
 * Single source of truth for the site's public origin.
 *
 * Social scrapers (Facebook, WhatsApp, X, LinkedIn, Slack) fetch `og:image`
 * as an ABSOLUTE url, so this must match the domain the site is actually
 * served from — otherwise the card renders blank.
 *
 * Set NEXT_PUBLIC_SITE_URL in the deploy environment. On Vercel it falls back
 * to the project's production domain automatically.
 */
function resolveSiteUrl(): string {
  const explicit = process.env.NEXT_PUBLIC_SITE_URL?.trim();
  if (explicit) return explicit.replace(/\/+$/, '');

  const vercel = process.env.VERCEL_PROJECT_PRODUCTION_URL?.trim();
  if (vercel) return `https://${vercel.replace(/\/+$/, '')}`;

  return 'http://localhost:3000';
}

export const siteUrl = resolveSiteUrl();
export const ogImage = `${siteUrl}/og-image.png`;
