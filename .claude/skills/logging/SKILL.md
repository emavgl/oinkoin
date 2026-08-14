---
name: logging
description: Adds consistent, context-aware Talker logging for important Oinkoin operations, diagnostics, warnings, and exceptions.
argument-hint: "[operation-or-file]"
---

# Skill: logging

Use the project logger in `lib/services/logger.dart` for important application operations. Logs are shown through the global Talker instance and are available in the in-app `LogScreen`.

## Create a logger with context

For a static service or class, use the actual project API:

```dart
class ExampleService {
  static final _logger = Logger.withContext('ExampleService');

  static Future<void> run() async {
    _logger.info('Starting operation');
  }
}
```

For an instance class:

```dart
final _logger = Logger.withClass(ExampleService);
```

Use a stable, useful context. Do not create a context for every individual method.

## Log levels

### `info` — important operations and milestones

Use `info` for events that explain the normal high-level flow:

- Starting and completing backup/restore
- Import/export counts and summaries
- User-triggered create/update/delete operations with meaningful identifiers
- Loading or applying a major configuration
- Starting/completing a long-running operation

Examples:

```dart
_logger.info('Starting portable preference restore (12 entries)');
_logger.info('Portable preference restore completed: 10 restored, 1 unknown, 1 invalid, 0 errors');
```

### `debug` — detailed diagnostics

Use `debug` for details useful while diagnosing behavior but too noisy for normal high-level reporting:

- Individual keys or record IDs processed
- Branch decisions and fallback paths
- Cache hits/misses
- A successfully applied setting
- Skipping optional work because no data is present

Examples:

```dart
_logger.debug('Restored preference: $key');
_logger.debug('No restored custom currency configuration to load');
```

### `warning` — recoverable unexpected conditions

Use `warning` when the application can safely continue:

- Unknown or removed preference keys
- Invalid setting types or values
- Missing optional data
- Duplicate records/categories that are intentionally ignored
- Unsupported but non-fatal input

```dart
_logger.warning('Skipping unknown preference from backup: $key');
```

### `error` / `critical` — failures

Use `error` for an operation failure that is handled, and `critical` only for severe failures requiring urgent attention. For caught exceptions, prefer `handle` so the exception and stack trace are retained:

```dart
try {
  await operation();
} catch (error, stackTrace) {
  _logger.handle(error, stackTrace, 'Failed to complete operation: $operationName');
}
```

Do not log only `error.toString()` when a stack trace is available.

## Logging pattern for important operations

For a non-trivial operation:

1. Log an `info` message when it starts.
2. Log useful per-item or branch details at `debug` level.
3. Log recoverable mismatches at `warning` level.
4. Catch exceptions at the narrowest useful boundary and call `handle` with the stack trace.
5. Log an `info` completion summary with counts/outcome.
6. Let the caller decide whether the operation should return failure, retry, or continue.

Each item in a batch should not abort the entire batch merely because one item failed. Isolate the item in `try/catch`, log the key/identifier and exception, and continue when safe.

## Security and privacy

Never log:

- Passwords, password hashes, encryption keys, or tokens
- Full preference values when they may contain sensitive data
- Personal financial amounts or notes unless explicitly required and safe
- Full file contents or backup payloads

Log safe metadata instead:

- Key names
- Record/category/wallet IDs when non-sensitive
- Counts and sizes
- Value types and validation status
- File names rather than file contents

For backup preferences, log `restored`, `unknown`, `invalid`, and `errors` counts, but never the setting values.

## Avoid noisy or misleading logs

- Do not use `info` for every loop item.
- Do not log successful operations as errors.
- Do not swallow exceptions silently.
- Do not duplicate the same exception at many layers unless each layer adds meaningful context.
- Do not use `print` for application diagnostics; use `Logger`.
- Keep messages actionable and include the operation/key/identifier needed to investigate.

## Verification

When adding logging:

- Run focused `flutter analyze` on changed files.
- Run relevant tests, especially failure and mismatch paths.
- Confirm exceptions include stack traces in the Talker output.
- Confirm logs do not expose secrets or financial payloads.
- For batch operations, verify one invalid item is logged and later valid items still complete.
