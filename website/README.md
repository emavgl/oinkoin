# Oinkoin Website

A modern, animated website for Oinkoin expense tracker built with Astro and Tailwind CSS.

## 🚀 Features

- **Modern Design** - Clean, minimal interface with Oinkoin's brand colors
- **Smooth Animations** - Fade-in effects and floating elements
- **Responsive** - Mobile-first design that works on all devices
- **Fast** - Static site generation for lightning-fast load times
- **SEO Optimized** - Built-in SEO best practices

## 📋 Prerequisites

- Node.js 18+ 
- npm or yarn

## 🛠️ Local Development

### 1. Install Dependencies

```bash
cd website
npm install
```

### 2. Start Development Server

```bash
npm run dev
```

The site will be available at `http://localhost:4321`

### 3. Build for Production

```bash
npm run build
```

The static files will be generated in the `dist/` directory.

### 4. Preview Production Build

```bash
npm run preview
```

## 📸 Adding Screenshots

1. Take screenshots of your app (recommended: 1080x1920 for mobile, 1920x1080 for desktop)
2. Save them in `public/images/` directory:
   - `dashboard.png` - Main dashboard view
   - `add-expense.png` - Add expense screen
   - `statistics.png` - Statistics/charts view
   - `categories.png` - Categories management

3. Update `src/components/Screenshots.astro` to use real images:

```astro
<img src="/images/dashboard.png" alt="Dashboard" class="rounded-2xl shadow-2xl" />
```

## 🎨 Customization

### Colors

Edit `tailwind.config.mjs` to change the color scheme:

```javascript
colors: {
  'oinkoin-primary': '#FF6B9D',    // Main pink color
  'oinkoin-secondary': '#4A5568',  // Gray text
  'oinkoin-accent': '#38B2AC',     // Teal accent
  'oinkoin-dark': '#1A202C',       // Dark background
  'oinkoin-light': '#F7FAFC',      // Light background
}
```

### Content

- **Hero Section**: `src/components/Hero.astro`
- **Features**: `src/components/Features.astro`
- **Screenshots**: `src/components/Screenshots.astro`
- **Download Links**: `src/components/Download.astro`
- **Footer**: `src/components/Footer.astro`

## 🚢 Deployment

### Deploy to Netlify

1. **Install Netlify CLI** (optional):
   ```bash
   npm install -g netlify-cli
   ```

2. **Build the site**:
   ```bash
   npm run build
   ```

3. **Deploy**:
   ```bash
   netlify deploy --prod --dir=dist
   ```

   Or connect your GitHub repository to Netlify for automatic deployments:
   - Go to [Netlify](https://app.netlify.com)
   - Click "Add new site" → "Import an existing project"
   - Choose your GitHub repository
   - Build command: `npm run build`
   - Publish directory: `dist`

### Deploy to Vercel

1. **Install Vercel CLI** (optional):
   ```bash
   npm install -g vercel
   ```

2. **Deploy**:
   ```bash
   vercel --prod
   ```

   Or connect your GitHub repository to Vercel:
   - Go to [Vercel](https://vercel.com)
   - Click "Add New Project"
   - Import your GitHub repository
   - Framework Preset: Astro
   - Build command: `npm run build`
   - Output directory: `dist`

### Deploy to GitHub Pages

1. **Update `astro.config.mjs`**:
   ```javascript
   export default defineConfig({
     site: 'https://yourusername.github.io',
     base: '/oinkoin',
   });
   ```

2. **Add GitHub Actions workflow** (`.github/workflows/deploy.yml`):
   ```yaml
   name: Deploy to GitHub Pages

   on:
     push:
       branches: [ main ]
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
         - name: Install dependencies
           run: |
             cd website
             npm install
         - name: Build
           run: |
             cd website
             npm run build
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
   - Source: GitHub Actions

### Deploy to Cloudflare Pages

1. **Connect repository**:
   - Go to [Cloudflare Pages](https://pages.cloudflare.com)
   - Click "Create a project"
   - Connect your GitHub repository

2. **Build settings**:
   - Build command: `cd website && npm install && npm run build`
   - Build output directory: `website/dist`
   - Root directory: `/`

## 📁 Project Structure

```
website/
├── public/              # Static assets
│   └── images/         # App screenshots go here
├── src/
│   ├── components/     # Reusable components
│   │   ├── Hero.astro
│   │   ├── Features.astro
│   │   ├── Screenshots.astro
│   │   ├── Download.astro
│   │   └── Footer.astro
│   ├── layouts/
│   │   └── Layout.astro
│   └── pages/
│       └── index.astro # Main page
├── astro.config.mjs    # Astro configuration
├── tailwind.config.mjs # Tailwind CSS configuration
└── package.json
```

## 🔧 Troubleshooting

### Port already in use
If port 4321 is busy, specify a different port:
```bash
npm run dev -- --port 3000
```

### Build errors
Clear the cache and rebuild:
```bash
rm -rf node_modules dist .astro
npm install
npm run build
```

## 📝 License

This website is part of the Oinkoin project and follows the same license.

## 🤝 Contributing

Contributions are welcome! Feel free to:
- Add more animations
- Improve responsiveness
- Add more sections
- Optimize performance

## 📧 Support

For questions or issues, please open an issue on [GitHub](https://github.com/emavgl/oinkoin/issues).

---

Built with [Astro](https://astro.build) and [Tailwind CSS](https://tailwindcss.com)

