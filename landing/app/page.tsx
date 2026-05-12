import type { Metadata } from 'next';
import Image from 'next/image';
import Link from 'next/link';
import {
  Download, Github, ShieldCheck, Cpu, TestTube2, Lock,
  TrendingUp, Send, LockKeyhole, History, CreditCard, Coins,
  Fingerprint, Zap, Settings2, PackageCheck, Smartphone,
  Cable, FileText, Shield, GitPullRequest, Info, Activity,
  ShieldAlert, MoveHorizontal, FileClock,
} from 'lucide-react';
import FaqAccordion from '@/components/FaqAccordion';
import RevealObserver from '@/components/RevealObserver';
import JsonLd from '@/components/JsonLd';

export const metadata: Metadata = {
  title: 'Octra Wallet — Download Android APK | Native PVAC Crypto Wallet for Octra Network',
  description:
    'Download Octra Wallet — the free, open-source Android wallet for Octra (OCT) cryptocurrency. Native PVAC privacy operations, live portfolio tracking, multi-wallet support, and encrypted balances.',
  alternates: { canonical: 'https://octrawallet.com/' },
};

const APK_URL =
  'https://github.com/Xyntera/Octra-Wallet/releases/download/v1.0.2/Octra-Wallet-v1.0.2-android.apk';

const faqs = [
  { q: 'What is Octra Wallet?', a: 'Octra Wallet is a free, open-source Android mobile wallet for the Octra (OCT) cryptocurrency network. It bundles native PVAC privacy libraries directly in the APK so all privacy operations run locally — no server needed.' },
  { q: 'How do I install Octra Wallet on Android?', a: 'Download the APK from GitHub Releases. In Settings → Apps → Special app access → Install unknown apps, enable it for your browser or Files app. Open the APK and tap Install. Requires Android 6.0+.' },
  { q: 'What is PVAC and why does it matter?', a: "PVAC (Private Value and Computation) is Octra's on-chain privacy system. It lets you encrypt OCT into a private shielded balance and send stealth transfers that only the recipient can discover. Octra Wallet runs PVAC proofs natively on your phone — no cloud, no server." },
  { q: 'Is Octra Wallet safe? Who holds my keys?', a: 'Fully non-custodial. Your private keys and seed phrase never leave your device. They are stored in Android\'s encrypted secure storage. The full source is auditable on GitHub and every APK is built by public CI.' },
  { q: 'Does Octra Wallet support multiple wallets?', a: 'Yes — create, import, or add watch-only wallets. Each has its own name, colour, and history. Switching is instant and all data is scoped to the active wallet.' },
  { q: 'What is the Portfolio tab?', a: 'Added in v1.0.2. It shows your total OCT holdings in USD at the live CoinGecko price, an interactive 7-day OCT/USD chart, 24h change badge, and individual wallet USD breakdowns.' },
  { q: 'Which Android versions are supported?', a: 'Android 6.0 (API 23) and above. The APK ships as arm64-v8a + x86_64 fat binary — covering virtually all modern Android phones and tablets.' },
  { q: 'How do I back up my wallet?', a: 'Tap the menu icon (top-right) on the Home tab → Export. Copy your private key or 12-word seed phrase and store it offline. There is no recovery option if you lose it.' },
  { q: 'Will Octra Wallet be on the Google Play Store?', a: 'Play Store distribution is planned. For now, sideload the APK from GitHub Releases. It is signed, CI-built, and production-ready.' },
];

const schema = {
  '@context': 'https://schema.org',
  '@graph': [
    { '@type': 'WebSite', '@id': 'https://octrawallet.com/#website', url: 'https://octrawallet.com/', name: 'Octra Wallet', publisher: { '@id': 'https://octrawallet.com/#organization' } },
    { '@type': 'Organization', '@id': 'https://octrawallet.com/#organization', name: 'Octra Wallet', url: 'https://octrawallet.com/', sameAs: ['https://github.com/Xyntera/Octra-Wallet'] },
    { '@type': 'SoftwareApplication', name: 'Octra Wallet', operatingSystem: 'Android 6.0+', applicationCategory: 'FinanceApplication', softwareVersion: '1.0.2', downloadUrl: APK_URL, url: 'https://octrawallet.com/', offers: { '@type': 'Offer', price: '0', priceCurrency: 'USD' }, aggregateRating: { '@type': 'AggregateRating', ratingValue: '5', ratingCount: '1', bestRating: '5' } },
    { '@type': 'FAQPage', mainEntity: faqs.map(({ q, a }) => ({ '@type': 'Question', name: q, acceptedAnswer: { '@type': 'Answer', text: a } })) },
  ],
};

