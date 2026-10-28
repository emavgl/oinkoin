import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/components/amount_input_field.dart';
import 'package:piggybank/components/inapp-keyboard.dart';
import 'package:piggybank/helpers/amount-input-utils.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    ServiceConfig.localTimezone = 'Europe/Vienna';
    SharedPreferences.setMockInitialValues({
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

  Future<void> pumpPage(
    WidgetTester tester,
    TextEditingController controller,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              AmountInputField(controller: controller),
              const SizedBox(height: 400),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder key(String label) => find.widgetWithText(CalculatorButton, label);

  Future<void> openKeyboard(WidgetTester tester) async {
    await tester.tap(find.byType(AmountInputField));
    await tester.pumpAndSettle();
    expect(inAppKeyboardOpen.value, isTrue);
  }

  testWidgets('typing with the caret in the middle inserts at the caret',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await pumpPage(tester, controller);
    await openKeyboard(tester);

    for (final digit in ['1', '2', '3', '4']) {
      await tester.tap(key(digit));
      await tester.pump();
    }
    expect(controller.text, '1,234');

    // Simulate the user tapping between the "1" and the "2".
    controller.selection = const TextSelection.collapsed(offset: 1);
    await tester.pump();

    await tester.tap(key('5'));
    await tester.pump();

    expect(controller.text, '15,234',
        reason: 'the typed digit must go where the caret is, '
            'got "${controller.text}"');
    expect(controller.selection.baseOffset, 2,
        reason: 'the caret must stay after the typed digit');
  });

  testWidgets('backspace with the caret in the middle deletes at the caret',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await pumpPage(tester, controller);
    await openKeyboard(tester);

    for (final digit in ['1', '2', '3', '4']) {
      await tester.tap(key(digit));
      await tester.pump();
    }
    expect(controller.text, '1,234');

    controller.selection = const TextSelection.collapsed(offset: 1);
    await tester.pump();

    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.pump();

    expect(controller.text, '234',
        reason: 'backspace must delete the character before the caret, '
            'got "${controller.text}"');
    expect(controller.selection.baseOffset, 0);
  });

  testWidgets('replacing a selected range writes at the selection',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await pumpPage(tester, controller);
    await openKeyboard(tester);

    for (final digit in ['1', '2', '3', '4']) {
      await tester.tap(key(digit));
      await tester.pump();
    }

    // Select "23" inside "1,234" and replace it with a "9".
    controller.selection = const TextSelection(baseOffset: 2, extentOffset: 4);
    await tester.pump();

    await tester.tap(key('9'));
    await tester.pump();

    expect(controller.text, '194');
    expect(controller.selection.baseOffset, 2);
  });
}
