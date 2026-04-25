import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/currency.dart';
import 'package:piggybank/settings/currencies-page.dart';

void main() {
  group('UserCurrency', () {
    test('should create a regular currency without custom fields', () {
      final currency = UserCurrency(
        isoCode: 'EUR',
        ratioToMain: 1.0,
      );

      expect(currency.isoCode, equals('EUR'));
      expect(currency.ratioToMain, equals(1.0));
      expect(currency.customSymbol, isNull);
      expect(currency.customName, isNull);
      expect(currency.isCustom, isFalse);
    });

    test('should create a custom currency with custom fields', () {
      final currency = UserCurrency(
        isoCode: 'MYC',
        ratioToMain: 2.5,
        customSymbol: 'M',
        customName: 'My Currency',
      );

      expect(currency.isoCode, equals('MYC'));
      expect(currency.ratioToMain, equals(2.5));
      expect(currency.customSymbol, equals('M'));
      expect(currency.customName, equals('My Currency'));
      expect(currency.isCustom, isTrue);
    });

    test('should serialize to JSON with custom fields', () {
      final currency = UserCurrency(
        isoCode: 'MYC',
        ratioToMain: 2.5,
        customSymbol: 'M',
        customName: 'My Currency',
      );

      final json = currency.toJson();

      expect(json['isoCode'], equals('MYC'));
      expect(json['ratioToMain'], equals(2.5));
      expect(json['customSymbol'], equals('M'));
      expect(json['customName'], equals('My Currency'));
    });

    test('should serialize to JSON without optional fields', () {
      final currency = UserCurrency(
        isoCode: 'EUR',
        ratioToMain: 1.0,
      );

      final json = currency.toJson();

      expect(json['isoCode'], equals('EUR'));
      expect(json['ratioToMain'], equals(1.0));
      expect(json.containsKey('customSymbol'), isFalse);
      expect(json.containsKey('customName'), isFalse);
    });

    test('should deserialize from JSON with custom fields', () {
      final json = {
        'isoCode': 'MYC',
        'ratioToMain': 2.5,
        'customSymbol': 'M',
        'customName': 'My Currency',
      };

      final currency = UserCurrency.fromJson(json);

      expect(currency.isoCode, equals('MYC'));
      expect(currency.ratioToMain, equals(2.5));
      expect(currency.customSymbol, equals('M'));
      expect(currency.customName, equals('My Currency'));
    });

    test('should deserialize from JSON without custom fields', () {
      final json = {
        'isoCode': 'EUR',
        'ratioToMain': 1.0,
      };

      final currency = UserCurrency.fromJson(json);

      expect(currency.isoCode, equals('EUR'));
      expect(currency.ratioToMain, equals(1.0));
      expect(currency.customSymbol, isNull);
      expect(currency.customName, isNull);
    });

    test('should create copy with updated values', () {
      final original = UserCurrency(
        isoCode: 'MYC',
        ratioToMain: 2.5,
        customSymbol: 'M',
        customName: 'My Currency',
      );

      final copy = original.copyWith(ratioToMain: 3.0);

      expect(copy.isoCode, equals('MYC'));
      expect(copy.ratioToMain, equals(3.0));
      expect(copy.customSymbol, equals('M'));
      expect(copy.customName, equals('My Currency'));
    });
  });

  group('CurrencyInfo', () {
    test('should return symbol from intl for standard currencies', () {
      final usd = CurrencyInfo.byCode('USD');
      expect(usd?.symbol, isNotEmpty);
    });

    test('should return isoCode as symbol when intl fails', () {
      final info = CurrencyInfo(isoCode: 'XYZ', name: 'Test Currency');
      expect(info.symbol, equals('XYZ'));
    });

    test('should add custom currency', () {
      CurrencyInfo.addCustomCurrency(
        const CurrencyInfo(
            isoCode: 'MYC', name: 'My Currency', customSymbol: 'M'),
      );

      final found = CurrencyInfo.byCode('MYC');
      expect(found, isNotNull);
      expect(found?.name, equals('My Currency'));
      expect(found?.symbol, equals('M'));
    });

    test('should update existing custom currency', () {
      CurrencyInfo.addCustomCurrency(
        const CurrencyInfo(
            isoCode: 'MYC', name: 'My Currency', customSymbol: 'M'),
      );

      CurrencyInfo.addCustomCurrency(
        const CurrencyInfo(
            isoCode: 'MYC', name: 'Updated Currency', customSymbol: 'X'),
      );

      final found = CurrencyInfo.byCode('MYC');
      expect(found?.name, equals('Updated Currency'));
      expect(found?.symbol, equals('X'));
    });

    test('should return null for non-existent currency', () {
      final found = CurrencyInfo.byCode('NONEXISTENT');
      expect(found, isNull);
    });

    test('should find both built-in and custom currencies', () {
      CurrencyInfo.addCustomCurrency(
        const CurrencyInfo(
            isoCode: 'MYC', name: 'My Currency', customSymbol: 'M'),
      );

      final found = CurrencyInfo.byCode('USD');
      expect(found, isNotNull);
      expect(found?.isoCode, equals('USD'));

      final customFound = CurrencyInfo.byCode('MYC');
      expect(customFound, isNotNull);
      expect(customFound?.isoCode, equals('MYC'));
    });

    test('should prefer built-in currency over custom with same code', () {
      final info =
          CurrencyInfo(isoCode: 'USD', name: 'Custom USD', customSymbol: 'U');
      CurrencyInfo.addCustomCurrency(info);

      final found = CurrencyInfo.byCode('USD');
      expect(found?.name, equals('US Dollar'));
    });
  });

  group('UserCurrencyConfig', () {
    test('should return list of iso codes', () {
      final config = UserCurrencyConfig(
        mainCurrency: 'EUR',
        currencies: [
          UserCurrency(isoCode: 'EUR', ratioToMain: 1.0),
          UserCurrency(isoCode: 'USD', ratioToMain: 1.1),
        ],
      );

      expect(config.isoCodes, containsAll(['EUR', 'USD']));
      expect(config.isoCodes.length, equals(2));
    });

    test('should get currency by code', () {
      final config = UserCurrencyConfig(
        mainCurrency: 'EUR',
        currencies: [
          UserCurrency(isoCode: 'USD', ratioToMain: 1.1),
        ],
      );

      final usd = config.getByCode('USD');
      expect(usd, isNotNull);
      expect(usd?.ratioToMain, equals(1.1));
    });

    test('should return null for non-existent code', () {
      final config = UserCurrencyConfig(
        mainCurrency: 'EUR',
        currencies: [
          UserCurrency(isoCode: 'USD', ratioToMain: 1.1),
        ],
      );

      final notFound = config.getByCode('GBP');
      expect(notFound, isNull);
    });
  });
}
