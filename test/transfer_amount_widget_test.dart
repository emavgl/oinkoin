import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/records-per-day.dart';
import 'package:piggybank/records/components/records-per-day-card.dart';
import 'package:piggybank/records/controllers/tab_records_controller.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;

void main() {
  const currencies = {1: 'GBP', 2: 'USD'};
  Record transfer() => Record(
    -15,
    'Transfer',
    null,
    DateTime.utc(2026, 10, 5),
    walletId: 1,
    transferWalletId: 2,
    transferValue: 25,
  );

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tz.initializeTimeZones();
    ServiceConfig.localTimezone = 'UTC';
    await initializeDateFormatting('en_US');
  });

  Future<void> preferences(String? main) async {
    SharedPreferences.setMockInitialValues({
      PreferencesKeys.walletsEnabled: false,
      PreferencesKeys.showCurrencySymbol: true,
      if (main != null) PreferencesKeys.defaultCurrency: main,
      PreferencesKeys.currencyConversionRates: jsonEncode({
        'GBP_USD': 99,
        'USD_GBP': 0.01,
        'GBP_EUR': 88,
      }),
    });
    ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
    ServiceConfig.currencyLocale = const Locale('en', 'US');
    ServiceConfig.currencyNumberFormat = null;
    ServiceConfig.currencyNumberFormatWithoutGrouping = null;
    ServiceConfig.perCurrencyNumberFormatCache.clear();
    ServiceConfig.privacyModeHiddenNotifier.value = false;
  }

  Future<void> pumpCard(WidgetTester tester, Record record) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordsPerDayCard(
            RecordsPerDay(DateTime(2026, 10, 5), records: [record]),
            walletCurrencyMap: currencies,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final main in ['GBP', 'USD', 'EUR', null]) {
    testWidgets('home shows both actual amounts with main currency $main', (
      tester,
    ) async {
      await preferences(main);
      await pumpCard(tester, transfer());
      expect(find.text(formatCurrencyAmount(-15, 'GBP')), findsOneWidget);
      expect(find.text(formatCurrencyAmount(25, 'USD')), findsOneWidget);
      expect(find.text(formatCurrencyAmount(-1485, 'USD')), findsNothing);
    });
  }

  testWidgets(
    'destination filter preserves both original amounts and their order',
    (tester) async {
      await preferences('GBP');
      final filtered = TabRecordsController.applyTransferAwareWalletFilter(
        [transfer()],
        {2},
      ).single!;
      expect(filtered.value, 25);
      expect(filtered.sourceTransferValue, -15);
      expect(filtered.transferExchangeRate, closeTo(25 / 15, 1e-12));
      expect(filtered.copyWith(title: 'Copy').sourceTransferValue, -15);
      expect(filtered.toMap().containsKey('sourceTransferValue'), isFalse);
      await pumpCard(tester, filtered);
      final received = find.text(formatCurrencyAmount(25, 'USD'));
      final sent = find.text(formatCurrencyAmount(-15, 'GBP'));
      expect(received, findsOneWidget);
      expect(sent, findsOneWidget);
      expect(
        tester.getTopLeft(received).dy,
        lessThan(tester.getTopLeft(sent).dy),
      );
    },
  );

  testWidgets('privacy hides both transfer amounts', (tester) async {
    await preferences('GBP');
    await pumpCard(tester, transfer());
    ServiceConfig.privacyModeHiddenNotifier.value = true;
    await tester.pump();
    expect(find.text(formatCurrencyAmount(-15, 'GBP')), findsNothing);
    expect(find.text(formatCurrencyAmount(25, 'USD')), findsNothing);
    ServiceConfig.privacyModeHiddenNotifier.value = false;
  });

  test(
    'same currency and incomplete transfers keep the existing fallback',
    () async {
      await preferences('GBP');
      expect(
        buildTransferAmountWidget(transfer(), {1: 'GBP', 2: 'GBP'}),
        isNull,
      );
      expect(buildTransferAmountWidget(transfer(), {1: 'GBP'}), isNull);
      final legacy = transfer()..transferValue = null;
      expect(buildTransferAmountWidget(legacy, currencies), isNotNull);
      final expense = transfer()..transferWalletId = null;
      expect(buildTransferAmountWidget(expense, currencies), isNull);
    },
  );
}
