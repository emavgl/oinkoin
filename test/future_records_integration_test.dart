import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/records-per-day.dart';
import 'package:piggybank/models/recurrent-period.dart';
import 'package:piggybank/models/recurrent-record-pattern.dart';
import 'package:piggybank/services/recurrent-record-service.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:timezone/data/latest_all.dart' as tz;

void main() {
  group('Future records integration tests', () {
    setUpAll(() {
      tz.initializeTimeZones();
      ServiceConfig.localTimezone = "Europe/Vienna";
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    final recurrentRecordService = RecurrentRecordService();

    test(
        'RecordsPerDay should include future records in balance calculation when enabled',
        () {
      final category =
          Category("Test Category", categoryType: CategoryType.expense);
      final today = DateTime.now();
      final dateKey = DateTime(today.year, today.month, today.day);

      // Create a mix of past and future records
      // Expenses are stored as negative values
      final pastRecord = Record(
        -100.0,
        "Past Expense",
        category,
        DateTime.now().subtract(Duration(hours: 1)).toUtc(),
        isFutureRecord: false,
      );

      final futureRecord = Record(
        -200.0,
        "Future Expense",
        category,
        DateTime.now().add(Duration(days: 1)).toUtc(),
        isFutureRecord: true,
      );

      final recordsPerDay =
          RecordsPerDay(dateKey, records: [pastRecord, futureRecord]);

      // When future records setting is enabled, they should be included in calculations
      expect(recordsPerDay.expenses, -300.0); // -100 + -200
      expect(recordsPerDay.income, 0.0);
      expect(recordsPerDay.balance, -300.0);
    });

    test(
        'RecordsPerDay should include future income records in calculation when enabled',
        () {
      final incomeCategory =
          Category("Salary", categoryType: CategoryType.income);
      final today = DateTime.now();
      final dateKey = DateTime(today.year, today.month, today.day);

      final pastIncome = Record(
        500.0,
        "Past Income",
        incomeCategory,
        DateTime.now().subtract(Duration(hours: 2)).toUtc(),
        isFutureRecord: false,
      );

      final futureIncome = Record(
        1000.0,
        "Future Income",
        incomeCategory,
        DateTime.now().add(Duration(days: 2)).toUtc(),
        isFutureRecord: true,
      );

      final recordsPerDay =
          RecordsPerDay(dateKey, records: [pastIncome, futureIncome]);

      // Should include both past and future income when future records are enabled
      expect(recordsPerDay.income, 1500.0); // 500 + 1000
      expect(recordsPerDay.expenses, 0.0);
      expect(recordsPerDay.balance, 1500.0);
    });

    test(
        'RecordsPerDay with only future records should include them in balance',
        () {
      final category =
          Category("Future Category", categoryType: CategoryType.expense);
      final today = DateTime.now();
      final dateKey = DateTime(today.year, today.month, today.day);

      // Expenses are stored as negative values
      final futureRecord1 = Record(
        -100.0,
        "Future 1",
        category,
        DateTime.now().add(Duration(days: 1)).toUtc(),
        isFutureRecord: true,
      );

      final futureRecord2 = Record(
        -200.0,
        "Future 2",
        category,
        DateTime.now().add(Duration(days: 2)).toUtc(),
        isFutureRecord: true,
      );

      final recordsPerDay =
          RecordsPerDay(dateKey, records: [futureRecord1, futureRecord2]);

      // Future records are included when the setting is enabled
      expect(recordsPerDay.expenses, -300.0);
      expect(recordsPerDay.income, 0.0);
      expect(recordsPerDay.balance, -300.0);
    });

    test('Verify Record model isFutureRecord flag persistence', () {
      final category = Category("Test");

      // Default should be false
      final normalRecord = Record(
        50.0,
        "Normal",
        category,
        DateTime.now().toUtc(),
      );
      expect(normalRecord.isFutureRecord, false);

      // Can be explicitly set to true
      final futureRecord = Record(
        100.0,
        "Future",
        category,
        DateTime.now().add(Duration(days: 1)).toUtc(),
        isFutureRecord: true,
      );
      expect(futureRecord.isFutureRecord, true);

      // Can be modified
      futureRecord.isFutureRecord = false;
      expect(futureRecord.isFutureRecord, false);
    });

    test('Monthly recurrent pattern generates correct future records count',
        () {
      final category =
          Category("Monthly Bill", categoryType: CategoryType.expense);
      final startDate = DateTime(2024, 1, 1).toUtc();
      final endOfYear = DateTime(2024, 12, 31, 23, 59).toUtc();

      final pattern = RecurrentRecordPattern(
        50.0,
        "Monthly Subscription",
        category,
        startDate,
        RecurrentPeriod.EveryMonth,
      );

      final records =
          recurrentRecordService.generateRecurrentRecordsFromDateTime(
        pattern,
        endOfYear,
      );

      // Should generate 12 monthly records (one for each month)
      expect(records.length, 12);

      // Verify all months are covered
      final months = records.map((r) => r.localDateTime.month).toSet();
      expect(months.length, 12);
      expect(months.contains(1), true);
      expect(months.contains(12), true);
    });

    test('Weekly pattern with future view date generates correct records', () {
      final category =
          Category("Weekly Task", categoryType: CategoryType.expense);
      final startDate = DateTime(2024, 1, 1).toUtc(); // Monday
      final endDate = DateTime(2024, 1, 29).toUtc(); // 4 weeks later

      final pattern = RecurrentRecordPattern(
        25.0,
        "Weekly Payment",
        category,
        startDate,
        RecurrentPeriod.EveryWeek,
      );

      final records =
          recurrentRecordService.generateRecurrentRecordsFromDateTime(
        pattern,
        endDate,
      );

      // Should generate 5 records (Jan 1, 8, 15, 22, 29)
      expect(records.length, 5);
    });

    test('Records with tags maintain isFutureRecord flag', () {
      final category = Category("Tagged Category");
      final tags = {'tag1', 'tag2', 'tag3'};

      final futureRecord = Record(
        100.0,
        "Tagged Future Record",
        category,
        DateTime.now().add(Duration(days: 5)).toUtc(),
        tags: tags,
        isFutureRecord: true,
      );

      expect(futureRecord.isFutureRecord, true);
      expect(futureRecord.tags, tags);
    });

    test('Mixed past and future records maintain their flags independently',
        () {
      final category = Category("Mixed Category");

      final records = [
        Record(100.0, "Past 1", category,
            DateTime.now().subtract(Duration(days: 2)).toUtc(),
            isFutureRecord: false),
        Record(200.0, "Past 2", category,
            DateTime.now().subtract(Duration(days: 1)).toUtc(),
            isFutureRecord: false),
        Record(300.0, "Future 1", category,
            DateTime.now().add(Duration(days: 1)).toUtc(),
            isFutureRecord: true),
        Record(400.0, "Future 2", category,
            DateTime.now().add(Duration(days: 2)).toUtc(),
            isFutureRecord: true),
      ];

      final pastRecords = records.where((r) => !r.isFutureRecord).toList();
      final futureRecords = records.where((r) => r.isFutureRecord).toList();

      expect(pastRecords.length, 2);
      expect(futureRecords.length, 2);
      expect(pastRecords.every((r) => !r.isFutureRecord), true);
      expect(futureRecords.every((r) => r.isFutureRecord), true);
    });
  });
}
