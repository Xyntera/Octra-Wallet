import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Privacy Policy',
  description: 'Octra Wallet privacy policy — how we handle (and do not collect) your data.',
  alternates: { canonical: 'https://octrawallet.com/privacy' },
};

export default function PrivacyPage() {
  return (
    <main>
      <div className="section-shell">
        <div style={{ maxWidth: 760, margin: '0 auto', padding: '72px 0 96px' }}>
          <h1 style={{ fontSize: 'clamp(2rem, 5vw, 3rem)', marginBottom: '2rem' }}>Privacy Policy</h1>
          <p style={{ color: 'var(--muted-2)', fontSize: '0.85rem', marginBottom: '2.5rem', fontFamily: 'var(--mono)' }}>Last updated: May 2026</p>

          <section style={{ marginBottom: '2.5rem' }}>
            <h2 style={{ fontSize: '1.3rem', marginBottom: '1rem' }}>1. No data collection</h2>
            <p>Octra Wallet does not collect, transmit, store, or share any personal data. The app is fully non-custodial and offline-first. Your private keys, seed phrase, PIN, and wallet data never leave your device.</p>
          </section>

          <section style={{ marginBottom: '2.5rem' }}>
            <h2 style={{ fontSize: '1.3rem', marginBottom: '1rem' }}>2. Network requests</h2>
            <p>The app communicates directly with the Octra network RPC endpoint (<span className="mono">octra.network</span>) to fetch balances, submit transactions, and retrieve transaction history. No intermediary server is used. The Portfolio tab fetches OCT/USD price data from the CoinGecko public API.</p>
          </section>

          <section style={{ marginBottom: '2.5rem' }}>
            <h2 style={{ fontSize: '1.3rem', marginBottom: '1rem' }}>3. Local storage</h2>
            <p>All sensitive data (private keys, seed phrases, PIN) is stored locally on your device using Android&apos;s encrypted secure storage (<span className="mono">flutter_secure_storage</span>). This data is protected by your device&apos;s hardware security module where available.</p>
          </section>

          <section style={{ marginBottom: '2.5rem' }}>
            <h2 style={{ fontSize: '1.3rem', marginBottom: '1rem' }}>4. This website</h2>
            <p>This website (<span className="mono">octrawallet.com</span>) is a static informational site hosted on Vercel. Vercel may collect standard web server logs (IP addresses, user agents, referrers) as part of its hosting service. We do not use analytics, tracking pixels, or cookies beyond what Vercel provides.</p>
          </section>

          <section style={{ marginBottom: '2.5rem' }}>
            <h2 style={{ fontSize: '1.3rem', marginBottom: '1rem' }}>5. Open source</h2>
            <p>The full source code of Octra Wallet is published on <a href="https://github.com/Xyntera/Octra-Wallet" target="_blank" rel="noreferrer noopener" style={{ color: 'var(--blue)' }}>GitHub</a> under GPL-2.0-or-later. You can audit every network request and data handling operation in the codebase.</p>
          </section>

          <section>
            <h2 style={{ fontSize: '1.3rem', marginBottom: '1rem' }}>6. Contact</h2>
            <p>If you have questions about privacy, open an issue on <a href="https://github.com/Xyntera/Octra-Wallet/issues" target="_blank" rel="noreferrer noopener" style={{ color: 'var(--blue)' }}>GitHub</a>.</p>
          </section>
        </div>
      </div>
    </main>
  );
}
