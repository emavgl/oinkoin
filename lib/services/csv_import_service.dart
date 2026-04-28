import 'dart:math';

import 'package:csv/csv.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/csv_import_mapping.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/wallet.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/database/exceptions.dart';
import 'package:piggybank/services/logger.dart';
import 'package:piggybank/services/service-config.dart';

/// Result of a CSV import operation.
class CsvImportResult {
  final int imported;
  final int skippedDuplicates;
  final int skippedErrors;
  final int totalRows;

  const CsvImportResult({
    required this.imported,
    required this.skippedDuplicates,
    required this.skippedErrors,
    required this.totalRows,
  });

  bool get isSuccess => imported > 0;
}

/// Preview generated from a CSV before import.
class CsvImportPreview {
  final Record? sampleRecord;
  final Map<String, String>? sampleCsvRow;
  final int totalParsableRows;
  final int unparseableRows;
  final List<String> uniqueCategories;
  final List<String> uniqueTags;
  final List<String> uniqueWallets;
  final DateTime? earliestDate;
  final DateTime? latestDate;
  final List<String> warnings;

  const CsvImportPreview({
    this.sampleRecord,
    this.sampleCsvRow,
    required this.totalParsableRows,
    required this.unparseableRows,
    required this.uniqueCategories,
    required this.uniqueTags,
    this.uniqueWallets = const [],
    this.earliestDate,
    this.latestDate,
    this.warnings = const [],
  });
}

/// Result of parsing a CSV string.
class CsvParseResult {
  final List<String> headers;
  final List<Map<String, String>> rows;

  const CsvParseResult(this.headers, this.rows);
}

/// Service for parsing, mapping, and importing records from CSV data.
///
/// Mirrors the behaviour of `scripts/oinkoin_from_csv_importer.py` but imports
/// directly into the database using the same duplicate-handling logic as
/// [BackupService.importDataFromBackupFile].
class CsvImportService {
  static final _logger = Logger.withClass(CsvImportService);

  /// Supported date formats for parsing (ordered by likelihood).
  static const _dateFormats = [
    'yyyy-MM-dd HH:mm:ss',
    'dd/MM/yyyy HH:mm:ss',
    'MM/dd/yyyy HH:mm:ss',
    'dd-MM-yyyy HH:mm:ss',
    'dd.MM.yyyy HH:mm:ss',
    'yyyy/MM/dd HH:mm:ss',
    'yyyy-MM-dd',
    'dd/MM/yyyy',
    'MM/dd/yyyy',
    'dd-MM-yyyy',
    'dd.MM.yyyy',
    'yyyy/MM/dd',
    'yyyyMMdd',
  ];

  // ---------------------------------------------------------------------------
  // Parsing
  // ---------------------------------------------------------------------------

  /// Parses raw CSV content into a [CsvParseResult] with header names and row maps.
  ///
  /// The [content] is assumed to be UTF-8 with an optional BOM prefix.
  /// Each row is a `Map<String, String>` keyed by the (trimmed) header name.
  static CsvParseResult parseCsv(String content) {
    _logger.debug('Parsing CSV content (${content.length} chars)');

    // Strip optional BOM
    if (content.startsWith('\uFEFF')) {
      content = content.substring(1);
    }

    // Auto-detect delimiter from first 4096 chars
    final sniffSample = content.length > 4096 ? content.substring(0, 4096) : content;
    final delimiter = _detectDelimiter(sniffSample);

    final converter = CsvToListConverter(
      fieldDelimiter: delimiter,
      eol: '\n',
      shouldParseNumbers: false,
    );
    final List<List<dynamic>> raw = converter.convert(content);

    if (raw.isEmpty) {
      _logger.warning('CSV parsing produced 0 rows');
      return CsvParseResult([], []);
    }

    // Normalise headers — trim whitespace, use original case
    final headers = raw.first
        .map((h) => h.toString().trim())
        .where((h) => h.isNotEmpty)
        .toList();

    if (headers.isEmpty) {
      return CsvParseResult(headers, []);
    }

    final rows = <Map<String, String>>[];
    for (int i = 1; i < raw.length; i++) {
      final row = raw[i];
      if (row.every((cell) => cell.toString().trim().isEmpty)) {
        continue; // skip completely empty rows
      }
      final map = <String, String>{};
      for (int j = 0; j < headers.length; j++) {
        map[headers[j]] = j < row.length ? row[j].toString().trim() : '';
      }
      rows.add(map);
    }

    _logger.info('Parsed ${rows.length} rows with ${headers.length} columns (delimiter: "${delimiter}")');
    return CsvParseResult(headers, rows);
  }