export default function HomePage() {
  return (
    <>
      <JsonLd schema={schema} />
      <RevealObserver />
      <main id="top">

        {/* ── Hero ── */}
        <section className="hero section-shell reveal" aria-labelledby="hero-heading">
          <div className="hero-copy">
            <span className="eyebrow">Free · Open-source · Android · v1.0.2</span>
            <h1 id="hero-heading">The Octra Wallet.<br />Private by default.<br />Yours forever.</h1>
            <p className="hero-lede">
              Download the only Android wallet that runs <strong>native PVAC privacy operations</strong>{' '}
              fully on-device. Public sends, encrypted balances, stealth transfers, live portfolio
              tracking — zero server dependencies.
            </p>
            <div className="hero-actions">
              <a className="button button-primary" href={APK_URL} target="_blank" rel="noreferrer noopener"
                aria-label="Download Octra Wallet v1.0.2 APK for Android">
                <Download aria-hidden="true" />
                Download v1.0.2 — Free
              </a>
              <a className="button button-ghost" href="https://github.com/Xyntera/Octra-Wallet" target="_blank" rel="noreferrer noopener">
                <Github aria-hidden="true" />
                View on GitHub
              </a>
            </div>
            <div className="release-strip">
              <span className="badge badge-green">Latest</span>
              <span className="mono">v1.0.2</span>
              <span className="sep">·</span>
              <span>Android 6.0+</span>
              <span className="sep">·</span>
              <span>arm64 &amp; x86_64</span>
              <span className="sep">·</span>
              <span>GPL-2.0</span>
            </div>
          </div>

          <div className="hero-visual" aria-hidden="true">
            <div className="phone-hero">
              <div className="phone-notch" />
              <Image
                src="/assets/ss-home.jpg"
                alt="Octra Wallet home screen showing 1139 OCT public balance and privacy action buttons"
                width={390}
                height={844}
                fetchPriority="high"
                priority
              />
            </div>
            <div className="float-card float-top">
              <span className="mono label">Native core</span>
              <strong>liboctra_core.so</strong>
            </div>
            <div className="float-card float-bottom">
              <span className="mono label">Privacy ops</span>
              <strong>On-device PVAC</strong>
            </div>
          </div>
        </section>

        {/* ── Trust bar ── */}
        <section className="trust-bar section-shell reveal" aria-label="Trust signals">
          <div className="trust-item"><ShieldCheck aria-hidden="true" /><span>Non-custodial</span></div>
          <div className="trust-divider" aria-hidden="true" />
          <div className="trust-item"><Cpu aria-hidden="true" /><span>On-device PVAC</span></div>
          <div className="trust-divider" aria-hidden="true" />
          <div className="trust-item"><Github aria-hidden="true" /><span>Open source</span></div>
          <div className="trust-divider" aria-hidden="true" />
          <div className="trust-item"><TestTube2 aria-hidden="true" /><span>CI-verified builds</span></div>
          <div className="trust-divider" aria-hidden="true" />
          <div className="trust-item"><Lock aria-hidden="true" /><span>GPL-2.0 licensed</span></div>
        </section>

        {/* ── Metrics ── */}
        <section className="metrics section-shell" aria-label="Key features">
          <article className="metric-card reveal">
            <Cpu className="metric-icon" aria-hidden="true" />
            <strong>On-device PVAC</strong>
            <p>All privacy proofs run in a native C++ library bundled inside the APK — nothing sent to a server.</p>
          </article>
          <article className="metric-card reveal" style={{ animationDelay: '.08s' }}>
            <TrendingUp className="metric-icon" aria-hidden="true" />
            <strong>Live Portfolio</strong>
            <p>Real-time OCT/USD price, 7-day interactive chart, and per-wallet dollar breakdown.</p>
          </article>
          <article className="metric-card reveal" style={{ animationDelay: '.16s' }}>
            <ShieldCheck className="metric-icon" aria-hidden="true" />
            <strong>Fully Auditable</strong>
            <p>GPL-2.0 source code, reproducible GitHub Actions builds, and public CI logs for every release.</p>
          </article>
        </section>

        {/* ── Screenshots ── */}
        <section className="section-shell screenshots-section reveal" id="screenshots" aria-labelledby="ss-heading">
          <div className="section-heading">
            <span className="eyebrow">App screenshots · v1.0.2</span>
            <h2 id="ss-heading">Every screen, as it really looks.</h2>
            <p>Real screenshots from the production APK — not mockups.</p>
          </div>
          <div className="screenshots-outer">
            <div className="screenshots-scroll" role="list" aria-label="App screenshots">
              {[
                { src: '/assets/ss-home.jpg', alt: 'Octra Wallet Home screen: 1139 OCT public balance, 137 OCT private balance, Send Receive Encrypt Decrypt action buttons', label: 'Home' },
                { src: '/assets/ss-portfolio.jpg', alt: 'Portfolio tab: $89.14 total value, +34.48% 24h change, 7-day OCT/USD price chart, wallet breakdown', label: 'Portfolio', isNew: true },
                { src: '/assets/ss-history.jpg', alt: 'Transaction history: OCT transfers, stealth claims, decrypt operations with amounts', label: 'History' },
                { src: '/assets/ss-private-send.jpg', alt: 'Private Send sheet: stealth transfer with recipient address and OCT amount fields', label: 'Private Send' },
                { src: '/assets/ss-wallets.jpg', alt: 'Multi-wallet selector: Wallet 1 and Wallet 2 with add wallet option', label: 'Wallets' },
              ].map(({ src, alt, label, isNew }) => (
                <div className="screenshot-item" role="listitem" key={src}>
                  <div className="ss-phone">
                    <div className="ss-notch" aria-hidden="true" />
                    <Image src={src} alt={alt} loading="lazy" width={200} height={422} />
                  </div>
                  <span className={`ss-label${isNew ? ' ss-new' : ''}`}>
                    {label}
                    {isNew && <span className="badge badge-blue">New</span>}
                  </span>
                </div>
              ))}
            </div>
          </div>
          <p className="scroll-hint" aria-live="polite">
            <MoveHorizontal className="icon-sm" aria-hidden="true" />
            <span>Swipe to see more screens</span>
          </p>
        </section>

        {/* ── Features ── */}
        <section className="section-shell split-section reveal" id="features" aria-labelledby="features-heading">
          <div className="section-intro">
            <span className="eyebrow">Wallet features</span>
            <h2 id="features-heading">Everything you need for Octra.</h2>
            <p>Built from the ground up for real day-to-day usage on the Octra network.</p>
          </div>
          <div className="feature-grid">
            {[
              { Icon: Send, title: 'Public & bulk transfers', desc: 'Sign and submit OCT transfers directly from Flutter. Batch up to 5 recipients with correct sequential nonces in one flow.' },
              { Icon: LockKeyhole, title: 'PVAC privacy operations', desc: 'Register your PVAC key, encrypt public OCT to private balance, decrypt back, send stealth transfers, scan outputs, and claim — all on-device.', delay: '.05s' },
              { Icon: TrendingUp, title: 'Portfolio tab', desc: 'Live OCT/USD price from CoinGecko, interactive 7-day chart, 24h change indicator, and a per-wallet USD breakdown updated on every refresh.', isBlue: true, badge: 'New in v1.0.2', delay: '.10s' },
              { Icon: History, title: 'Full transaction history', desc: 'OctraScan-backed history scoped to the active wallet — transfers in and out, stealth claims, encrypt/decrypt ops, with one-tap explorer links.', delay: '.15s' },
              { Icon: CreditCard, title: 'Multi-wallet management', desc: 'Create HD wallets, import by seed phrase or private key, add watch-only addresses, rename, assign colours, export, and switch instantly.', delay: '.20s' },
              { Icon: Coins, title: 'Custom tokens', desc: 'Import any Octra token by contract address, view live balances, send token transfers, and swipe to remove tokens you no longer need.', delay: '.25s' },
              { Icon: Fingerprint, title: 'PIN & biometric security', desc: '4-digit PIN with optional Face ID or fingerprint. Required before every transaction-changing operation. Shake animation on wrong PIN.', delay: '.30s' },
              { Icon: Zap, title: 'Dynamic fees', desc: 'Recommended fee fetched per operation type before every submit — always paying the right amount, never overpaying.', delay: '.35s' },
            ].map(({ Icon, title, desc, delay, isBlue, badge }) => (
              <article className="feature-card reveal" key={title} style={delay ? { animationDelay: delay } : undefined}>
                <div className={`feature-icon-wrap${isBlue ? ' blue' : ''}`} aria-hidden="true">
                  <Icon />
                </div>
                <h3>{title}{badge && <> <span className="badge badge-blue">{badge}</span></>}</h3>
                <p>{desc}</p>
              </article>
            ))}
          </div>
        </section>

        {/* ── Install ── */}
        <section className="section-shell install-section reveal" id="install" aria-labelledby="install-heading">
          <div className="section-heading centered">
            <span className="eyebrow">Installation guide</span>
            <h2 id="install-heading">Install Octra Wallet in 3 steps.</h2>
            <p>No app store required. Sideload in under a minute on any Android 6.0+ device.</p>
          </div>
          <div className="steps">
            <article className="step-card reveal">
              <div className="step-num-big" aria-hidden="true">1</div>
              <div className="feature-icon-wrap" aria-hidden="true"><Download /></div>
              <h3>Download the APK</h3>
              <p>Tap the button below to download <span className="mono">Octra-Wallet-v1.0.2-android.apk</span> directly from GitHub Releases.</p>
              <a className="button button-primary" href={APK_URL} target="_blank" rel="noreferrer noopener" style={{ marginTop: 'auto' }}>
                <Download aria-hidden="true" />
                Download APK
              </a>
            </article>
            <article className="step-card reveal" style={{ animationDelay: '.1s' }}>
              <div className="step-num-big" aria-hidden="true">2</div>
              <div className="feature-icon-wrap" aria-hidden="true"><Settings2 /></div>
              <h3>Allow unknown apps</h3>
              <p>On Android: <strong>Settings → Apps → Special app access → Install unknown apps</strong> — enable for your browser or Files app.</p>
            </article>
            <article className="step-card reveal" style={{ animationDelay: '.2s' }}>
              <div className="step-num-big" aria-hidden="true">3</div>
              <div className="feature-icon-wrap" aria-hidden="true"><PackageCheck /></div>
              <h3>Open &amp; install</h3>
              <p>Open the downloaded APK from your notification or file manager and tap <strong>Install</strong>. Launch Octra Wallet and create or import your wallet.</p>
            </article>
          </div>
        </section>

        {/* ── Architecture ── */}
        <section className="architecture section-shell reveal" id="architecture" aria-labelledby="arch-heading">
          <div className="section-heading centered">
            <span className="eyebrow">Architecture</span>
            <h2 id="arch-heading">No server. No custodian. No compromise.</h2>
            <p>Flutter owns the interface. Native libraries own the crypto. Long PVAC operations run in background isolates so the UI never freezes.</p>
          </div>
          <div className="pipeline">
            <article className="pipeline-step reveal">
              <span className="step-num">01</span>
              <div className="feature-icon-wrap small" aria-hidden="true"><Smartphone /></div>
              <h3>Flutter UI</h3>
              <p>Wallet state, screens, portfolio, history, QR flows, and all user confirmations.</p>
            </article>
            <div className="pipeline-arrow" aria-hidden="true" />
            <article className="pipeline-step reveal" style={{ animationDelay: '.1s' }}>
              <span className="step-num">02</span>
              <div className="feature-icon-wrap small" aria-hidden="true"><Cable /></div>
              <h3>Dart FFI bridge</h3>
              <p>Stable JSON command surface between Dart and native C++. Runs in a serialized background isolate.</p>
            </article>
            <div className="pipeline-arrow" aria-hidden="true" />
            <article className="pipeline-step reveal" style={{ animationDelay: '.2s' }}>
              <span className="step-num">03</span>
              <div className="feature-icon-wrap small" aria-hidden="true"><Cpu /></div>
              <h3>Native PVAC</h3>
              <p>Vendored C++ PVAC backend packaged as <span className="mono">liboctra_core.so</span> — runs 100% on device.</p>
            </article>
          </div>
        </section>

        {/* ── Security ── */}
        <section className="section-shell proof-section reveal" id="security" aria-labelledby="security-heading">
          <div className="proof-panel">
            <span className="eyebrow">Open-source security</span>
            <h2 id="security-heading">Inspect every line of code.</h2>
            <p>The full Flutter source, native C++ bridge, and vendored PVAC backend are published on GitHub. Every release APK is produced by a public GitHub Actions workflow — no secret build servers.</p>
            <div className="proof-links" role="list">
              <a href="https://github.com/Xyntera/Octra-Wallet/blob/main/LICENSE" target="_blank" rel="noreferrer noopener" role="listitem"><FileText className="icon-sm" aria-hidden="true" /> License</a>
              <a href="https://github.com/Xyntera/Octra-Wallet/blob/main/SECURITY.md" target="_blank" rel="noreferrer noopener" role="listitem"><Shield className="icon-sm" aria-hidden="true" /> Security policy</a>
              <a href="https://github.com/Xyntera/Octra-Wallet/blob/main/CONTRIBUTING.md" target="_blank" rel="noreferrer noopener" role="listitem"><GitPullRequest className="icon-sm" aria-hidden="true" /> Contributing</a>
              <a href="https://github.com/Xyntera/Octra-Wallet/blob/main/NOTICE.md" target="_blank" rel="noreferrer noopener" role="listitem"><Info className="icon-sm" aria-hidden="true" /> Notices</a>
              <a href="https://github.com/Xyntera/Octra-Wallet/actions" target="_blank" rel="noreferrer noopener" role="listitem"><Activity className="icon-sm" aria-hidden="true" /> CI runs</a>
            </div>
          </div>
          <div className="warning-panel reveal">
            <div className="warning-icon-wrap" aria-hidden="true"><ShieldAlert /></div>
            <h3>Non-custodial warning</h3>
            <p>You hold your own private keys. Nobody — not the developer, not any server — can recover a lost seed phrase. Test with small amounts first.</p>
          </div>
        </section>

        {/* ── FAQ ── */}
        <section className="section-shell faq-section reveal" id="faq" aria-labelledby="faq-heading">
          <div className="section-heading centered">
            <span className="eyebrow">FAQ</span>
            <h2 id="faq-heading">Frequently asked questions.</h2>
          </div>
          <FaqAccordion items={faqs} />
          <p style={{ textAlign: 'center', marginTop: '24px' }}>
            <Link href="/faq" style={{ color: 'var(--blue)', fontWeight: 700, fontSize: '0.9rem' }}>
              View all FAQs →
            </Link>
          </p>
        </section>

        {/* ── Download CTA ── */}
        <section className="download-section section-shell reveal" id="download" aria-labelledby="download-heading">
          <div className="download-inner">
            <div className="download-copy">
              <span className="eyebrow">Free download · No account needed</span>
              <h2 id="download-heading">Get Octra Wallet for Android.</h2>
              <p>CI-built and verified to include <span className="mono">liboctra_core.so</span>, <span className="mono">libcrypto.so</span>, and <span className="mono">libc++_shared.so</span>. Minimum Android 6.0 (API 23).</p>
            </div>
            <div className="download-actions">
              <a className="button button-primary button-xl" href={APK_URL} target="_blank" rel="noreferrer noopener" aria-label="Download Octra Wallet v1.0.2 APK">
                <PackageCheck aria-hidden="true" />
                Download v1.0.2 APK
              </a>
              <a className="button button-ghost" href="https://github.com/Xyntera/Octra-Wallet/releases/latest" target="_blank" rel="noreferrer noopener">
                <FileClock aria-hidden="true" />
                Release notes
              </a>
              <p className="download-note">Enable <em>Install unknown apps</em> in Android settings before installing.</p>
            </div>
          </div>
        </section>

      </main>
    </>
  );
}
