import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:piggybank/helpers/datetime-utility-functions.dart';
import 'package:piggybank/records/controllers/tab_records_controller.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/homepage-time-interval.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'helpers/test_database.dart';

void main() {
  late TabRecordsController controller;
  late SharedPreferences sharedPreferences;
  late DatabaseInterface database;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('en_US', null);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tz.initializeTimeZones();
    ServiceConfig.localTimezone = "Europe/Vienna";
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      PreferencesKeys.homepageTimeInterval:
          HomepageTimeInterval.CurrentWeek.index,
      PreferencesKeys.homepageRecordsMonthStartDay: 1,
      PreferencesKeys.firstDayOfWeek: DateTime.monday,
    });
    sharedPreferences = await SharedPreferences.getInstance();
    ServiceConfig.sharedPreferences = sharedPreferences;

    await TestDatabaseHelper.setupTestDatabase();
    database = ServiceConfig.database;

    controller = TabRecordsController();
    controller.initialize();
  });

  test('debug week shift', () async {
    DateTime currentWeekStart = DateTime(2026, 3, 30);
    print('Setting customIntervalFrom = $currentWeekStart');
    controller.customIntervalFrom = currentWeekStart;

    print('Before shift: from=${controller.customIntervalFrom}');

    await controller.shiftInterval(-1);

    print(
        'After shift: from=${controller.customIntervalFrom}, to=${controller.customIntervalTo}');

    // Expected: March 23, 2026
    print('Expected: from=2026-03-23, to=2026-03-29 23:59:59');
  });
}
