#!/usr/bin/env python3
"""
For each key in en-US.json, report which locale files still need a translation.
A string is considered untranslated when its value equals its key.

Output: JSON array sorted by key, each entry:
  {"key": "...", "missing_locales": ["de.json", "it.json", ...]}

Only entries with at least one missing locale are included.

Usage:
  python3 scripts/find_missing_translations.py
  python3 scripts/find_missing_translations.py --locale it.json
  python3 scripts/find_missing_translations.py --locale it.json --locale de.json

Entries marked with status "skip" in _automated_translation.json are ignored.
Entries may also list locale codes in "same_as_english_locales" when the English
spelling is a valid translation for those specific locales.
"""
import argparse
import json
from pathlib import Path

SKIP_LOCALES = {"en-US.json", "en-GB.json"}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--locale",
        action="append",
        dest="locales",
        metavar="LOCALE",
        help="Restrict to specific locale file(s) (e.g. it.json). Repeatable.",
    )
    parser.add_argument("--locales-dir", default="assets/locales")
    parser.add_argument(
        "--translation-tracking",
        default="_automated_translation.json",
        help="Path to the translation context file used for skip statuses.",
    )
    args = parser.parse_args()

    locales_dir = Path(args.locales_dir)

    with open(locales_dir / "en-US.json", encoding="utf-8") as f:
        source: dict = json.load(f)

    tracking_path = Path(args.translation_tracking)
    skipped_keys = set()
    if tracking_path.exists():
        with open(tracking_path, encoding="utf-8") as f:
            tracking: dict = json.load(f)
        skipped_keys = {
            key
            for key, entry in tracking.get("keys", {}).items()
            if isinstance(entry, dict) and entry.get("status") == "skip"
        }
        same_as_english_locales = {
            key: {
                locale if locale.endswith(".json") else locale + ".json"
                for locale in entry.get("same_as_english_locales", [])
            }
            for key, entry in tracking.get("keys", {}).items()
            if isinstance(entry, dict)
        }
    else:
        same_as_english_locales = {}

    all_locale_files = sorted(
        p for p in locales_dir.glob("*.json") if p.name not in SKIP_LOCALES
    )

    if args.locales:
        # Normalise: accept both "it" and "it.json"
        requested = {loc if loc.endswith(".json") else loc + ".json" for loc in args.locales}
        all_locale_files = [p for p in all_locale_files if p.name in requested]

    locale_data: dict[str, dict] = {}
    for path in all_locale_files:
        with open(path, encoding="utf-8") as f:
            locale_data[path.name] = json.load(f)

    results = []
    for key in source:
        if key in skipped_keys:
            continue

        missing = [
            locale_name
            for locale_name, data in locale_data.items()
            if data.get(key, key) == key
            and locale_name not in same_as_english_locales.get(key, set())
            # missing or value == key means untranslated unless explicitly allowed
        ]
        if missing:
            results.append({"key": key, "missing_locales": sorted(missing)})

    print(json.dumps(results, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
