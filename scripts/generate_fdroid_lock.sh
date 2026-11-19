#!/bin/bash
# Regenerate pubspec.yaml.fdroid and pubspec.lock.fdroid: the manifest and
# its pub-resolved lockfile that F-Droid's build consumes.
#
# F-Droid's recipe just copies these two files into place (no live editing,
# no pub resolution) before running `pub get --enforce-lockfile`, so they
# must already be fully self-consistent. This script does the resolution
# here (with network access) instead, and is meant to be re-run whenever real
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
FDROID_PUBSPEC="$PROJECT_DIR/pubspec.yaml.fdroid"
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
  # pub get regenerates the macOS plugin registrant; restore it so the
  # working tree stays clean.
  git -C "$PROJECT_DIR" checkout -- macos/Flutter/GeneratedPluginRegistrant.swift 2>/dev/null || true
}
trap cleanup EXIT

# Backup original pubspec and lockfile
cp "$PUBSPEC" "$PUBSPEC_BACKUP"
cp "$LOCKFILE" "$LOCKFILE_BACKUP"

# No stubbing step any more: the app no longer depends on Google Play Billing,
# so the F-Droid manifest is simply a copy of the real one.
cp "$PUBSPEC" "$FDROID_PUBSPEC"

cd "$PROJECT_DIR"
if [ -x "$PROJECT_DIR/submodules/flutter/bin/flutter" ]; then
  FLUTTER="$PROJECT_DIR/submodules/flutter/bin/flutter"
else
  FLUTTER="$(command -v flutter)"
fi

"$FLUTTER" pub get

cp "$LOCKFILE" "$FDROID_LOCKFILE"
echo "Wrote $FDROID_PUBSPEC"
echo "Wrote $FDROID_LOCKFILE"
