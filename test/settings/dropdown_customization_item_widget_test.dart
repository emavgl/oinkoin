import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/preferences-options.dart';
import 'package:piggybank/settings/dropdown-customization-item.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The "Decimal digits" dropdown-customization dialog has 9 options
/// (0 through 8), which is enough to force scrolling on most screens. These
/// tests make sure the dialog never overflows its bounds — especially on
/// short viewports (small phones, landscape) and with larger accessibility
/// text scales — and that every option remains reachable by scrolling.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
  });

  Widget buildTestApp({required Widget child, double textScale = 1.0}) {
    return MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          // Override only textScaler, inheriting size/padding/devicePixelRatio
          // etc. from the ambient MediaQuery (which reflects setSurfaceSize).
          // Constructing a fresh MediaQueryData(textScaler: ...) instead would
          // reset `size` to Size.zero, silently breaking the dialog's own
          // MediaQuery.of(context).size-based maxHeight calculation.
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(body: child),
        ),
      ),
    );
  }

  Future<void> pumpDecimalDigitsItem(
    WidgetTester tester, {
    required Size surfaceSize,
    double textScale = 1.0,
  }) async {
    await tester.binding.setSurfaceSize(surfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildTestApp(
      textScale: textScale,
      child: DropdownCustomizationItem<int>(
        title: "Decimal digits",
        subtitle: "Select the number of decimal digits",
        dropdownValues: PreferencesOptions.decimalDigits,
        selectedDropdownKey: "2",
        sharedConfigKey: "numberDecimalDigits",
      ),
    ));
    await tester.pumpAndSettle();
  }

  group('Decimal digits dialog on small screens', () {
    testWidgets('opens without overflowing on a small phone (320x480)',
        (WidgetTester tester) async {
      await pumpDecimalDigitsItem(tester,
          surfaceSize: const Size(320, 480));

      await tester.tap(find.text('Decimal digits'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      // A RenderFlex overflow (or any other layout exception) would surface
      // here as a FlutterError caught by the test binding.
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'opens without overflowing on a short landscape viewport (800x360)',
        (WidgetTester tester) async {
      await pumpDecimalDigitsItem(tester,
          surfaceSize: const Size(800, 360));

      await tester.tap(find.text('Decimal digits'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'opens without overflowing at the max accessibility text scale (3.0)',
        (WidgetTester tester) async {
      // 3.0 matches Android's "Largest" accessibility text size setting.
      await pumpDecimalDigitsItem(tester,
          surfaceSize: const Size(320, 480), textScale: 3.0);

      await tester.tap(find.text('Decimal digits'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);

      // The OK button must still be reachable, not just present.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the last option ("8") is reachable by scrolling',
        (WidgetTester tester) async {
      await pumpDecimalDigitsItem(tester,
          surfaceSize: const Size(320, 480));

      await tester.tap(find.text('Decimal digits'));
      await tester.pumpAndSettle();

      // The dialog caps its height and the option list scrolls internally,
      // so the last option may not be laid out/visible until scrolled to.
      // Tap the whole RadioListTile (not the raw Text glyph) so the tap
      // lands reliably even right at the scrolled-to edge of the dialog.
      final lastOption = find.byWidgetPredicate(
          (w) => w is RadioListTile<String> && w.value == '8');
      await tester.dragUntilVisible(
        lastOption,
        find.byType(Scrollable).last,
        const Offset(0, -50),
      );
      expect(tester.takeException(), isNull);

      await tester.tap(lastOption);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // The tap above must have selected the option, not dismissed the
      // dialog by falling through to the modal barrier behind it.
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('8'), findsOneWidget); // reflected in the tile subtitle
      expect(tester.takeException(), isNull);
    });

    testWidgets('the OK button remains reachable and closes the dialog',
        (WidgetTester tester) async {
      await pumpDecimalDigitsItem(tester,
          surfaceSize: const Size(320, 480));

      await tester.tap(find.text('Decimal digits'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
