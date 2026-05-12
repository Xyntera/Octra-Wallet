import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import Link from 'next/link';
import { getAllBlogPosts, getBlogPost } from '@/lib/content';
import MarkdownContent from '@/components/MarkdownContent';
import { ArrowLeft, Calendar, Clock, User, ChevronRight } from 'lucide-react';

interface Props {
  params: Promise<{ slug: string }>;
}

export async function generateStaticParams() {
  return getAllBlogPosts().map(p => ({ slug: p.slug }));
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params;
  const post = getBlogPost(slug);
  if (!post) return {};
  return {
    title: post.title,
    description: post.description,
    alternates: { canonical: `https://octrawallet.com/blog/${slug}` },
    openGraph: { title: post.title, description: post.description, type: 'article', publishedTime: post.date },
  };
}

function formatDate(d: string) {
  return new Date(d).toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' });
}

export default async function BlogPostPage({ params }: Props) {
  const { slug } = await params;
  const post = getBlogPost(slug);
  if (!post) notFound();

  return (
    <main>
      <div className="section-shell">
        <nav className="breadcrumb" aria-label="Breadcrumb">
          <Link href="/">Home</Link>
          <ChevronRight aria-hidden="true" style={{ width: 14, height: 14 }} />
          <Link href="/blog">Blog</Link>
          <ChevronRight aria-hidden="true" style={{ width: 14, height: 14 }} />
          <span>{post.title}</span>
        </nav>

        <article className="post-layout">
          <Link href="/blog" className="back-link">
            <ArrowLeft aria-hidden="true" /> Back to Blog
          </Link>

          <header className="post-header">
            <div className="post-tags">
              {post.tags.map(tag => <span className="tag" key={tag}>{tag}</span>)}
            </div>
            <h1 style={{ marginTop: '12px' }}>{post.title}</h1>
            <div className="post-meta">
              <span className="post-meta-item"><Calendar style={{ width: 14, height: 14 }} aria-hidden="true" /> {formatDate(post.date)}</span>
              <span className="post-meta-item"><Clock style={{ width: 14, height: 14 }} aria-hidden="true" /> {post.readingTime} min read</span>
              <span className="post-meta-item"><User style={{ width: 14, height: 14 }} aria-hidden="true" /> {post.author}</span>
            </div>
            {post.description && (
              <p style={{ fontSize: '1.05rem', color: 'var(--muted)', marginBottom: 0 }}>{post.description}</p>
            )}
          </header>

          <MarkdownContent markdown={post.markdown} />
        </article>
      </div>
    </main>
  );
}
