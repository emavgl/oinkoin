import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/statistics/statistics-models.dart';
import 'package:piggybank/statistics/statistics-summary-card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;

Category _category(String name, CategoryType type) {
  return Category(name, categoryType: type);
}

/// Builds the exact record set from issue #407 (the "Other" category name is
/// used by BOTH an expense record and an income record).
///
/// Income records:  Other 61.15, Rent 533.96, Investing 202.07  -> 797.18
/// Expense records: abs sum 440.06
List<Record?> _recordsFromIssue407() {
  final tools = _category('Tools', CategoryType.expense);
  final food = _category('Food', CategoryType.expense);
  final selfCare = _category('Self-care', CategoryType.expense);
  final home = _category('Home', CategoryType.expense);
  final houseCosts = _category('House Costs', CategoryType.expense);
  final car = _category('Car', CategoryType.expense);
  final cycling = _category('Cycling', CategoryType.expense);
  final clothing = _category('Clothing', CategoryType.expense);
  final hiking = _category('Hiking', CategoryType.expense);
  final rent = _category('Rent', CategoryType.income);
  final investing = _category('Investing', CategoryType.income);
  // Same name, different category type — this is the crux of the bug.
  final otherIncome = _category('Other', CategoryType.income);
  final otherExpense = _category('Other', CategoryType.expense);

  return [
    Record(-10.5, null, tools, DateTime.utc(2026, 7, 1)),
    Record(-0.52, null, food, DateTime.utc(2026, 7, 7)),
    Record(-1.83, null, food, DateTime.utc(2026, 7, 8)),
    Record(161.74, null, rent, DateTime.utc(2026, 7, 8)),
    Record(-26.62, null, food, DateTime.utc(2026, 7, 9)),
    Record(-8.3, null, selfCare, DateTime.utc(2026, 7, 9)),
    Record(-87.6, null, home, DateTime.utc(2026, 7, 10)),
    Record(-25.8, null, home, DateTime.utc(2026, 7, 10)),
    Record(-8.59, null, home, DateTime.utc(2026, 7, 10)),
    Record(-1.83, null, food, DateTime.utc(2026, 7, 11)),
    Record(61.15, null, otherIncome, DateTime.utc(2026, 7, 12)),
    Record(-3.05, null, car, DateTime.utc(2026, 7, 15)),
    Record(-34.88, null, cycling, DateTime.utc(2026, 7, 16)),
    Record(67.42, null, rent, DateTime.utc(2026, 7, 15)),
    Record(-0.76, null, food, DateTime.utc(2026, 7, 17)),
    Record(48.99, null, rent, DateTime.utc(2026, 7, 18)),
    Record(67.6, null, rent, DateTime.utc(2026, 7, 20)),
    Record(94.11, null, rent, DateTime.utc(2026, 7, 24)),
    Record(-2.36, null, houseCosts, DateTime.utc(2026, 7, 24)),
    Record(-16.4, null, houseCosts, DateTime.utc(2026, 7, 24)),
    Record(-2.0, null, houseCosts, DateTime.utc(2026, 7, 24)),
    Record(-102.0, null, clothing, DateTime.utc(2026, 7, 24)),
    Record(-96.0, null, hiking, DateTime.utc(2026, 7, 25)),
    Record(-1.74, null, food, DateTime.utc(2026, 7, 24)),
    Record(-2.5, null, food, DateTime.utc(2026, 7, 30)),
    Record(94.1, null, rent, DateTime.utc(2026, 7, 30)),
    Record(-6.78, null, otherExpense, DateTime.utc(2026, 7, 31)),
    Record(202.07, null, investing, DateTime.utc(2026, 7, 31)),
  ];
}

void main() {
  setUpAll(() async {
    tz.initializeTimeZones();
    TestWidgetsFlutterBinding.ensureInitialized();
    ServiceConfig.localTimezone = 'Europe/Vienna';
    SharedPreferences.setMockInitialValues({});
    ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
    ServiceConfig.currencyLocale = const Locale('en', 'US');
    ServiceConfig.currencyNumberFormat = null;
    ServiceConfig.currencyNumberFormatWithoutGrouping = null;
    setNumberFormatCache();
  });

  group('StatisticsSummaryCard category section totals', () {
    testWidgets(
        'balance tab: income/expense headers match their own category rows '
        'when a category name is shared across types (issue #407)', (
      tester,
    ) async {
      final records = _recordsFromIssue407();

      // The Balance tab receives income and expense records together,
      // filtered only by "not a transfer".
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatisticsSummaryCard(
                records: records,
                groupByType: GroupByType.category,
                isBalance: true,
                showRecordsToggle: true,
                onGroupByTypeChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Income records sum to 797.18 (Rent 533.96 + Investing 202.07 +
      // Other income 61.15). The income header must NOT include the expense
      // "Other" record (-6.78), which would inflate it to 803.96.
      expect(find.text('797.18'), findsOneWidget,
          reason: 'Income header should be 797.18, not 803.96');
      expect(find.text('803.96'), findsNothing);

      // Expense records abs sum to 440.06. The expense header must NOT
      // include the income "Other" record (61.15), which would inflate it to
      // 501.21.
      expect(find.text('440.06'), findsOneWidget,
          reason: 'Expenses header should be 440.06, not 501.21');
      expect(find.text('501.21'), findsNothing);

      // The individual category rows must stay attributed to the right type.
      expect(find.textContaining('61.15'), findsOneWidget);
      expect(find.textContaining('6.78'), findsOneWidget);
    });

    testWidgets(
        'income tab: shared "Other" category keeps only its income record '
        '(issue #407)', (
      tester,
    ) async {
      // The Income tab pre-filters to income-type records, so the expense
      // "Other" record (-6.78) must never appear here.
      final records = _recordsFromIssue407().where((r) {
        return r!.category!.categoryType == CategoryType.income;
      }).toList();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatisticsSummaryCard(
                records: records,
                groupByType: GroupByType.category,
                showRecordsToggle: true,
                onGroupByTypeChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('61.15'), findsOneWidget,
          reason: 'Income "Other" record (61.15) should be present');
      expect(find.textContaining('6.78'), findsNothing,
          reason: 'Expense "Other" record must not leak into the income tab');
    });
  });
}