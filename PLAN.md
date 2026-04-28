# CSV Import Feature — Implementation Plan

## Overview

Add a **CSV Import** feature to the app, accessible from the Settings tab for Pro users only. The user provides a CSV file (from disk or clipboard), the app parses it, auto-maps columns to record fields, lets the user adjust the mapping interactively with a live preview, and then imports the records directly into the database — using the same duplicate-handling logic already used by backup restore.

This mirrors the behavior of `scripts/oinkoin_from_csv_importer.py` but as a first-class Flutter UI in the app, with direct DB insertion instead of JSON file generation.

---

## 1. Architecture & File Layout

```
lib/
  services/
    csv_import_service.dart          # NEW — parsing, auto-mapping, duplicate-safe import
  settings/
    csv_import/
      csv_import_page.dart           # NEW — main page: file/clipboard input → mapping → summary → import
      csv_mapping_screen.dart        # NEW — mapping UI (column pickers + live preview)
      csv_import_summary_screen.dart # NEW — summary before import
  models/
    csv_import_mapping.dart          # NEW — data class for the field→column mapping
test/
  csv_import_service_test.dart       # NEW — unit tests for CsvImportService
  csv_import_mapping_test.dart       # NEW — mapping logic tests
  csv_import_integration_test.dart   # NEW — integration test (parse CSV → DB insert → verify)
```

---

## 2. Data Model: `CsvImportMapping`

```dart
class CsvImportMapping {
  String? titleColumn;       // CSV header name for record title
  String? valueColumn;       // CSV header name for amount
  String? datetimeColumn;    // CSV header name for date/time
  String? categoryColumn;    // CSV header name for category name
  String? descriptionColumn; // CSV header name for description/notes
  String? tagsColumn;        // CSV header name for tags (semicolon or comma separated)
}
```

Supports JSON serialization (for potential future save/restore of user mappings).

---

## 3. Service: `CsvImportService`

### 3.1 Parsing (`parseCsv`)
- Input: `String csvContent` (from file or clipboard)
- Auto-detect delimiter (comma, semicolon, tab) via `csv` package Sniffer
- Parse with `CsvToListConverter` or `csv.DictReader` equivalent
- Return: `List<String> headers` + `List<Map<String, String>> rows`

### 3.2 Auto-mapping (`autoMap`)
- Input: `List<String> headers`
- Apply same heuristics as the Python script:
  - `title` → header matching "title", "name" (case-insensitive, exact)
  - `value` → header containing "money", "amount", "value"
  - `datetime` → header containing "date", "time", "timestamp"
  - `category_name` → header matching "category", "categoria" (case-insensitive, exact)
  - `description` → header containing "description", "note", "memo"
  - `tags` → header containing "tags", "tag", "labels"
- Return `CsvImportMapping` with nullable strings (null when no match found)

### 3.3 Value parsing
- `parseMoney(String? value)` → `double?`
  - Strip currency symbols, handle both `.` and `,` as decimal separators
- `parseDateTime(String? value)` → `DateTime?`
  - Support ISO 8601, common date formats (dd/MM/yyyy, MM/dd/yyyy, dd-MM-yyyy, etc.)
  - Support Unix timestamps (seconds and milliseconds)
- Mirror the Python `parse_to_ms` and `parse_money` logic closely

### 3.4 Preview generation (`generatePreview`)
- Input: `CsvImportMapping`, sample row, list of all rows
- Return a `CsvImportPreview` containing:
  - Sample parsed record (Record object, not yet inserted)
  - Statistics: total parsable rows, unique categories, date range, unique tags
  - Warnings: rows with unparseable values or dates (count)

### 3.5 Import (`importRecords`)
This is the core method that mirrors `BackupService.importDataFromBackupFile` for records/categories/tags only (no wallets, profiles, recurrent patterns).

- Input: `CsvImportMapping`, `List<Map<String, String>> rows`
- Steps:
  1. **Build categories map**: iterate rows, extract unique `(category_name, category_type)` pairs. Category type = expense (0) if value < 0, income (1) if value >= 0.
  2. **Insert categories** (same as backup restore):
     ```dart
     for (var cat in categories) {
       try {
         await database.addCategory(cat);
       } on ElementAlreadyExists {
         // skip — category already exists
       }
     }
     ```
  3. **Build records**: parse each row into a `Record` object. Assign:
     - `walletId` → current predefined wallet (or default wallet)
     - `profileId` → current active profile
     - `timeZoneName` → `ServiceConfig.localTimezone`
     - `tags` → parsed from tags column (split by `;` or `,`)
  4. **Insert records in batch**: use `database.addRecordsInBatch(records)` — this already has duplicate detection:
     ```sql
     INSERT OR IGNORE ... WHERE NOT EXISTS (
       SELECT 1 FROM records
       WHERE datetime = ? AND value = ? AND title IS ? 
         AND category_name = ? AND category_type = ?
         AND wallet_id IS ? AND (profile_id IS NULL OR profile_id = ?)
     )
     ```
  5. **Insert tags**: after batch commit, query each inserted record's ID and insert its tags (same as `addRecordsInBatch` Phase 2).
  6. Return `CsvImportResult` with counts: imported, skipped (duplicates), errors.

