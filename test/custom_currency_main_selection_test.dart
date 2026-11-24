import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n_extension/i18n_extension.dart';
import 'package:piggybank/models/currency.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/choose-main-currency-page.dart';
import 'package:piggybank/settings/currencies-page.dart';
import 'package:piggybank/wallets/currency-picker-page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
  });

  testWidgets('custom currency can be searched and picked as main currency',
      (tester) async {
    CurrencyInfo.addCustomCurrency(
      const CurrencyInfo(
          isoCode: 'CM1', name: 'Custom Main', customSymbol: 'C'),
    );

    String? picked;
    await tester.pumpWidget(
      I18n(
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  picked = await Navigator.of(context).push<String?>(
                    MaterialPageRoute(
                      builder: (_) => const ChooseMainCurrencyPage(),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Custom Main');
    await tester.pumpAndSettle();

    // A user-defined currency is offered like any built-in one.
    expect(
      find.descendant(
        of: find.byType(ListTile),
        matching: find.text('Custom Main'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(ListTile),
        matching: find.text('CM1'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('CM1'));
    await tester.pumpAndSettle();

    expect(picked, equals('CM1'));
  });

  testWidgets(
      'full currency list offers adding a missing currency from the app bar',
      (tester) async {
    await tester.pumpWidget(
      I18n(
        child: MaterialApp(
          home: const CurrencyPickerPage(showAllCurrencies: true),
        ),
      ),
    );
    await tester.pump();

    // The action is available without having to search for anything.
    final addAction = find.descendant(
      of: find.byType(AppBar),
      matching: find.byIcon(Icons.add),
    );
    expect(addAction, findsOneWidget);

    await tester.tap(addAction);
    await tester.pumpAndSettle();

    expect(find.text('Add Custom Currency'), findsOneWidget);
  });

  testWidgets('main currency picker offers adding a missing currency',
      (tester) async {
    await tester.pumpWidget(
      I18n(
        child: MaterialApp(home: const ChooseMainCurrencyPage()),
      ),
    );
    await tester.pump();

    final addAction = find.descendant(
      of: find.byType(AppBar),
      matching: find.byIcon(Icons.add),
    );
    expect(addAction, findsOneWidget);

    await tester.tap(addAction);
    await tester.pumpAndSettle();

    expect(find.text('Add Custom Currency'), findsOneWidget);
  });

  testWidgets('empty search result offers adding a missing currency',
      (tester) async {
    await tester.pumpWidget(
      I18n(
        child: MaterialApp(home: const ChooseMainCurrencyPage()),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'zzzzzz');
    await tester.pumpAndSettle();

    expect(find.text('No currency found'), findsOneWidget);
    expect(find.text('Add your missing currency'), findsOneWidget);

    await tester.tap(find.text('Add your missing currency'));
    await tester.pumpAndSettle();

    expect(find.text('Add Custom Currency'), findsOneWidget);
  });

  testWidgets(
      'empty search result in the full list offers adding a missing currency',
      (tester) async {
    await tester.pumpWidget(
      I18n(
        child: MaterialApp(
          home: const CurrencyPickerPage(showAllCurrencies: true),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'zzzzzz');
    await tester.pumpAndSettle();

    expect(find.text('No currency found'), findsOneWidget);
    expect(find.text('Add your missing currency'), findsOneWidget);

    await tester.tap(find.text('Add your missing currency'));
    await tester.pumpAndSettle();

    expect(find.text('Add Custom Currency'), findsOneWidget);
  });

  test('custom currency chosen as main keeps its custom name and symbol', () {
    CurrencyInfo.addCustomCurrency(
      const CurrencyInfo(
          isoCode: 'CM2', name: 'Second Custom', customSymbol: 'S'),
    );

    final custom = buildUserCurrencyEntry('CM2');
    expect(custom.isoCode, equals('CM2'));
    expect(custom.ratioToMain, equals(1.0));
    expect(custom.isCustom, isTrue);
    expect(custom.customName, equals('Second Custom'));
    expect(custom.customSymbol, equals('S'));

    final builtIn = buildUserCurrencyEntry('USD');
    expect(builtIn.isCustom, isFalse);
    expect(builtIn.customName, isNull);
    expect(builtIn.customSymbol, isNull);
  });
}
