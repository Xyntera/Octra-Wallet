import type { MetadataRoute } from 'next';
import { getAllBlogPosts, getAllDocPages, getAllChangelog } from '@/lib/content';

export default function sitemap(): MetadataRoute.Sitemap {
  const base = 'https://octrawallet.com';
  const now = new Date('2026-05-12');

  const staticRoutes: MetadataRoute.Sitemap = [
    { url: base, lastModified: now, changeFrequency: 'weekly', priority: 1.0 },
    { url: `${base}/blog`, lastModified: now, changeFrequency: 'weekly', priority: 0.8 },
    { url: `${base}/docs`, lastModified: now, changeFrequency: 'monthly', priority: 0.8 },
    { url: `${base}/changelog`, lastModified: now, changeFrequency: 'weekly', priority: 0.7 },
    { url: `${base}/faq`, lastModified: now, changeFrequency: 'monthly', priority: 0.6 },
    { url: `${base}/privacy`, lastModified: now, changeFrequency: 'yearly', priority: 0.3 },
  ];

  const blogRoutes = getAllBlogPosts().map(p => ({
    url: `${base}/blog/${p.slug}`,
    lastModified: p.date ? new Date(p.date) : now,
    changeFrequency: 'monthly' as const,
    priority: 0.7,
  }));

  const docRoutes = getAllDocPages().map(p => ({
    url: `${base}/docs/${p.slugPath.join('/')}`,
    lastModified: now,
    changeFrequency: 'monthly' as const,
    priority: 0.6,
  }));

  return [...staticRoutes, ...blogRoutes, ...docRoutes];
}