  /// Heuristically detects the CSV delimiter from a sample.
  static String _detectDelimiter(String sample) {
    // Count occurrences of common delimiters
    final counts = <String, int>{
      ',': 0,
      ';': 0,
      '\t': 0,
    };
    for (final char in sample.split('')) {
      if (counts.containsKey(char)) {
        counts[char] = counts[char]! + 1;
      }
    }
    // Return the delimiter with the highest count, default to comma
    final best = counts.entries.reduce((a, b) => a.value > b.value ? a : b);
    return best.value > 0 ? best.key : ',';
  }

  // ---------------------------------------------------------------------------
  // Auto-mapping
  // ---------------------------------------------------------------------------

  /// Automatically maps CSV columns to Oinkoin fields using heuristics
  /// matching the Python script's logic.
  static CsvImportMapping autoMap(List<String> headers) {
    final lower = headers.map((h) => h.toLowerCase()).toList();

    String? findExact(List<String> candidates) {
      for (final c in candidates) {
        final idx = lower.indexOf(c);
        if (idx != -1) return headers[idx];
      }
      return null;
    }

    String? findContaining(List<String> candidates) {
      for (int i = 0; i < lower.length; i++) {
        for (final c in candidates) {
          if (lower[i].contains(c)) return headers[i];
        }
      }
      return null;
    }

    return CsvImportMapping(
      titleColumn: findExact(['title', 'name']),
      valueColumn: findContaining(['money', 'amount', 'value']),
      datetimeColumn: findContaining(['date', 'time', 'timestamp']),
      categoryColumn: findExact(['category', 'categoria']),
      descriptionColumn: findContaining(['description', 'note', 'memo']),
      tagsColumn: findContaining(['tags', 'tag', 'labels']),
      walletColumn: findContaining(['wallet', 'account']),
    );
  }

  // ---------------------------------------------------------------------------
  // Value parsing
  // ---------------------------------------------------------------------------

  /// Parses a monetary string value into a double.
  ///
  /// Handles currency symbols, thousand separators, and locale-aware decimal
  /// separators (period vs comma) by detecting which format the string uses.
  static double? parseMoney(String? value) {
    if (value == null) return null;
    final valStr = value.trim();
    if (valStr.isEmpty) return null;

    // Handle negative values in parentheses e.g. "(50.00)" — check BEFORE stripping
    if (valStr.startsWith('(') && valStr.endsWith(')')) {
      final inner = valStr.substring(1, valStr.length - 1).trim();
      final innerClean = inner.replaceAll(RegExp(r'[^\d,.\-]'), '');
      if (innerClean.isNotEmpty) {
        final parsed = parseMoney('-$innerClean');
        return parsed;
      }
      return null;
    }

    // Strip everything except digits, comma, period, and leading minus
    var clean = valStr.replaceAll(RegExp(r'[^\d,.\-]'), '');

    if (clean.isEmpty) return null;

    // Determine which is the decimal separator:
    // If both comma and period present, the one that appears last is decimal.
    if (clean.contains(',') && clean.contains('.')) {
      final lastComma = clean.lastIndexOf(',');
      final lastDot = clean.lastIndexOf('.');
      if (lastDot > lastComma) {
        // period is decimal → strip commas (thousands)
        clean = clean.replaceAll(',', '');
      } else {
        // comma is decimal → strip periods (thousands)
        clean = clean.replaceAll('.', '').replaceAll(',', '.');
      }
    } else if (clean.contains(',')) {
      // Only comma present
      // If it's at position -3 (e.g. "100,00"), treat as decimal
      if (clean.length - clean.lastIndexOf(',') <= 3 &&
          clean.indexOf(',') == clean.lastIndexOf(',')) {
        clean = clean.replaceAll(',', '.');
      } else {
        // Otherwise treat as thousands separator and remove
        clean = clean.replaceAll(',', '');
      }
    }
    // If only period present, it's already the decimal separator

    try {
      return double.parse(clean);
    } catch (_) {
      return null;
    }
  }

