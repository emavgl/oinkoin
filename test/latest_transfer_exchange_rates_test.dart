import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/wallet.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/services/transfer-exchange-rate-service.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:piggybank/settings/currencies-page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers/test_database.dart';

void main() {
  late int usd;
  late int eur;
  late int jpy;
  final day1 = DateTime.utc(2020, 1, 1);
  final day2 = DateTime.utc(2020, 1, 2);
  final day3 = DateTime.utc(2020, 1, 3);

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    ServiceConfig.localTimezone = 'UTC';
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      PreferencesKeys.defaultCurrency: 'USD',
      PreferencesKeys.currencyConversionRates: jsonEncode({
        'USD_EUR': 0.5,
        'EUR_USD': 2,
        'CHF_USD': 1.1,
      }),
      PreferencesKeys.userCurrencies: jsonEncode(
        UserCurrencyConfig(
          mainCurrency: 'USD',
          currencies: [
            UserCurrency(isoCode: 'USD', ratioToMain: 1),
            UserCurrency(
              isoCode: 'EUR',
              ratioToMain: 2,
              decimalDigits: 8,
              customName: 'My Euro',
              customSymbol: 'E',
            ),
            UserCurrency(isoCode: 'CHF', ratioToMain: 1.1),
          ],
        ).toJson(),
      ),
    });
    ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
    await TestDatabaseHelper.setupTestDatabase();
    usd = await ServiceConfig.database.addWallet(
      Wallet('USD', currency: 'USD'),
    );
    eur = await ServiceConfig.database.addWallet(
      Wallet('EUR', currency: 'EUR'),
    );
    jpy = await ServiceConfig.database.addWallet(
      Wallet('JPY', currency: 'JPY'),
    );
  });

  Future<int> add(
    int source,
    int destination,
    double sent,
    double? received,
    DateTime date,
  ) => ServiceConfig.database.addRecord(
    Record(
      -sent,
      'Transfer',
      null,
      date,
      walletId: source,
      transferWalletId: destination,
      transferValue: received,
    ),
  );

  void expectEuroRate(double rate) {
    expect(getConversionRates()['USD_EUR'], closeTo(rate, 1e-12));
    expect(getConversionRates()['EUR_USD'], closeTo(1 / rate, 1e-12));
    expect(
      getUserCurrencyConfig().getByCode('EUR')!.ratioToMain,
      closeTo(1 / rate, 1e-12),
    );
  }

  test('saving toward the foreign currency updates both directions and currency settings', () async {
    final id = await add(usd, eur, 100, 92, day1);
    expectEuroRate(0.92);
    expect(convertAmount(100, 'USD', 'EUR'), 92);
    expect(convertAmount(92, 'EUR', 'USD'), closeTo(100, 1e-12));
    final config = getUserCurrencyConfig();
    expect(config.isoCodes, ['USD', 'EUR', 'CHF']);
    expect(config.getByCode('EUR')!.decimalDigits, 8);
    expect(config.getByCode('EUR')!.customName, 'My Euro');
    expect(config.getByCode('EUR')!.customSymbol, 'E');
    expect(config.getByCode('CHF')!.ratioToMain, 1.1);
    expect(getConversionRates()['CHF_USD'], 1.1);
    final saved = await ServiceConfig.database.getRecordById(id);
    expect(saved!.value, -100);
    expect(saved.transferValue, 92);
  });

  test(
    'the reverse-direction transfer sets the same main-to-other orientation',
    () async {
      await add(eur, usd, 80, 100, day1);
      expectEuroRate(0.8);
    },
  );

  test(
    'newest transaction date wins, not save order or transfer direction',
    () async {
      await add(usd, eur, 100, 95, day3);
      await add(eur, usd, 80, 100, day2);
      await add(usd, eur, 100, 70, day1);
      expectEuroRate(0.95);
    },
  );

  test('concurrent saves finish with the newest dated transfer rate', () async {
    await Future.wait([
      add(usd, eur, 100, 95, day3),
      add(eur, usd, 80, 100, day2),
      add(usd, eur, 100, 70, day1),
    ]);
    expectEuroRate(0.95);
  });

  test('ties use the larger record id deterministically', () async {
    await add(usd, eur, 100, 92, day1);
    await add(eur, usd, 96, 100, day1);
    expectEuroRate(0.96);
  });

  test('editing the latest received amount updates the rate without changing older transfers', () async {
    final older = await add(usd, eur, 100, 70, day1);
    final latest = await add(usd, eur, 100, 92, day2);
    final record = (await ServiceConfig.database.getRecordById(latest))!;
    record.transferValue = 95;
    await ServiceConfig.database.updateRecordById(latest, record);
    expectEuroRate(0.95);
    expect(
      (await ServiceConfig.database.getRecordById(older))!.transferValue,
      70,
    );
  });

  test(
    'backdating the latest record recalculates from the newly latest transfer',
    () async {
      await add(usd, eur, 100, 70, day2);
      final id = await add(usd, eur, 100, 92, day3);
      final record = (await ServiceConfig.database.getRecordById(id))!;
      record.utcDateTime = day1;
      await ServiceConfig.database.updateRecordById(id, record);
      expectEuroRate(0.7);
    },
  );

  test(
    'deleting the latest transfer falls back to the older completed transfer',
    () async {
      await add(usd, eur, 100, 70, day1);
      final id = await add(usd, eur, 100, 92, day2);
      await ServiceConfig.database.deleteRecordById(id);
      expectEuroRate(0.7);
    },
  );

  test('future-dated transfers wait until their transaction time', () async {
    await add(usd, eur, 100, 70, day1);
    final future = DateTime.now().toUtc().add(const Duration(days: 10));
    await add(usd, eur, 100, 99, future);
    expectEuroRate(0.7);
    await TransferExchangeRateService.refresh(
      ServiceConfig.database,
      asOf: future.subtract(const Duration(milliseconds: 1)),
    );
    expectEuroRate(0.7);
    await TransferExchangeRateService.refresh(
      ServiceConfig.database,
      asOf: future,
    );
    expectEuroRate(0.99);
  });

  test('invalid and legacy amounts do not override an actual rate', () async {
    await add(usd, eur, 100, 92, day1);
    await add(usd, eur, 0, 99, day2);
    await add(usd, eur, 100, 0, day2);
    await add(usd, eur, 100, -10, day2);
    await add(usd, eur, 100, null, day2);
    expectEuroRate(0.92);
  });

  test(
    'transfers not involving the main currency leave its rates unchanged',
    () async {
      await add(eur, jpy, 100, 16000, day1);
      expectEuroRate(0.5);
      expect(getConversionRates()['USD_JPY'], isNull);
    },
  );

  test('rates are independently chosen for each foreign currency', () async {
    await add(usd, eur, 100, 92, day1);
    await add(jpy, usd, 15000, 100, day3);
    expectEuroRate(0.92);
    expect(getConversionRates()['USD_JPY'], 150);
    expect(getConversionRates()['JPY_USD'], closeTo(1 / 150, 1e-12));
  });

  test('batch inserts use the latest dated transfer', () async {
    await ServiceConfig.database.addRecordsInBatchNoDuplicateCheck([
      Record(
        -100,
        'Old',
        null,
        day1,
        walletId: usd,
        transferWalletId: eur,
        transferValue: 70,
      ),
      Record(
        -100,
        'New',
        null,
        day3,
        walletId: usd,
        transferWalletId: eur,
        transferValue: 95,
      ),
      Record(
        -100,
        'Middle',
        null,
        day2,
        walletId: usd,
        transferWalletId: eur,
        transferValue: 80,
      ),
    ]);
    expectEuroRate(0.95);
  });

  test(
    'changing the main currency recalculates in the new direction',
    () async {
      await add(usd, eur, 100, 92, day1);
      await ServiceConfig.sharedPreferences!.setString(
        PreferencesKeys.defaultCurrency,
        'EUR',
      );
      await TransferExchangeRateService.refresh(ServiceConfig.database);
      expect(getConversionRates()['EUR_USD'], closeTo(100 / 92, 1e-12));
    },
  );

  test('no configured main currency leaves manual conversion preferences unchanged', () async {
    await ServiceConfig.sharedPreferences!.remove(
      PreferencesKeys.defaultCurrency,
    );
    await add(usd, eur, 100, 92, day1);
    expectEuroRate(0.5);
  });
}
