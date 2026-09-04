import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/records-per-day.dart';
import 'package:piggybank/records/components/records-per-day-card.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;

/// Tapping a day header starts a new entry pre-dated to that day (#372).
void main() {
  final food = Category('Food', categoryType: CategoryType.expense);

  setUpAll(() async {
    tz.initializeTimeZones();
    await initializeDateFormatting('en_US');
    TestWidgetsFlutterBinding.ensureInitialized();
    ServiceConfig.localTimezone = 'Europe/Vienna';
    SharedPreferences.setMockInitialValues({});
    ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
    ServiceConfig.currencyLocale = const Locale('en', 'US');
    ServiceConfig.currencyNumberFormat = null;
    ServiceConfig.currencyNumberFormatWithoutGrouping = null;
    setNumberFormatCache();
  });

  testWidgets('tapping the date header reports that day', (tester) async {
    final day = DateTime(2026, 6, 15);
    DateTime? tapped;
    final recordsDay = RecordsPerDay(
      day,
      records: <Record?>[
        Record(-10.0, 'groceries', food, DateTime.utc(2026, 6, 15)),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RecordsPerDayCard(
              recordsDay,
              onDateTapped: (date) => tapped = date,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('15'));
    await tester.pump();

    expect(tapped, isNotNull);
    expect(tapped!.year, 2026);
    expect(tapped!.month, 6);
    expect(tapped!.day, 15);
  });

  testWidgets('no tap action without a callback', (tester) async {
    final recordsDay = RecordsPerDay(
      DateTime(2026, 6, 15),
      records: <Record?>[
        Record(-10.0, 'groceries', food, DateTime.utc(2026, 6, 15)),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RecordsPerDayCard(recordsDay),
          ),
        ),
      ),
    );
    await tester.pump();

    // Renders fine; the header has no tap handler so nothing can fire.
    expect(find.text('15'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('15'),
        matching: find.byWidgetPredicate(
          (w) => w is InkWell && w.onTap != null,
        ),
      ),
      findsNothing,
    );
  });
}
