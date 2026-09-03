import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/wallet.dart';
import 'package:piggybank/records/components/days-summary-box-card.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/wallets/wallets-list.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;

/// Privacy mode on the wallet screen.
///
/// These tests pump the real wallet-screen widgets with plain objects (no
/// database): hiding is driven by the single global
/// [ServiceConfig.privacyModeNotifier], which is the same notifier the
/// homepage summary card and the wallet total toggle write to. That shared
/// notifier is what keeps the mode in sync when switching pages: enabling
/// it from one side hides amounts everywhere, disabling reveals them.
void main() {
  final wallets = [
    Wallet('Cash', id: 1, initialAmount: 100.0, balance: 100.0),
    Wallet('Bank', id: 2, initialAmount: 50.0, balance: 50.0),
  ];

  final food = Category('Food', categoryType: CategoryType.expense);
  final salary = Category('Salary', categoryType: CategoryType.income);
  final records = <Record?>[
    Record(-100.0, 'groceries', food, DateTime.utc(2026, 7, 1)),
    Record(50.0, 'pay', salary, DateTime.utc(2026, 7, 2)),
  ];

  setUpAll(() async {
    tz.initializeTimeZones();
    TestWidgetsFlutterBinding.ensureInitialized();
    ServiceConfig.localTimezone = 'Europe/Vienna';
    SharedPreferences.setMockInitialValues({});
    ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
    ServiceConfig.currencyLocale = const Locale('en', 'US');
    ServiceConfig.currencyNumberFormat = null;
    ServiceConfig.currencyNumberFormatWithoutGrouping = null;
    setNumberFormatCache();
  });

  setUp(() {
    ServiceConfig.privacyModeNotifier.value = false;
  });

  Future<void> pumpWalletRows(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          // Bounded height: ReorderableListView manages its own scrolling.
          body: SizedBox(
            height: 600,
            child: WalletsList(wallets),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('wallet rows show balances when privacy mode is off',
      (tester) async {
    await pumpWalletRows(tester);

    expect(find.text(DaysSummaryBox.obscuredAmountText), findsNothing);
    expect(find.text('100.00'), findsOneWidget);
    expect(find.text('50.00'), findsOneWidget);
  });

  testWidgets('wallet rows hide balances when privacy mode is on',
      (tester) async {
    await pumpWalletRows(tester);

    // Same call the wallet total tap makes.
    ServiceConfig.setPrivacyMode(true);
    await tester.pump();

    expect(find.text(DaysSummaryBox.obscuredAmountText), findsNWidgets(2));
    expect(find.text('100.00'), findsNothing);
    expect(find.text('50.00'), findsNothing);
  });

  testWidgets(
      'toggling privacy from the homepage side hides the wallet rows too',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(
                height: 200,
                child: DaysSummaryBox(
                  records,
                  walletLabel: 'All wallets',
                  walletBalanceString: '-50.00',
                  walletBalance: -50.0,
                  showWalletRow: false,
                ),
              ),
              SizedBox(
                height: 400,
                child: WalletsList(wallets),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text(DaysSummaryBox.obscuredAmountText), findsNothing);

    // Tap a homepage amount (the balance is unique to the summary card):
    // the shared notifier flips, wallet rows follow.
    await tester.tap(find.text('-50.00'));
    await tester.pump();

    expect(ServiceConfig.privacyModeNotifier.value, isTrue);
    // 3 homepage amounts + 2 wallet rows.
    expect(find.text(DaysSummaryBox.obscuredAmountText), findsNWidgets(5));

    // Disabling from either side reveals everything again.
    ServiceConfig.setPrivacyMode(false);
    await tester.pump();

    expect(find.text(DaysSummaryBox.obscuredAmountText), findsNothing);
  });
}
