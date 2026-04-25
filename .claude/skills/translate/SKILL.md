---
name: translate
description: Translates untranslated strings in a locale JSON file for the Oinkoin app. Use when the user wants to localise or update translations for a specific language, or says "translate <locale>".
argument-hint: "[locale-file]"
---

# Skill: translate

Translate missing strings key-by-key across all locale files (or a specific one).

## Usage
```
/translate [locale-file]
```
- `/translate` — processes all locale files
- `/translate it.json` — processes Italian only

---

## How translations work in this project

- All locale files live in `assets/locales/`.
- `assets/locales/en-US.json` is the **source of truth**.
- A string is **untranslated** when its value equals its key in a locale file.
- `en-GB.json` is always skipped (near-identical to US English).

---

## Workflow

This skill uses `_automated_translation.json` at the project root to track context for every string. **Always check this file before translating.**

### Step 0 — Sync keys and ensure tracking file is current
```bash
python3 scripts/update_en_strings.py
```

Then verify tracking file is in sync:
```bash
# If keys were added/removed, regenerate the tracking file (see CLAUDE.md for script)
```

### Step 1 — Discover what needs translating
Run the discovery script to get a structured list of every key that is missing in one or more locale files:

```bash
# All locales:
python3 scripts/find_missing_translations.py

# Specific locale(s):
python3 scripts/find_missing_translations.py --locale it.json
python3 scripts/find_missing_translations.py --locale it.json --locale de.json
```

Output is a JSON array:
```json
[
  { "key": "Apply", "missing_locales": ["de.json", "fr.json", "it.json"] },
  { "key": "Amount (Ascending)", "missing_locales": ["it.json"] }
]
```

If the array is empty, tell the user everything is translated and stop.

### Step 2 — Process key by key

For **each entry** in the discovery output:

**2a. Check _automated_translation.json for context**

Look up the key in `_automated_translation.json`:
```bash
python3 -c "import json; d=json.load(open('_automated_translation.json')); print(json.dumps(d['keys']['your_key'], indent=2))"
```

Three possibilities:

**Status = "verified"** — Context is documented, proceed to translation (2c)

**Status = "pending"** — Context not yet researched, do research first (2b)

**Status = "skip"** — Don't translate (brand names, technical terms, universal)

**2b. If pending: Research and document context**

Search the Dart source to understand where the key is used:
```bash
grep -rn "Key text here" lib/
```

Read the surrounding code (5-10 lines before/after) to understand:
- **Page context**: Settings, Wallets, Records, Currencies, Categories, etc.?
- **Component context**: Button label, dropdown option, form field, error message, dialog title, description text?
- **User perspective**: What would the user see on screen? What does this word mean in that UI context?

**Example**: 
- "Left" in a currency symbol position dropdown = positional (left of amount), not directional
- Context changes translation from simple directional to positional description

Update `_automated_translation.json` with findings:
```json
{
  "keys": {
    "Left": {
      "key": "Left",
      "context": "Currency symbol position option",
      "file": "lib/settings/constants/preferences-options.dart:136",
      "page": "Settings > Currency Formatting",
      "component": "currencySymbolPosition dropdown option",
      "meaning": "Position the currency symbol to the LEFT of the amount (e.g., $100 vs 100$)",
      "notes": "Positional context - pair with 'Default' and 'Right' options",
      "status": "verified"
    }
  }
}
```

**2c. Translate into all missing locales at once**

With verified context in mind, produce the most natural translation for every locale in `missing_locales`:
- **Context is the source of truth**: Use documented meaning, not literal word
- Keep placeholders exactly as-is: `%s`, `%d`, `%1$s`, etc.
- Match tone/terminology of already-translated strings in the same locale file
- Strings with status="skip" should be kept as English (e.g., "Oinkoin Pro", "PIN", "CSV")
- If the word is identical in English and target language, verify it's correct in context (often fine for tech terms)

**2d. Write translations immediately**

Apply all translations for this key to affected locale files in one batch:
```bash
python3 scripts/write_translations.py <<'EOF'
{
  "de.json":  { "Apply": "Anwenden" },
  "fr.json":  { "Apply": "Appliquer" },
  "it.json":  { "Apply": "Applica" }
}
EOF
```

The script only overwrites values that still equal their key (untranslated). Already-translated strings are never touched.

### Step 3 — Continue with the next key
Repeat Step 2 for every entry in the discovery output.

### Step 4 — Report
After processing all keys, print a compact summary table:

| Key | Locale | Translation |
|-----|--------|-------------|
| Apply | it.json | Applica |
| Apply | de.json | Anwenden |
| … | … | … |

---

## Helper scripts reference

| Script | Purpose |
|--------|---------|
| `scripts/update_en_strings.py` | Sync `en-US.json` from source code and remove stale keys from all locales |
| `scripts/find_missing_translations.py` | List every key that is untranslated in one or more locales |
| `scripts/write_translations.py` | Apply a batch of translations from stdin JSON to locale files |

---

## Important rules

- **Never modify already-translated strings** (value ≠ key).
- **Never change keys** — only values.
- Process the **entire discovery list** in one invocation; do not stop to ask for confirmation.
- `en-GB.json` is always skipped.
