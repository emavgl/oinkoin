#!/bin/bash
# Regenerate pubspec.lock.fdroid: the pub-resolved lockfile for the stubbed
# (in_app_purchase-free) dependency graph that F-Droid's build consumes.
#
# F-Droid's recipe runs `pub get --enforce-lockfile` against a pubspec.yaml
# that has already been stubbed by stub_in_app_purchase.py, so pubspec.lock
# must already match the stubbed manifest with no live re-resolution inside
# F-Droid's isolated builder. This script does that resolution here (with
# network access) instead, and is meant to be re-run whenever real
# dependencies change (wired into the release workflow).
#
# Usage:
#   ./scripts/generate_fdroid_lock.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PUBSPEC="$PROJECT_DIR/pubspec.yaml"
PUBSPEC_BACKUP="$PROJECT_DIR/pubspec.yaml.bak"
LOCKFILE="$PROJECT_DIR/pubspec.lock"
LOCKFILE_BACKUP="$PROJECT_DIR/pubspec.lock.bak"
FDROID_LOCKFILE="$PROJECT_DIR/pubspec.lock.fdroid"

cleanup() {
  if [ -f "$PUBSPEC_BACKUP" ]; then
    mv "$PUBSPEC_BACKUP" "$PUBSPEC"
    echo "Restored pubspec.yaml"
  fi
  if [ -f "$LOCKFILE_BACKUP" ]; then
    mv "$LOCKFILE_BACKUP" "$LOCKFILE"
    echo "Restored pubspec.lock"
  fi
  # pub get with the stubs regenerates this file without the StoreKit plugin;
  # restore it so the working tree stays clean.
  git -C "$PROJECT_DIR" checkout -- macos/Flutter/GeneratedPluginRegistrant.swift 2>/dev/null || true
}
trap cleanup EXIT

# Backup original pubspec and lockfile
cp "$PUBSPEC" "$PUBSPEC_BACKUP"
cp "$LOCKFILE" "$LOCKFILE_BACKUP"

# Swap real packages for stubs (version-agnostic, YAML-validated)
python3 "$SCRIPT_DIR/stub_in_app_purchase.py"

cd "$PROJECT_DIR"
if [ -x "$PROJECT_DIR/submodules/flutter/bin/flutter" ]; then
  FLUTTER="$PROJECT_DIR/submodules/flutter/bin/flutter"
else
  FLUTTER="$(command -v flutter)"
fi

"$FLUTTER" pub get

cp "$LOCKFILE" "$FDROID_LOCKFILE"
echo "Wrote $FDROID_LOCKFILE"