### 3.6 Clipboard support
- `parseFromClipboard()` — get clipboard text via `Clipboard.getData(Clipboard.kTextPlain)`, delegate to `parseCsv`.

---

## 4. UI Flow

### 4.1 Entry Point: Settings Page

Add a new `SettingsItem` in `lib/settings/settings-page.dart`, placed after "Restore Backup":

```dart
Stack(
  children: [
    SettingsItem(
      icon: Icon(Icons.file_upload, color: Colors.white),
      iconBackgroundColor: Colors.indigo.shade600,
      title: 'Import from CSV'.i18n,
      subtitle: "Import records from a CSV file or clipboard".i18n,
      onPressed: ServiceConfig.isPremium
          ? () async => await Navigator.push(context, 
              MaterialPageRoute(builder: (_) => CsvImportPage()))
          : () async => await Navigator.push(context, 
              MaterialPageRoute(builder: (_) => PremiumSplashScreen())),
    ),
    if (!ServiceConfig.isPremium)
      Container(
        margin: EdgeInsets.fromLTRB(8, 8, 0, 0),
        child: getProLabel(labelFontSize: 10.0),
      ),
  ],
),
```

### 4.2 Page 1: `CsvImportPage` — File/Clipboard Input

```
┌─────────────────────────────────────────┐
│  AppBar: "Import from CSV"              │
├─────────────────────────────────────────┤
│                                         │
│   📄  [Select CSV File]                 │
│                                         │
│   ── OR ──                              │
│                                         │
│   📋  [Paste from Clipboard]            │
│         (shows preview of first 3 rows) │
│                                         │
│   ⚠️  If no CSV in clipboard:           │
│       "Clipboard does not contain       │
│        valid CSV data"                  │
│                                         │
│   After file/clipboard loaded:          │
│   ┌─────────────────────────────────┐   │
│   │ CSV Preview (first 5 rows)      │   │
│   │ Header: title | value | date... │   │
│   │ Row 1:  ...                     │   │
│   │ Row 2:  ...                     │   │
│   └─────────────────────────────────┘   │
│                                         │
│   [Continue to Mapping]  (→ next page)  │
│                                         │
└─────────────────────────────────────────┘
```

States:
- **Initial**: Two buttons + clipboard paste area
- **Loading**: Spinner while parsing
- **Error**: "Could not parse CSV — check format and encoding"
- **Loaded**: Preview + Continue button

### 4.3 Page 2: `CsvMappingScreen` — Column Mapping

```
┌─────────────────────────────────────────┐
│  AppBar: "Map Columns"                  │
├─────────────────────────────────────────┤
│                                         │
│  Field          → CSV Column            │
│  ───────────────────────────────────    │
│  Title          → [title        ▼]      │
│  Amount         → [amount       ▼]      │
│  Date/Time      → [date         ▼]      │
│  Category       → [category     ▼]      │
│  Description    → [None         ▼]      │
│  Tags           → [None         ▼]      │
│                                         │
│  Each dropdown shows all CSV headers    │
│  + "None" option. Auto-mapped by        │
│  name heuristics on page load.          │
│                                         │
├─────────────────────────────────────────┤
│  LIVE PREVIEW                           │
│  ┌─────────────────────────────────┐   │
│  │ Original CSV Row:               │   │
│  │   title: "Grocery shopping"     │   │
│  │   amount: "-45.50"              │   │
│  │   date: "2024-01-15"            │   │
│  │   ...                           │   │
│  │                                 │   │
│  │ → Imported Record:              │   │
│  │   Title: "Grocery shopping"     │   │
│  │   Value: -45.50                 │   │
│  │   Date: 2024-01-15 00:00:00     │   │
│  │   Category: Uncategorized       │   │
│  │   Tags: []                      │   │
│  └─────────────────────────────────┘   │
│                                         │
│  [← Back]           [Continue →]       │
│                                         │
└─────────────────────────────────────────┘
```

- Each mapping change instantly updates the live preview.
- "None" means the field will be null/empty in imported records.
- Amount and Date/Time are required (at minimum); show validation warning if unmapped.

### 4.4 Page 3: `CsvImportSummaryScreen` — Summary & Confirm

