#!/usr/bin/env python3
"""Swap the published in_app_purchase package for the local no-op stubs.

Rewrites the `in_app_purchase` entry in pubspec.yaml to point at
stubs/in_app_purchase, regardless of its current source or version
constraint, so this never breaks on a version bump. Also drops in
pubspec.lock.fdroid (pre-resolved for the stubbed graph by
scripts/generate_fdroid_lock.sh) as pubspec.lock, so F-Droid's
`pub get --enforce-lockfile` succeeds without any live re-resolution inside
its isolated builder.

The edit itself is a key-anchored, version-agnostic line rewrite that keeps
all formatting and comments intact (a full YAML re-dump would destroy them).
When PyYAML is available (it always is where fdroidserver runs), the result
is additionally parsed and validated as YAML.
"""

import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PUBSPEC = ROOT / "pubspec.yaml"
LOCKFILE = ROOT / "pubspec.lock"
FDROID_LOCKFILE = ROOT / "pubspec.lock.fdroid"
STUB_REF = "{ path: stubs/in_app_purchase }"


def stub_pubspec_yaml():
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


def swap_in_fdroid_lockfile():
    if not FDROID_LOCKFILE.exists():
        print(f"warning: {FDROID_LOCKFILE} not found, leaving pubspec.lock untouched")
        return
    shutil.copyfile(FDROID_LOCKFILE, LOCKFILE)
    print(f"Swapped in {FDROID_LOCKFILE.name} as pubspec.lock")


def main():
    stub_pubspec_yaml()
    swap_in_fdroid_lockfile()


if __name__ == "__main__":
    main()
