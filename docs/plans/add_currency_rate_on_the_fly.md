# Feature Plan: Per-Transaction Custom Exchange Rate

> **Branch:** `add_currency_rate_on_the_fly`
> **Date:** 2026-05-03
> **Status:** Draft / Plan

## 1. The Problem

Currently, when creating a transfer between wallets with different currencies (e.g., USD → SDG), the app always uses a **single global rate** from Settings > Currency. This rate is stored in `SharedPreferences` and applied at the moment of the transfer.

**Tarig's use case:** Exchange rates fluctuate daily/weekly. He needs to:

1. Transfer $100 USD → SDG at last week's rate (600 SDG/USD)
2. Transfer another $100 today at today's rate (650 SDG/USD)
3. Have **both historical amounts preserved** without changing the global rate back and forth

**Current behavior:** The converted amount (`transferValue`) IS stored per-transaction in the database, so old transfers don't change when you update the global rate. However:

- You **cannot set a custom rate** for a single transfer — it always uses whatever is in Settings
- If you **edit** an old transfer, it **recalculates** using the current global rate (overwriting the historical value)
- The actual exchange rate used is **not stored** — only the resulting converted amount

## 2. Proposed Solution

Allow the user to **enter or override the exchange rate** directly on the Edit Record screen when creating/editing a transfer between different-currency wallets. Store that per-transaction rate in the database so it survives edits.

### 2.1. Data Model Changes

#### `Record` model (`lib/models/record.dart`)

Add a new nullable field:

```dart
double? transferRate;
```

- `null` = not a cross-currency transfer, or use the global rate (backward compatible)
- non-null = the custom exchange rate used for this specific transaction (in "1 source currency = X destination currency" format)

#### `RecurrentRecordPattern` model (`lib/models/recurrent-record-pattern.dart`)

Same field, for consistency:

```dart
double? transferRate;
```

### 2.2. Database Changes (Migration v27)

Add a new column to both tables:

```sql
ALTER TABLE records ADD COLUMN transfer_rate REAL;
ALTER TABLE recurrent_record_patterns ADD COLUMN transfer_rate REAL;
```

- Bump `SqliteDatabase.version` from 26 → 27
- Add migration function `_migrateTo27`
- Update `_createRecordsTable()` and `_createRecurrentRecordPatternsTable()` to include the new column in new databases
- Update all `INSERT` statements to include `transfer_rate`

### 2.3. Serialization Changes

- **`Record.toMap()` / `Record.fromMap()`**: Include/exclude `transfer_rate`
- **`RecurrentRecordPattern.toMap()` / `fromMap()`**: Same
- **Backup (`Backup.toMap()` / `fromMap()`)** uses the above, no extra changes needed

### 2.4. Currency Conversion Rate Display Helper

Add a new helper in `lib/helpers/records-utility-functions.dart`:

```dart
/// Formats an exchange rate for display, e.g. "1 USD = 650.00 SDG".
/// Uses the actual [rate] if provided, otherwise falls back to the global rate.
String formatTransferRateDisplay(
  String fromCurrency,
  String toCurrency, {
  double? rate,
}) {
  if (rate != null) {
    return '1 $fromCurrency = ${rate.toStringAsFixed(2)} $toCurrency';
  }
  return getConversionRateString(fromCurrency, toCurrency) ?? 'N/A';
}
```

### 2.5. UI Changes — Edit Record Page

On the **Edit Record** screen (`lib/records/edit-record-page.dart`):

#### When to show the rate input

Show a **rate row** when **all** of these are true:
1. The record is a transfer (destination wallet selected)
2. Source and destination wallets have different currencies
3. Both currencies are non-null

#### What the rate row looks like

```
┌─────────────────────────────────────┐
│ Exchange Rate                       │
│ ┌───────────────────┐               │
│ │ 650.00            │  1 USD → SDG │
│ └───────────────────┘               │
│ Last rate from settings: 1 USD =    │
│ 600.00 SDG                          │
│ [Reset to global rate]              │
└─────────────────────────────────────┘
```