```
┌─────────────────────────────────────────┐
│  AppBar: "Import Summary"               │
├─────────────────────────────────────────┤
│                                         │
│   📊 Import Summary                     │
│                                         │
│   ✅ Records to import:    142          │
│   ⚠️  Unparseable rows:     3           │
│   📂 Unique categories:     8           │
│   🏷️  Unique tags:          12          │
│   📅 Date range:            2024-01-01  │
│                             to          │
│                             2024-12-31  │
│                                         │
│   ⚠️ Warnings:                          │
│   • 3 rows have unparseable dates       │
│   • 5 rows have missing amounts         │
│                                         │
│   These rows will be skipped.           │
│                                         │
│   Duplicate records (same datetime,     │
│   value, title, category, wallet)       │
│   will be skipped automatically.        │
│                                         │
│   [← Back to Mapping]   [Import →]     │
│                                         │
└─────────────────────────────────────────┘
```

After import:
```
┌─────────────────────────────────────────┐
│  ✅ Import Complete                     │
│                                         │
│   Imported: 139 records                 │
│   Skipped (duplicates): 0               │
│   Skipped (errors): 3                   │
│                                         │
│   [Done]  → pops back to Settings       │
└─────────────────────────────────────────┘
```

---

## 5. Duplicate Handling (Mirrors Backup Restore)

The `addRecordsInBatch` method already implements duplicate detection:

```sql
INSERT OR IGNORE INTO records (...)
SELECT ... WHERE NOT EXISTS (
  SELECT 1 FROM records
  WHERE datetime = ?
    AND value = ?
    AND title IS ?
    AND category_name = ?
    AND category_type = ?
    AND wallet_id IS ?
    AND (profile_id IS NULL OR profile_id = ?)
)
```

This means:
- A record is considered duplicate if it has the **same** datetime, value, title, category, wallet, and profile.
- Duplicates are silently skipped (`INSERT OR IGNORE`).
- We do NOT need to implement new deduplication logic — just reuse the existing `addRecordsInBatch`.

For categories, the same pattern applies:
```dart
try {
  await database.addCategory(cat);
} on ElementAlreadyExists {
  // skip — already present
}
```

---

## 6. New i18n Keys Required

Add to `assets/locales/en-US.json`:
```json
"Import from CSV": "Import from CSV",
"Import records from a CSV file or clipboard": "Import records from a CSV file or clipboard",
"Select CSV File": "Select CSV File",
"Paste from Clipboard": "Paste from Clipboard",
"Clipboard is empty or does not contain valid CSV": "Clipboard is empty or does not contain valid CSV",
"Could not parse CSV": "Could not parse CSV",
"Map Columns": "Map Columns",
"Live Preview": "Live Preview",
"Original CSV Row": "Original CSV Row",
"Imported Record": "Imported Record",
"No column mapped": "No column mapped",
"Title column": "Title column",
"Amount column": "Amount column",
"Date column": "Date column",
"Category column": "Category column",
"Description column": "Description column",
"Tags column": "Tags column",
"Import Summary": "Import Summary",
"Records to import": "Records to import",
"Unparseable rows": "Unparseable rows",
"Unique categories": "Unique categories",
"Unique tags": "Unique tags",
"Date range": "Date range",
"Records imported": "Records imported",
"Skipped (duplicates)": "Skipped (duplicates)",
"Skipped (errors)": "Skipped (errors)",
"Import Complete": "Import Complete",
"Import Failed": "Import Failed",
"Import": "Import",
"Continue to Mapping": "Continue to Mapping",
"None": "None"
```

---

## 7. Testing Plan

### 7.1 `csv_import_service_test.dart` (Unit Tests)

Test `CsvImportService` methods in isolation (no DB):

| Test | Description |
|------|-------------|
| `parseCsv with comma delimiter` | Basic CSV parsing, returns headers + rows |
| `parseCsv with semicolon delimiter` | Handles European-style CSV |
| `parseCsv with tab delimiter` | Handles TSV files |
| `parseCsv with BOM` | Handles UTF-8 BOM |
| `parseCsv with empty file` | Returns empty headers/rows, no crash |
| `parseCsv with single column` | Handles degraded case |
| `autoMap matches exact header names` | "title" → titleColumn, "amount" → valueColumn, etc. |
| `autoMap matches case-insensitive` | "TITLE", "Amount", "Date" all match |
| `autoMap matches partial substrings` | "Transaction Amount" → valueColumn |
| `autoMap returns null for unmatched` | No column matches → field is null |
| `parseMoney handles dollar sign` | "$1,234.56" → 1234.56 |
| `parseMoney handles euro suffix` | "1.234,56 €" → 1234.56 |
| `parseMoney handles negative parenthesized` | "(50.00)" → -50.00 |
| `parseMoney handles plain number` | "42" → 42.0 |
| `parseMoney returns null for garbage` | "abc" → null |
| `parseDateTime handles ISO 8601` | "2024-01-15T10:30:00" → correct DateTime |
| `parseDateTime handles dd/MM/yyyy` | "15/01/2024" → correct DateTime |
| `parseDateTime handles MM/dd/yyyy` | "01/15/2024" → correct DateTime |
| `parseDateTime handles unix ms timestamp` | "1705312200000" → correct DateTime |
| `parseDateTime handles unix s timestamp` | "1705312200" → correct DateTime |
| `parseDateTime returns null for garbage` | "not a date" → null |
| `generatePreview computes correct stats` | Counts records, unique categories, date range |
| `generatePreview handles all-null mapping` | Doesn't crash when no columns mapped |