  /// Parses a date/time string into UTC milliseconds-since-epoch.
  ///
  /// Supports ISO 8601, common slash/dash/dot date formats, Unix timestamps
  /// in seconds and milliseconds.
  static int? parseToMs(String? value) {
    if (value == null) return null;
    final valStr = value.trim();
    if (valStr.isEmpty) return null;

    // Try explicit date formats first (before plain number)
    for (final fmt in _dateFormats) {
      final parsed = _tryParseFormat(valStr, fmt);
      if (parsed != null) return parsed;
    }

    // Try plain number (Unix timestamp) after named formats
    final numVal = double.tryParse(valStr);
    if (numVal != null) {
      if (numVal < 10000000000) {
        // Seconds → milliseconds
        return (numVal * 1000).round();
      } else {
        // Already milliseconds
        return numVal.round();
      }
    }

    // Try ISO 8601
    final dt = DateTime.tryParse(valStr);
    if (dt != null) {
      // Interpret as local time in the user's timezone, then convert to UTC
      final location = tz.getLocation(ServiceConfig.localTimezone);
      final local = tz.TZDateTime(
        location,
        dt.year, dt.month, dt.day,
        dt.hour, dt.minute, dt.second, dt.millisecond,
      );
      return local.toUtc().millisecondsSinceEpoch;
    }

    return null;
  }

  /// Splits a date string according to format character positions.
  /// For example, format 'yyyyMMdd' splits '20240115' into [2024, 01, 15].
  static List<String> _splitByFormat(String dateStr, String format) {
    // Count consecutive identical format chars
    final groups = <_FmtGroup>[];
    int i = 0;
    while (i < format.length) {
      final char = format[i];
      int j = i;
      while (j < format.length && format[j] == char) j++;
      groups.add(_FmtGroup(char, j - i));
      i = j;
    }
    final result = <String>[];
    int pos = 0;
    for (final g in groups) {
      final len = g.len.clamp(0, dateStr.length - pos);
      result.add(dateStr.substring(pos, pos + len));
      pos += len;
    }
    return result;
  }

  /// Attempts to parse [value] according to [format] and returns milliseconds
  /// since epoch, or null on failure.
  static int? _tryParseFormat(String value, String format) {
    try {
      final parts = _splitDateTime(value);
      final dateStr = parts[0];
      final timeStr = parts.length > 1 ? parts[1] : '00:00:00';

      final dateParts = _splitDate(dateStr, format);
      if (dateParts == null) return null;

      final timeParts = timeStr.split(':');
      final hour = timeParts.isNotEmpty ? int.tryParse(timeParts[0]) ?? 0 : 0;
      final minute = timeParts.length > 1 ? int.tryParse(timeParts[1]) ?? 0 : 0;
      final second = timeParts.length > 2 ? int.tryParse(timeParts[2]) ?? 0 : 0;

      // Interpret as local time in the user's timezone, then convert to UTC
      final location = tz.getLocation(ServiceConfig.localTimezone);
      final dt = tz.TZDateTime(
        location,
        dateParts[0],
        dateParts[1],
        dateParts[2],
        hour,
        minute,
        second,
      ).toUtc();
      return dt.millisecondsSinceEpoch;
    } catch (_) {
      return null;
    }
  }

