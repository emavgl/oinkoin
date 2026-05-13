#!/usr/bin/env python3
"""
Apply a batch of translations to locale files.

Reads a JSON object from stdin:
  {
    "it.json": {"Apply": "Applica", "Amount (Ascending)": "Importo (Crescente)"},
    "de.json": {"Apply": "Anwenden"}
  }

For each locale, only entries where the current value equals the key
(untranslated) or the key is absent are updated. Already-translated
strings are never overwritten.

Key order in each locale file is preserved; new keys are inserted in
the same position they occupy in en-US.json (maintaining alphabetical
order with the rest of the file).

Usage:
  echo '{"it.json": {"Apply": "Applica"}}' | python3 scripts/write_translations.py
  python3 scripts/write_translations.py < translations.json
"""
import json
import sys
from pathlib import Path


LOCALES_DIR = Path("assets/locales")


def ordered_merge(existing: dict, updates: dict, source_order: list[str]) -> dict:
    """
    Merge updates into existing dict.
    New keys are placed at the position they appear in source_order.
    """
    merged = dict(existing)
    for key, value in updates.items():
        current = merged.get(key, key)
        if current == key:  # untranslated or missing — safe to write
            merged[key] = value

    # Re-sort by source order so new keys land in the right position
    source_index = {k: i for i, k in enumerate(source_order)}
    return dict(
        sorted(merged.items(), key=lambda kv: source_index.get(kv[0], len(source_order)))
    )


def main():
    raw = sys.stdin.read().strip()
    if not raw:
        print("No input received.", file=sys.stderr)
        sys.exit(1)

    try:
        batch: dict[str, dict] = json.loads(raw)
    except json.JSONDecodeError as e:
        print(f"Invalid JSON input: {e}", file=sys.stderr)
        sys.exit(1)

    with open(LOCALES_DIR / "en-US.json", encoding="utf-8") as f:
        source_order: list[str] = list(json.load(f).keys())

    for locale_name, updates in batch.items():
        locale_path = LOCALES_DIR / locale_name
        if not locale_path.exists():
            print(f"WARNING: {locale_path} not found, skipping.", file=sys.stderr)
            continue

        with open(locale_path, encoding="utf-8") as f:
            existing: dict = json.load(f)

        merged = ordered_merge(existing, updates, source_order)

        with open(locale_path, "w", encoding="utf-8") as f:
            json.dump(merged, f, indent=2, ensure_ascii=False)

        written = [k for k in updates if existing.get(k, k) == k]
        skipped = [k for k in updates if k not in written]
        print(f"{locale_name}: wrote {len(written)} key(s)" +
              (f", skipped {len(skipped)} already-translated" if skipped else ""))


if __name__ == "__main__":
    main()
