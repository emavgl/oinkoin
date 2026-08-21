import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/statistics/overview-card.dart';
import 'package:piggybank/statistics/statistics-models.dart';
import 'package:piggybank/statistics/statistics-utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;

final expenseCategory = Category(
  'Food',
  color: Colors.red,
  categoryType: CategoryType.expense,
);

void main() {
  setUpAll(() async {
    tz.initializeTimeZones();
    TestWidgetsFlutterBinding.ensureInitialized();
    ServiceConfig.localTimezone = 'Europe/Vienna';
    // Default (primary) currency: USD with a EUR->USD conversion rate of 1.1.
    SharedPreferences.setMockInitialValues({
      'defaultCurrency': 'USD',
      'currencyConversionRates': '{"EUR_USD": 1.1}',
    });
    ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
    ServiceConfig.currencyLocale = const Locale('en', 'US');
    ServiceConfig.currencyNumberFormat = null;
    ServiceConfig.currencyNumberFormatWithoutGrouping = null;
    setNumberFormatCache();
  });

  Future<void> pumpOverviewCard(
    WidgetTester tester, {
    required List<Record?> records,
    required Map<int, String?> walletCurrencyMap,
    double? selectedAmount,
    DateTime? selectedDate,
    List<Record?> selectedRecords = const [],
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: OverviewCard(
              DateTime(2025, 1, 1),
              DateTime(2025, 1, 31),
              records,
              AggregationMethod.DAY,
              selectedAmount: selectedAmount,
              selectedDate: selectedDate,
              selectedRecords: selectedRecords,
              walletCurrencyMap: walletCurrencyMap,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('OverviewCard selected amount with multi-currency', () {
    testWidgets(
        'pie slice with a single secondary currency shows converted primary '
        'amount and original secondary amount', (tester) async {
      final eurRecord = Record(-100.0, 'Groceries', expenseCategory,
          DateTime.utc(2025, 1, 15),
          walletId: 1, timeZoneName: 'UTC');

      await pumpOverviewCard(
        tester,
        records: [eurRecord],
        walletCurrencyMap: {1: 'EUR'},
        // Pie chart selection: no date, only the slice records.
        selectedAmount: 100.0,
        selectedRecords: [eurRecord],
      );

      // Primary (converted) amount as the main line: 100 EUR * 1.1 = 110 USD.
      expect(find.text('\$ 110.00'), findsOneWidget,
          reason: 'Converted primary amount should be shown as the main line');
      // Original secondary amount as the second line.
      expect(find.text('€ 100.00'), findsOneWidget,
          reason: 'Original secondary amount should be shown as the second line');
    });

    testWidgets(
        'bar selection with a single secondary currency (derived from the '
        'selected date) also shows both amounts', (tester) async {
      final eurRecord = Record(-100.0, 'Groceries', expenseCategory,
          DateTime.utc(2025, 1, 15),
          walletId: 1, timeZoneName: 'UTC');

      await pumpOverviewCard(
        tester,
        records: [eurRecord],
        walletCurrencyMap: {1: 'EUR'},
        // Bar chart selection: date set, no explicit selected records.
        selectedAmount: 100.0,
        selectedDate: truncateDateTime(eurRecord.localDateTime,
            AggregationMethod.DAY),
      );

      expect(find.text('\$ 110.00'), findsOneWidget,
          reason: 'Converted primary amount should be shown as the main line');
      expect(find.text('€ 100.00'), findsOneWidget,
          reason: 'Original secondary amount should be shown as the second line');
    });

    testWidgets(
        'selection mixing several currencies shows only the sum in the '
        'primary currency', (tester) async {
      final eurRecord = Record(-100.0, 'Groceries', expenseCategory,
          DateTime.utc(2025, 1, 15),
          walletId: 1, timeZoneName: 'UTC');
      final usdRecord = Record(-50.0, 'Fuel', expenseCategory,
          DateTime.utc(2025, 1, 15),
          walletId: 2, timeZoneName: 'UTC');

      await pumpOverviewCard(
        tester,
        records: [eurRecord, usdRecord],
        walletCurrencyMap: {1: 'EUR', 2: 'USD'},
        selectedAmount: 150.0,
        selectedRecords: [eurRecord, usdRecord],
      );

      // 100 EUR * 1.1 + 50 USD = 160 USD, single line in the primary currency.
      expect(find.text('\$ 160.00'), findsOneWidget,
          reason: 'Mixed-currency selection should sum to the primary currency');
      expect(find.text('€ 100.00'), findsNothing,
          reason: 'No original secondary line should be shown for mixed currencies');
    });
  });
}
