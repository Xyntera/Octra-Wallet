import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import Link from 'next/link';
import { getAllDocPages, getDocPage } from '@/lib/content';
import MarkdownContent from '@/components/MarkdownContent';
import { ArrowLeft, ChevronRight } from 'lucide-react';

interface Props {
  params: Promise<{ slug: string[] }>;
}

export async function generateStaticParams() {
  return getAllDocPages().map(p => ({ slug: p.slugPath }));
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params;
  const page = getDocPage(slug);
  if (!page) return {};
  return {
    title: page.title,
    description: page.description,
    alternates: { canonical: `https://octrawallet.com/docs/${slug.join('/')}` },
  };
}

export default async function DocPage({ params }: Props) {
  const { slug } = await params;
  const page = getDocPage(slug);
  if (!page) notFound();

  return (
    <div>
      <nav className="breadcrumb" aria-label="Breadcrumb">
        <Link href="/">Home</Link>
        <ChevronRight aria-hidden="true" style={{ width: 14, height: 14 }} />
        <Link href="/docs">Docs</Link>
        <ChevronRight aria-hidden="true" style={{ width: 14, height: 14 }} />
        <span>{page.title}</span>
      </nav>

      <Link href="/docs" className="back-link">
        <ArrowLeft aria-hidden="true" /> All Docs
      </Link>

      <h1 style={{ fontSize: 'clamp(1.6rem, 4vw, 2.4rem)', marginBottom: 8 }}>{page.title}</h1>
      {page.description && <p style={{ fontSize: '1.05rem', marginBottom: 32 }}>{page.description}</p>}

      <MarkdownContent markdown={page.markdown} />
    </div>
  );
}
