import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/helpers/alert-dialog-builder.dart';

/// Helper widget that displays an AlertDialogBuilder dialog and exposes
/// the result via a callback.
class DialogLauncher extends StatelessWidget {
  final AlertDialogBuilder Function() builderFn;

  const DialogLauncher({super.key, required this.builderFn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) {
          return ElevatedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => builderFn().build(context),
              );
            },
            child: const Text('Show Dialog'),
          );
        },
      ),
    );
  }
}

Widget _buildTestApp(Widget child) {
  return MaterialApp(home: child);
}

void main() {
  testWidgets('AlertDialogBuilder renders title and subtitle',
      (WidgetTester tester) async {
    final builder = AlertDialogBuilder('Test Title')
        .addSubtitle('Test subtitle content');

    await tester.pumpWidget(_buildTestApp(
      Builder(
        builder: (context) {
          return ElevatedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => builder.build(context),
              );
            },
            child: const Text('Show Dialog'),
          );
        },
      ),
    ));

    // Tap the button to show the dialog
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    // Verify title and subtitle are displayed
    expect(find.text('Test Title'), findsOneWidget);
    expect(find.text('Test subtitle content'), findsOneWidget);
  });

  testWidgets('AlertDialogBuilder renders default button names',
      (WidgetTester tester) async {
    final builder = AlertDialogBuilder('Title');

    await tester.pumpWidget(_buildTestApp(
      Builder(
        builder: (context) {
          return ElevatedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => builder.build(context),
              );
            },
            child: const Text('Show Dialog'),
          );
        },
      ),
    ));

    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    // Default button names should be "OK" (trueButton) and "Cancel" (falseButton)
    // "Cancel" is translated via .i18n, but in test context should fallback to "Cancel"
    // "OK" is the hard-coded default for trueButtonName
    expect(find.text('OK'), findsOneWidget);
  });

  testWidgets('Cancel button on the left, OK button on the right',
      (WidgetTester tester) async {
    final builder = AlertDialogBuilder('Title')
        .addTrueButtonName('Confirm')
        .addFalseButtonName('Dismiss');

    await tester.pumpWidget(_buildTestApp(
      Builder(
        builder: (context) {
          return ElevatedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => builder.build(context),
              );
            },
            child: const Text('Show Dialog'),
          );
        },
      ),
    ));

    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    // Find the two TextButtons
    final dismissButton = find.widgetWithText(TextButton, 'Dismiss');
    final confirmButton = find.widgetWithText(TextButton, 'Confirm');

    expect(dismissButton, findsOneWidget);
    expect(confirmButton, findsOneWidget);

    // Get the actions Row (the Column containing the button widgets)
    // We verify the order by checking their positions
    final dismissRect = tester.getRect(dismissButton);
    final confirmRect = tester.getRect(confirmButton);

    // Dismiss (Cancel) should be to the left of Confirm (OK)
    expect(dismissRect.left, lessThan(confirmRect.left));
  });

  testWidgets('OK button returns true, Cancel button returns false',
      (WidgetTester tester) async {
    bool? result;

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              final builder = AlertDialogBuilder('Test')
                  .addTrueButtonName('Yes')
                  .addFalseButtonName('No');
              result = await showDialog(
                context: context,
                builder: (_) => builder.build(context),
              );
            },
            child: const Text('Show Dialog'),
          );
        },
      ),
    ));

    // Test Cancel (false) button
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'No'));
    await tester.pumpAndSettle();

    expect(result, isFalse);

    // Test OK (true) button
    result = null;
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Yes'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });

  testWidgets('AlertDialogBuilder with custom title',
      (WidgetTester tester) async {
    final builder = AlertDialogBuilder('Original Title')
        .addTitle('Custom Title');

    await tester.pumpWidget(_buildTestApp(
      Builder(
        builder: (context) {
          return ElevatedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => builder.build(context),
              );
            },
            child: const Text('Show Dialog'),
          );
        },
      ),
    ));

    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Custom Title'), findsOneWidget);
    expect(find.text('Original Title'), findsNothing);
  });
}
