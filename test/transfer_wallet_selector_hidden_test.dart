import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/wallet.dart';
import 'package:piggybank/records/components/transfer_wallet_selector.dart';
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

  // Hide every wallet, including the default one, so the selector starts with
  // nothing to show.
  Future<void> hideAllWallets(WidgetTester tester) async {
    await tester.runAsync(() async {
      DatabaseInterface db = ServiceConfig.database;
      final wallets = await db.getAllWallets();
      for (final wallet in wallets) {
        wallet.isHidden = true;
        await db.updateWallet(wallet.id!, wallet);
      }
      await db.addWallet(Wallet('Piggy', isHidden: true));
    });
  }

  testWidgets('hidden wallets stay listed and selectable for transfers',
      (tester) async {
    await hideAllWallets(tester);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TransferWalletSelector(onContinue: (_, __) {}),
      ),
    ));
    await settle(tester);

    // Transfers are not spending, so hiding a wallet must not take it out of
    // the transfer flow.
    expect(find.text('Piggy'), findsOneWidget);
    expect(find.text('No wallets available'), findsNothing);
    expect(find.text('Show hidden wallets'), findsNothing);

    await tester.tap(find.text('Piggy'));
    await settle(tester);
    expect(find.byIcon(Icons.north_east), findsOneWidget);
  });
}
