import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n_extension/i18n_extension.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/wallet.dart';
import 'package:piggybank/records/edit-record-page.dart';
import 'package:piggybank/services/profile-service.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:piggybank/statistics/statistics-models.dart';
import 'package:piggybank/statistics/statistics-utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'helpers/test_database.dart';

final _expenseCategory = Category(
  'Groceries',
  color: Colors.green,
  categoryType: CategoryType.expense,
);

Record _expense(double value, {int? walletId, int? transferWalletId}) => Record(
  value,
  'Groceries',
  _expenseCategory,
  DateTime.utc(2026, 6, 1, 12),
  walletId: walletId,
  transferWalletId: transferWalletId,
);

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    tz.initializeTimeZones();
    ServiceConfig.localTimezone = 'UTC';
  });

  group('getAmountColor treats zero as neutral', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({
        PreferencesKeys.colorizeAmounts: true,
      });
      ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
    });

    test('zero is neutral even when colorization is enabled', () {
      expect(getAmountColor(0, Brightness.light), isNull);
      expect(getAmountColor(-0.0, Brightness.light), isNull);
    });

    test('non-zero keeps green/red by sign', () {
      expect(getAmountColor(10, Brightness.light), Colors.green.shade700);
      expect(getAmountColor(-10, Brightness.light), Colors.red.shade700);
    });

    test('a zero-amount record is neutral via getRecordAmountColor', () {
      expect(getRecordAmountColor(_expense(0), Brightness.light), isNull);
    });
  });

  group('zero totals keep the currency when one is configured', () {
    test('empty total uses the default currency', () async {
      SharedPreferences.setMockInitialValues({
        PreferencesKeys.defaultCurrency: 'EUR',
      });
      ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
      ServiceConfig.currencyLocale = const Locale('en', 'US');
      setNumberFormatCache();

      final result = computeConvertedTotal(
        const [],
        const {},
        isAbsValue: true,
      );
      expect(result.total, 0);
      expect(result.currency, 'EUR');
      expect(formatRecordsTotalResult(result), contains('€'));
    });

    test('empty total without a default currency has no symbol', () async {
      SharedPreferences.setMockInitialValues({});
      ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
      ServiceConfig.currencyLocale = const Locale('en', 'US');
      setNumberFormatCache();

      final result = computeConvertedTotal(
        const [],
        const {},
        isAbsValue: true,
      );
      expect(result.currency, isNull);
      expect(formatRecordsTotalResult(result), isNot(contains('€')));
    });
  });

  group('isCountedInStatistics', () {
    test('excludes transfers and zero-amount records', () {
      expect(isCountedInStatistics(null), isFalse);
      expect(isCountedInStatistics(_expense(-20.0, walletId: 1)), isTrue);
      expect(isCountedInStatistics(_expense(0.0, walletId: 1)), isFalse);
      expect(
        isCountedInStatistics(
          _expense(-20.0, walletId: 1, transferWalletId: 2),
        ),
        isFalse,
      );
    });
  });

  group('statistics aggregation omits zero-amount records', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
    });

    test('a day made up only of a zero-amount record does not appear', () {
      final records = <Record?>[_expense(-20.0), _expense(0.0, walletId: 1)];
      final data = aggregateRecordsByDate(records, AggregationMethod.DAY);
      expect(data, hasLength(1));
      expect(data.single.value, -20.0);
    });

    test('transfers and zero records are both ignored', () {
      final records = <Record?>[
        _expense(-20.0),
        _expense(0.0, walletId: 1),
        _expense(-50.0, walletId: 1, transferWalletId: 2),
      ];
      final data = aggregateRecordsByDate(records, AggregationMethod.DAY);
      expect(data, hasLength(1));
      expect(data.single.value, -20.0);
    });
  });

  group('edit-record page allows zero-amount expense/income records', () {
    late Wallet source;
    late Wallet destination;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      tz.initializeTimeZones();
      ServiceConfig.localTimezone = 'UTC';
      await initializeDateFormatting('en_US', null);
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'amountInputKeyboardType': 0,
        PreferencesKeys.walletsEnabled: true,
      });
      ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
      ServiceConfig.currencyLocale = const Locale('en', 'US');
      ServiceConfig.currencyNumberFormat = null;
      ServiceConfig.currencyNumberFormatWithoutGrouping = null;
      ServiceConfig.isPremium = true;
      await TestDatabaseHelper.setupTestDatabase();
      await ProfileService.instance.initialize();

      source = Wallet('Source');
      destination = Wallet('Destination');
      source.id = await ServiceConfig.database.addWallet(source);
      destination.id = await ServiceConfig.database.addWallet(destination);
    });

    tearDown(() {
      ServiceConfig.isPremium = false;
    });

    Finder fieldByIdentifier(String identifier) => find.descendant(
      of: find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.identifier == identifier,
      ),
      matching: find.byType(TextFormField),
    );

    Future<void> settleWithRealAsync(WidgetTester tester) async {
      for (var i = 0; i < 40; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
    }

    Future<void> pumpPage(WidgetTester tester, {Wallet? dest}) async {
      await tester.runAsync(
        () => ServiceConfig.database.addCategory(_expenseCategory),
      );
      await tester.pumpWidget(
        I18n(
          child: MaterialApp(
            home: EditRecordPage(
              passedCategory: _expenseCategory,
              initialWallet: source,
              initialDestinationWallet: dest,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<List<Record?>> allRecords(WidgetTester tester) async {
      late List<Record?> records;
      await tester.runAsync(() async {
        records = await ServiceConfig.database.getAllRecords();
      });
      return records;
    }

    Future<void> tapSave(WidgetTester tester) async {
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      await settleWithRealAsync(tester);
      // Flush the amount listener's 2s debounce so no Timer is left pending.
      await tester.pump(const Duration(seconds: 3));
    }

    testWidgets('a plain zero-amount expense is saved', (tester) async {
      await pumpPage(tester);

      await tester.enterText(fieldByIdentifier('amount-field'), '0');
      await tester.pump();
      await tapSave(tester);

      final records = await allRecords(tester);
      expect(records.length, 1);
      expect(records.single!.value, 0);
    });

    testWidgets('a zero-amount expense with a destination wallet is saved', (
      tester,
    ) async {
      await pumpPage(tester, dest: destination);

      await tester.enterText(fieldByIdentifier('amount-field'), '0');
      await tester.pump();
      await tapSave(tester);

      expect(find.text('Please enter a positive amount.'), findsNothing);
      final records = await allRecords(tester);
      expect(records.length, 1);
      expect(records.single!.value, 0);
    });
  });
}
