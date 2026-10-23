import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/wallet.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/profile-service.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/wallets/wallet-picker-page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import '../helpers/test_database.dart';

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

  // sqflite work runs off the fake clock, so pump across real-async gaps.
  Future<void> settle(WidgetTester tester, {int rounds = 40}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  // sqflite futures only progress under runAsync inside a widget test.
  Future<Wallet> addHiddenWallet(WidgetTester tester) async {
    late Wallet wallet;
    await tester.runAsync(() async {
      DatabaseInterface db = ServiceConfig.database;
      final id = await db.addWallet(Wallet('Piggy', isHidden: true));
      wallet = (await db.getWalletById(id))!;
    });
    return wallet;
  }

  Future<void> pumpPicker(
    WidgetTester tester, {
    List<Wallet> initiallySelected = const [],
    bool showHiddenWallets = false,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: WalletPickerPage(
        initiallySelected: initiallySelected,
        showHiddenWallets: showHiddenWallets,
      ),
    ));
    await settle(tester);
  }

  testWidgets('hidden wallet is not listed until revealed', (tester) async {
    await addHiddenWallet(tester);
    await pumpPicker(tester);

    expect(find.text('Piggy'), findsNothing);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(PopupMenuItem<int>, 'Show hidden wallets'),
    );
    await settle(tester);

    expect(find.text('Piggy'), findsOneWidget);
  });

  testWidgets('no reveal control when there are no hidden wallets',
      (tester) async {
    await pumpPicker(tester);
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  testWidgets('an already selected hidden wallet stays listed',
      (tester) async {
    final hidden = await addHiddenWallet(tester);
    await pumpPicker(tester, initiallySelected: [hidden]);

    expect(find.text('Piggy'), findsOneWidget);
  });

  testWidgets('transfer context lists hidden wallets without a reveal control',
      (tester) async {
    await addHiddenWallet(tester);
    await pumpPicker(tester, showHiddenWallets: true);

    expect(find.text('Piggy'), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });
}
