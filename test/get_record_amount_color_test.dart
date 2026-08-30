import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final expenseCategory = Category(
    'Expense',
    iconCodePoint: 1,
    categoryType: CategoryType.expense,
    color: Colors.red,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      PreferencesKeys.colorizeAmounts: true,
    });
    ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
  });

  Record record({
    required double value,
    int? walletId,
    int? transferWalletId,
    bool isSingleSideTransferView = false,
  }) {
    final r = Record(
      value,
      'Test',
      expenseCategory,
      DateTime(2026, 6, 1).toUtc(),
      walletId: walletId,
      transferWalletId: transferWalletId,
    );
    r.isSingleSideTransferView = isSingleSideTransferView;
    return r;
  }

  group('getRecordAmountColor', () {
    test('colors a non-transfer negative record red', () {
      final color = getRecordAmountColor(
        record(value: -50, walletId: 1),
        Brightness.dark,
      );
      expect(color, Colors.red.shade400);
    });

    test('colors a non-transfer positive record green', () {
      final color = getRecordAmountColor(
        record(value: 50, walletId: 1),
        Brightness.dark,
      );
      expect(color, Colors.green.shade400);
    });

    test(
      'scenario: both source and destination wallets visible -> neutral '
      '(reported expectation: "un singolo record per trasferimento, non '
      'colorato")',
      () {
        final color = getRecordAmountColor(
          record(
            value: -100,
            walletId: 1,
            transferWalletId: 2,
            isSingleSideTransferView: false,
          ),
          Brightness.dark,
        );
        expect(color, isNull);
      },
    );

    test(
      'scenario: only the source wallet visible -> colored red '
      '(reported expectation: "esclusivamente Wallet A ... colorato in rosso")',
      () {
        final color = getRecordAmountColor(
          record(
            value: -100, // source perspective: money leaving, negative
            walletId: 1,
            transferWalletId: 2,
            isSingleSideTransferView: true,
          ),
          Brightness.dark,
        );
        expect(color, Colors.red.shade400);
      },
    );

    test(
      'scenario: only the destination wallet visible -> colored green '
      '(reported expectation: "esclusivamente Wallet B ... colorato in verde")',
      () {
        final color = getRecordAmountColor(
          record(
            value: 100, // destination perspective: money received, positive
            walletId: 1,
            transferWalletId: 2,
            isSingleSideTransferView: true,
          ),
          Brightness.dark,
        );
        expect(color, Colors.green.shade400);
      },
    );
  });
}
