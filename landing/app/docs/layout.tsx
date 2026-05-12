import Link from 'next/link';
import { getAllDocPages } from '@/lib/content';
import { BookOpen } from 'lucide-react';

export default async function DocsLayout({ children }: { children: React.ReactNode }) {
  const pages = await getAllDocPages();

  // Group by section
  const sections: Record<string, typeof pages> = {};
  pages.forEach(p => {
    const s = p.section || 'General';
    if (!sections[s]) sections[s] = [];
    sections[s].push(p);
  });

  return (
    <main>
      <div className="docs-wrapper">
        <aside className="docs-sidebar" aria-label="Documentation navigation">
          <Link
            href="/docs"
            className="docs-sidebar-link"
            style={{ fontWeight: 800, marginBottom: 4, color: 'var(--text)' }}
          >
            <BookOpen style={{ width: 16, height: 16 }} aria-hidden="true" />
            Documentation
          </Link>
          {Object.entries(sections).map(([section, sectionPages]) => (
            <div key={section}>
              <p className="docs-sidebar-title">{section}</p>
              {sectionPages.map(p => (
                <Link
                  key={p.slugPath.join('/')}
                  href={`/docs/${p.slugPath.join('/')}`}
                  className="docs-sidebar-link"
                >
                  {p.title}
                </Link>
              ))}
            </div>
          ))}
        </aside>
        <div className="docs-content">
          {children}
        </div>
      </div>
    </main>
  );
}
