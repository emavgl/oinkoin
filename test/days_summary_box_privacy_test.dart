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

/// The core privacy behavior: amounts are concealed behind placeholders
/// while privacy mode is on, and tapping any amount reveals them again.
/// Both the homepage card and the wallet screen observe the same global
/// notifier, so this single flow covers the shared toggle.
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

  testWidgets('amounts hide in privacy mode and reappear on tap',
      (tester) async {
    final food = Category('Food', categoryType: CategoryType.expense);
    final salary = Category('Salary', categoryType: CategoryType.income);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 200,
            child: DaysSummaryBox(
              <Record?>[
                Record(-100.0, 'groceries', food, DateTime.utc(2026, 7, 1)),
                Record(50.0, 'pay', salary, DateTime.utc(2026, 7, 2)),
              ],
              walletLabel: 'All wallets',
              walletBalanceString: '-50.00',
              walletBalance: -50.0,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text(obscuredAmountText), findsNothing);

    ServiceConfig.setPrivacyMode(true);
    await tester.pump();
    // Income, Expenses, Balance, and the wallet balance.
    expect(find.text(obscuredAmountText), findsNWidgets(4));

    // The first placeholder is the wallet header (opens the wallet picker);
    // tap a stat amount to toggle privacy back off.
    await tester.tap(find.text(obscuredAmountText).at(1));
    await tester.pump();
    expect(ServiceConfig.privacyModeNotifier.value, isFalse);
    expect(find.text(obscuredAmountText), findsNothing);
  });
}
