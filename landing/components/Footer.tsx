import Link from 'next/link';
import Image from 'next/image';

export default function Footer() {
  return (
    <footer className="footer" role="contentinfo">
      <div className="footer-brand">
        <Image src="/assets/owl-logo.png" alt="Octra Wallet" className="brand-mark" width={30} height={30} loading="lazy" />
        <div>
          <strong>Octra Wallet</strong>
          <p>octrawallet.com · By Glaqz</p>
        </div>
      </div>
      <nav className="footer-links" aria-label="Footer navigation">
        <Link href="/blog">Blog</Link>
        <Link href="/docs">Docs</Link>
        <Link href="/changelog">Changelog</Link>
        <a href="https://octrascan.io" target="_blank" rel="noreferrer noopener">OctraScan</a>
        <a href="https://github.com/Xyntera/Octra-Wallet" target="_blank" rel="noreferrer noopener">GitHub</a>
        <a href="https://github.com/Xyntera/Octra-Wallet/releases" target="_blank" rel="noreferrer noopener">Releases</a>
        <Link href="/privacy">Privacy</Link>
      </nav>
    </footer>
  );
}
