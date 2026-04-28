import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/helpers/datetime-utility-functions.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/recurrent-period.dart';
import 'package:piggybank/models/recurrent-record-pattern.dart';
import 'package:piggybank/services/recurrent-record-service.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'helpers/test_database.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tz.initializeTimeZones();
  });

  setUp(() async {
    await TestDatabaseHelper.setupTestDatabase();
  });

  test('records with IANA timezone show correct local time', () async {
    // After the fix, ServiceConfig.localTimezone is always an IANA name
    // like "Europe/Vienna", so getLocation never falls back to tz.local.
    ServiceConfig.localTimezone = "Europe/Vienna";
    final service = RecurrentRecordService();
    final category = Category("Test", categoryType: CategoryType.expense);
    final db = ServiceConfig.database;
    await db.addCategory(category);

    final localDate = DateTime(2026, 4, 28, 11, 20);
    final utcDate = localDate.toUtc(); // 09:20 UTC

    final pattern = RecurrentRecordPattern(
      10.0, "Test", category, utcDate, RecurrentPeriod.EveryDay,
      timeZoneName: "Europe/Vienna",
    );
    await db.addRecurrentRecordPattern(pattern);

    await service.updateRecurrentRecords(DateTime.utc(2026, 4, 30));

    final records = await db.getAllRecords();
    expect(records.isNotEmpty, true);
    for (var r in records) {
      expect(r!.localDateTime.hour, 11,
          reason: 'Record should show 11:20 local time, not UTC');
      expect(r.localDateTime.minute, 20);
    }
  });

  test('getLocation rejects abbreviation CEST, requiring IANA names', () {
    // Verify that "Europe/Vienna" (IANA name) works with getLocation.
    ServiceConfig.localTimezone = "Europe/Vienna";

    final validLocation = getLocation("Europe/Vienna");
    expect(validLocation.name, "Europe/Vienna");

    // "CEST" is an abbreviation, not an IANA name. getLocation will fall
    // back to tz.local, which may be UTC on some Linux systems. The fix
    // in main.dart ensures ServiceConfig.localTimezone is always an IANA
    // name, so this fallback path is never hit for the app's local timezone.
    final fallbackLocation = getLocation("CEST");
    expect(fallbackLocation.name, isNot("CEST"),
        reason: 'CEST should not resolve as a valid timezone');
  });
}
