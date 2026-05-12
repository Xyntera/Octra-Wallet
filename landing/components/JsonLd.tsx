'use client';

import { useEffect, useRef } from 'react';

interface Props {
  schema: Record<string, unknown>;
}

export default function JsonLd({ schema }: Props) {
  const inserted = useRef(false);

  useEffect(() => {
    if (inserted.current) return;
    inserted.current = true;
    const script = document.createElement('script');
    script.setAttribute('type', 'application/ld+json');
    // script.text is the safe DOM API for inline script content (not innerHTML)
    script.text = JSON.stringify(schema);
    document.head.appendChild(script);
    return () => {
      try { document.head.removeChild(script); } catch { /* already removed */ }
    };
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  return null;
}
