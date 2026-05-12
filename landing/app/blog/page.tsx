import type { Metadata } from 'next';
import Link from 'next/link';
import { getAllBlogPosts } from '@/lib/content';
import { Calendar, Clock, ArrowRight, PenLine } from 'lucide-react';

export const metadata: Metadata = {
  title: 'Blog',
  description: 'News, tutorials, and updates about Octra Wallet — PVAC privacy, release notes, and the Octra network.',
  alternates: { canonical: 'https://octrawallet.com/blog' },
};

function formatDate(d: string) {
  return new Date(d).toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' });
}

export default async function BlogPage() {
  const posts = await getAllBlogPosts();

  return (
    <main>
      <div className="section-shell">
        <div className="page-hero reveal">
          <span className="eyebrow"><PenLine className="icon-sm" aria-hidden="true" /> Blog</span>
          <h1>News &amp; Updates</h1>
          <p>Release announcements, tutorials, and deep dives on PVAC privacy and the Octra network.</p>
        </div>

        {posts.length === 0 ? (
          <div className="empty-state">
            <PenLine aria-hidden="true" />
            <p>No posts yet — check back soon.</p>
          </div>
        ) : (
          <div className="blog-grid">
            {posts.map((post) => (
              <Link href={`/blog/${post.slug}`} className="blog-card reveal" key={post.slug}>
                <div className="blog-card-meta">
                  <span style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                    <Calendar aria-hidden="true" /> {formatDate(post.date)}
                  </span>
                  <span style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                    <Clock aria-hidden="true" /> {post.readingTime} min read
                  </span>
                </div>
                <h3>{post.title}</h3>
                <p>{post.description}</p>
                <div className="blog-card-footer">
                  <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' as const }}>
                    {post.tags.slice(0, 3).map(tag => (
                      <span className="tag" key={tag}>{tag}</span>
                    ))}
                  </div>
                  <span className="read-more">Read more <ArrowRight aria-hidden="true" /></span>
                </div>
              </Link>
            ))}
          </div>
        )}
      </div>
    </main>
  );
}
