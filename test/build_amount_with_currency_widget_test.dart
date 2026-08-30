import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      PreferencesKeys.colorizeAmounts: true,
      PreferencesKeys.defaultCurrency: 'EUR',
      PreferencesKeys.currencyConversionRates: '{"USD_EUR": 0.9}',
    });
    ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
    ServiceConfig.currencyLocale = const Locale('en', 'US');
  });

  /// Pumps [widget] and returns the color of every Text in the tree, in
  /// paint order (so [0] is the primary/converted line, [1] the secondary/
  /// original line, for the two-line currency conversion layout).
  Future<List<Color?>> _pumpAndGetTextColors(
      WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Align(alignment: Alignment.topRight, child: widget)),
    ));
    return tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.style?.color)
        .toList();
  }

  group('buildAmountWithCurrencyWidget - transfer color neutrality', () {
    testWidgets(
      'neutralColor: true keeps the secondary currency line uncolored '
      '(regression: it used to color itself by sign regardless of the '
      'transfer context the primary line already respects)',
      (tester) async {
        final widget = buildAmountWithCurrencyWidget(
          -100.0,
          'USD',
          mainStyle: const TextStyle(fontSize: 18, color: null),
          brightness: Brightness.dark,
          neutralColor: true,
        );

        final colors = await _pumpAndGetTextColors(tester, widget);
        expect(colors.length, 2,
            reason: 'USD -> EUR conversion should render two lines');
        // Neither line should be colored red/green; the secondary line
        // falls back to the same muted color used when colorization is
        // disabled entirely, not a sign-based red.
        expect(colors[1], isNot(equals(Colors.red.shade400)));
        expect(colors[1], isNot(equals(Colors.green.shade700)));
      },
    );

    testWidgets(
      'neutralColor: false (default) still colors the secondary line by '
      'sign, for non-transfer records',
      (tester) async {
        final widget = buildAmountWithCurrencyWidget(
          -100.0,
          'USD',
          mainStyle: const TextStyle(fontSize: 18),
          brightness: Brightness.dark,
        );

        final colors = await _pumpAndGetTextColors(tester, widget);
        expect(colors.length, 2);
        expect(colors[1], equals(Colors.red.shade400),
            reason: 'a negative, non-transfer amount should color red');
      },
    );

    testWidgets(
      'neutralColor: true also applies to positive (income-shaped) transfer amounts',
      (tester) async {
        final widget = buildAmountWithCurrencyWidget(
          100.0,
          'USD',
          mainStyle: const TextStyle(fontSize: 18),
          brightness: Brightness.dark,
          neutralColor: true,
        );

        final colors = await _pumpAndGetTextColors(tester, widget);
        expect(colors[1], isNot(equals(Colors.green.shade700)));
      },
    );

    testWidgets(
      'a single-side transfer view (neutralColor: false) colors both the '
      'converted and original-currency lines consistently, matching sign',
      (tester) async {
        // Simulates records-per-day-card.dart's call: the caller already
        // resolved the color (e.g. red, only the source wallet is in view)
        // and baked it into mainStyle; the secondary line must match it,
        // not compute an independent (possibly different) color.
        final widget = buildAmountWithCurrencyWidget(
          -100.0,
          'USD',
          mainStyle: TextStyle(fontSize: 18, color: Colors.red.shade400),
          brightness: Brightness.dark,
          neutralColor: false,
        );

        final colors = await _pumpAndGetTextColors(tester, widget);
        expect(colors, [Colors.red.shade400, Colors.red.shade400]);
      },
    );

    testWidgets(
      'a single-side transfer view for the destination wallet colors both '
      'lines green',
      (tester) async {
        final widget = buildAmountWithCurrencyWidget(
          100.0,
          'USD',
          mainStyle: TextStyle(fontSize: 18, color: Colors.green.shade400),
          brightness: Brightness.dark,
          neutralColor: false,
        );

        final colors = await _pumpAndGetTextColors(tester, widget);
        expect(colors, [Colors.green.shade400, Colors.green.shade400]);
      },
    );
  });
}
