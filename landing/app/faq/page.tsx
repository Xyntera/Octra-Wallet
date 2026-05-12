import type { Metadata } from 'next';
import FaqAccordion from '@/components/FaqAccordion';
import { HelpCircle } from 'lucide-react';

export const metadata: Metadata = {
  title: 'FAQ',
  description: 'Frequently asked questions about Octra Wallet — installation, PVAC privacy, security, multi-wallet, portfolio, and more.',
  alternates: { canonical: 'https://octrawallet.com/faq' },
};

const faqSections = [
  {
    title: 'Getting Started',
    items: [
      { q: 'What is Octra Wallet?', a: 'Octra Wallet is a free, open-source Android mobile wallet for the Octra (OCT) cryptocurrency network. It bundles native PVAC privacy libraries directly in the APK so all privacy operations run locally on your device — no server or backend process needed.' },
      { q: 'How do I download and install Octra Wallet?', a: 'Download the APK from the GitHub Releases page. On your Android phone, go to Settings → Apps → Special app access → Install unknown apps and enable it for your browser or Files app. Open the downloaded APK and tap Install. Minimum Android 6.0 (API 23).' },
      { q: 'Which Android versions are supported?', a: 'Android 6.0 (API level 23) or higher. The release APK is a fat binary supporting both arm64-v8a and x86_64 ABIs, covering virtually all modern Android phones and tablets.' },
    ],
  },
  {
    title: 'Privacy & Security',
    items: [
      { q: 'What is PVAC and why does it matter?', a: "PVAC (Private Value and Computation) is Octra's privacy system. It lets you encrypt your public OCT balance into a private encrypted balance, and decrypt it back — all without revealing amounts on-chain. Stealth transfers use PVAC to send OCT privately so only the recipient can discover and claim the funds. Octra Wallet runs PVAC proofs natively on your device using a compiled C++ library, keeping your keys and computations completely local." },
      { q: 'Is Octra Wallet safe? Who controls my keys?', a: "Octra Wallet is fully non-custodial — your private keys and seed phrase never leave your device. The app stores them in Android's encrypted secure storage. No third party has access. The full source code is publicly auditable on GitHub under the GPL-2.0 license." },
      { q: 'How do I back up my wallet?', a: 'Open the wallet menu (top-right icon on the Home tab) and tap Export. You can copy your private key or reveal your 12-word seed phrase. Store these offline in a safe place — anyone with this information controls your funds, and there is no recovery mechanism if you lose them.' },
      { q: 'What PIN and biometric options are available?', a: 'You can set a 4-digit PIN to protect local wallet access. On supported devices, you can also enable Face ID or fingerprint unlock as an alternative. The PIN is required before every transaction-changing operation.' },
    ],
  },
  {
    title: 'Wallet Features',
    items: [
      { q: 'Does Octra Wallet support multiple wallets?', a: 'Yes. You can create, import, or add watch-only wallets inside the app. Each wallet has its own name, color avatar, address, and balance. Switching wallets is instant and history is automatically scoped to the active wallet.' },
      { q: 'What is the Portfolio tab?', a: 'The Portfolio tab (added in v1.0.2) shows your total OCT holdings converted to USD at the live CoinGecko price, an interactive 7-day OCT/USD price chart, a 24-hour change percentage badge, and a per-wallet breakdown of OCT balance and USD value.' },
      { q: 'Can I send to multiple recipients at once?', a: 'Yes — the Bulk Public Send feature lets you submit up to 5 public OCT transfers in one flow, with sequential nonces automatically calculated for all pending transactions.' },
      { q: 'How do custom tokens work?', a: 'You can import any Octra token contract by address. Once imported, the wallet shows your live token balance, allows token transfers, and you can swipe to remove tokens you no longer need.' },
    ],
  },
  {
    title: 'Open Source & Distribution',
    items: [
      { q: 'Is Octra Wallet open source?', a: 'Yes. The entire Flutter app and native C++ PVAC bridge are published on GitHub under the GPL-2.0-or-later license with an OpenSSL linking permission. You can inspect, audit, fork, and build from source using Flutter 3.5+ and Android NDK.' },
      { q: 'Will Octra Wallet be on the Play Store?', a: 'Play Store distribution is planned for a future release. For now, download the signed APK from the GitHub Releases page and sideload it manually. Enable "Install unknown apps" in Android settings before installing.' },
      { q: 'How are releases built and verified?', a: 'Every release APK is produced by a public GitHub Actions CI workflow. Build logs are public, the APK is signed, and the workflow is reproducible. There are no secret build servers.' },
    ],
  },
];

export default function FaqPage() {
  return (
    <main>
      <div className="section-shell">
        <div className="page-hero reveal">
          <span className="eyebrow"><HelpCircle className="icon-sm" aria-hidden="true" /> FAQ</span>
          <h1>Frequently Asked Questions</h1>
          <p>Everything you need to know about Octra Wallet, PVAC privacy, and the Octra network.</p>
        </div>

        <div className="faq-page-list">
          {faqSections.map(section => (
            <div key={section.title} style={{ marginBottom: 48 }}>
              <h2 style={{ fontSize: '1.2rem', marginBottom: 16, color: 'var(--text)' }}>{section.title}</h2>
              <FaqAccordion items={section.items} />
            </div>
          ))}
        </div>
      </div>
    </main>
  );
}
