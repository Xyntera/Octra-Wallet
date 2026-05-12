import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  experimental: {
    // Treat remark/gray-matter as server-only (avoids edge runtime issues)
  },
};

export default nextConfig;
