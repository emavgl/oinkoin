#!/bin/bash
# Simulate F-Droid's build recipe locally, without fdroidserver:
#   prebuild: cp pubspec.yaml.fdroid pubspec.yaml
#             cp pubspec.lock.fdroid pubspec.lock
#   build:    flutter pub get --enforce-lockfile
#
# Run this after touching pubspec.yaml, pubspec.lock, pubspec.yaml.fdroid,
# pubspec.lock.fdroid, or the stubs/ packages, to catch a lockfile mismatch
# before it shows up as a failed F-Droid build.
#
# Usage:
#   ./scripts/test_fdroid_recipe.sh
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
  git -C "$PROJECT_DIR" checkout -- macos/Flutter/GeneratedPluginRegistrant.swift 2>/dev/null || true
}
trap cleanup EXIT

cp "$PUBSPEC" "$PUBSPEC_BACKUP"
cp "$LOCKFILE" "$LOCKFILE_BACKUP"

cd "$PROJECT_DIR"
if [ -x "$PROJECT_DIR/submodules/flutter/bin/flutter" ]; then
  FLUTTER="$PROJECT_DIR/submodules/flutter/bin/flutter"
else
  FLUTTER="$(command -v flutter)"
fi

echo "== prebuild: cp pubspec.yaml.fdroid pubspec.yaml; cp pubspec.lock.fdroid pubspec.lock =="
cp "$FDROID_PUBSPEC" "$PUBSPEC"
cp "$FDROID_LOCKFILE" "$LOCKFILE"

echo "== build: flutter pub get --enforce-lockfile =="
"$FLUTTER" pub get --enforce-lockfile

echo "OK: pubspec.lock.fdroid satisfies pubspec.yaml.fdroid under --enforce-lockfile"
