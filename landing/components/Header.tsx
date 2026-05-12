'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';
import Image from 'next/image';
import { Download, Github, Menu, X, BookOpen, PenLine, Clock } from 'lucide-react';

export default function Header() {
  const [open, setOpen] = useState(false);
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const handler = () => setScrolled(window.scrollY > 10);
    window.addEventListener('scroll', handler, { passive: true });
    return () => window.removeEventListener('scroll', handler);
  }, []);

  useEffect(() => {
    const handler = (e: MouseEvent) => {
      const nav = document.getElementById('navLinks');
      const btn = document.getElementById('menuBtn');
      if (open && nav && btn && !nav.contains(e.target as Node) && !btn.contains(e.target as Node)) {
        setOpen(false);
      }
    };
    document.addEventListener('click', handler);
    return () => document.removeEventListener('click', handler);
  }, [open]);

  return (
    <nav className={`topbar${scrolled ? ' scrolled' : ''}`} aria-label="Main navigation">
      <Link className="brand" href="/" aria-label="Octra Wallet home">
        <Image src="/assets/owl-logo.png" alt="Octra Wallet logo" className="brand-mark" width={34} height={34} />
        <span>Octra Wallet</span>
      </Link>

      <div className={`nav-links${open ? ' open' : ''}`} id="navLinks" role="menubar">
        <Link href="/blog" role="menuitem" onClick={() => setOpen(false)}>
          <PenLine className="icon-sm" aria-hidden="true" />
          Blog
        </Link>
        <Link href="/docs" role="menuitem" onClick={() => setOpen(false)}>
          <BookOpen className="icon-sm" aria-hidden="true" />
          Docs
        </Link>
        <Link href="/changelog" role="menuitem" onClick={() => setOpen(false)}>
          <Clock className="icon-sm" aria-hidden="true" />
          Changelog
        </Link>
        <a href="https://github.com/Xyntera/Octra-Wallet" target="_blank" rel="noreferrer noopener" role="menuitem" onClick={() => setOpen(false)}>
          <Github className="icon-sm" aria-hidden="true" />
          GitHub
        </a>
        <a
          className="nav-cta"
          href="https://github.com/Xyntera/Octra-Wallet/releases/download/v1.0.2/Octra-Wallet-v1.0.2-android.apk"
          target="_blank"
          rel="noreferrer noopener"
          onClick={() => setOpen(false)}
        >
          <Download className="icon-sm" aria-hidden="true" />
          Download APK
        </a>
      </div>

      <button
        id="menuBtn"
        className="menu-button"
        type="button"
        onClick={() => setOpen(v => !v)}
        aria-label="Toggle navigation"
        aria-expanded={open}
        aria-controls="navLinks"
      >
        {open ? <X aria-hidden="true" /> : <Menu aria-hidden="true" />}
      </button>
    </nav>
  );
}
