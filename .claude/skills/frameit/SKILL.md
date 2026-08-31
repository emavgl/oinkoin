---
name: frameit
description: Installs and runs the Oinkoin screenshot framing workflow with Fastlane Frameit and Samsung Galaxy S21 support.
argument-hint: "[rebuild]"
---

# Skill: frameit

Use this skill when preparing or rebuilding Oinkoin's Google Play Store screenshots.

## What this workflow does

The project uses Fastlane Frameit to add a Samsung Galaxy S21 5G frame, yellow background, and marketing text to Android screenshots.

The standard Frameit gem does not register the S21 device even though its frame assets exist in the official Frameit repository. The project therefore provides:

- `scripts/frameit_s21_patch.rb` - registers the S21 device while using the official Frameit asset host.
- `scripts/frameit_android_runner.rb` - loads Fastlane before the patch and starts Frameit's Android command.
- `scripts/frameit_android.sh` - runs the workflow from the repository root.
- `fastlane/screenshots/Framefile.json` - defines the layout, typography, and per-image text.

The frame assets are hosted by the official Frameit project at https://fastlane.github.io/frameit-frames/.

## Installation

Install Ruby, Bundler, and ImageMagick. On Ubuntu/Debian:

```bash
sudo apt-get update
sudo apt-get install -y ruby-full imagemagick
```

Install the pinned Fastlane dependency from the repository root:

```bash
bundle install
```

The dependency is pinned in `Gemfile` and `Gemfile.lock`. Do not install an unrelated global Fastlane version for this workflow.

## Rebuild screenshots

Place the raw Android screenshots in `fastlane/screenshots/` using the names matched by `Framefile.json` (for example, `image1.png` through `image5.png`). Then run:

```bash
./scripts/frameit_android.sh
```

Frameit downloads the official device assets on the first run. It writes framed files beside the inputs with the `_framed.png` suffix, such as `image1_framed.png`.

The script can pass additional Frameit arguments:

```bash
./scripts/frameit_android.sh --verbose
```

## Configuration

Edit `fastlane/screenshots/Framefile.json` to change:

- Background image and padding
- S21 frame selection
- Font files, sizes, and colors
- Marketing headings and subtitles
- Screenshot-specific text matched by `filter`

Keep `force_device_type` set to `Samsung Galaxy S21 5G` unless the S21 patch and frame source are intentionally changed together.

## Verification

Run the script successfully and check that every expected output exists. Verify dimensions with:

```bash
for image in fastlane/screenshots/*_framed.png; do
  identify "$image"
done
```

The Play Store phone screenshots should be portrait images at 1620x2880. Inspect at least one output visually after changing the Framefile.

## Source control

Commit the workflow files and configuration, but do not commit raw input screenshots or generated framed screenshots unless explicitly requested. The expected reusable files are:

- `.claude/skills/frameit/SKILL.md`
- `Gemfile`
- `Gemfile.lock`
- `fastlane/screenshots/Framefile.json`
- `scripts/frameit_android.sh`
- `scripts/frameit_android_runner.rb`
- `scripts/frameit_s21_patch.rb`