### 7.2 `csv_import_integration_test.dart` (Integration Tests with DB)

Uses `TestDatabaseHelper` (in-memory SQLite):

| Test | Description |
|------|-------------|
| `import creates new categories` | CSV with 3 new categories → all are inserted |
| `import skips duplicate categories` | CSV with category that already exists → no error |
| `import inserts records` | Valid CSV → records appear in DB |
| `import skips duplicate records` | Re-import same CSV → 0 new records (INSERT OR IGNORE) |
| `import assigns records to predefined wallet` | All imported records have correct wallet_id |
| `import assigns records to active profile` | Records get correct profile_id |
| `import handles tags` | CSV with tags column → tags inserted via records_tags |
| `import with empty CSV` | 0 rows → 0 records inserted, no crash |
| `import with missing amount column` | Records without value are skipped |
| `import with mixed valid/invalid rows` | Valid rows inserted, invalid skipped |
| `full flow: parse → auto-map → import → verify` | End-to-end test |

---

## 8. Edge Cases & Robustness

### 8.1 Input Edge Cases
- **BOM (byte order mark)**: UTF-8 BOM at file start must be stripped before parsing
- **Mixed delimiters**: Some rows use comma, others semicolon — detect via Sniffer on first N lines
- **Quoted fields**: Fields containing commas/newlines must be handled (CSV package does this)
- **Empty rows**: Trailing empty rows in CSV should be ignored
- **Header-only CSV**: No data rows → show "No data to import" message
- **Very large CSV**: 10k+ rows → parse in background isolate? For MVP, parse on main thread with loading indicator. If performance issues arise, add `compute()` for parsing.

### 8.2 Mapping Edge Cases
- **All fields unmapped**: Warning — "At least Amount and Date must be mapped"
- **Only title mapped**: Records get title only, value=0, datetime=now
- **Category column mapped but value doesn't exist**: Category is created automatically (via `addRecord` which calls `addCategory`)

### 8.3 Import Edge Cases
- **No wallet exists**: Use default wallet (guaranteed to exist via DB migration)
- **No profile**: Use active profile from `ProfileService`
- **Duplicate records across the CSV itself**: Only first occurrence is inserted (INSERT OR IGNORE + identical rows match the WHERE NOT EXISTS)
- **CSV with future dates**: Imported normally — no restriction
- **CSV with transfers**: Not supported in MVP — transfer fields are not mappable

---

## 9. Dependencies

- `csv` package — already in `pubspec.yaml` (used by `CSVExporter`)
- `file_picker` — already in `pubspec.yaml` (used by backup restore)
- `flutter/services.dart` — `Clipboard` API, already available

No new packages needed.

---

## 10. Implementation Order

1. **Create `CsvImportMapping` model** — simple data class
2. **Create `CsvImportService`** — parsing, auto-mapping, money/date parsing, import logic
3. **Write unit tests** — `csv_import_service_test.dart` (all parsing/mapping/money/date tests)
4. **Create UI pages** — `csv_import_page.dart`, `csv_mapping_screen.dart`, `csv_import_summary_screen.dart`
5. **Wire into Settings page** — add `SettingsItem` with Pro gate
6. **Add i18n keys** to `en-US.json`, run `update_en_strings.py`, update `_automated_translation.json`
7. **Write integration tests** — `csv_import_integration_test.dart`
8. **Manual QA** — test with real CSV exports from Oinkoin, bank CSVs, and edge case files

---

## 11. What This Feature Does NOT Do

- **No wallet/profile import** — records are imported into the current active wallet and profile only
- **No recurrent pattern import** — CSV rows become one-time records
- **No transfer support** — `transfer_wallet_id` and `transfer_value` are not mappable
- **No export of mapping presets** — mapping is per-session (future: could save user mappings)
- **No JSON backup file output** — records go directly to the database
- **No undo** — once imported, records can be deleted manually but there's no "undo import" button (same as backup restore)
