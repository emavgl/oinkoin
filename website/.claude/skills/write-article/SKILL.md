---
name: write-article
description: Creates or updates blog articles for the Oinkoin website. Use when the user wants to write a blog post, publish a release article, or add content to the website blog.
argument-hint: "[topic or release-version]"
---

# Skill: write-article

Write a blog article for the Oinkoin website.

## Usage
```
/write-article [topic]
/write-article 2.1.0
```

---

## Blog article system

- Articles live in `website/src/content/blog/` as Markdown files.
- The file name becomes the URL slug (e.g. `linux-beta.md` → `/blog/linux-beta`).
- Use kebab-case for filenames: `my-new-feature.md`.

---

## Frontmatter schema

Every article **must** have frontmatter between `---` delimiters:

```yaml
---
title: 'Article Title'       # required — page title & blog listing
description: 'Short summary' # required — shown in listing & meta tags
pubDate: 2026-05-03           # required — ISO date (YYYY-MM-DD)
updatedDate: 2026-05-10       # optional — if article is revised
heroImage: '/path/image.png'  # optional — not currently used in template
---
```

---

## Markdown content guidelines

### Headings
- Start with `##` (h2) for top-level sections. The article title becomes the page `<h1>` automatically.
- Use `###` (h3) for sub-sections under an `##`.
- Headings render with 2px larger font than body text and 1.5em top margin.

### Body text
- Regular paragraphs automatically use `1.15rem` font size.
- **Bold** with `**double asterisks**`.
- Lists use blue (`#2563eb`) markers.

### Links
- External links open in the same tab. Format: `[text](url)`.
- Common URLs to reference:
  - Google Play: `https://play.google.com/store/apps/details?id=com.emavgl.piggybank`
  - GitHub releases: `https://github.com/emavgl/oinkoin/releases`
  - GitHub issues: `https://github.com/emavgl/oinkoin/issues`

### Separator
Use `---` on its own line to insert a horizontal rule. This is typically used before the footer/download links section. It renders with 2.5em vertical margin.

### Images
Wrap images in a centered div to match existing posts:
```html
<div style="text-align:center; margin: 2em 0;">
  <img src="/path/to/image.png" alt="Description" style="width:96px; height:96px; display:inline-block;" />
</div>
```
Place images in `website/public/`.

---

## Footer / download links convention

End articles with a separator, then a heading, then download links:

```markdown
---

## Upgrade Now

Download version **X.Y.Z** from [Google Play](https://play.google.com/store/apps/details?id=com.emavgl.piggybank) or grab the APK directly from our [GitHub releases page](https://github.com/emavgl/oinkoin/releases/tag/X.Y.Z).

Have questions or feedback? Open an issue or start a discussion on [GitHub](https://github.com/emavgl/oinkoin).
```


