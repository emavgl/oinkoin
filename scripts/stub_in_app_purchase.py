#!/usr/bin/env python3
"""Swap the published in_app_purchase package for the local no-op stubs.

Rewrites the `in_app_purchase` dependency in pubspec.yaml to a path
dependency pointing at stubs/in_app_purchase, regardless of its current
source or version constraint, so this never breaks on a version bump.

This is a one-time generation step used only by
scripts/generate_fdroid_lock.sh to produce pubspec.yaml.fdroid, a build
artifact that nothing reads as human-facing config - so a plain PyYAML
load/mutate/dump round trip is fine here, even though it drops comments and
reformats the file. Nothing applies this live at build time (locally or in
F-Droid's build) - that just copies the already-committed
pubspec.yaml.fdroid/pubspec.lock.fdroid into place.
"""

import sys
from pathlib import Path

import yaml

PUBSPEC = Path(__file__).resolve().parent.parent / "pubspec.yaml"
STUB_DEP = {"path": "stubs/in_app_purchase"}


def main():
    try:
        with PUBSPEC.open(encoding="utf-8") as f:
            data = yaml.safe_load(f)
    except FileNotFoundError:
        sys.exit(f"error: {PUBSPEC} not found")

    deps = data.get("dependencies", {})
    if "in_app_purchase" not in deps:
        sys.exit("error: 'in_app_purchase' dependency not found in pubspec.yaml")

    if deps["in_app_purchase"] == STUB_DEP:
        print("in_app_purchase already points at the stubs")
        return

    deps["in_app_purchase"] = STUB_DEP

    with PUBSPEC.open("w", encoding="utf-8") as f:
        yaml.dump(data, f, sort_keys=False, default_flow_style=False)

    print("Swapped in_app_purchase for local stubs")


if __name__ == "__main__":
    main()
