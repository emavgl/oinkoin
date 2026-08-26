#!/bin/bash
# Build the Pro flavor without proprietary Google Play Billing dependencies.
# The Pro distribution is sideloaded/outside Google Play and uses the same
# no-op in_app_purchase stubs as the F-Droid build.
#
# Usage:
#   BUILD_COMMAND=appbundle ./scripts/build_pro.sh [flutter build arguments]
#   ./scripts/build_pro.sh [flutter build apk arguments]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PUBSPEC="$PROJECT_DIR/pubspec.yaml"
PUBSPEC_BACKUP="$PROJECT_DIR/pubspec.yaml.bak"

cleanup() {
  if [ -f "$PUBSPEC_BACKUP" ]; then
    mv "$PUBSPEC_BACKUP" "$PUBSPEC"
    echo "Restored pubspec.yaml"
  fi
}
trap cleanup EXIT

cp "$PUBSPEC" "$PUBSPEC_BACKUP"
sed -i 's|  in_app_purchase: \^3\.3\.0|  in_app_purchase: { path: stubs/in_app_purchase }|' "$PUBSPEC"

echo "Swapped in_app_purchase for Pro stubs"
cd "$PROJECT_DIR"
flutter pub get
BUILD_COMMAND="${BUILD_COMMAND:-apk}"
flutter build "$BUILD_COMMAND" --flavor pro "$@"
