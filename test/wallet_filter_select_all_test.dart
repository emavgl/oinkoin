import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/wallet.dart';
import 'package:piggybank/records/controllers/tab_records_controller.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/profile-service.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'helpers/test_database.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tz.initializeTimeZones();
    ServiceConfig.localTimezone = "Europe/Vienna";
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
    ServiceConfig.currencyLocale = const Locale('en', 'US');
    ServiceConfig.currencyNumberFormat = null;
    ServiceConfig.currencyNumberFormatWithoutGrouping = null;
    await TestDatabaseHelper.setupTestDatabase();
    await ProfileService.instance.initialize();
  });

  Future<void> settle(WidgetTester tester, {int rounds = 40}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  testWidgets(
      'select all while a hidden wallet exists keeps the shown wallets only',
      (tester) async {
    late TabRecordsController controller;
    late Set<String> visibleNames;

    await tester.runAsync(() async {
      DatabaseInterface db = ServiceConfig.database;
      await db.addWallet(Wallet('Visible A', initialAmount: 100.0));
      await db.addWallet(Wallet('Visible B', initialAmount: 50.0));
      await db.addWallet(
        Wallet('Hidden', isHidden: true, initialAmount: 500.0),
      );
      final wallets = await db.getAllWallets();
      visibleNames = wallets
          .where((w) => !w.isArchived && !w.isHidden)
          .map((w) => w.name)
          .toSet();
      controller = TabRecordsController(onStateChanged: () {});
      await controller.initialize();
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => controller.navigateToWalletPicker(context),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await settle(tester);

    expect(find.text('Hidden'), findsNothing);
    await tester.tap(find.text('Select all'));
    await tester.pump();
    await tester.tap(find.text('Apply'));
    await settle(tester);

    // Selecting all the listed wallets is an explicit selection, not
    // "All accounts": the hidden wallet stays out of the filter.
    expect(
      controller.selectedWallets.map((w) => w.name).toSet(),
      visibleNames,
    );
    expect(controller.selectedWallets.any((w) => w.isHidden), isFalse);
    expect(controller.selectedWallets, isNotEmpty);

    controller.dispose();
  });
}