  static List<String> _splitDateTime(String value) {
    // Split on space or 'T'
    final tIdx = value.indexOf('T');
    if (tIdx != -1) {
      return [value.substring(0, tIdx), value.substring(tIdx + 1)];
    }
    return value.split(' ');
  }

  static List<int>? _splitDate(String dateStr, String format) {
    // Determine order from format string
    final yIdx = format.indexOf('y');
    final mIdx = format.indexOf('M');
    final dIdx = format.indexOf('d');

    if (yIdx == -1 || mIdx == -1 || dIdx == -1) return null;

    // Try splitting by common separators first
    var parts = dateStr.split(RegExp(r'[/\-.]'));

    // If no separators found in the date string AND the format has no
    // separators (e.g., yyyyMMdd), split by format group lengths.
    if (parts.length == 1 && dateStr.length >= 6) {
      final formatHasOnlyAlpha = !format.contains(RegExp(r'[^a-zA-Z]'));
      if (formatHasOnlyAlpha) {
        parts = _splitByFormat(dateStr, format);
      }
    }

    if (parts.length < 3) return null;

    // Build order list: (index, type)
    final orderIndices = <int>[yIdx, mIdx, dIdx];
    final orderTypes = <String>['y', 'm', 'd'];
    // Sort by index (simple bubble sort for 3 elements)
    for (int i = 0; i < 2; i++) {
      for (int j = i + 1; j < 3; j++) {
        if (orderIndices[i] > orderIndices[j]) {
          final tmpIdx = orderIndices[i];
          orderIndices[i] = orderIndices[j];
          orderIndices[j] = tmpIdx;
          final tmpType = orderTypes[i];
          orderTypes[i] = orderTypes[j];
          orderTypes[j] = tmpType;
        }
      }
    }

    int year = 0, month = 0, day = 0;
    for (int i = 0; i < 3 && i < parts.length; i++) {
      final val = int.tryParse(parts[i]);
      if (val == null) return null;
      switch (orderTypes[i]) {
        case 'y':
          year = val >= 100 ? val : 2000 + val;
          break;
        case 'm':
          month = val;
          break;
        case 'd':
          day = val;
          break;
      }
    }

    if (year < 1 || month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }

    return [year, month, day];
  }

  // ---------------------------------------------------------------------------
  // Preview
  // ---------------------------------------------------------------------------

  /// Builds a preview from the parsed CSV and mapping.
  static CsvImportPreview buildPreview(
    List<Map<String, String>> rows,
    CsvImportMapping mapping,
  ) {
    int parsable = 0;
    int unparseable = 0;
    final categories = <String>{};
    final tags = <String>{};
    final wallets = <String>{};
    int? earliestMs;
    int? latestMs;

    Record? sampleRecord;
    Map<String, String>? sampleCsvRow;

    for (final row in rows) {
      final value = parseMoney(row[mapping.valueColumn]);
      final dateMs = parseToMs(row[mapping.datetimeColumn]);
      final cat = row[mapping.categoryColumn] ?? 'Uncategorized';

      if (value != null && dateMs != null) {
        parsable++;
        categories.add(cat);

        if (earliestMs == null || dateMs < earliestMs) earliestMs = dateMs;
        if (latestMs == null || dateMs > latestMs) latestMs = dateMs;

        if (mapping.tagsColumn != null) {
          final raw = row[mapping.tagsColumn];
          if (raw != null && raw.isNotEmpty) {
            for (final t in _splitTags(raw)) {
              tags.add(t);
            }
          }
        }

        if (mapping.walletColumn != null) {
          final w = row[mapping.walletColumn];
          if (w != null && w.trim().isNotEmpty) {
            wallets.add(w.trim());
          }
        }

        // Keep first parsable row as sample
        sampleCsvRow ??= Map.from(row);
        if (sampleRecord == null) {
          sampleRecord = _rowToRecord(row, mapping);
        }
      } else {
        unparseable++;
      }
    }

    final warnings = <String>[];
    if (!mapping.hasMinimumMapping) {
      warnings.add('Amount and Date/Time columns must be mapped for records to be imported.');
    }
    if (unparseable > 0) {
      warnings.add('$unparseable row(s) could not be parsed and will be skipped.');
    }
    if (parsable == 0) {
      warnings.add('No records can be imported with the current mapping.');
    }

    return CsvImportPreview(
      sampleRecord: sampleRecord,
      sampleCsvRow: sampleCsvRow,
      totalParsableRows: parsable,
      unparseableRows: unparseable,
      uniqueCategories: categories.toList()..sort(),
      uniqueTags: tags.toList()..sort(),
      uniqueWallets: wallets.toList()..sort(),
      earliestDate: earliestMs != null
          ? DateTime.fromMillisecondsSinceEpoch(earliestMs, isUtc: true)
          : null,
      latestDate: latestMs != null
          ? DateTime.fromMillisecondsSinceEpoch(latestMs, isUtc: true)
          : null,
      warnings: warnings,
    );
  }

