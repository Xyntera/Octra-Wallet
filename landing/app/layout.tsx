import type { Metadata } from 'next';
import { Outfit, IBM_Plex_Mono } from 'next/font/google';
import Header from '@/components/Header';
import Footer from '@/components/Footer';
import './globals.css';

const outfit = Outfit({
  subsets: ['latin'],
  variable: '--font-outfit',
  display: 'swap',
});

const ibmPlexMono = IBM_Plex_Mono({
  weight: ['400', '500', '600'],
  subsets: ['latin'],
  variable: '--font-mono',
  display: 'swap',
});

export const metadata: Metadata = {
  metadataBase: new URL('https://octrawallet.com'),
  title: {
    default: 'Octra Wallet — Download Android APK | Native PVAC Crypto Wallet for Octra Network',
    template: '%s | Octra Wallet',
  },
  description:
    'Download Octra Wallet — the free, open-source Android wallet for Octra (OCT) cryptocurrency. Native PVAC privacy operations, live portfolio tracking, multi-wallet support, and encrypted balances. No wallet server needed.',
  keywords: ['Octra wallet', 'OCT wallet', 'Octra wallet download', 'PVAC wallet', 'privacy crypto wallet'],
  authors: [{ name: 'Glaqz' }],
  robots: {
    index: true,
    follow: true,
    googleBot: { index: true, follow: true, 'max-image-preview': 'large', 'max-snippet': -1 },
  },
  openGraph: {
    type: 'website',
    siteName: 'Octra Wallet',
    locale: 'en_US',
    url: 'https://octrawallet.com',
    images: [{ url: '/assets/ss-home.jpg', width: 1080, height: 2276, alt: 'Octra Wallet home screen' }],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Octra Wallet — Download APK | Native PVAC Crypto Wallet',
    description: 'Free Android wallet for Octra (OCT) with native PVAC privacy, live portfolio, and multi-wallet support.',
    images: ['/assets/ss-home.jpg'],
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${outfit.variable} ${ibmPlexMono.variable}`}>
      <head>
        <meta name="theme-color" content="#000000" />
        <link rel="icon" type="image/png" sizes="32x32" href="/assets/favicon.png" />
        <link rel="apple-touch-icon" href="/assets/favicon.png" />
      </head>
      <body>
        <Header />
        {children}
        <Footer />
      </body>
    </html>
  );
}
