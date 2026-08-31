#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
screenshots_dir="$repo_root/fastlane/screenshots"

cd "$screenshots_dir"
bundle exec ruby "$repo_root/scripts/frameit_android_runner.rb" android "$@"
