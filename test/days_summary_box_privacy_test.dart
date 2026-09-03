import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/records/components/days-summary-box-card.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;

final food = Category('Food', categoryType: CategoryType.expense);
final salary = Category('Salary', categoryType: CategoryType.income);

final records = <Record?>[
  Record(-100.0, 'groceries', food, DateTime.utc(2026, 7, 1)),
  Record(50.0, 'pay', salary, DateTime.utc(2026, 7, 2)),
];

void main() {
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

  Future<void> pumpSummaryBox(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 200,
            child: DaysSummaryBox(
              records,
              walletLabel: 'All wallets',
              walletBalanceString: '-50.00',
              walletBalance: -50.0,
              showWalletRow: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('amounts are visible when privacy mode is off', (tester) async {
    await pumpSummaryBox(tester);

    expect(find.text(DaysSummaryBox.obscuredAmountText), findsNothing);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('Balance'), findsOneWidget);
  });

  testWidgets('amounts are replaced with placeholders in privacy mode',
      (tester) async {
    await pumpSummaryBox(tester);

    ServiceConfig.setPrivacyMode(true);
    await tester.pump();

    // Income, Expenses, and Balance amounts are all concealed.
    expect(find.text(DaysSummaryBox.obscuredAmountText), findsNWidgets(3));
  });

  testWidgets('tapping an amount toggles privacy mode', (tester) async {
    await pumpSummaryBox(tester);

    ServiceConfig.setPrivacyMode(true);
    await tester.pump();
    expect(find.text(DaysSummaryBox.obscuredAmountText), findsNWidgets(3));

    await tester.tap(find.text(DaysSummaryBox.obscuredAmountText).first);
    await tester.pump();

    expect(ServiceConfig.privacyModeNotifier.value, isFalse);
    expect(find.text(DaysSummaryBox.obscuredAmountText), findsNothing);
  });

  testWidgets('wallet balance is concealed in privacy mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 200,
            child: DaysSummaryBox(
              records,
              walletLabel: 'All wallets',
              walletBalanceString: '-50.00',
              walletBalance: -50.0,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Wallet balance and Balance stat coincide at -50.00 here.
    expect(find.text('-50.00'), findsNWidgets(2));

    ServiceConfig.setPrivacyMode(true);
    await tester.pump();

    expect(find.text('-50.00'), findsNothing);
    // Three stat amounts plus the wallet balance.
    expect(find.text(DaysSummaryBox.obscuredAmountText), findsNWidgets(4));
  });
}
