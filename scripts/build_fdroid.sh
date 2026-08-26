#!/bin/bash
# Build the F-Droid flavor with in_app_purchase stripped out.
#
# F-Droid forbids proprietary dependencies (Google Play Billing) in the APK.
# This script temporarily swaps the real in_app_purchase packages for no-op
# stubs, builds the fdroid flavor, then restores the original pubspec.yaml.
#
# Usage:
#   ./scripts/build_fdroid.sh [--release]
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PUBSPEC="$PROJECT_DIR/pubspec.yaml"
PUBSPEC_BACKUP="$PROJECT_DIR/pubspec.yaml.bak"

BUILD_ARGS=("$@")
if [ ${#BUILD_ARGS[@]} -eq 0 ]; then
  BUILD_ARGS=("--release")
fi

cleanup() {
  if [ -f "$PUBSPEC_BACKUP" ]; then
    mv "$PUBSPEC_BACKUP" "$PUBSPEC"
    echo "Restored pubspec.yaml"
  fi
}
trap cleanup EXIT

# Backup original pubspec
cp "$PUBSPEC" "$PUBSPEC_BACKUP"

# Swap real packages for stubs
sed -i 's|  in_app_purchase: \^3\.3\.0|  in_app_purchase: { path: stubs/in_app_purchase }|' "$PUBSPEC"

echo "Swapped in_app_purchase for F-Droid stubs"

# Regenerate plugin list without the real plugins
cd "$PROJECT_DIR"
flutter pub get

# Build
flutter build apk --flavor fdroid "${BUILD_ARGS[@]}"
