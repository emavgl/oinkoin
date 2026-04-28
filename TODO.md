# CSV Import — Implementation TODO

- [x] Create `CsvImportMapping` model
- [x] Create `CsvImportService` (parsing, auto-mapping, money/date parsing, import)
- [x] Create `CsvImportPage` (file/clipboard input screen)
- [x] Create `CsvMappingScreen` (column mapping UI with live preview)
- [x] Create `CsvImportSummaryScreen` (summary & confirm import)
- [x] Wire "Import from CSV" into Settings page (Pro-gated)
- [x] Add i18n keys to `en-US.json`
- [x] Run `update_en_strings.py` to sync locales
- [x] Update `_automated_translation.json` with context for new keys
- [x] Write `csv_import_service_test.dart` (55 unit tests)
- [x] Write `csv_import_integration_test.dart` (14 integration tests)
- [ ] Manual QA with real CSV files
