import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';

import cloudflare from '@astrojs/cloudflare';

export default defineConfig({
  integrations: [sitemap()],
  site: 'https://oinkoin.com',
  adapter: cloudflare(),
});
