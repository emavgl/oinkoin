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

  testWidgets('rapid taps on different keys all register', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await pumpPage(tester, controller);
    await tester.tap(find.byType(AmountInputField));
    await tester.pumpAndSettle();
    expect(inAppKeyboardOpen.value, isTrue);

    // Three taps back to back without letting a frame pass in between.
    await tester.tap(find.widgetWithText(CalculatorButton, '1'));
    await tester.tap(find.widgetWithText(CalculatorButton, '2'));
    await tester.tap(find.widgetWithText(CalculatorButton, '3'));
    await tester.pump();

    expect(controller.text, '123',
        reason: 'fast taps must all be entered, got "${controller.text}"');
  });

  testWidgets('repeated taps on the same key all register', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await pumpPage(tester, controller);
    await tester.tap(find.byType(AmountInputField));
    await tester.pumpAndSettle();

    Finder key(String label) => find.widgetWithText(CalculatorButton, label);
    await tester.tap(key('7'));
    await tester.tap(key('7'));
    await tester.tap(key('7'));
    await tester.pump();

    expect(controller.text, '777',
        reason: 'fast taps on one key must repeat, got "${controller.text}"');
  });

  testWidgets('a tap during the slide-in animation registers', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await pumpPage(tester, controller);

    // Open and let the overlay be inserted, but stop while it is still
    // sliding in (the entrance is 250ms).
    await tester.tap(find.byType(AmountInputField));
    await tester.pump();
    expect(inAppKeyboardOpen.value, isTrue);

    // Record where the "5" key ends up, once the animation is done.
    await tester.pumpAndSettle();
    final target = tester.getCenter(find.widgetWithText(CalculatorButton, '5'));
    final settledText = controller.text;

    // Close and reopen, then tap that same screen position early in the
    // entrance animation — what a fast user does.
    dismissInAppKeyboard();
    await tester.pumpAndSettle();
    expect(inAppKeyboardOpen.value, isFalse);

    await tester.tap(find.byType(AmountInputField));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(target);
    await tester.pumpAndSettle();

    expect(controller.text, '${settledText}5',
        reason: 'a tap aimed at a key while the keyboard is still sliding in '
            'must reach that key, got "${controller.text}"');
  });

  testWidgets('taps right after the animation finishes register',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await pumpPage(tester, controller);
    await tester.tap(find.byType(AmountInputField));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(CalculatorButton, '4'));
    await tester.pump();
    expect(controller.text, '4');
  });

  testWidgets('a key held for 200ms registers on release', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await pumpPage(tester, controller);
    await tester.tap(find.byType(AmountInputField));
    await tester.pumpAndSettle();

    final gesture =
        await tester.startGesture(tester.getCenter(find.ancestor(of: find.text('9'), matching: find.byType(CalculatorButton))));
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await tester.pump();

    expect(controller.text, '9',
        reason: 'a key pressed a bit longer than the tap deadline must still '
            'enter its digit, got "${controller.text}"');
  });

  testWidgets('two fingers on two keys at once both register', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await pumpPage(tester, controller);
    await tester.tap(find.byType(AmountInputField));
    await tester.pumpAndSettle();

    final g1 =
        await tester.startGesture(tester.getCenter(find.ancestor(of: find.text('1'), matching: find.byType(CalculatorButton))));
    final g2 =
        await tester.startGesture(tester.getCenter(find.ancestor(of: find.text('2'), matching: find.byType(CalculatorButton))));
    await tester.pump();
    await g1.up();
    await g2.up();
    await tester.pump();

    expect(controller.text, '12',
        reason: 'overlapping taps on two keys must both be entered, '
            'got "${controller.text}"');
  });

  testWidgets('a tap during the slide-in does not hit the page behind',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    var pagePointerDowns = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              // Fills the screen: every pointer the overlay does not absorb
              // reaches this listener.
              Positioned.fill(
                child: Listener(
                  onPointerDown: (_) => pagePointerDowns += 1,
                  behavior: HitTestBehavior.opaque,
                  child: const SizedBox.expand(),
                ),
              ),
              Column(
                children: [AmountInputField(controller: controller)],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(AmountInputField));
    await tester.pumpAndSettle();
    expect(inAppKeyboardOpen.value, isTrue);

    // Where the "5" key ends up once settled.
    final target = tester.getCenter(find.widgetWithText(CalculatorButton, '5'));

    // Settled: the keyboard absorbs its own footprint.
    final downsBefore = pagePointerDowns;
    await tester.tapAt(target);
    await tester.pump();
    expect(pagePointerDowns, downsBefore,
        reason: 'once settled, a tap on a key must not reach the page behind');

    dismissInAppKeyboard();
    await tester.pumpAndSettle();

    await tester.tap(find.byType(AmountInputField));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(target);
    await tester.pumpAndSettle();

    expect(pagePointerDowns, downsBefore,
        reason: 'a tap aimed at the keyboard must not fall through to the '
            'page underneath while the keyboard is still sliding in');
  });
}
