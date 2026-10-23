import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/wallet.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/profile-service.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:piggybank/wallets/wallets-tab-page.dart';
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

  Future<void> settle(WidgetTester tester, {int rounds = 40}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  // A visible wallet worth 100 and a hidden one worth 500, so the header
  // total tells whether the hidden wallet is being counted.
  Future<void> seedWallets(WidgetTester tester, {bool hidden = true}) async {
    await tester.runAsync(() async {
      DatabaseInterface db = ServiceConfig.database;
      final defaultWallet =
          (await db.getAllWallets()).firstWhere((w) => w.isDefault);
      defaultWallet.initialAmount = 100.0;
      await db.updateWallet(defaultWallet.id!, defaultWallet);
      await db.addWallet(
        Wallet('Piggy', isHidden: hidden, initialAmount: 500.0),
      );
    });
  }

  Future<void> pumpWalletsTab(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: WalletsTabPage()));
    await settle(tester);
  }

  /// The big combined-balance number in the header.
  String headerTotal(WidgetTester tester) {
    final text = tester.widgetList<Text>(find.byType(Text)).firstWhere(
          (t) =>
              (t.style?.fontSize ?? 0) >= 24 &&
              t.style?.fontWeight == FontWeight.bold,
        );
    return text.data!;
  }

  testWidgets('a hidden wallet is out of the list and the total by default',
      (tester) async {
    await seedWallets(tester);
    await pumpWalletsTab(tester);

    expect(find.text('Piggy'), findsNothing);
    expect(headerTotal(tester), '100.00');
  });

  testWidgets('revealing a hidden wallet lists it but still excludes it',
      (tester) async {
    await seedWallets(tester);
    await pumpWalletsTab(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    // Let the popup route finish its open animation before tapping an item.
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(PopupMenuItem<int>, 'Show hidden wallets'),
    );
    await settle(tester);

    expect(find.text('Piggy'), findsOneWidget);
    expect(find.text('500.00'), findsOneWidget);
    expect(headerTotal(tester), '100.00');
  });

  testWidgets('hiding a wallet drops it from a saved selection',
      (tester) async {
    await seedWallets(tester, hidden: false);
    late int defaultId;
    late int piggyId;
    await tester.runAsync(() async {
      final wallets = await ServiceConfig.database.getAllWallets();
      defaultId = wallets.firstWhere((w) => w.isDefault).id!;
      piggyId = wallets.firstWhere((w) => w.name == 'Piggy').id!;
      final prefs = ServiceConfig.sharedPreferences!;
      await prefs.setStringList(
        PreferencesKeys.walletsTabWalletFilter(
            ProfileService.instance.activeProfileId!),
        [defaultId.toString(), piggyId.toString()],
      );
    });
    await pumpWalletsTab(tester);
    expect(headerTotal(tester), '600.00');

    // Hiding the wallet removes it from the saved filter (done by the edit
    // page); the next reload must drop it from the in-memory selection.
    await tester.runAsync(() async {
      final db = ServiceConfig.database;
      final piggy = (await db.getWalletById(piggyId))!;
      piggy.isHidden = true;
      await db.updateWallet(piggyId, piggy);
      final prefs = ServiceConfig.sharedPreferences!;
      await prefs.setStringList(
        PreferencesKeys.walletsTabWalletFilter(
            ProfileService.instance.activeProfileId!),
        [defaultId.toString()],
      );
    });
    final state = tester.state<WalletsTabPageState>(find.byType(WalletsTabPage));
    await tester.runAsync(() => state.onTabChange());
    await settle(tester);

    expect(headerTotal(tester), '100.00');
    expect(find.text('Piggy'), findsNothing);
  });

  testWidgets('a saved selection of a hidden wallet keeps counting',
      (tester) async {
    await seedWallets(tester);
    await tester.runAsync(() async {
      final wallets = await ServiceConfig.database.getAllWallets();
      final defaultId = wallets.firstWhere((w) => w.isDefault).id!;
      final piggyId = wallets.firstWhere((w) => w.name == 'Piggy').id!;
      final prefs = ServiceConfig.sharedPreferences!;
      await prefs.setStringList(
        PreferencesKeys.walletsTabWalletFilter(
            ProfileService.instance.activeProfileId!),
        [defaultId.toString(), piggyId.toString()],
      );
    });
    await pumpWalletsTab(tester);

    expect(headerTotal(tester), '600.00');

    final state = tester.state<WalletsTabPageState>(find.byType(WalletsTabPage));
    await tester.runAsync(() => state.onTabChange());
    await settle(tester);
    expect(headerTotal(tester), '600.00');
  });
}
