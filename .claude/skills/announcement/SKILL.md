---
name: announcement
description: Adds a new in-app announcement to Oinkoin using the announcements framework. Use when the user wants to send a user-facing announcement, show a startup dialog, or publish a blog post about a new feature.
argument-hint: "<id> [title]"
---

# Skill: announcement

Add a new in-app announcement to Oinkoin.

## Usage

```
/announcement 2026-10-new-feature "New Feature X is here"
```

The `<id>` is a date-prefixed slug (YYYY-MM-slug). The title is the dialog/page heading.

---

## How announcements work

The framework has three layers:

| Layer | Location | Purpose |
|-------|----------|---------|
| **Manifest** | `assets/docs/announcements/manifest.json` | Lists all announcements (id, date, title key, dialog flag) |
| **Body** | `assets/docs/announcements/<id>.md` | Markdown content shown in the dialog and announcements page |
| **Settings** | Settings → Announcements | Lists all entries; tapping one opens the markdown viewer |

A manifest entry with `"dialog": true` also triggers a **one-time startup dialog** (dismissed permanently via SharedPreferences).

---

## Workflow

### Step 1 — Create the markdown body

Create `assets/docs/announcements/<id>.md` (English only).

Rules:
- First line should be a bold heading: `**Your announcement title**`
- Keep the tone friendly and concise
- Links are tappable in the dialog (uses `flutter_markdown_plus`)
- Announcements are intentionally English-only by default — do not create translated copies unless explicitly asked

### Step 2 — Register in the manifest

Add an entry to `assets/docs/announcements/manifest.json`:

```json
{
  "communications": [
    {
      "id": "2026-10-new-feature",
      "date": "2026-10-15",
      "titleKey": "New Feature X is here",
      "dialog": true
    }
  ]
}
```

Fields:
- **id**: folder-safe slug, prefixed with date for sorting
- **date**: ISO-8601 date (YYYY-MM-DD)
- **titleKey**: exact English string used as the i18n key (must match `en-US.json`)
- **dialog**: `true` to show a one-time startup dialog; `false` for page-only entries

### Step 3 — Add the i18n key

The `titleKey` must exist in `assets/locales/en-US.json` as both key and value:

```json
"New Feature X is here": "New Feature X is here"
```

Then run:
```bash
python3 scripts/update_en_strings.py
```

This syncs the key into all locale files (value = key = untranslated, which is fine since announcements are English-only).

### Step 4 — Document context (optional but recommended)

Add the key to `_automated_translation.json` with `"status": "verified"` so future `/translate` runs don't try to translate it:

```json
"New Feature X is here": {
  "key": "New Feature X is here",
  "context": "Title of a startup announcement dialog for Feature X",
  "file": "lib/comms/announcement-dialog.dart",
  "page": "Startup dialog + Settings > Announcements",
  "component": "Dialog title / list item title",
  "meaning": "Announcement about Feature X availability",
  "notes": "English-only announcement by decision.",
  "status": "verified"
}
```

### Step 5 — (Optional) Write a blog post

If the announcement warrants a blog post, create `website/src/content/blog/<slug>.md` with frontmatter matching existing posts:

```markdown
---
title: 'Your Blog Title'
description: 'Short description for SEO.'
pubDate: 2026-10-15
---

# Your Blog Title

Content here...
```

The blog is at `https://oinkoin.com/blog/<slug>`.

Link to it from the announcement body markdown: `[Read more in our blog](https://oinkoin.com/blog/<slug>)`.

### Step 6 — Verify

```bash
flutter analyze
flutter test test/communication_service_test.dart
```

Then test on-device:
1. Clear app data (`adb shell pm clear <package>`)
2. Launch the app
3. Verify the dialog appears on first launch
4. Dismiss and relaunch — dialog should NOT appear again
5. Check Settings → Announcements shows the entry

---

## Removing an announcement

To remove the startup dialog but keep the entry visible on the announcements page:
- Set `"dialog": false` in the manifest

To remove entirely:
- Delete the `.md` file
- Remove the entry from `manifest.json`
- Remove the i18n key from `en-US.json` and re-run `python3 scripts/update_en_strings.py`

---

## File reference

| File | Role |
|------|------|
| `assets/docs/announcements/manifest.json` | Announcement registry |
| `assets/docs/announcements/<id>.md` | Body content (English) |
| `lib/services/communication-service.dart` | Service: loads manifest, resolves bodies, show-once logic |
| `lib/comms/announcement-dialog.dart` | Startup dialog UI + `maybeShowAnnouncementDialog()` |
| `lib/comms/announcements-page.dart` | Settings list page |
| `lib/comms/communication-detail-page.dart` | Markdown viewer page |
| `lib/settings/settings-page.dart:355-369` | Settings item that navigates to Announcements |
