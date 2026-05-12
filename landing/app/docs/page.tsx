import type { Metadata } from 'next';
import Link from 'next/link';
import { getAllDocPages } from '@/lib/content';
import { BookOpen, ArrowRight } from 'lucide-react';

export const metadata: Metadata = {
  title: 'Documentation',
  description: 'Octra Wallet documentation — getting started, PVAC privacy operations, portfolio, multi-wallet management, and more.',
  alternates: { canonical: 'https://octrawallet.com/docs' },
};

export default function DocsIndexPage() {
  const pages = getAllDocPages();

  const sections: Record<string, typeof pages> = {};
  pages.forEach(p => {
    const s = p.section || 'General';
    if (!sections[s]) sections[s] = [];
    sections[s].push(p);
  });

  return (
    <div>
      <div style={{ marginBottom: 40 }}>
        <span className="eyebrow"><BookOpen className="icon-sm" aria-hidden="true" /> Documentation</span>
        <h1 style={{ fontSize: 'clamp(1.8rem, 4vw, 2.6rem)', marginBottom: 12 }}>Octra Wallet Docs</h1>
        <p style={{ maxWidth: 560 }}>Everything you need to use Octra Wallet — from installation to advanced PVAC privacy operations.</p>
      </div>

      {Object.entries(sections).map(([section, sectionPages]) => (
        <div key={section} style={{ marginBottom: 40 }}>
          <h2 style={{ fontSize: '1rem', fontFamily: 'var(--mono)', letterSpacing: '0.06em', textTransform: 'uppercase', color: 'var(--muted-2)', marginBottom: 12 }}>{section}</h2>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {sectionPages.map(p => (
              <Link
                key={p.slugPath.join('/')}
                href={`/docs/${p.slugPath.join('/')}`}
                style={{
                  display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                  padding: '14px 18px', background: 'var(--surface)', border: '1px solid var(--line)',
                  borderRadius: 'var(--r)', textDecoration: 'none', color: 'var(--text)',
                  transition: 'border-color 0.2s',
                }}
              >
                <div>
                  <strong style={{ display: 'block', fontSize: '0.96rem' }}>{p.title}</strong>
                  {p.description && <span style={{ fontSize: '0.84rem', color: 'var(--muted)' }}>{p.description}</span>}
                </div>
                <ArrowRight style={{ width: 18, height: 18, color: 'var(--blue)', flexShrink: 0 }} aria-hidden="true" />
              </Link>
            ))}
          </div>
        </div>
      ))}

      {pages.length === 0 && (
        <div className="empty-state">
          <BookOpen aria-hidden="true" />
          <p>Documentation coming soon.</p>
        </div>
      )}
    </div>
  );
}
