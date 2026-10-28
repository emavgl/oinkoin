import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/components/amount_input_field.dart';
import 'package:piggybank/helpers/amount-input-utils.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// End-to-end checks for edits coming from the system keyboard: the platform
/// sends the whole new text plus the caret position, and the formatter chain
/// must keep the caret where the user typed.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    ServiceConfig.localTimezone = 'Europe/Vienna';
    SharedPreferences.setMockInitialValues({'amountInputKeyboardType': 0});
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
            children: [AmountInputField(controller: controller)],
          ),
        ),
      ),
    );
    await tester.tap(find.byType(AmountInputField));
    await tester.pumpAndSettle();
  }

  testWidgets('inserting a digit in the middle keeps the caret', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await pumpPage(tester, controller);

    tester.testTextInput.updateEditingValue(const TextEditingValue(
      text: '1234',
      selection: TextSelection.collapsed(offset: 4),
    ));
    await tester.pump();
    expect(controller.text, '1,234');

    // The user placed the caret after the "1" and typed a "5".
    tester.testTextInput.updateEditingValue(const TextEditingValue(
      text: '15,234',
      selection: TextSelection.collapsed(offset: 2),
    ));
    await tester.pump();

    expect(controller.text, '15,234',
        reason: 'the digit must stay where the caret is, '
            'got "${controller.text}"');
    expect(controller.selection.baseOffset, 2);
  });

  testWidgets('backspace in the middle deletes at the caret', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await pumpPage(tester, controller);

    tester.testTextInput.updateEditingValue(const TextEditingValue(
      text: '15234',
      selection: TextSelection.collapsed(offset: 5),
    ));
    await tester.pump();
    expect(controller.text, '15,234');

    // Caret after the "1", backspace removes the "5".
    tester.testTextInput.updateEditingValue(const TextEditingValue(
      text: '1,234',
      selection: TextSelection.collapsed(offset: 1),
    ));
    await tester.pump();

    expect(controller.text, '1,234',
        reason: 'backspace must delete before the caret, '
            'got "${controller.text}"');
    expect(controller.selection.baseOffset, 1);
  });
}