- **Text field** pre-filled with the current global rate from `getConversionRates()`
- User can type any positive number to override
- Shows "1 USD = X SDG" label next to the field for context
- Shows a small hint text: "Default rate from Settings: 1 USD = 600.00 SDG"
- A "Reset" button/icon to go back to the global rate
- Read-only mode: show the rate as text

#### Validation

- Must be a positive number
- Show error if zero or negative

### 2.6. Business Logic Changes

#### `_recalculateTransferValue()` (`edit-record-page.dart:1022`)

Current:
```dart
record!.transferValue = convertAmount(record!.value!.abs(), src, dest);
```

New logic:
```dart
final amount = record!.value!.abs();
if (record!.transferRate != null && record!.transferRate! > 0) {
  record!.transferValue = amount * record!.transferRate!;
} else {
  record!.transferValue = convertAmount(amount, src, dest);
}
```

#### `_appendTransferNoteToDescription()` (`edit-record-page.dart:1038`)

Use the actual rate (custom or global) in the auto-generated description note:

```dart
final rateDisplay = record!.transferRate != null
    ? '1 $srcCurrency = ${record!.transferRate!.toStringAsFixed(2)} $destCurrency'
    : getConversionRateString(srcCurrency, destCurrency);
```

#### On page init (editing existing record)

When loading an existing record with a `transferRate`:
- Pre-fill the rate field with `record.transferRate`
- On first load, also show the current global rate as a hint

#### On wallet/amount change

When source wallet, destination wallet, or amount changes while a custom rate is set:
- Recalculate `transferValue` using the custom rate (not the global rate)
- Do NOT overwrite `transferRate` — only update `transferValue`

#### When user clears/resets the rate

Set `transferRate` to `null` and recalculate using `convertAmount()`.

### 2.7. Recurring Pattern Handling

Same logic applies to `RecurrentRecordPattern`:
- `transferRate` is persisted in the `recurrent_record_patterns` table
- When creating a pattern from a record (`RecurrentRecordPattern.fromRecord()`), copy `transferRate`
- When the pattern generates instances, the rate is propagated

## 3. Files to Modify

| # | File | Change |
|---|------|--------|
| 1 | `lib/models/record.dart` | Add `transferRate` field, update `toMap()`/`fromMap()` |
| 2 | `lib/models/recurrent-record-pattern.dart` | Add `transferRate` field, update `toMap()`/`fromMap()` |
| 3 | `lib/services/database/sqlite-database.dart` | Bump version to 27, update INSERT statements |
| 4 | `lib/services/database/sqlite-migration-service.dart` | Add v27 migration, update CREATE TABLE statements |
| 5 | `lib/records/edit-record-page.dart` | Add rate input UI, update `_recalculateTransferValue()`, update `_appendTransferNoteToDescription()`, handle init logic |
| 6 | `lib/helpers/records-utility-functions.dart` | Add `formatTransferRateDisplay()` helper |
| 7 | `lib/i18n.dart` | (If any new strings are added, add translation entries and update `_automated_translation.json`) |

## 4. Files to Create

| # | File | Purpose |
|---|------|---------|
| 1 | `lib/records/components/transfer_rate_row.dart` | New widget for the exchange rate row (keeps edit-record-page.dart manageable) |

## 5. Files to Update (I18n)

Entries in `assets/locales/en-US.json`:

```json
{
  "Exchange Rate": "Exchange Rate",
  "Custom rate for this transfer": "Custom rate for this transfer",
  "Reset to default rate": "Reset to default rate",
  "Default rate from settings": "Default rate from settings",
  "Enter a positive number": "Enter a positive number"
}
```

## 6. Migration Plan (Database v26 → v27)

