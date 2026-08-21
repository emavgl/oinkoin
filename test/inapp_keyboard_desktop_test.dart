import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/components/amount_input_field.dart';
import 'package:piggybank/helpers/amount-input-utils.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    ServiceConfig.localTimezone = 'Europe/Vienna';
    SharedPreferences.setMockInitialValues({
      // Select the in-app keyboard for amount input.
      'amountInputKeyboardType': 2,
      'inAppKeyboardScale': 1,
      'inAppKeyboardBackgroundColorIndex': 0,
      'inAppKeyboardButtonColorIndex': 0,
      'inAppKeyboardTextColorIndex': 0,
    });
    ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
    ServiceConfig.currencyLocale = const Locale('en', 'US');
    ServiceConfig.currencyNumberFormat = null;
    ServiceConfig.currencyNumberFormatWithoutGrouping = null;
    setNumberFormatCache();
  });

  /// Pumps a page with an amount field (and optionally a second, regular text
  /// field below it). The caller must set [debugDefaultTargetPlatformOverride]
  /// first and restore it afterwards, so desktop-specific focus behaviors are
  /// exercised without leaking the override into the framework invariants.
  Future<void> pumpPage(
    WidgetTester tester,
    TextEditingController controller, {
    bool withSecondField = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              AmountInputField(controller: controller),
              if (withSecondField) ...[
                const SizedBox(height: 16),
                const TextField(
                  decoration: InputDecoration(labelText: 'Title'),
                ),
              ],
              const SizedBox(height: 300),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('keyboard stays open when tapping a key on Windows',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await pumpPage(tester, controller);

      await tester.tap(find.byType(AmountInputField));
      await tester.pumpAndSettle();
      expect(inAppKeyboardOpen.value, isTrue,
          reason: 'keyboard should open after tapping the amount field');

      await tester.tap(find.text('5'));
      await tester.pump();

      expect(inAppKeyboardOpen.value, isTrue,
          reason: 'keyboard must stay open when tapping a key on desktop');
      expect(controller.text, '5',
          reason: 'the tapped digit must be entered into the field');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('keyboard stays open when tapping empty page space on Linux',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await pumpPage(tester, controller);

      await tester.tap(find.byType(AmountInputField));
      await tester.pumpAndSettle();
      expect(inAppKeyboardOpen.value, isTrue);

      // Tap empty space between the field and the keyboard.
      await tester.tapAt(const Offset(200, 300));
      await tester.pump();

      expect(inAppKeyboardOpen.value, isTrue,
          reason: 'tapping empty space must not close the keyboard');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('keyboard closes when tapping another text field on desktop',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await pumpPage(tester, controller, withSecondField: true);

      await tester.tap(find.byType(AmountInputField));
      await tester.pumpAndSettle();
      expect(inAppKeyboardOpen.value, isTrue);

      // Tapping another text field moves focus away and must close the
      // keyboard (the amount field's focus listener handles dismissal).
      await tester.tap(find.byType(TextField).last);
      await tester.pumpAndSettle();

      expect(inAppKeyboardOpen.value, isFalse,
          reason: 'tapping another text field must close the keyboard');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
