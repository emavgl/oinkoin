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

/// Privacy mode on the homepage summary card.
///
/// The settings switch only arms the feature; hiding itself happens through
/// the eye button or by tapping an amount. Both drive the same global
/// hidden state that the wallet screen observes too.
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
    ServiceConfig.privacyModeEnabledNotifier.value = false;
    ServiceConfig.privacyModeHiddenNotifier.value = false;
  });

  testWidgets('tapping hides only while armed; disarming reveals',
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

    // Disarmed: tapping an amount does nothing (two '-50.00' texts exist:
    // the wallet header and the balance stat; either tap is ignored).
    await tester.tap(find.text('-50.00').first);
    await tester.pump();
    expect(ServiceConfig.privacyModeHiddenNotifier.value, isFalse);
    expect(find.text(obscuredAmountText), findsNothing);

    // Armed: tapping the balance stat hides income, expenses, balance,
    // and wallet balance.
    ServiceConfig.setPrivacyModeEnabled(true);
    await tester.pump();
    await tester.tap(find.text('-50.00').last);
    await tester.pump();
    expect(ServiceConfig.privacyModeHiddenNotifier.value, isTrue);
    expect(find.text(obscuredAmountText), findsNWidgets(4));

    // Disarming reveals everything again.
    ServiceConfig.setPrivacyModeEnabled(false);
    await tester.pump();
    expect(find.text(obscuredAmountText), findsNothing);
  });
}