```dart
static Future<void> _migrateTo27(Database db) async {
  await safeAlterTable(db, "ALTER TABLE records ADD COLUMN transfer_rate REAL;");
  await safeAlterTable(db, "ALTER TABLE recurrent_record_patterns ADD COLUMN transfer_rate REAL;");
}
```

Also update `_createRecordsTable()` and `_createRecurrentRecordPatternsTable()` in the migration service to include `transfer_rate REAL` for fresh installs.

## 7. Edge Cases

### 7.1. User changes source/destination currency

- If the currencies change (e.g., user switches from USD→SDG to EUR→SDG), the stored `transferRate` becomes invalid
- **Behavior:** Clear `transferRate` and recalculate from global rates

### 7.2. User changes wallet to same currency

- If both wallets now share the same currency, `transferValue` is set to `null` and `transferRate` should also be cleared
- **Behavior:** Hide the rate row entirely

### 7.3. User changes the amount

- Recalculate `transferValue` using the existing `transferRate` (if set) or global rate
- **Behavior:** `transferRate` stays unchanged

### 7.4. User edits an old transfer that had a custom rate

- Load `transferRate` from database and pre-fill it
- User can change it, keep it, or reset to global

### 7.5. Backup/Restore

- Since `Record.toMap()`/`fromMap()` will include `transferRate`, backups will automatically preserve the rate
- **Backward compatibility:** Old backups without `transfer_rate` will just deserialize as `null`, which is safe

### 7.6. Same-currency transfer then change to different currencies

- If user starts with same-currency wallets (no rate shown), then picks different currencies, the rate row appears pre-filled with global rate

## 8. UI/UX Flow

### Creating a new transfer

```
1. User picks expense category
2. User picks source wallet (USD) and destination wallet (SDG) ← both have currencies
3. User enters amount ($100)
4. ↓ Rate row appears with global rate pre-filled (600.00)
5. User can:
   a. Leave as-is → uses global rate → transferValue = $60,000 SDG
   b. Edit to 650.00 → custom rate → transferValue = $65,000 SDG
6. User saves → record stored with transferRate = 650.00
```

### Editing an existing transfer

```
1. User opens existing transfer record
2. Rate field shows the stored rate (if any), or is blank (falling back to global)
3. Hint text shows: "Default: 1 USD = 600 SDG"
4. User can modify or reset
```

### Read-only view

When `readOnly = true` (e.g., viewing a past record):
- Show the rate as informative text: "Rate: 1 USD = 650.00 SDG"

## 9. Testing

### Unit Tests

| Test | File |
|------|------|
| Record serialization includes `transferRate` | `test/models/record.dart` |
| `transferRate` null round-trips correctly | `test/models/record.dart` |
| `RecurrentRecordPattern.fromRecord()` copies `transferRate` | `test/recurrent_pattern_edit_test.dart` |
| `_recalculateTransferValue()` uses custom rate when set | New test in `test/records/` |
| `convertAmount()` unchanged (still uses global) | Existing tests |

### Widget Tests

| Test | File |
|------|------|
| Rate row appears when wallets have different currencies | New widget test |
| Rate row hidden when same currency | New widget test |
| Rate row hidden when no destination wallet | New widget test |
| Custom rate persists through save/load | Integration test |

### Migration Test

| Test | File |
|------|------|
| Database migration v26→v27 adds column without data loss | `test/test_database.dart` |

## 10. Implementation Order

1. **Model layer:** Add `transferRate` to `Record` and `RecurrentRecordPattern`
2. **Database layer:** Migration v27 + update INSERT statements
3. **Helper layer:** Add `formatTransferRateDisplay()`
4. **UI layer:** Create `TransferRateRow` widget
5. **Business logic:** Update `_recalculateTransferValue()` and `_appendTransferNoteToDescription()`
6. **Integration:** Wire up the UI in `edit-record-page.dart`
7. **I18n:** Add/update translation strings
8. **Tests:** Update existing + add new tests
9. **Verify:** Manual test of the full flow
