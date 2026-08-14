---
name: markup-text
description: Adds or updates localized text with reusable inline bold, italic, or underline markup in the Oinkoin Flutter app.
argument-hint: "[text-or-file]"
---

# Skill: markup-text

Use the shared `MarkupText` widget when a localized sentence needs part of its text emphasized. Keep the markup in the localized string so translators can reorder the emphasized words naturally.

## Supported markup

`lib/components/markup_text.dart` supports:

- `<b>...</b>` and `<strong>...</strong>` — bold
- `<i>...</i>` and `<em>...</em>` — italic
- `<u>...</u>` — underline

Markup can be combined and nested where the parser supports it. Text without markup is rendered as ordinary `Text`.

## Usage

Store the markup in `assets/locales/en-US.json` and attach localization directly to the literal:

```dart
MarkupText(
  "Select the <b>origin</b> wallet".i18n,
  style: instructionStyle,
)
```

Do not localize a conditional expression after choosing the string:

```dart
// Avoid this form.
(condition ? "..." : "...").i18n
```

Prefer `.i18n` beside each source literal:

```dart
final instruction = condition
    ? MarkupText("Select the <b>origin</b> wallet".i18n)
    : MarkupText("Select the <b>destination</b> wallet".i18n);
```

## Localization workflow

1. Add the marked source string to `assets/locales/en-US.json`.
2. Search the codebase and read the surrounding UI to document its meaning.
3. Add the key to `_automated_translation.json` with page, component, meaning, and translation notes.
4. Run `python3 scripts/update_en_strings.py` when adding a new source string.
5. Do not manually add translations to other locales unless the task requests it.
6. Translators may move `<b>`, `<i>`, or `<u>` markers around the translated words; never split the sentence into separate widgets to force English word order.

The markup tags are part of the localization key/value and must remain balanced in every locale.

## Typography rules

`MarkupText` merges its supplied style with `DefaultTextStyle.of(context).style`. Pass only the local visual changes needed by the feature; do not replace the app font family accidentally. The surrounding app typography should remain consistent for both marked and unmarked strings.

Use the same layout and style conventions as neighboring `Text` widgets. For an instruction or list heading, reuse the existing style rather than creating a new font treatment.

## Tests

Add or update tests in `test/markup_text_test.dart` for reusable parser behavior:

- Plain text renders without markup spans.
- Bold, italic, and underline tags apply the expected `TextStyle`.
- Multiple marked sections render in the correct order.
- Surrounding/default font style is preserved.
- Untranslated or malformed markup does not crash the widget.

For feature-specific markup, add a widget test that verifies the localized sentence and emphasis in each UI state.

## Checklist

- [ ] Markup is in the locale string, not hard-coded as a transfer-specific parser.
- [ ] Each source literal uses `.i18n` directly.
- [ ] Tags are balanced and can be reordered by translators.
- [ ] `_automated_translation.json` contains verified context.
- [ ] `MarkupText` inherits the surrounding typography.
- [ ] Parser and feature tests pass.
