# Quick Start Guide - Oinkoin Website

## 🚀 Get Started in 3 Steps

### Step 1: Install Dependencies
```bash
cd website
npm install
```

### Step 2: Start Development Server
```bash
npm run dev
```

Open http://localhost:4321 in your browser 🎉

### Step 3: Make It Your Own

1. **Add Screenshots**
   - Place app screenshots in `public/images/`
   - Update `src/components/Screenshots.astro`

2. **Customize Colors**
   - Edit `tailwind.config.mjs`

3. **Update Content**
   - Edit components in `src/components/`

## 📦 Production Build

```bash
npm run build
```

Output is in `dist/` directory - ready to deploy!

## 🌐 Deploy (Choose One)

### Netlify (Easiest)
```bash
npm install -g netlify-cli
npm run build
netlify deploy --prod --dir=dist
```

### Vercel
```bash
npm install -g vercel
vercel --prod
```

### GitHub Pages
- Push to GitHub
- Enable Pages in repository settings
- Select "GitHub Actions" as source

See `README.md` for detailed deployment instructions.

## 🎨 What's Included

- ✅ Modern, animated landing page
- ✅ Responsive design (mobile-first)
- ✅ Feature showcase section
- ✅ Screenshot gallery with placeholders
- ✅ Download section with platform links
- ✅ SEO optimized
- ✅ Fast static site (Astro)
- ✅ Tailwind CSS for styling
- ✅ Smooth animations and transitions

## 🔥 Pro Tips

1. **Screenshots**: Use high-quality PNG images (1080x1920 for mobile views)
2. **Performance**: Images are automatically optimized by Astro
3. **SEO**: Update meta tags in `src/layouts/Layout.astro`
4. **Analytics**: Add Google Analytics or Plausible in the layout
5. **Custom Domain**: Configure in your deployment platform settings

## 🆘 Need Help?

- Check `README.md` for detailed documentation
- Visit [Astro Docs](https://docs.astro.build)
- Open an issue on GitHub

Happy building! 🎉

