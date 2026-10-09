import type { MetadataRoute } from 'next';
import { siteUrl } from '@/lib/site';

export default function sitemap(): MetadataRoute.Sitemap {
  const base = siteUrl;
  return [
    { url: base, lastModified: new Date('2026-06-08'), changeFrequency: 'weekly', priority: 1 },
    { url: `${base}/menu`, lastModified: new Date('2026-06-08'), changeFrequency: 'weekly', priority: 0.8 },
  ];
}
