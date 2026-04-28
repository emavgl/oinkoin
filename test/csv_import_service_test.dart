import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/csv_import_mapping.dart';
import 'package:piggybank/services/csv_import_service.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;

/// Unit tests for [CsvImportService] — parsing, auto-mapping, money/date
/// parsing, and preview generation. No database required.
void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
    ServiceConfig.localTimezone = 'Etc/UTC';
  });

  group('CsvImportService.parseCsv', () {
    test('parses comma-delimited CSV', () {
      const content = 'title,amount,date\nGrocery,-45.50,2024-01-15\nSalary,3000.00,2024-01-20';
      final parsed = CsvImportService.parseCsv(content);
      final headers = parsed.headers;
      final rows = parsed.rows;

      expect(headers, ['title', 'amount', 'date']);
      expect(rows.length, 2);
      expect(rows[0]['title'], 'Grocery');
      expect(rows[0]['amount'], '-45.50');
      expect(rows[0]['date'], '2024-01-15');
    });

    test('parses semicolon-delimited CSV (European style)', () {
      const content = 'title;amount;date\nGrocery;-45,50;15/01/2024';
      final parsed = CsvImportService.parseCsv(content);
      final headers = parsed.headers;
      final rows = parsed.rows;

      expect(headers, ['title', 'amount', 'date']);
      expect(rows.length, 1);
      expect(rows[0]['amount'], '-45,50');
    });

    test('parses tab-delimited CSV', () {
      const content = 'title\tamount\tdate\nGrocery\t-45.50\t2024-01-15';
      final parsed = CsvImportService.parseCsv(content);
      final headers = parsed.headers;
      final rows = parsed.rows;

      expect(headers, ['title', 'amount', 'date']);
      expect(rows.length, 1);
    });

    test('handles UTF-8 BOM', () {
      const content = '\uFEFFtitle,amount\nTest,42';
      final parsed = CsvImportService.parseCsv(content);
      final headers = parsed.headers;
      final rows = parsed.rows;

      expect(headers, ['title', 'amount']);
      expect(rows.length, 1);
      expect(rows[0]['title'], 'Test');
    });

    test('handles empty CSV', () {
      final parsed = CsvImportService.parseCsv('');
      final headers = parsed.headers;
      final rows = parsed.rows;
      expect(headers, isEmpty);
      expect(rows, isEmpty);
    });

    test('handles header-only CSV (no data rows)', () {
      const content = 'col1,col2,col3';
      final parsed = CsvImportService.parseCsv(content);
      final headers = parsed.headers;
      final rows = parsed.rows;
      expect(headers, ['col1', 'col2', 'col3']);
      expect(rows, isEmpty);
    });

    test('skips completely empty rows', () {
      const content = 'title,amount\nTest,42\n   ,  ,  \nTest2,99';
      final parsed = CsvImportService.parseCsv(content);
      final headers = parsed.headers;
      final rows = parsed.rows;
      expect(rows.length, 2);
    });

    test('handles quoted fields with commas', () {
      const content = 'title,description\n"Lunch, at cafe","Good food, nice place"';
      final parsed = CsvImportService.parseCsv(content);
      final headers = parsed.headers;
      final rows = parsed.rows;
      expect(rows[0]['title'], 'Lunch, at cafe');
      expect(rows[0]['description'], 'Good food, nice place');
    });

    test('handles single column CSV', () {
      const content = 'title\nFirst\nSecond';
      final parsed = CsvImportService.parseCsv(content);
      final headers = parsed.headers;
      final rows = parsed.rows;
      expect(headers, ['title']);
      expect(rows.length, 2);
      expect(rows[0]['title'], 'First');
    });
  });

  group('CsvImportService.autoMap', () {
    test('matches exact header names', () {
      final mapping = CsvImportService.autoMap(
          ['title', 'amount', 'date', 'category', 'description', 'tags']);
      expect(mapping.titleColumn, 'title');
      expect(mapping.valueColumn, 'amount');
      expect(mapping.datetimeColumn, 'date');
      expect(mapping.categoryColumn, 'category');
      expect(mapping.descriptionColumn, 'description');
      expect(mapping.tagsColumn, 'tags');
    });

    test('matches case-insensitively', () {
      final mapping =
          CsvImportService.autoMap(['Title', 'AMOUNT', 'Date', 'CATEGORY']);
      expect(mapping.titleColumn, 'Title');
      expect(mapping.valueColumn, 'AMOUNT');
      expect(mapping.datetimeColumn, 'Date');
      expect(mapping.categoryColumn, 'CATEGORY');
    });

    test('matches partial substrings for value/datetime/description/tags', () {
      final mapping = CsvImportService.autoMap([
        'Transaction Amount',
        'Date & Time',
        'Notes/Memo',
        'Labels (tags)',
      ]);
      expect(mapping.valueColumn, 'Transaction Amount');
      expect(mapping.datetimeColumn, 'Date & Time');
      expect(mapping.descriptionColumn, 'Notes/Memo');
      expect(mapping.tagsColumn, 'Labels (tags)');
    });

    test('matches "name" as title', () {
      final mapping = CsvImportService.autoMap(['name', 'value', 'date']);
      expect(mapping.titleColumn, 'name');
    });

    test('matches "categoria" as category', () {
      final mapping = CsvImportService.autoMap(['categoria', 'importo', 'data']);
      expect(mapping.categoryColumn, 'categoria');
    });

    test('returns null for unmatched fields', () {
      final mapping = CsvImportService.autoMap(['foo', 'bar', 'baz']);
      expect(mapping.titleColumn, isNull);
      expect(mapping.valueColumn, isNull);
      expect(mapping.datetimeColumn, isNull);
      expect(mapping.categoryColumn, isNull);
      expect(mapping.descriptionColumn, isNull);
      expect(mapping.tagsColumn, isNull);
    });

    test('handles empty headers list', () {
      final mapping = CsvImportService.autoMap([]);
      expect(mapping.isEmpty, isTrue);
    });

    test('"money" in header matches value', () {
      final mapping = CsvImportService.autoMap(['Money', 'Timestamp']);
      expect(mapping.valueColumn, 'Money');
    });

    test('"timestamp" in header matches datetime', () {
      final mapping = CsvImportService.autoMap(['Timestamp']);
      expect(mapping.datetimeColumn, 'Timestamp');
    });
  });

  group('CsvImportService.parseMoney', () {
    test('handles positive number', () {
      expect(CsvImportService.parseMoney('42'), 42.0);
    });

    test('handles negative number', () {
      expect(CsvImportService.parseMoney('-42.50'), -42.50);
    });

    test('handles dollar sign prefix', () {
      expect(CsvImportService.parseMoney('\$1,234.56'), 1234.56);
    });

    test('handles euro suffix', () {
      expect(CsvImportService.parseMoney('1.234,56 €'), closeTo(1234.56, 0.01));
    });

    test('handles plain integer', () {
      expect(CsvImportService.parseMoney('100'), 100.0);
    });

    test('handles negative in parentheses', () {
      expect(CsvImportService.parseMoney('(50.00)'), -50.00);
    });

    test('handles empty string', () {
      expect(CsvImportService.parseMoney(''), isNull);
    });

    test('handles null input', () {
      expect(CsvImportService.parseMoney(null), isNull);
    });

    test('returns null for non-numeric string', () {
      expect(CsvImportService.parseMoney('abc'), isNull);
    });

    test('handles comma as decimal separator (European)', () {
      expect(CsvImportService.parseMoney('45,50'), 45.50);
    });

    test('handles comma as thousands separator', () {
      expect(CsvImportService.parseMoney('1,234'), 1234.0);
    });

    test('handles negative with currency symbol', () {
      expect(CsvImportService.parseMoney('£-99.99'), -99.99);
    });

    test('handles whitespace', () {
      expect(CsvImportService.parseMoney('  42  '), 42.0);
    });
  });

  group('CsvImportService.parseToMs', () {
    test('handles ISO 8601 datetime', () {
      final ms = CsvImportService.parseToMs('2024-01-15T10:30:00');
      expect(ms, isNotNull);
      final dt = DateTime.fromMillisecondsSinceEpoch(ms!, isUtc: true);
      expect(dt.year, 2024);
      expect(dt.month, 1);
      expect(dt.day, 15);
      expect(dt.hour, 10);
      expect(dt.minute, 30);
    });

    test('handles ISO 8601 date only', () {
      final ms = CsvImportService.parseToMs('2024-01-15');
      expect(ms, isNotNull);
      final dt = DateTime.fromMillisecondsSinceEpoch(ms!, isUtc: true);
      expect(dt.year, 2024);
      expect(dt.month, 1);
      expect(dt.day, 15);
    });

    test('handles dd/MM/yyyy format', () {
      final ms = CsvImportService.parseToMs('15/01/2024');
      expect(ms, isNotNull);
      final dt = DateTime.fromMillisecondsSinceEpoch(ms!, isUtc: true);
      expect(dt.year, 2024);
      expect(dt.month, 1);
      expect(dt.day, 15);
    });

    test('handles MM/dd/yyyy format', () {
      final ms = CsvImportService.parseToMs('01/15/2024');
      expect(ms, isNotNull);
      final dt = DateTime.fromMillisecondsSinceEpoch(ms!, isUtc: true);
      expect(dt.month, 1);
      expect(dt.day, 15);
    });

    test('handles dd-MM-yyyy format', () {
      final ms = CsvImportService.parseToMs('15-01-2024');
      expect(ms, isNotNull);
      final dt = DateTime.fromMillisecondsSinceEpoch(ms!, isUtc: true);
      expect(dt.year, 2024);
      expect(dt.month, 1);
      expect(dt.day, 15);
    });

    test('handles dd.MM.yyyy format', () {
      final ms = CsvImportService.parseToMs('15.01.2024');
      expect(ms, isNotNull);
      final dt = DateTime.fromMillisecondsSinceEpoch(ms!, isUtc: true);
      expect(dt.year, 2024);
      expect(dt.month, 1);
      expect(dt.day, 15);
    });

    test('handles Unix timestamp in milliseconds', () {
      final ms = CsvImportService.parseToMs('1705312200000');
      expect(ms, 1705312200000);
    });

    test('handles Unix timestamp in seconds', () {
      final ms = CsvImportService.parseToMs('1705312200');
      expect(ms, 1705312200000);
    });

    test('handles datetime with time', () {
      final ms = CsvImportService.parseToMs('15/01/2024 14:30:00');
      expect(ms, isNotNull);
      final dt = DateTime.fromMillisecondsSinceEpoch(ms!, isUtc: true);
      expect(dt.hour, 14);
      expect(dt.minute, 30);
    });

    test('returns null for garbage', () {
      expect(CsvImportService.parseToMs('not a date'), isNull);
    });

    test('handles null input', () {
      expect(CsvImportService.parseToMs(null), isNull);
    });

    test('handles empty string', () {
      expect(CsvImportService.parseToMs(''), isNull);
    });

    test('handles yyyyMMdd format', () {
      final ms = CsvImportService.parseToMs('20240115');
      expect(ms, isNotNull);
      final dt = DateTime.fromMillisecondsSinceEpoch(ms!, isUtc: true);
      expect(dt.year, 2024);
      expect(dt.month, 1);
      expect(dt.day, 15);
    });
  });

  group('CsvImportService.buildPreview', () {
    final headers = ['Title', 'Amount', 'Date', 'Category', 'Note', 'Tags'];
    final mapping = CsvImportMapping(
      titleColumn: 'Title',
      valueColumn: 'Amount',
      datetimeColumn: 'Date',
      categoryColumn: 'Category',
      descriptionColumn: 'Note',
      tagsColumn: 'Tags',
    );

    final rows = [
      {
        'Title': 'Grocery',
        'Amount': '-45.50',
        'Date': '2024-01-15',
        'Category': 'Food',
        'Note': 'Weekly shopping',
        'Tags': 'groceries;food',
      },
      {
        'Title': 'Salary',
        'Amount': '3000',
        'Date': '2024-01-20',
        'Category': 'Income',
        'Note': '',
        'Tags': 'work',
      },
      {
        'Title': 'Bad Row',
        'Amount': 'abc',
        'Date': 'not-a-date',
        'Category': '',
        'Note': '',
        'Tags': '',
      },
    ];

    test('computes correct stats', () {
      final preview = CsvImportService.buildPreview(rows, mapping);

      expect(preview.totalParsableRows, 2);
      expect(preview.unparseableRows, 1);
      expect(preview.uniqueCategories, ['Food', 'Income']);
      expect(preview.uniqueTags, contains('groceries'));
      expect(preview.uniqueTags, contains('food'));
      expect(preview.uniqueTags, contains('work'));
      expect(preview.earliestDate, isNotNull);
      expect(preview.latestDate, isNotNull);
    });

    test('sample record uses first parsable row', () {
      final preview = CsvImportService.buildPreview(rows, mapping);

      expect(preview.sampleRecord, isNotNull);
      expect(preview.sampleRecord!.title, 'Grocery');
      expect(preview.sampleRecord!.value, -45.50);
    });

    test('warns when minimum mapping is missing', () {
      final emptyMapping = CsvImportMapping();
      final preview = CsvImportService.buildPreview(rows, emptyMapping);

      expect(preview.warnings, isNotEmpty);
      expect(preview.warnings.any((w) => w.contains('Amount')), isTrue);
    });

    test('warns about unparseable rows', () {
      final preview = CsvImportService.buildPreview(rows, mapping);

      expect(
        preview.warnings.any((w) => w.contains('1 row') && w.contains('skipped')),
        isTrue,
      );
    });

    test('handles empty rows gracefully', () {
      final preview = CsvImportService.buildPreview([], mapping);

      expect(preview.totalParsableRows, 0);
      expect(preview.unparseableRows, 0);
      expect(preview.uniqueCategories, isEmpty);
      expect(preview.sampleRecord, isNull);
    });

    test('handles null mapping columns', () {
      final preview = CsvImportService.buildPreview(rows, CsvImportMapping());
      expect(preview.totalParsableRows, 0);
    });
  });

  group('CsvImportMapping', () {
    test('hasMinimumMapping requires value and datetime', () {
      expect(CsvImportMapping().hasMinimumMapping, isFalse);
      expect(
        CsvImportMapping(valueColumn: 'amount').hasMinimumMapping,
        isFalse,
      );
      expect(
        CsvImportMapping(datetimeColumn: 'date').hasMinimumMapping,
        isFalse,
      );
      expect(
        CsvImportMapping(valueColumn: 'amount', datetimeColumn: 'date')
            .hasMinimumMapping,
        isTrue,
      );
    });

    test('setColumn updates the correct field', () {
      final m = CsvImportMapping();
      m.setColumn('title', 'Name');
      m.setColumn('value', 'Amount');
      expect(m.titleColumn, 'Name');
      expect(m.valueColumn, 'Amount');
    });

    test('columnFor returns correct mapping', () {
      final m = CsvImportMapping(titleColumn: 'T', valueColumn: 'V');
      expect(m.columnFor('title'), 'T');
      expect(m.columnFor('value'), 'V');
      expect(m.columnFor('datetime'), isNull);
    });

    test('toJson and fromJson round-trip', () {
      final original = CsvImportMapping(
        titleColumn: 'Name',
        valueColumn: 'Amount',
        datetimeColumn: 'Date',
      );
      final json = original.toJson();
      final restored = CsvImportMapping.fromJson(json);
      expect(restored.titleColumn, 'Name');
      expect(restored.valueColumn, 'Amount');
      expect(restored.datetimeColumn, 'Date');
      expect(restored.categoryColumn, isNull);
    });

    test('isEmpty returns true when all fields are null', () {
      expect(CsvImportMapping().isEmpty, isTrue);
      expect(CsvImportMapping(titleColumn: 'x').isEmpty, isFalse);
    });

    test('walletColumn is included in field order and labels', () {
      expect(CsvImportMapping.fieldOrder, contains('wallet'));
      expect(CsvImportMapping.fieldLabels['wallet'], 'Wallet');
    });

    test('walletColumn is auto-mapped from wallet/account headers', () {
      final m1 = CsvImportService.autoMap(['wallet', 'amount', 'date']);
      expect(m1.walletColumn, 'wallet');

      final m2 = CsvImportService.autoMap(['Account Name', 'Value', 'Timestamp']);
      expect(m2.walletColumn, 'Account Name');
    });

    test('walletColumn is null when no wallet column exists', () {
      final m = CsvImportService.autoMap(['title', 'amount', 'date']);
      expect(m.walletColumn, isNull);
    });

    test('buildPreview tracks unique wallets', () {
      final rows = [
        {'Title': 'A', 'Amount': '10', 'Date': '2024-01-01', 'Wallet': 'Bank'},
        {'Title': 'B', 'Amount': '20', 'Date': '2024-01-02', 'Wallet': 'Cash'},
        {'Title': 'C', 'Amount': '30', 'Date': '2024-01-03', 'Wallet': 'Bank'},
      ];
      final mapping = CsvImportMapping(
        titleColumn: 'Title',
        valueColumn: 'Amount',
        datetimeColumn: 'Date',
        walletColumn: 'Wallet',
      );
      final preview = CsvImportService.buildPreview(rows, mapping);
      expect(preview.uniqueWallets.length, 2);
      expect(preview.uniqueWallets, containsAll(['Bank', 'Cash']));
    });

    test('buildPreview empty wallets when wallet column not mapped', () {
      final rows = [
        {'Title': 'A', 'Amount': '10', 'Date': '2024-01-01', 'Wallet': 'Bank'},
      ];
      final mapping = CsvImportMapping(
        titleColumn: 'Title',
        valueColumn: 'Amount',
        datetimeColumn: 'Date',
      );
      final preview = CsvImportService.buildPreview(rows, mapping);
      expect(preview.uniqueWallets, isEmpty);
    });
  });
}
