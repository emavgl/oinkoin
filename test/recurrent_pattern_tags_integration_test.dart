import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/recurrent-period.dart';
import 'package:piggybank/models/recurrent-record-pattern.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/recurrent-record-service.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest_all.dart' as tz;

void main() {
  group('Recurrent Pattern Tags Integration Test', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      tz.initializeTimeZones();
      ServiceConfig.localTimezone = "Europe/Vienna";
    });

    setUp(() async {
      DatabaseInterface db = ServiceConfig.database;
      await db.deleteDatabase();
    });

    test(
        'Records generated from recurrent patterns should have associated tags in database',
        () async {
      DatabaseInterface db = ServiceConfig.database;
      RecurrentRecordService service = RecurrentRecordService();

      // Create a category
      final category = Category("Subscription");
      await db.addCategory(category);

      // Create a recurrent pattern with tags
      final pattern = RecurrentRecordPattern(
        50.0,
        "Netflix",
        category,
        DateTime.utc(2023, 1, 1),
        RecurrentPeriod.EveryMonth,
        tags: {'streaming', 'entertainment', 'monthly'}.toSet(),
      );

      await db.addRecurrentRecordPattern(pattern);

      // Simulate the recurrent record service generating records
      await service.updateRecurrentRecords();

      // Retrieve all records from the database
      final allRecords = await db.getAllRecords();

      // Verify records were created
      expect(allRecords.isNotEmpty, true,
          reason: 'Records should have been generated from the pattern');

      // Verify each record has the tags from the pattern
      for (var record in allRecords) {
        expect(record?.tags, isNotEmpty,
            reason: 'Each generated record should have tags');
        expect(record?.tags,
            containsAll(['streaming', 'entertainment', 'monthly']),
            reason:
                'Each generated record should have all tags from the recurrent pattern');
      }

      // Verify we can query by tags
      final taggedRecords = await db.getAggregatedRecordsByTagInInterval(
          DateTime.utc(2023, 1, 1), DateTime.now().toUtc());

      expect(
          taggedRecords
              .any((element) => element['key'] == 'streaming'),
          true,
          reason: 'Should be able to find records by streaming tag');
      expect(
          taggedRecords
              .any((element) => element['key'] == 'entertainment'),
          true,
          reason: 'Should be able to find records by entertainment tag');
      expect(
          taggedRecords
              .any((element) => element['key'] == 'monthly'),
          true,
          reason: 'Should be able to find records by monthly tag');
    });
  });
}