  // ---------------------------------------------------------------------------
  // Import
  // ---------------------------------------------------------------------------

  /// Imports records from the parsed CSV rows into the database.
  ///
  /// Uses the same duplicate-handling as [BackupService.importDataFromBackupFile]:
  ///  - Categories are inserted with [ElementAlreadyExists] catch.
  ///  - Records use [DatabaseInterface.addRecordsInBatch] which skips
  ///    duplicates via `INSERT OR IGNORE`.
  ///  - Tags are inserted after records are committed.
  static Future<CsvImportResult> importRecords(
    List<Map<String, String>> rows,
    CsvImportMapping mapping, {
    DatabaseInterface? database,
  }) async {
    final db = database ?? ServiceConfig.database;
    _logger.info('Starting CSV import: ${rows.length} rows');

    // 1. Collect unique categories
    final categoryMap = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final val = parseMoney(row[mapping.valueColumn]);
      if (val == null) continue;
      final dateMs = parseToMs(row[mapping.datetimeColumn]);
      if (dateMs == null) continue;

      final catName = row[mapping.categoryColumn] ?? 'Uncategorized';
      final catType = val < 0 ? CategoryType.expense : CategoryType.income;
      final catKey = '$catName|${catType.index}';

      if (!categoryMap.containsKey(catKey)) {
        final color = _randomColor();
        categoryMap[catKey] = {
          'name': catName,
          'category_type': catType.index,
          'last_used': dateMs,
          'record_count': 0,
          'color': color,
          'is_archived': 0,
          'sort_order': categoryMap.length,
          'icon': 63, // default question mark icon
        };
      }
    }

    // 2. Insert categories (skip duplicates)
    int categoriesInserted = 0;
    for (final entry in categoryMap.entries) {
      final cat = Category(
        entry.value['name'],
        categoryType: CategoryType.values[entry.value['category_type']],
      );
      cat.lastUsed =
          DateTime.fromMillisecondsSinceEpoch(entry.value['last_used'], isUtc: true);
      try {
        await db.addCategory(cat);
        categoriesInserted++;
      } catch (e) {
        if (e is ElementAlreadyExists) {
          // already exists — skip silently
        } else {
          _logger.warning('Failed to insert category "${cat.name}": $e');
        }
      }
    }
    _logger.info('Categories: $categoriesInserted new / ${categoryMap.length - categoriesInserted} existing');

    // 3. Build records (only parsable rows)
    final records = <Record>[];
    int skippedErrors = 0;

    // Resolve wallets lazily — cache by name to avoid repeated DB calls
    final walletCache = <String, Wallet>{};
    final defaultWallet = await db.getDefaultWallet();

