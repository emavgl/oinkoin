import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/recurrent-period.dart';
import 'package:piggybank/models/recurrent-record-pattern.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/recurrent-record-service.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz_timezone;

import 'helpers/test_database.dart';

/// Regression tests for discussion #463: recurring entries were duplicated on
/// the day they manifested because two overlapping recurrent-records updates
/// both generated and stored the record that became due that day.
void main() {
  late Database rawDatabase;
  late DatabaseInterface database;
  late final tz_timezone.Location location;

  final category = Category("Salary463Test", categoryType: CategoryType.income);

  DateTime today() {
    final now = tz_timezone.TZDateTime.now(location);
    return DateTime(now.year, now.month, now.day);
  }

  DateTime endOfToday() {
    final day = today();
    return DateTime(day.year, day.month, day.day, 23, 59, 59, 999);
  }

  /// The end date used by the records page: the end of the visible month.
  DateTime viewEndDate() {
    final day = today();
    return tz_timezone.TZDateTime(location, day.year, day.month + 1, 0, 23, 59)
        .toUtc();
  }

  /// A view end date far enough away to always contain future occurrences.
  DateTime farEndDate() => viewEndDate().add(const Duration(days: 60));

  /// Local midnight of [localDay], converted to the record's UTC instant.
  DateTime localMidnightUtc(DateTime localDay) => tz_timezone.TZDateTime(
        location,
        localDay.year,
        localDay.month,
        localDay.day,
      ).toUtc();

  /// A pattern that starts today: its first record manifests today.
  RecurrentRecordPattern patternStartingToday({
    String title = "IG Metall",
    Set<String>? tags,
  }) {
    return RecurrentRecordPattern(
      1500.0,
      title,
      category,
      localMidnightUtc(today()),
      RecurrentPeriod.EveryWeek,
      tags: tags,
    );
  }

  RecurrentRecordPattern dailyPattern({
    required int daysAgo,
    String title = "Daily stipend",
  }) {
    final day = today();
    return RecurrentRecordPattern(
      10.0,
      title,
      category,
      localMidnightUtc(DateTime(day.year, day.month, day.day - daysAgo)),
      RecurrentPeriod.EveryDay,
    );
  }

  /// A monthly pattern whose occurrences are the first of each month.
  RecurrentRecordPattern monthlyPattern({
    required int monthsAgo,
    String title = "IG Metall",
    Set<String>? tags,
  }) {
    final day = today();
    return RecurrentRecordPattern(
      1500.0,
      title,
      category,
      localMidnightUtc(DateTime(day.year, day.month - monthsAgo, 1)),
      RecurrentPeriod.EveryMonth,
      tags: tags,
    );
  }

  /// Past records a fresh pattern is expected to store, computed with the pure
  /// generation function so the expectations never depend on today's date.
  List<Record> expectedStoredRecords(RecurrentRecordPattern pattern) {
    final generated = RecurrentRecordService()
        .generateRecurrentRecordsFromDateTime(pattern, viewEndDate());
    return generated
        .where((record) =>
            record.utcDateTime.isBefore(endOfToday()) ||
            record.utcDateTime.isAtSameMomentAs(endOfToday()))
        .toList();
  }

  /// Multiset of stored records, keyed by the fields that identify one record.
  /// A duplicated record shows up as a count of 2.
  Map<String, int> recordCounts(Iterable<Record?> records) {
    final counts = <String, int>{};
    for (final record in records.whereType<Record>()) {
      final key =
          '${record.title}|${record.utcDateTime.millisecondsSinceEpoch}|${record.value}';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tz.initializeTimeZones();
    ServiceConfig.localTimezone = "Europe/Vienna";
    location = tz_timezone.getLocation(ServiceConfig.localTimezone);
  });

  setUp(() async {
    rawDatabase = await TestDatabaseHelper.setupTestDatabase();
    database = ServiceConfig.database;
    await database.addCategory(category);
  });

  group('Overlapping recurrent records updates', () {
    test('two overlapping updates store the record that manifests today once',
        () async {
      final pattern = patternStartingToday();
      await database.addRecurrentRecordPattern(pattern);

      // The records page triggers these without awaiting them (cold start,
      // resume, tab change), so they used to run at the same time and both
      // inserted the record that became due today.
      await Future.wait([
        RecurrentRecordService().updateRecurrentRecords(viewEndDate()),
        RecurrentRecordService().updateRecurrentRecords(viewEndDate()),
      ]);

      final stored = await database.getAllRecords();
      expect(stored.length, 1, reason: 'A due record must be stored once');
      expect(recordCounts(stored), recordCounts(expectedStoredRecords(pattern)));
    });

    test('three overlapping updates store the record that manifests today once',
        () async {
      final pattern = patternStartingToday();
      await database.addRecurrentRecordPattern(pattern);

      await Future.wait([
        RecurrentRecordService().updateRecurrentRecords(viewEndDate()),
        RecurrentRecordService().updateRecurrentRecords(viewEndDate()),
        RecurrentRecordService().updateRecurrentRecords(viewEndDate()),
      ]);

      final stored = await database.getAllRecords();
      expect(stored.length, 1);
      expect(recordCounts(stored), recordCounts(expectedStoredRecords(pattern)));
    });

    test('overlapping updates keep a monthly pattern free of duplicates',
        () async {
      final pattern = monthlyPattern(monthsAgo: 3);
      await database.addRecurrentRecordPattern(pattern);
      final expected = expectedStoredRecords(pattern);
      expect(expected.length, greaterThanOrEqualTo(3),
          reason: 'The monthly pattern must have several past occurrences');

      await Future.wait([
        RecurrentRecordService().updateRecurrentRecords(viewEndDate()),
        RecurrentRecordService().updateRecurrentRecords(viewEndDate()),
      ]);

      final stored = await database.getAllRecords();
      expect(recordCounts(stored), recordCounts(expected));
      for (final count in recordCounts(stored).values) {
        expect(count, 1, reason: 'No occurrence may be stored twice');
      }
    });

    test('overlapping updates store every due day of a daily pattern once',
        () async {
      final pattern = dailyPattern(daysAgo: 4);
      await database.addRecurrentRecordPattern(pattern);
      final expected = expectedStoredRecords(pattern);
      expect(expected.length, 5);

      await Future.wait([
        RecurrentRecordService().updateRecurrentRecords(viewEndDate()),
        RecurrentRecordService()
            .updateRecurrentRecords(viewEndDate().add(const Duration(days: 1))),
      ]);

      final stored = await database.getAllRecords();
      expect(stored.length, 5);
      expect(recordCounts(stored), recordCounts(expected));
    });

    test(
        'overlapping updates keep every one of several patterns free of duplicates',
        () async {
      final patterns = <RecurrentRecordPattern>[
        monthlyPattern(monthsAgo: 2),
        monthlyPattern(monthsAgo: 1, title: "Rent"),
        dailyPattern(daysAgo: 3),
      ];
      for (final pattern in patterns) {
        await database.addRecurrentRecordPattern(pattern);
      }
      final expected = [
        for (final pattern in patterns) ...expectedStoredRecords(pattern),
      ];

      await Future.wait([
        RecurrentRecordService().updateRecurrentRecords(viewEndDate()),
        RecurrentRecordService().updateRecurrentRecords(viewEndDate()),
        RecurrentRecordService().updateRecurrentRecords(viewEndDate()),
      ]);

      final stored = await database.getAllRecords();
      expect(recordCounts(stored), recordCounts(expected));
      expect(stored.length, expected.length);
    });

    test('overlapping updates advance the last-update date to the stored record',
        () async {
      final pattern = patternStartingToday();
      await database.addRecurrentRecordPattern(pattern);
      final expected = expectedStoredRecords(pattern);
      expect(expected.length, 1);

      await Future.wait([
        RecurrentRecordService().updateRecurrentRecords(viewEndDate()),
        RecurrentRecordService().updateRecurrentRecords(viewEndDate()),
      ]);

      final patterns = await database.getRecurrentRecordPatterns();
      expect(patterns.length, 1);
      expect(
        patterns.single.utcLastUpdate?.millisecondsSinceEpoch,
        expected.single.utcDateTime.millisecondsSinceEpoch,
        reason: 'The pattern must remember the last record it generated',
      );
    });

    test('updates run after the manifesting day do not store the record again',
        () async {
      final pattern = patternStartingToday();
      await database.addRecurrentRecordPattern(pattern);
      final expected = expectedStoredRecords(pattern);

      final service = RecurrentRecordService();
      await Future.wait([
        service.updateRecurrentRecords(viewEndDate()),
        service.updateRecurrentRecords(viewEndDate()),
      ]);
      for (var i = 0; i < 5; i++) {
        await service.updateRecurrentRecords(viewEndDate());
      }

      final stored = await database.getAllRecords();
      expect(stored.length, 1);
      expect(recordCounts(stored), recordCounts(expected));
    });

    test('overlapping updates with different end dates do not duplicate records',
        () async {
      final pattern = patternStartingToday();
      await database.addRecurrentRecordPattern(pattern);
      final expected = expectedStoredRecords(pattern);

      await Future.wait([
        RecurrentRecordService()
            .updateRecurrentRecords(viewEndDate().add(const Duration(days: 31))),
        RecurrentRecordService().updateRecurrentRecords(viewEndDate()),
        RecurrentRecordService()
            .updateRecurrentRecords(viewEndDate().add(const Duration(days: 90))),
      ]);

      final stored = await database.getAllRecords();
      expect(stored.length, 1);
      expect(recordCounts(stored), recordCounts(expected));
    });

    test('future occurrences are returned but never stored', () async {
      await database.addRecurrentRecordPattern(patternStartingToday());

      final results = await Future.wait([
        RecurrentRecordService().updateRecurrentRecords(farEndDate()),
        RecurrentRecordService().updateRecurrentRecords(farEndDate()),
      ]);

      final stored = await database.getAllRecords();
      expect(stored.length, 1);
      for (final record in stored.whereType<Record>()) {
        expect(
          record.utcDateTime.isAfter(endOfToday()),
          isFalse,
          reason: 'Future records must stay in memory until they manifest',
        );
      }

      // Both updates report the same upcoming occurrences, and none of them was
      // written to the database.
      for (final futureRecords in results) {
        expect(futureRecords, isNotEmpty);
        for (final record in futureRecords) {
          expect(record.isFutureRecord, isTrue);
          expect(record.id, isNull);
          expect(record.utcDateTime.isAfter(endOfToday()), isTrue);
        }
      }
      expect(recordCounts(results[0]), recordCounts(results[1]));
    });

    test('tags are stored once per generated record when updates overlap',
        () async {
      final taggedPattern = patternStartingToday(tags: {'salary', 'monthly'});
      await database.addRecurrentRecordPattern(taggedPattern);
      await database.addRecurrentRecordPattern(
        dailyPattern(daysAgo: 1, title: "Daily stipend"),
      );

      await Future.wait([
        RecurrentRecordService().updateRecurrentRecords(viewEndDate()),
        RecurrentRecordService().updateRecurrentRecords(viewEndDate()),
      ]);

      final stored = await database.getAllRecords();
      expect(stored.length, 3, reason: 'One weekly and two daily records');

      final associations = await rawDatabase.rawQuery(
        "SELECT record_id, COUNT(*) AS occurrences FROM records_tags "
        "GROUP BY record_id",
      );
      expect(associations.length, 1,
          reason: 'Only the tagged record has tag associations');
      expect(associations.single['occurrences'], 2,
          reason: 'Both tags of the pattern must be stored once');

      final tagNames = await rawDatabase.rawQuery(
        "SELECT tag_name FROM records_tags ORDER BY tag_name",
      );
      expect(
        tagNames.map((row) => row['tag_name']).toList(),
        ['monthly', 'salary'],
      );
    });

    test('a failed update does not block the following updates', () async {
      await database.addRecurrentRecordPattern(patternStartingToday());

      final failingService = RecurrentRecordService()
        ..database = _FailingDatabase(database);
      await expectLater(
        failingService.updateRecurrentRecords(viewEndDate()),
        throwsA(isA<StateError>()),
      );

      // The update queue must not stay stuck behind the failed update.
      final futureRecords =
          await RecurrentRecordService().updateRecurrentRecords(farEndDate());

      final stored = await database.getAllRecords();
      expect(stored.length, 1);
      expect(futureRecords, isNotEmpty);
    });
  });

  group('Batch insert keeps its duplicate semantics', () {
    test('overlapping identical batches store one copy', () async {
      final date = DateTime.now().toUtc();
      Record record() => Record(
            12.0,
            "Coffee",
            category,
            date,
            description: "Morning coffee",
          );

      await Future.wait([
        database.addRecordsInBatch([record()]),
        database.addRecordsInBatch([record()]),
      ]);

      expect((await database.getAllRecords()).length, 1);
    });

    test('overlapping batches keep identical records one-to-one', () async {
      final date = DateTime.now().toUtc();
      Record record() => Record(
            12.0,
            "Coffee",
            category,
            date,
            description: "Morning coffee",
          );

      // Both records of the first batch are stored, the second batch finds both
      // of them already stored and adds nothing.
      await Future.wait([
        database.addRecordsInBatch([record(), record()]),
        database.addRecordsInBatch([record(), record()]),
      ]);

      expect((await database.getAllRecords()).length, 2);
    });

    test('overlapping batches of distinct records all get stored', () async {
      final date = DateTime.now().toUtc();
      await Future.wait([
        database.addRecordsInBatch([
          Record(12.0, "Coffee", category, date, description: "first"),
        ]),
        database.addRecordsInBatch([
          Record(12.0, "Coffee", category, date, description: "second"),
        ]),
      ]);

      final records = await database.getAllRecords();
      expect(records.length, 2);
      expect(records.map((r) => r!.description).toSet(), {'first', 'second'});
    });
  });
}

/// A database whose pattern read fails once, to exercise a failing update.
class _FailingDatabase implements DatabaseInterface {
  _FailingDatabase(this.delegate);

  final DatabaseInterface delegate;
  bool failNextRead = true;

  @override
  Future<List<RecurrentRecordPattern>> getRecurrentRecordPatterns({
    int? profileId,
  }) {
    if (failNextRead) {
      failNextRead = false;
      return Future.error(StateError('simulated database failure'));
    }
    return delegate.getRecurrentRecordPatterns(profileId: profileId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
