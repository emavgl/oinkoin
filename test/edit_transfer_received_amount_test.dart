import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n_extension/i18n_extension.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/recurrent-period.dart';
import 'package:piggybank/models/recurrent-record-pattern.dart';
import 'package:piggybank/models/wallet.dart';
import 'package:piggybank/records/components/wallet_transfer_row.dart';
import 'package:piggybank/records/edit-record-page.dart';
import 'package:piggybank/services/profile-service.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'helpers/test_database.dart';

void main() {
  late Wallet source;
  late Wallet destination;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tz.initializeTimeZones();
    ServiceConfig.localTimezone = 'UTC';
    await initializeDateFormatting('en_US', null);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'amountInputKeyboardType': 0,
      PreferencesKeys.currencyConversionRates: jsonEncode({'USD_EUR': 0.9}),
    });
    ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
    ServiceConfig.currencyLocale = const Locale('en', 'US');
    ServiceConfig.currencyNumberFormat = null;
    ServiceConfig.currencyNumberFormatWithoutGrouping = null;
    await TestDatabaseHelper.setupTestDatabase();
    await ProfileService.instance.initialize();
    source = Wallet('Source', currency: 'USD');
    destination = Wallet('Destination', currency: 'EUR');
    source.id = await ServiceConfig.database.addWallet(source);
    destination.id = await ServiceConfig.database.addWallet(destination);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Finder field(String identifier) => find.descendant(
    of: find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.identifier == identifier,
    ),
    matching: find.byType(TextFormField),
  );

  Future<void> open(
    WidgetTester tester, {
    Record? record,
    bool readOnly = false,
  }) async {
    await tester.pumpWidget(
      I18n(
        child: MaterialApp(
          home: EditRecordPage(
            isTransferFlow: true,
            initialWallet: source,
            initialDestinationWallet: destination,
            passedRecord: record,
            readOnly: readOnly,
          ),
        ),
      ),
    );
    await settle(tester);
  }

  Future<List<Record?>> records(WidgetTester tester) async {
    late List<Record?> result;
    await tester.runAsync(() async {
      result = await ServiceConfig.database.getAllRecords();
    });
    return result;
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.byType(FloatingActionButton));
    await settle(tester);
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  }

  testWidgets('manual received amount sets balances and actual rate', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(field('amount-field'), '100');
    await tester.pump();
    expect(
      tester
          .widget<TextFormField>(field('received-amount-field'))
          .controller!
          .text,
      '90.0',
    );
    await tester.enterText(field('received-amount-field'), '92');
    await tester.pump();
    expect(find.text('1 USD = 0.92 EUR'), findsOneWidget);
    await save(tester);
    final saved = (await records(tester)).single!;
    expect(saved.value, -100);
    expect(saved.transferValue, 92);
    expect(saved.description, contains('1 USD = 0.92 EUR'));
    await tester.runAsync(() async {
      expect(
        (await ServiceConfig.database.getWalletById(source.id!))!.balance,
        -100,
      );
      expect(
        (await ServiceConfig.database.getWalletById(destination.id!))!.balance,
        92,
      );
    });
    expect(
      ServiceConfig.sharedPreferences!.getString(
        PreferencesKeys.currencyConversionRates,
      ),
      jsonEncode({'USD_EUR': 0.9}),
    );
    await finish(tester);
  });

  testWidgets('manual amount works without any global conversion rate', (
    tester,
  ) async {
    await ServiceConfig.sharedPreferences!.remove(
      PreferencesKeys.currencyConversionRates,
    );
    await open(tester);
    await tester.enterText(field('amount-field'), '100');
    await tester.enterText(field('received-amount-field'), '92');
    await save(tester);
    expect((await records(tester)).single!.transferValue, 92);
    await finish(tester);
  });

  testWidgets(
    'source edits update suggestions but preserve manual received amounts',
    (tester) async {
      await open(tester);
      await tester.enterText(field('amount-field'), '200');
      await tester.pump();
      expect(
        tester
            .widget<TextFormField>(field('received-amount-field'))
            .controller!
            .text,
        '180.0',
      );
      await tester.enterText(field('received-amount-field'), '185');
      await tester.enterText(field('amount-field'), '100');
      await tester.pump();
      expect(find.text('1 USD = 1.85 EUR'), findsOneWidget);
      await save(tester);
      expect((await records(tester)).single!.transferValue, 185);
      await finish(tester);
    },
  );

  testWidgets(
    'editing existing transfer preserves historical received amount',
    (tester) async {
      await tester.runAsync(
        () => ServiceConfig.database.addRecord(
          Record(
            -100,
            'Transfer',
            null,
            DateTime.utc(2026),
            walletId: source.id,
            transferWalletId: destination.id,
            transferValue: 92.12345678,
          ),
        ),
      );
      final saved = (await records(tester)).single!;
      await ServiceConfig.sharedPreferences!.setString(
        PreferencesKeys.currencyConversionRates,
        jsonEncode({'USD_EUR': 0.5}),
      );
      await open(tester, record: saved);
      expect(
        tester
            .widget<TextFormField>(field('received-amount-field'))
            .controller!
            .text,
        '92.12345678',
      );
      await save(tester);
      expect((await records(tester)).single!.transferValue, 92.12345678);
      await finish(tester);
    },
  );

  testWidgets('changing to same-currency wallet clears custom conversion', (
    tester,
  ) async {
    final sameCurrency = Wallet('USD destination', currency: 'USD');
    await tester.runAsync(() async {
      sameCurrency.id = await ServiceConfig.database.addWallet(sameCurrency);
    });
    await open(tester);
    await tester.enterText(field('amount-field'), '100');
    await tester.enterText(field('received-amount-field'), '92');
    tester
        .widget<WalletTransferRow>(find.byType(WalletTransferRow))
        .onDestinationChanged(sameCurrency);
    await tester.pump();
    expect(field('received-amount-field'), findsNothing);
    await save(tester);
    expect((await records(tester)).single!.transferValue, isNull);
    await finish(tester);
  });

  testWidgets('empty and zero received amounts block saving', (tester) async {
    await open(tester);
    await tester.enterText(field('amount-field'), '100');
    for (final invalid in ['', '0', '-1', '10+']) {
      await tester.enterText(field('received-amount-field'), invalid);
      await save(tester);
      if (invalid == '10+') {
        expect(find.textContaining('Not a valid format'), findsOneWidget);
      } else {
        expect(find.text('Please enter a positive amount.'), findsOneWidget);
      }
      expect(await records(tester), isEmpty);
    }
    await finish(tester);
  });

  testWidgets(
    'received expressions are evaluated before validation and saving',
    (tester) async {
      await open(tester);
      await tester.enterText(field('amount-field'), '100');
      await tester.enterText(field('received-amount-field'), '90+2');
      await save(tester);
      expect((await records(tester)).single!.transferValue, 92);
      await finish(tester);
    },
  );
  testWidgets('legacy transfers preserve their fallback received amount', (
    tester,
  ) async {
    await tester.runAsync(
      () => ServiceConfig.database.addRecord(
        Record(
          -100,
          'Transfer',
          null,
          DateTime.utc(2026),
          walletId: source.id,
          transferWalletId: destination.id,
        ),
      ),
    );
    await open(tester, record: (await records(tester)).single!);
    await save(tester);
    expect((await records(tester)).single!.transferValue, 100);
    await finish(tester);
  });

  testWidgets(
    'small saved amounts do not turn scientific notation into a different balance',
    (tester) async {
      await tester.runAsync(
        () => ServiceConfig.database.addRecord(
          Record(
            -1,
            'Transfer',
            null,
            DateTime.utc(2026),
            walletId: source.id,
            transferWalletId: destination.id,
            transferValue: 0.00000001,
          ),
        ),
      );
      await open(tester, record: (await records(tester)).single!);
      expect(
        tester
            .widget<TextFormField>(field('received-amount-field'))
            .controller!
            .text,
        '0.00000001',
      );
      await save(tester);
      expect((await records(tester)).single!.transferValue, 0.00000001);
      await finish(tester);
    },
  );

  testWidgets('read-only transfer shows actual amount without mutating it', (
    tester,
  ) async {
    final original = Record(
      -100,
      'Transfer',
      null,
      DateTime.utc(2026),
      walletId: source.id,
      transferWalletId: destination.id,
      transferValue: 92,
    );
    await open(tester, record: original, readOnly: true);
    expect(
      tester.widget<TextFormField>(field('received-amount-field')).enabled,
      isFalse,
    );
    expect(find.text('1 USD = 0.92 EUR'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(original.transferValue, 92);
    await finish(tester);
  });

  testWidgets('received amount uses decimal comma preferences', (tester) async {
    await ServiceConfig.sharedPreferences!.setString(
      PreferencesKeys.decimalSeparator,
      ',',
    );
    await ServiceConfig.sharedPreferences!.setString(
      PreferencesKeys.groupSeparator,
      '.',
    );
    await open(tester);
    await tester.enterText(field('amount-field'), '100');
    await tester.enterText(field('received-amount-field'), '92,50');
    await save(tester);
    expect((await records(tester)).single!.transferValue, 92.5);
    await finish(tester);
  });

  testWidgets('editing a recurrent transfer saves its custom received amount', (
    tester,
  ) async {
    ServiceConfig.isPremium = true;
    final pattern = RecurrentRecordPattern(
      -100,
      'Transfer',
      null,
      DateTime.utc(2027),
      RecurrentPeriod.EveryMonth,
      id: 'transfer-pattern',
      walletId: source.id,
      transferWalletId: destination.id,
      transferValue: 92,
    );
    await tester.runAsync(
      () => ServiceConfig.database.addRecurrentRecordPattern(pattern),
    );
    await tester.pumpWidget(
      I18n(
        child: MaterialApp(
          home: EditRecordPage(passedRecurrentRecordPattern: pattern),
        ),
      ),
    );
    await settle(tester);
    expect(
      tester
          .widget<TextFormField>(field('received-amount-field'))
          .controller!
          .text,
      '92.0',
    );
    await tester.enterText(field('received-amount-field'), '95');
    await save(tester);
    await tester.runAsync(() async {
      final saved = await ServiceConfig.database.getRecurrentRecordPattern(
        pattern.id,
      );
      expect(saved!.transferValue, 95);
      expect(saved.value, -100);
    });
    ServiceConfig.isPremium = false;
    await finish(tester);
  });
  testWidgets(
    'in-app keyboard keeps automatic suggestions until manually edited',
    (tester) async {
      await ServiceConfig.sharedPreferences!.setInt(
        'amountInputKeyboardType',
        2,
      );
      await open(tester);
      tester.widget<TextFormField>(field('amount-field')).controller!.text =
          '100';
      await tester.pump();
      expect(
        tester
            .widget<TextFormField>(field('received-amount-field'))
            .controller!
            .text,
        '90.0',
      );
      tester.widget<TextFormField>(field('amount-field')).controller!.text =
          '200';
      await tester.pump();
      expect(
        tester
            .widget<TextFormField>(field('received-amount-field'))
            .controller!
            .text,
        '180.0',
      );
      tester
              .widget<TextFormField>(field('received-amount-field'))
              .controller!
              .text =
          '185';
      tester.widget<TextFormField>(field('amount-field')).controller!.text =
          '100';
      await tester.pump();
      expect(
        tester
            .widget<TextFormField>(field('received-amount-field'))
            .controller!
            .text,
        '185',
      );
      await save(tester);
      expect((await records(tester)).single!.transferValue, 185);
      await finish(tester);
    },
  );
  testWidgets('zero sent amount blocks saving a transfer', (tester) async {
    await open(tester);
    await tester.enterText(field('amount-field'), '0');
    await tester.enterText(field('received-amount-field'), '92');
    await save(tester);
    expect(find.text('Please enter a positive amount.'), findsOneWidget);
    expect(await records(tester), isEmpty);
    await finish(tester);
  });

  testWidgets('reselecting the same wallets preserves a custom amount', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(field('amount-field'), '100');
    await tester.enterText(field('received-amount-field'), '92');
    final selector = tester.widget<WalletTransferRow>(
      find.byType(WalletTransferRow),
    );
    selector.onSourceChanged(source);
    selector.onDestinationChanged(destination);
    await tester.pump();
    expect(
      tester
          .widget<TextFormField>(field('received-amount-field'))
          .controller!
          .text,
      '92',
    );
    await save(tester);
    expect((await records(tester)).single!.transferValue, 92);
    await finish(tester);
  });
  testWidgets(
    'changing received amount detaches an individual recurring occurrence',
    (tester) async {
      final pattern = RecurrentRecordPattern(
        -100,
        'Transfer',
        null,
        DateTime.utc(2027),
        RecurrentPeriod.EveryMonth,
        id: 'transfer-pattern',
        walletId: source.id,
        transferWalletId: destination.id,
        transferValue: 92,
      );
      await tester.runAsync(() async {
        await ServiceConfig.database.addRecurrentRecordPattern(pattern);
        await ServiceConfig.database.addRecord(
          Record(
            -100,
            'Transfer',
            null,
            DateTime.utc(2027),
            walletId: source.id,
            transferWalletId: destination.id,
            transferValue: 92,
            recurrencePatternId: pattern.id,
          ),
        );
      });
      await open(tester, record: (await records(tester)).single!);
      await tester.enterText(field('received-amount-field'), '95');
      await save(tester);
      final saved = (await records(tester)).single!;
      expect(saved.transferValue, 95);
      expect(saved.recurrencePatternId, isNull);
      await tester.runAsync(() async {
        expect(
          (await ServiceConfig.database.getRecurrentRecordPattern(pattern.id))!
              .transferValue,
          92,
        );
      });
      await finish(tester);
    },
  );

  testWidgets(
    'saving a custom rate updates the global rate used for wallets',
    (tester) async {
      await ServiceConfig.sharedPreferences!.setString(
        PreferencesKeys.defaultCurrency,
        'USD',
      );
      await ServiceConfig.sharedPreferences!.setString(
        PreferencesKeys.currencyConversionRates,
        jsonEncode({'USD_EUR': 0.9, 'EUR_USD': 1 / 0.9}),
      );
      await open(tester);
      await tester.enterText(field('amount-field'), '100');
      await tester.enterText(field('received-amount-field'), '92');
      await save(tester);
      final rates = getConversionRates();
      expect(rates['USD_EUR'], closeTo(0.92, 1e-12));
      expect(rates['EUR_USD'], closeTo(1 / 0.92, 1e-12));
      await finish(tester);
    },
  );
}
