# Translation Context Tracking System

## Overview

This project uses an **_automated_translation.json** file to track context for every translatable string before translation. This ensures:
- Translations account for how strings are used, not just literal word meanings
- Consistency across languages
- Prevention of errors like translating "Left" as directional when it means currency symbol position
- A permanent record of why each string is translated a certain way

## The System

### Files Involved

1. **_automated_translation.json** — Master context file
   - Contains ALL keys from `assets/locales/en-US.json`
   - For each key: context, page, component, meaning, notes, status
   - Single source of truth for translation decisions

2. **assets/locales/en-US.json** — English source strings
   - The reference for all keys that need translation
   - Updated via `python3 scripts/update_en_strings.py`

3. **.claude/skills/translate/SKILL.md** — Translation workflow
   - Step-by-step guide for translating strings
   - Enforces context lookup via _automated_translation.json

## When Adding a New String to en-US.json

### Immediate Actions

1. **Run the sync script** to update all locale files:
   ```bash
   python3 scripts/update_en_strings.py
   ```

2. **Verify the new key exists** in _automated_translation.json:
   ```bash
   grep '"your_new_key"' _automated_translation.json
   ```
   - If missing, regenerate (see "Regenerating _automated_translation.json" below)

3. **Research context** for the new key:
   - Search codebase: `grep -rn "your_new_key" lib/ --include="*.dart"`
   - Read surrounding code (5-10 lines before/after)
   - Understand: What page is it on? What UI component? What does the user see?

4. **Update _automated_translation.json**:
   ```bash
   # Edit manually or use provided Python script
   # For the new key, fill in:
   # - context: Where it appears
   # - file: Which file(s) use it
   # - page: Which app page (e.g., "Settings > Currency")
   # - component: UI element type (e.g., "dropdown option", "button label")
   # - meaning: What it means to the end user
   # - notes: Any special translation considerations
   # - status: Set to "verified" once context is documented
   ```

5. **Invoke the translate skill**:
   ```bash
   /translate
   ```
   - The skill will check _automated_translation.json for context
   - For keys with verified context, it can proceed with translations
   - For keys with status="pending", it will research and add context

### Example: Adding "Email" String

You add this to en-US.json:
```json
"Email": "Email"
```

Then:
1. Run `python3 scripts/update_en_strings.py`
2. Search: `grep -rn "Email" lib/` → find it in `lib/settings/profile-page.dart` line 42
3. Read surrounding code → "Email" is a label above a text field for entering email
4. Update _automated_translation.json:
```json
"Email": {
  "context": "User profile email field label",
  "file": "lib/settings/profile-page.dart:42",
  "page": "Settings > Profile",
  "component": "TextFormField label",
  "meaning": "Electronic mail address input",
  "notes": "Keep as-is in many languages - email is universal term",
  "status": "verified"
}
```
5. Run `/translate` → skill sees context and translates appropriately

## Regenerating _automated_translation.json

If keys get out of sync with en-US.json (keys added/removed/renamed):

```bash
python3 << 'EOF'
import json
from pathlib import Path

# Read current en-US.json
with open('assets/locales/en-US.json', 'r', encoding='utf-8') as f:
    en_us = json.load(f)

# Read current _automated_translation.json to preserve context
with open('_automated_translation.json', 'r', encoding='utf-8') as f:
    existing = json.load(f)

# Merge: keep existing context, add new keys as pending
merged = {}
for key in sorted(en_us.keys()):
    if key in existing['keys']:
        # Preserve existing context
        merged[key] = existing['keys'][key]
    else:
        # New key - pending context
        merged[key] = {
            "key": key,
            "context": None,
            "file": None,
            "page": None,
            "component": None,
            "meaning": None,
            "notes": None,
            "status": "pending"
        }

# Write updated file
output = existing['_meta']
output['total_keys'] = len(merged)
output['last_updated'] = "2026-04-21"  # Update date

with open('_automated_translation.json', 'w', encoding='utf-8') as f:
    json.dump({'_meta': output, 'keys': merged}, f, indent=2, ensure_ascii=False)

# Report removed keys
removed = set(existing['keys'].keys()) - set(en_us.keys())
if removed:
    print(f"Removed {len(removed)} keys from tracking:")
    for key in sorted(removed):
        print(f"  - {key}")

print(f"Total keys now: {len(merged)}")
EOF
```

## Key Status Values

- **pending** — Context needs to be researched and documented before translation
- **verified** — Context is documented; ready to translate
- **skip** — Should NOT be translated (brand names like "Oinkoin Pro", technical terms, universal terms like "OK")

## Translation Workflow

When `/translate` is invoked:

1. **Check _automated_translation.json** for each untranslated key
2. **If status="verified"**: Use documented context to translate
3. **If status="pending"**: 
   - Research context (grep codebase, read surrounding code)
   - Update _automated_translation.json with findings
   - Set status to "verified" (or "skip" if not translatable)
   - Then translate
4. **Write translations** only after context is established

## Best Practices

### Context Documentation
- **Be specific**: "Button label on Settings page" not just "Button"
- **Include examples**: "Currency symbol position dropdown" with options like "$100" vs "100$"
- **Note language considerations**: "May have same word in target language", "Check financial app conventions", etc.

### Status Values
- Don't skip lightly — only skip if truly untranslatable
- Mark as "pending" if unsure — better to slow down than guess
- Once "verified", context becomes the source of truth for all locales

### Maintenance
- Update _automated_translation.json **before** translating
- Commit changes to this file with the translations
- Keep it in sync with en-US.json
- Review quarterly for outdated or unclear context entries

## Emergency: Fixing Bad Translations

If a translation is discovered to be wrong:

1. **Root cause**: Check _automated_translation.json
   - Was context missing or wrong? → Update context
   - Was context correct but translation missed it? → Retranslate
2. **Fix context** in _automated_translation.json first
3. **Retranslate** with corrected context
4. **Document lesson learned** in notes field for future reference

## Example: The "Left" Translation

**Mistake**: Translated "Left" as simple directional term "Sinistra" in Italian

**Root cause**: Didn't verify context in _automated_translation.json

**Fix**:
1. Updated _automated_translation.json:
   ```json
   "Left": {
     "context": "Currency symbol position option",
     "file": "lib/settings/constants/preferences-options.dart:136",
     "page": "Settings > Currency",
     "component": "currencySymbolPosition dropdown",
     "meaning": "Position currency symbol to the LEFT of amount (e.g., $100)",
     "notes": "Positional context - use 'A sinistra' or equivalent in target language",
     "status": "verified"
   }
   ```
2. Retranslated with positional context in mind
3. Similar fix for "Right", "With space", "Without space" options

## Commands Quick Reference

```bash
# Sync en-US.json and update all locales with new keys
python3 scripts/update_en_strings.py

# Find what needs translating
python3 scripts/find_missing_translations.py

# When ready to translate (after verifying context)
/translate

# Verify a specific key exists in tracking file
grep '"your_key"' _automated_translation.json

# View context for a key
python3 -c "import json; d=json.load(open('_automated_translation.json')); print(json.dumps(d['keys']['your_key'], indent=2))"
```