    for (final row in rows) {
      final value = parseMoney(row[mapping.valueColumn]);
      final dateMs = parseToMs(row[mapping.datetimeColumn]);

      if (value == null || dateMs == null) {
        skippedErrors++;
        continue;
      }

      int? walletId;
      if (mapping.walletColumn != null) {
        final walletName = row[mapping.walletColumn]?.trim() ?? '';
        if (walletName.isNotEmpty) {
          if (!walletCache.containsKey(walletName)) {
            walletCache[walletName] =
                await _getOrCreateWallet(walletName, db);
          }
          walletId = walletCache[walletName]!.id;
        }
      }
      walletId ??= defaultWallet?.id;

      final record = _rowToRecord(row, mapping, walletId: walletId);
      records.add(record);
    }

    final totalBeforeBatch = records.length;

    // 4. Insert records in batch (duplicate detection via INSERT OR IGNORE)
    await db.addRecordsInBatch(records);

    // 5. Count how many were actually inserted
    // (We can't easily tell from addRecordsInBatch which were ignored,
    //  so we estimate based on the total. The batch itself handles dedup.)
    final allRecordsAfter = await db.getAllRecords();
    _logger.info(
      'Import complete: ~$totalBeforeBatch records processed, '
      '${skippedErrors} skipped (parse errors), '
      'total records in DB now: ${allRecordsAfter.length}',
    );

    return CsvImportResult(
      imported: totalBeforeBatch,
      skippedDuplicates: 0, // exact count not available from batch
      skippedErrors: skippedErrors,
      totalRows: rows.length,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Converts a parsed CSV row to a [Record] using the given mapping.
  static Record _rowToRecord(
    Map<String, String> row,
    CsvImportMapping mapping, {
    int? walletId,
  }) {
    final value = parseMoney(row[mapping.valueColumn]) ?? 0.0;
    final dateMs = parseToMs(row[mapping.datetimeColumn]) ??
        DateTime.now().toUtc().millisecondsSinceEpoch;
    final utcDateTime = DateTime.fromMillisecondsSinceEpoch(dateMs, isUtc: true);
    final catName = row[mapping.categoryColumn] ?? 'Uncategorized';
    final catType = value < 0 ? CategoryType.expense : CategoryType.income;

    final category = Category(catName, categoryType: catType);
    final tags = _splitTags(row[mapping.tagsColumn]);

    return Record(
      value,
      row[mapping.titleColumn] ?? '',
      category,
      utcDateTime,
      description: row[mapping.descriptionColumn],
      timeZoneName: ServiceConfig.localTimezone,
      walletId: walletId,
      tags: tags.toSet(),
    );
  }

  /// Splits a raw tags string by semicolon or comma.
  static List<String> _splitTags(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    return raw
        .split(RegExp(r'[;,]'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  /// Generates a random category color matching `scripts/oinkoin_from_csv_importer.py`.
  static String _randomColor() {
    final rng = Random();
    return '255:${rng.nextInt(205) + 50}:${rng.nextInt(205) + 50}:${rng.nextInt(205) + 50}';
  }

  /// Returns an existing wallet by name (case-insensitive), or creates a new
  /// one in the current profile. New wallets are not marked as default.
  static Future<Wallet> _getOrCreateWallet(
    String walletName,
    DatabaseInterface db,
  ) async {
    final trimmed = walletName.trim();
    if (trimmed.isEmpty) {
      final defaultWallet = await db.getDefaultWallet();
      return defaultWallet!;
    }

    // Look up by name (case-insensitive) in the current profile
    Wallet? existing;
    try {
      existing = await db.getWalletByName(trimmed, null);
    } catch (_) {
      // getWalletByName may throw on some implementations; fall through
    }

    if (existing != null) return existing;

    // Create a new wallet
    final wallet = Wallet(trimmed, initialAmount: 0);
    final newId = await db.addWallet(wallet);
    final created = await db.getWalletById(newId);
    return created!;
  }
}

/// Internal helper for splitting date strings by format groups.
class _FmtGroup {
  final String char;
  final int len;
  const _FmtGroup(this.char, this.len);
}
