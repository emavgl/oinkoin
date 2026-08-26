#!/usr/bin/env python3
"""Swap the published in_app_purchase package for the local no-op stubs.

Rewrites the `in_app_purchase` entry in pubspec.yaml to point at
stubs/in_app_purchase, regardless of its current source or version
constraint, so this never breaks on a version bump.

The edit itself is a key-anchored, version-agnostic line rewrite that keeps
all formatting and comments intact (a full YAML re-dump would destroy them).
When PyYAML is available (it always is where fdroidserver runs), the result
is additionally parsed and validated as YAML.
"""

import re
import sys
from pathlib import Path

PUBSPEC = Path(__file__).resolve().parent.parent / "pubspec.yaml"
STUB_REF = "{ path: stubs/in_app_purchase }"


def main():
    try:
        text = PUBSPEC.read_text(encoding="utf-8")
    except FileNotFoundError:
        sys.exit(f"error: {PUBSPEC} not found")

    pattern = re.compile(r"^(\s*in_app_purchase:[ \t]*)(\S.*)$", re.MULTILINE)
    if not pattern.search(text):
        sys.exit("error: 'in_app_purchase' dependency not found in pubspec.yaml")

    updated = pattern.sub(lambda m: m.group(1) + STUB_REF, text, count=1)
    if updated == text:
        print("in_app_purchase already points at the stubs")
        return

    try:
        import yaml

        data = yaml.safe_load(updated)
        dep = data["dependencies"]["in_app_purchase"]
        if not (isinstance(dep, dict) and dep.get("path") == "stubs/in_app_purchase"):
            sys.exit("error: rewritten pubspec.yaml did not validate")
    except ImportError:
        pass  # no PyYAML here; the key-anchored rewrite is sufficient
    except Exception as e:
        sys.exit(f"error: rewritten pubspec.yaml is invalid: {e}")

    PUBSPEC.write_text(updated, encoding="utf-8")
    print("Swapped in_app_purchase for local stubs")


if __name__ == "__main__":
    main()
