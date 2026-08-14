---
name: add-setting
description: Adds a key-value preference to the Oinkoin Flutter app, connects it to the UI and defaults, and integrates safe backup and restore behavior.
argument-hint: "[setting-name]"
---

# Skill: add-setting

Use this skill whenever a new user preference or key-value application setting is introduced.

## 1. Define the key

Add a named constant to `lib/settings/constants/preferences-keys.dart` in the appropriate section:

```dart
class PreferencesKeys {
  static const showExampleSetting = 'showExampleSetting';
}
```

Use the stable storage key as the value. Do not rename an existing key casually: renaming breaks existing local preferences and older backups unless a migration/compatibility path is provided.

## 2. Define the default

Add the setting to `PreferencesDefaultValues.defaultValues` in `lib/settings/constants/preferences-defaults-values.dart`.

The default must have the same Dart type that the setting uses in `SharedPreferences`:

- `bool` → `setBool` / `getBool`
- `int` → `setInt` / `getInt`
- `double` → `setDouble` / `getDouble`
- `String` → `setString` / `getString`
- `List<String>` → `setStringList` / `getStringList`

Use `PreferencesUtils.getOrDefault<T>(prefs, key)` when reading a setting so a missing key receives its default.

## 3. Add options and UI

For finite choices, add the user-facing values to `lib/settings/constants/preferences-options.dart`. Store stable values such as enum indexes, not translated labels.

Use the existing settings widgets where possible:

- `SwitchCustomizationItem` for booleans
- `DropdownCustomizationItem` for options
- Existing text/input setting components for strings

Place the setting in the correct subsection of `lib/settings/customization-page.dart` or the relevant settings page. Localize all user-facing strings with `.i18n`. If a new source string is added:

1. Add it to `assets/locales/en-US.json`.
2. Run `python3 scripts/update_en_strings.py`.
3. Research its usage and document it in `_automated_translation.json`.
4. Translate other locales only when requested.

If the setting affects cached application state, update the relevant service/notifier and invalidate caches where necessary.

## 4. Add it to portable backup/restore

Portable settings are handled by `lib/services/preferences-backup-service.dart`.

### Export allowlist

Add the key to `_portableKeys` only if it is safe and meaningful to copy to another device/profile. Do not include:

- Backup passwords or backup automation controls
- App-lock/security state
- Active profile identifiers
- Profile-specific wallet filters
- Device-local file paths or uploaded files
- Internal counters or prompt state

If the setting is portable, add a validator to `_validators` matching its current type and valid values. Invalid values must be rejected rather than blindly applied:

```dart
PreferencesKeys.showExampleSetting: (value) => value is bool,
```

For enum indexes, validate the actual supported set/range. For serialized JSON, validate that it parses and has the expected structure.

Both export and restore must remain tolerant:

- Unknown keys are skipped.
- Invalid values are skipped.
- A setter exception is isolated to that key.
- A setter returning `false` is treated as a failure.
- No preference mismatch may abort database restore.

Never log preference values or secrets. The preference backup service logs key names, statuses, counters, and exception stack traces safely.

## 5. Tests

Add tests to `test/backup/preferences_backup_service_test.dart` covering:

- Valid value is exported.
- Sensitive/device-local values remain excluded.
- Valid value restores with the expected type.
- Unknown/removed key is skipped.
- Wrong type is skipped.
- Invalid enum/index/serialized value is skipped.
- A valid setting after an invalid setting still restores.
- Restore completes for arbitrary or malformed payloads.

If the setting affects real application/database behavior, add or extend an integration test in `test/backup/preferences_backup_integration_test.dart` to prove that database restoration still succeeds when the setting is malformed.

## Checklist

- [ ] Key added to `PreferencesKeys`.
- [ ] Default added with the correct type.
- [ ] Options/UI use stable stored values and localized labels.
- [ ] New English strings are synced and context-documented.
- [ ] Portable backup allowlist updated if appropriate.
- [ ] Validator added for the setting.
- [ ] Unknown, wrong-type, invalid-value, and mixed-payload tests added.
- [ ] No sensitive or device-specific data is copied.
- [ ] Focused analysis and backup tests pass.
