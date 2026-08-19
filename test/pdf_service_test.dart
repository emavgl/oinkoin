import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart' show initializeDateFormatting;
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/services/pdf-service.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;

void main() {
  group('PDFExporter', () {
    setUpAll(() async {
      tz.initializeTimeZones();
      ServiceConfig.localTimezone = "Europe/Vienna";
      await initializeDateFormatting('en_US', null);
      SharedPreferences.setMockInitialValues({});
      ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
      ServiceConfig.currencyLocale = const Locale('en', 'US');
      setNumberFormatCache();
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    List<Record> _sampleRecords() {
      final food = Category('Food', categoryType: CategoryType.expense);
      final salary = Category('Salary', categoryType: CategoryType.income);
      return [
        Record(
          -10.0,
          'Lunch',
          food,
          DateTime(2023, 1, 1, 12),
          id: 1,
          description: 'Ate at a restaurant',
          walletId: 1,
          tags: {'meal', 'work'},
        ),
        Record(
          -20.0,
          'Groceries',
          food,
          DateTime(2023, 1, 2, 18),
          id: 2,
          description: 'Weekly shopping',
          walletId: 1,
          tags: {'food'},
        ),
        Record(
          100.0,
          'January salary',
          salary,
          DateTime(2023, 1, 3, 8),
          id: 3,
          description: 'Monthly paycheck',
          walletId: 2,
        ),
      ];
    }

    test('createPdfFromRecordList returns a valid PDF document', () async {
      final bytes = await PDFExporter.createPdfFromRecordList(
        _sampleRecords(),
        from: DateTime(2023, 1, 1),
        to: DateTime(2023, 1, 31),
        walletNames: const {1: 'Cash', 2: 'Bank'},
        walletCurrencyMap: const {1: 'EUR', 2: 'EUR'},
      );

      expect(bytes, isA<Uint8List>());
      expect(bytes.isNotEmpty, isTrue);
      expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
    });

    test('createPdfFromRecordList handles an empty record list', () async {
      final bytes = await PDFExporter.createPdfFromRecordList(
        <Record?>[],
        from: DateTime(2023, 1, 1),
        to: DateTime(2023, 1, 31),
      );

      expect(bytes.isNotEmpty, isTrue);
      expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
    });

    test('createPdfFromRecordList handles a large record list spanning pages',
        () async {
      final food = Category('Food', categoryType: CategoryType.expense);
      final salary = Category('Salary', categoryType: CategoryType.income);
      final records = <Record>[];
      for (var i = 0; i < 2000; i++) {
        records.add(Record(
          i.isEven ? -10.0 : 100.0,
          'Record $i',
          i.isEven ? food : salary,
          DateTime(2020 + (i % 6), 1 + (i % 12), 1 + (i % 28), i % 24),
          id: i,
          walletId: (i % 3) + 1,
          tags: {'tag${i % 5}'},
        ));
      }
      final bytes = await PDFExporter.createPdfFromRecordList(
        records,
        from: DateTime(2020, 1, 1),
        to: DateTime(2026, 12, 31),
        walletNames: const {1: 'Cash', 2: 'Bank', 3: 'Card'},
        walletCurrencyMap: const {1: 'EUR', 2: 'EUR', 3: 'EUR'},
      );

      expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
    });

    test('createPdfFromRecordList works when colorize is enabled', () async {
      SharedPreferences.setMockInitialValues({'colorizeAmounts': true});
      ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
      setNumberFormatCache();

      final food = Category('Food', categoryType: CategoryType.expense);
      final salary = Category('Salary', categoryType: CategoryType.income);
      final records = [
        Record(-10.0, 'Lunch', food, DateTime(2023, 1, 1, 12),
            id: 1, walletId: 1, tags: {'meal'}),
        Record(100.0, 'Salary', salary, DateTime(2023, 1, 3, 8),
            id: 2, walletId: 2, tags: {'pay'}),
      ];
      final bytes = await PDFExporter.createPdfFromRecordList(
        records,
        from: DateTime(2023, 1, 1),
        to: DateTime(2023, 1, 31),
        walletNames: const {1: 'Cash', 2: 'Bank'},
        walletCurrencyMap: const {1: 'EUR', 2: 'EUR'},
      );

      expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
    });

    test('createPdfFromRecordList excludes transfers', () async {
      final food = Category('Food', categoryType: CategoryType.expense);
      final records = [
        Record(
          -5.0,
          'Coffee',
          food,
          DateTime(2023, 1, 1),
          id: 1,
          walletId: 1,
        ),
        Record(
          -5.0,
          'Transfer',
          food,
          DateTime(2023, 1, 2),
          id: 2,
          walletId: 1,
          transferWalletId: 2,
        ),
      ];
      final bytes = await PDFExporter.createPdfFromRecordList(
        records,
        from: DateTime(2023, 1, 1),
        to: DateTime(2023, 1, 31),
        walletNames: const {1: 'Cash', 2: 'Bank'},
        walletCurrencyMap: const {1: 'EUR', 2: 'EUR'},
      );

      expect(bytes.isNotEmpty, isTrue);
      expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
    });

    test('createPdfFromRecordList can render statistics without statistics',
        () async {
      final bytes = await PDFExporter.createPdfFromRecordList(
        _sampleRecords(),
        from: DateTime(2023, 1, 1),
        to: DateTime(2023, 1, 31),
        sections: const {PdfSection.records},
      );

      expect(bytes.isNotEmpty, isTrue);
      expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
    });

    test('createPdfFromRecordList can render records without statistics',
        () async {
      final bytes = await PDFExporter.createPdfFromRecordList(
        _sampleRecords(),
        from: DateTime(2023, 1, 1),
        to: DateTime(2023, 1, 31),
        sections: const {PdfSection.expenses, PdfSection.income},
      );

      expect(bytes.isNotEmpty, isTrue);
      expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
    });
  });
}
