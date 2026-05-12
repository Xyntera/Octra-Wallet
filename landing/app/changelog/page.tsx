import type { Metadata } from 'next';
import { getAllChangelog } from '@/lib/content';
import MarkdownContent from '@/components/MarkdownContent';
import { Clock } from 'lucide-react';

export const metadata: Metadata = {
  title: 'Changelog',
  description: 'Full version history for Octra Wallet — release notes, new features, and bug fixes for every version.',
  alternates: { canonical: 'https://octrawallet.com/changelog' },
};

function formatDate(d: string) {
  return new Date(d).toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' });
}

export default function ChangelogPage() {
  const entries = getAllChangelog();

  return (
    <main>
      <div className="section-shell">
        <div className="page-hero reveal">
          <span className="eyebrow"><Clock className="icon-sm" aria-hidden="true" /> Changelog</span>
          <h1>Version History</h1>
          <p>Every release — what changed, what was fixed, and what was added.</p>
        </div>

        {entries.length === 0 ? (
          <div className="empty-state">
            <Clock aria-hidden="true" />
            <p>No changelog entries yet.</p>
          </div>
        ) : (
          <div className="changelog-list">
            {entries.map(entry => (
              <div className="changelog-item" key={entry.version}>
                <div className="changelog-version-col">
                  <div className="version-badge">{entry.version}</div>
                  {entry.date && <div className="changelog-date">{formatDate(entry.date)}</div>}
                </div>
                <div className="changelog-content">
                  <MarkdownContent markdown={entry.markdown} className="changelog-content" />
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </main>
  );
}
