#!/bin/bash
# Build the Pro or Alpha flavor without proprietary Google Play Billing
# dependencies. Both distributions are sideloaded/outside Google Play and use
# the same no-op in_app_purchase stubs as the F-Droid build.
#
# Usage:
#   BUILD_COMMAND=appbundle ./scripts/build_pro.sh [flutter build arguments]
#   ./scripts/build_pro.sh [flutter build apk arguments]
#
# Set FLAVOR=alpha to build the alpha flavor (defaults to pro).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PUBSPEC="$PROJECT_DIR/pubspec.yaml"
PUBSPEC_BACKUP="$PROJECT_DIR/pubspec.yaml.bak"
LOCKFILE="$PROJECT_DIR/pubspec.lock"
LOCKFILE_BACKUP="$PROJECT_DIR/pubspec.lock.bak"

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

cp "$PUBSPEC" "$PUBSPEC_BACKUP"
cp "$LOCKFILE" "$LOCKFILE_BACKUP"
python3 "$SCRIPT_DIR/stub_in_app_purchase.py"

echo "Swapped in_app_purchase for stubs"
cd "$PROJECT_DIR"
flutter pub get
BUILD_COMMAND="${BUILD_COMMAND:-apk}"
FLAVOR="${FLAVOR:-pro}"
flutter build "$BUILD_COMMAND" --flavor "$FLAVOR" "$@"
