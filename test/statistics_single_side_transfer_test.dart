import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/statistics/balance-chart-models.dart';
import 'package:piggybank/statistics/record-filters.dart';
import 'package:piggybank/statistics/statistics-models.dart';
import 'package:piggybank/statistics/statistics-utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;

/// Issue #431: the statistics page must treat a wallet-filtered transfer the
/// same way the home page does. A transfer seen from one side only moves money
/// in or out of the viewed wallet, so it counts as income (destination side) or
/// expenses (source side); a fully-visible transfer still nets to zero.
void main() {
  final expenseCategory = Category('Food', categoryType: CategoryType.expense);
  final incomeCategory = Category('Salary', categoryType: CategoryType.income);

  // Wallet 1 is the source (EUR), wallet 2 the destination (USD).
  const walletCurrencyMap = {1: 'EUR', 2: 'USD'};

  Record transfer({double value = -100.0}) => Record(
    value,
    'Transfer',
    null,
    DateTime.utc(2026, 7, 1),
    walletId: 1,
    transferWalletId: 2,
    timeZoneName: 'UTC',
  );

  Record sourceView({double value = -100.0}) =>
      transfer(value: value).copyWith(isSingleSideTransferView: true);

  Record destinationView({double received = 100.0}) => transfer(
    value: received,
  ).copyWith(isDestinationTransferView: true, isSingleSideTransferView: true);

  Record expense({double value = -50.0}) => Record(
    value,
    'lunch',
    expenseCategory,
    DateTime.utc(2026, 7, 1),
    walletId: 1,
    timeZoneName: 'UTC',
  );

  Record income({double value = 1000.0}) => Record(
    value,
    'pay',
    incomeCategory,
    DateTime.utc(2026, 7, 1),
    walletId: 1,
    timeZoneName: 'UTC',
  );

  setUpAll(() async {
    tz.initializeTimeZones();
    TestWidgetsFlutterBinding.ensureInitialized();
    ServiceConfig.localTimezone = 'Europe/Vienna';
    SharedPreferences.setMockInitialValues({
      'defaultCurrency': 'EUR',
      'currencyConversionRates': '{"USD_EUR": 0.92}',
    });
    ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
  });

  group('statistics record classification', () {
    test('a fully-visible transfer is ignored', () {
      expect(isCountedInStatistics(transfer()), isFalse);
      expect(isIncomeRecordForStatistics(transfer()), isFalse);
      expect(isExpenseRecordForStatistics(transfer()), isFalse);
    });

    test('a source-side transfer counts as an expense', () {
      final record = sourceView();
      expect(isCountedInStatistics(record), isTrue);
      expect(isExpenseRecordForStatistics(record), isTrue);
      expect(isIncomeRecordForStatistics(record), isFalse);
    });

    test('a destination-side transfer counts as income', () {
      final record = destinationView();
      expect(isCountedInStatistics(record), isTrue);
      expect(isIncomeRecordForStatistics(record), isTrue);
      expect(isExpenseRecordForStatistics(record), isFalse);
    });

    test('normal records still follow their category type', () {
      expect(isExpenseRecordForStatistics(expense()), isTrue);
      expect(isIncomeRecordForStatistics(expense()), isFalse);
      expect(isIncomeRecordForStatistics(income()), isTrue);
      expect(isExpenseRecordForStatistics(income()), isFalse);
    });
  });

  group('destination-view currency resolution', () {
    test('a destination-side transfer converts from the destination wallet',
        () {
      // 100 USD received, default currency EUR -> 92 EUR.
      expect(
        getRecordValueInDefaultCurrency(destinationView(), walletCurrencyMap),
        closeTo(92.0, 0.001),
      );
    });

    test('a source-side transfer converts from the source wallet', () {
      // 100 EUR sent, already the default currency.
      expect(
        getRecordValueInDefaultCurrency(sourceView(), walletCurrencyMap),
        closeTo(-100.0, 0.001),
      );
    });
  });

  group('statistics aggregation', () {
    test('aggregateRecordsByDate keeps single-side transfers', () {
      final records = [sourceView(value: -30.0), destinationView(received: 50.0)]
          .cast<Record?>();
      final data = aggregateRecordsByDate(
        records,
        AggregationMethod.DAY,
        walletCurrencyMap: walletCurrencyMap,
      );

      // -30 EUR + 50 USD * 0.92 = -30 + 46 = 16 EUR.
      expect(data.single.value, closeTo(16.0, 0.001));
    });
  });

  group('ComparisonDataAggregator', () {
    test('splits single-side transfers by sign', () {
      final config = ChartDateRangeConfig.create(
        AggregationMethod.DAY,
        DateTime(2026, 7, 1),
        DateTime(2026, 7, 2),
      );
      final aggregator = ComparisonDataAggregator(
        AggregationMethod.DAY,
        walletCurrencyMap: walletCurrencyMap,
      );
      final data = aggregator.aggregate([
        expense(), // -50 EUR
        income(), // +1000 EUR
        sourceView(value: -30.0), // -30 EUR expense
        destinationView(received: 50.0), // +46 EUR income
        transfer(), // fully visible: ignored
      ].cast<Record?>(), config);

      final period = data['7/1'];
      expect(period, isNotNull);
      expect(period!.expenses, closeTo(80.0, 0.001));
      expect(period.income, closeTo(1046.0, 0.001));
    });
  });

  group('RecordFilters.byWallet', () {
    test('a destination-side transfer matches the destination wallet', () {
      final records = [sourceView(), destinationView()].cast<Record?>();

      expect(
        RecordFilters.byWallet(records, '2', null),
        hasLength(1),
      );
      expect(
        RecordFilters.byWallet(records, '2', null).single!.isDestinationTransferView,
        isTrue,
      );
      expect(RecordFilters.byWallet(records, '1', null), hasLength(1));
      expect(
        RecordFilters.byWallet(records, '1', null).single!.isDestinationTransferView,
        isFalse,
      );
    });
  });
}
