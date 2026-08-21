import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/wallet.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/statistics/statistics-models.dart';
import 'package:piggybank/statistics/statistics-summary-card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;

final food = Category('Food', categoryType: CategoryType.expense);
final salary = Category('Salary', categoryType: CategoryType.income);

void main() {
  setUpAll(() async {
    tz.initializeTimeZones();
    TestWidgetsFlutterBinding.ensureInitialized();
    ServiceConfig.localTimezone = 'Europe/Vienna';
    SharedPreferences.setMockInitialValues({
      // Enable sign-based colorization of amounts.
      'colorizeAmounts': true,
    });
    ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
    ServiceConfig.currencyLocale = const Locale('en', 'US');
    ServiceConfig.currencyNumberFormat = null;
    ServiceConfig.currencyNumberFormatWithoutGrouping = null;
    setNumberFormatCache();
  });

  Future<void> pumpSummaryCard(
    WidgetTester tester, {
    required List<Record?> records,
    required GroupByType groupByType,
    Map<int, Wallet> walletMap = const {},
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatisticsSummaryCard(
              records: records,
              groupByType: groupByType,
              showRecordsToggle: true,
              walletMap: walletMap,
              onGroupByTypeChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  void expectColored(
      WidgetTester tester, String text, Color color, String reason) {
    final widget = find.text(text);
    expect(widget, findsOneWidget, reason: 'Amount "$text" should be present');
    final textWidget = tester.widget<Text>(widget);
    expect(textWidget.style?.color, color, reason: reason);
  }

  testWidgets('category rows are colorized by sign', (tester) async {
    final records = <Record?>[
      Record(-100.0, 'groceries', food, DateTime.utc(2026, 7, 1)),
      Record(50.0, 'pay', salary, DateTime.utc(2026, 7, 2)),
    ];

    await pumpSummaryCard(tester,
        records: records, groupByType: GroupByType.category);

    // Category rows: abs amount with percentage, colored by sign
    // (expenses red, income green).
    expectColored(tester, '100.00 (100.00%)', Colors.red.shade700,
        'Expense category row must be colorized red');
    expectColored(tester, '50.00 (100.00%)', Colors.green.shade700,
        'Income category row must be colorized green');
  });

  testWidgets('tag rows are colorized by sign', (tester) async {
    final records = <Record?>[
      Record(-100.0, 'groceries', food, DateTime.utc(2026, 7, 1),
          tags: {'home'}),
      Record(50.0, 'pay', salary, DateTime.utc(2026, 7, 2), tags: {'work'}),
    ];

    await pumpSummaryCard(tester,
        records: records, groupByType: GroupByType.tag);

    // Total magnitude 150: home = 66.67%, work = 33.33%.
    expectColored(tester, '100.00 (66.67%)', Colors.red.shade700,
        'Expense tag row must be colorized red');
    expectColored(tester, '50.00 (33.33%)', Colors.green.shade700,
        'Income tag row must be colorized green');
  });

  testWidgets('wallet rows are colorized by sign', (tester) async {
    final records = <Record?>[
      Record(-100.0, 'groceries', food, DateTime.utc(2026, 7, 1), walletId: 1),
      Record(50.0, 'pay', salary, DateTime.utc(2026, 7, 2), walletId: 2),
    ];
    final walletMap = {
      1: Wallet('Main', id: 1),
      2: Wallet('Savings', id: 2),
    };

    await pumpSummaryCard(tester,
        records: records,
        groupByType: GroupByType.wallet,
        walletMap: walletMap);

    // Total magnitude 150: Main = 66.67%, Savings = 33.33%.
    expectColored(tester, '100.00 (66.67%)', Colors.red.shade700,
        'Expense wallet row must be colorized red');
    expectColored(tester, '50.00 (33.33%)', Colors.green.shade700,
        'Income wallet row must be colorized green');
  });
}
