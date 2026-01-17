# Deployment Guide - Oinkoin Website

Complete guide for deploying the Oinkoin website to various hosting platforms.

## 📋 Pre-Deployment Checklist

- [ ] Add real app screenshots to `public/images/`
- [ ] Update download links in `src/components/Download.astro`
- [ ] Test the build locally: `npm run build && npm run preview`
- [ ] Update site URL in `astro.config.mjs`
- [ ] Add favicon to `public/favicon.png`

## 🌐 Deployment Options

### Option 1: Netlify (Recommended for Beginners)

**Why Netlify?**
- Easiest setup
- Automatic deployments from Git
- Free SSL certificate
- CDN included
- Form handling and serverless functions available

**Steps:**

1. **Via Netlify Dashboard** (Easiest):
   ```bash
   # Build the site first
   npm run build
   ```
   
   - Go to [app.netlify.com](https://app.netlify.com)
   - Click "Add new site" → "Deploy manually"
   - Drag and drop the `dist/` folder
   - Done! 🎉

2. **Via Git Integration** (Recommended):
   - Push your code to GitHub
   - Go to [app.netlify.com](https://app.netlify.com)
   - Click "Add new site" → "Import an existing project"
   - Connect to GitHub and select your repository
   - Build settings:
     - Base directory: `website`
     - Build command: `npm run build`
     - Publish directory: `dist`
   - Click "Deploy site"

3. **Via Netlify CLI**:
   ```bash
   npm install -g netlify-cli
   cd website
   npm run build
   netlify deploy --prod --dir=dist
   ```

**Custom Domain:**
- Go to Site settings → Domain management
- Click "Add custom domain"
- Follow DNS configuration instructions

---

### Option 2: Vercel

**Why Vercel?**
- Optimized for frontend frameworks
- Excellent performance
- Free SSL and CDN
- Automatic HTTPS

**Steps:**

1. **Via Vercel Dashboard**:
   - Push code to GitHub
   - Go to [vercel.com](https://vercel.com)
   - Click "Add New Project"
   - Import your GitHub repository
   - Framework Preset: **Astro**
   - Root Directory: `website`
   - Build Command: `npm run build`
   - Output Directory: `dist`
   - Click "Deploy"

2. **Via Vercel CLI**:
   ```bash
   npm install -g vercel
   cd website
   vercel --prod
   ```

**Environment Variables:**
If needed, add in dashboard under Settings → Environment Variables

---

### Option 3: GitHub Pages

**Why GitHub Pages?**
- Free for public repositories
- Simple GitHub integration
- Good for open-source projects

**Steps:**

1. **Update Astro Config**:
   Edit `astro.config.mjs`:
   ```javascript
   export default defineConfig({
     site: 'https://yourusername.github.io',
     base: '/repository-name',
     integrations: [tailwind()],
   });
   ```

2. **Create GitHub Actions Workflow**:
   Create `.github/workflows/deploy-website.yml` in your repository root:
   ```yaml
   name: Deploy Website to GitHub Pages

   on:
     push:
       branches: [ main, master ]
       paths:
         - 'website/**'
     workflow_dispatch:

   permissions:
     contents: read
     pages: write
     id-token: write

   jobs:
     build:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4
         
         - uses: actions/setup-node@v4
           with:
             node-version: 18
             cache: 'npm'
             cache-dependency-path: website/package-lock.json
         
         - name: Install dependencies
           working-directory: ./website
           run: npm ci
         
         - name: Build website
           working-directory: ./website
           run: npm run build
         
         - name: Upload artifact
           uses: actions/upload-pages-artifact@v2
           with:
             path: ./website/dist

     deploy:
       needs: build
       runs-on: ubuntu-latest
       environment:
         name: github-pages
         url: ${{ steps.deployment.outputs.page_url }}
       steps:
         - name: Deploy to GitHub Pages
           id: deployment
           uses: actions/deploy-pages@v2
   ```

3. **Enable GitHub Pages**:
   - Go to repository Settings → Pages
   - Source: **GitHub Actions**
   - Push your code and the workflow will deploy automatically

---

### Option 4: Cloudflare Pages

**Why Cloudflare Pages?**
- Fastest global CDN
- Unlimited bandwidth
- Free for most projects
- DDoS protection included

**Steps:**

1. **Via Dashboard**:
   - Go to [pages.cloudflare.com](https://pages.cloudflare.com)
   - Click "Create a project"
   - Connect your GitHub account
   - Select your repository
   - Build settings:
     - Framework preset: **Astro**
     - Build command: `cd website && npm install && npm run build`
     - Build output directory: `website/dist`
   - Click "Save and Deploy"

2. **Custom Domain**:
   - Go to Custom domains
   - Add your domain
   - Update DNS records as instructed

---

### Option 5: Self-Hosted (VPS)

**Why Self-Host?**
- Full control
- Can integrate with existing infrastructure
- Good for advanced users

**Steps:**

1. **Build the site**:
   ```bash
   npm run build
   ```

2. **Upload to server**:
   ```bash
   # Using SCP
   scp -r dist/* user@yourserver.com:/var/www/oinkoin

   # Or using rsync
   rsync -avz dist/ user@yourserver.com:/var/www/oinkoin
   ```

3. **Configure web server**:

   **Nginx**:
   ```nginx
   server {
       listen 80;
       server_name oinkoin.com www.oinkoin.com;
       root /var/www/oinkoin;
       index index.html;

       location / {
           try_files $uri $uri/ /index.html;
       }

       # Cache static assets
       location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2)$ {
           expires 1y;
           add_header Cache-Control "public, immutable";
       }
   }
   ```

   **Apache**:
   ```apache
   <VirtualHost *:80>
       ServerName oinkoin.com
       ServerAlias www.oinkoin.com
       DocumentRoot /var/www/oinkoin

       <Directory /var/www/oinkoin>
           Options -Indexes +FollowSymLinks
           AllowOverride All
           Require all granted
           
           # SPA fallback
           RewriteEngine On
           RewriteBase /
           RewriteRule ^index\.html$ - [L]
           RewriteCond %{REQUEST_FILENAME} !-f
           RewriteCond %{REQUEST_FILENAME} !-d
           RewriteRule . /index.html [L]
       </Directory>
   </VirtualHost>
   ```

4. **Setup SSL with Let's Encrypt**:
   ```bash
   sudo apt install certbot python3-certbot-nginx
   sudo certbot --nginx -d oinkoin.com -d www.oinkoin.com
   ```

---

## 🔒 Custom Domain Setup

### For Netlify/Vercel/Cloudflare:

1. **Add domain in platform dashboard**
2. **Update DNS records** at your domain registrar:
   ```
   Type: CNAME
   Name: www
   Value: your-site.netlify.app (or vercel.app, pages.dev)

   Type: A (or use their nameservers)
   Name: @
   Value: [provided by platform]
   ```

3. **Wait for DNS propagation** (can take up to 48 hours, usually 5-10 minutes)

4. **SSL certificate** is automatically provisioned

---

## 📊 Analytics Setup

### Google Analytics

Add to `src/layouts/Layout.astro` in `<head>`:
```html
<!-- Google Analytics -->
<script async src="https://www.googletagmanager.com/gtag/js?id=G-XXXXXXXXXX"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', 'G-XXXXXXXXXX');
</script>
```

### Plausible (Privacy-focused)

```html
<script defer data-domain="oinkoin.com" src="https://plausible.io/js/script.js"></script>
```

---

## ⚡ Performance Optimization

1. **Enable compression** (Gzip/Brotli) on your server
2. **Optimize images** before adding to `public/images/`
3. **Use WebP format** for better compression
4. **Enable CDN** (most platforms do this automatically)
5. **Add cache headers** for static assets

---

## 🐛 Troubleshooting

### Build fails on deployment platform

**Solution**: Check Node.js version
```json
// Add to package.json
"engines": {
  "node": ">=18.0.0"
}
```

### 404 errors for routes

**Solution**: Ensure proper fallback configuration (platforms usually handle this automatically for Astro)

### Assets not loading

**Solution**: Use relative paths or set correct `base` in `astro.config.mjs`

### Slow build times

**Solution**: Enable caching in CI/CD pipeline

---

## ✅ Post-Deployment Checklist

- [ ] Site loads correctly
- [ ] All links work
- [ ] Images display properly
- [ ] Mobile responsive
- [ ] SSL certificate active (HTTPS)
- [ ] Analytics tracking
- [ ] Test download links
- [ ] Check performance (Lighthouse score)
- [ ] Submit to search engines

---

## 🎯 Monitoring

### Uptime Monitoring
- [UptimeRobot](https://uptimerobot.com) (Free)
- [StatusCake](https://www.statuscake.com)

### Performance Monitoring
- [Google PageSpeed Insights](https://pagespeed.web.dev/)
- [GTmetrix](https://gtmetrix.com/)

---

## 📈 SEO Tips

1. Add `sitemap.xml`:
   ```bash
   npm run build
   # Astro generates sitemap automatically if configured
   ```

2. Add `robots.txt` in `public/`:
   ```
   User-agent: *
   Allow: /
   Sitemap: https://oinkoin.com/sitemap.xml
   ```

3. Submit to search engines:
   - [Google Search Console](https://search.google.com/search-console)
   - [Bing Webmaster Tools](https://www.bing.com/webmasters)

---

## 🆘 Need Help?

- [Astro Deployment Docs](https://docs.astro.build/en/guides/deploy/)
- [Netlify Docs](https://docs.netlify.com/)
- [Vercel Docs](https://vercel.com/docs)
- [Cloudflare Pages Docs](https://developers.cloudflare.com/pages/)

---

**Recommended**: Start with **Netlify** for easiest setup, or **Vercel** for best performance. Both have excellent free tiers!

