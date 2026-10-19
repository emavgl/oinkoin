import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/records/components/days-summary-box-card.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;

/// Issue #431: with a single wallet selected on the home page, transfers were
/// listed (colored by direction) but never counted in the Income / Expenses /
/// Balance totals. A transfer seen from one side only moves money in or out of
/// the viewed wallet, so it must count by sign; a fully-visible transfer
/// (both sides or no wallet filter) stays excluded because it nets to zero.
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

  final expenseCategory = Category('Food', categoryType: CategoryType.expense);
  final incomeCategory = Category('Salary', categoryType: CategoryType.income);

  Record expense({double value = -50.0}) => Record(
        value,
        'groceries',
        expenseCategory,
        DateTime.utc(2026, 7, 1),
        walletId: 1,
      );

  Record income({double value = 1000.0}) => Record(
        value,
        'pay',
        incomeCategory,
        DateTime.utc(2026, 7, 1),
        walletId: 1,
      );

  Record transfer({
    double value = -30.0,
    int walletId = 1,
    int transferWalletId = 2,
  }) =>
      Record(
        value,
        'Transfer',
        null,
        DateTime.utc(2026, 7, 1),
        walletId: walletId,
        transferWalletId: transferWalletId,
      );

  Record destinationView(double received) => transfer(value: received).copyWith(
        isDestinationTransferView: true,
        isSingleSideTransferView: true,
      );

  Record sourceView(double sent) =>
      transfer(value: sent).copyWith(isSingleSideTransferView: true);

  /// The exact string DaysSummaryBox renders for a total.
  String totalText(double value, {String? currency = 'EUR'}) =>
      formatRecordsTotalResult(RecordsTotalResult(value, currency));

  Future<void> pumpSummary(WidgetTester tester, List<Record?> records) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 200,
            child: DaysSummaryBox(
              records,
              walletLabel: 'Cash',
              walletBalanceString: '9999.99',
              walletBalance: 9999.99,
              walletCurrencyMap: const {1: 'EUR', 2: 'EUR'},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
      'single-side transfers count toward income, expenses and balance',
      (tester) async {
    await pumpSummary(tester, [
      income(), // +1000
      expense(), // -50
      destinationView(123.45), // received into the viewed wallet
      sourceView(-30.0), // sent from the viewed wallet
      transfer(value: -70.0), // internal movement: nets to zero, ignored
    ]);

    expect(find.text(totalText(1123.45)), findsOneWidget); // income
    expect(find.text(totalText(80.0)), findsOneWidget); // expenses
    expect(find.text(totalText(1043.45)), findsOneWidget); // balance
  });

  testWidgets(
      'without a wallet filter transfers stay excluded from every total',
      (tester) async {
    await pumpSummary(tester, [
      income(),
      expense(),
      transfer(value: -100.0), // no single-side view flags
    ]);

    expect(find.text(totalText(1000.0)), findsOneWidget); // income
    expect(find.text(totalText(50.0)), findsOneWidget); // expenses
    expect(find.text(totalText(950.0)), findsOneWidget); // balance
  });

  testWidgets('a destination-view transfer alone shows as income and balance',
      (tester) async {
    await pumpSummary(tester, [destinationView(100.0)]);

    expect(find.text(totalText(100.0)), findsNWidgets(2)); // income + balance
    // No expenses: the empty total has no configured default currency here.
    expect(find.text(totalText(0.0, currency: null)), findsOneWidget);
  });

  group('destination-view currency resolution', () {
    test('buildCurrencyBreakdown uses the destination wallet currency', () {
      final record = destinationView(90.0);
      final breakdown = buildCurrencyBreakdown([record], {1: 'USD', 2: 'EUR'});
      expect(breakdown, {'EUR': 90.0});
    });

    test('computeConvertedTotal picks the destination wallet currency', () {
      final record = destinationView(90.0);
      final result = computeConvertedTotal([record], {1: 'USD', 2: 'EUR'});
      expect(result.total, 90.0);
      expect(result.currency, 'EUR');
    });
  });
}
