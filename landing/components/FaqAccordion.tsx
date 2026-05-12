'use client';

import { useState } from 'react';
import { ChevronDown } from 'lucide-react';

interface FaqItem {
  q: string;
  a: string;
}

export default function FaqAccordion({ items }: { items: FaqItem[] }) {
  const [openIdx, setOpenIdx] = useState<number | null>(null);

  return (
    <div className="faq-list" role="list">
      {items.map(({ q, a }, i) => (
        <div
          key={i}
          className={`faq-item${openIdx === i ? ' open' : ''}`}
          role="listitem"
        >
          <div
            className="faq-summary"
            onClick={() => setOpenIdx(openIdx === i ? null : i)}
            role="button"
            tabIndex={0}
            aria-expanded={openIdx === i}
            onKeyDown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); setOpenIdx(openIdx === i ? null : i); } }}
          >
            <span>{q}</span>
            <ChevronDown aria-hidden="true" />
          </div>
          {openIdx === i && <p className="faq-body">{a}</p>}
        </div>
      ))}
    </div>
  );
}
