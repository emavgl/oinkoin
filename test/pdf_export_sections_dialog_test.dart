import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/records/components/pdf_export_sections_dialog.dart';
import 'package:piggybank/services/pdf-service.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(home: child);
}

Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.text('Show Dialog'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('all sections are selected by default', (tester) async {
    await tester.pumpWidget(_buildTestApp(Builder(
      builder: (context) => ElevatedButton(
        onPressed: () => showDialog(
          context: context,
          builder: (context) => const PdfExportSectionsDialog(),
        ),
        child: const Text('Show Dialog'),
      ),
    )));
    await _openDialog(tester);

    for (final section in PdfSection.values) {
      expect(
        find.widgetWithText(CheckboxListTile, switch (section) {
          PdfSection.expenses => 'Expenses',
          PdfSection.income => 'Income',
          PdfSection.balance => 'Balance',
          PdfSection.records => 'Records',
        }),
        findsOneWidget,
      );
    }
    expect(
      tester
          .widget<CheckboxListTile>(find.widgetWithText(
              CheckboxListTile, 'Expenses'))
          .value,
      isTrue,
    );
    expect(
      tester
          .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'Select all'))
          .value,
      isTrue,
    );
  });

  testWidgets('cancel returns null', (tester) async {
    Set<PdfSection>? result;
    await tester.pumpWidget(_buildTestApp(Builder(
      builder: (context) => ElevatedButton(
        onPressed: () async {
          result = await showDialog<Set<PdfSection>>(
            context: context,
            builder: (context) => const PdfExportSectionsDialog(),
          );
        },
        child: const Text('Show Dialog'),
      ),
    )));
    await _openDialog(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('confirm returns all sections by default', (tester) async {
    Set<PdfSection>? result;
    await tester.pumpWidget(_buildTestApp(Builder(
      builder: (context) => ElevatedButton(
        onPressed: () async {
          result = await showDialog<Set<PdfSection>>(
            context: context,
            builder: (context) => const PdfExportSectionsDialog(),
          );
        },
        child: const Text('Show Dialog'),
      ),
    )));
    await _openDialog(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Export'));
    await tester.pumpAndSettle();

    expect(result, PdfSection.values.toSet());
  });

  testWidgets('deselected sections are omitted from the result',
      (tester) async {
    Set<PdfSection>? result;
    await tester.pumpWidget(_buildTestApp(Builder(
      builder: (context) => ElevatedButton(
        onPressed: () async {
          result = await showDialog<Set<PdfSection>>(
            context: context,
            builder: (context) => const PdfExportSectionsDialog(),
          );
        },
        child: const Text('Show Dialog'),
      ),
    )));
    await _openDialog(tester);

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Records'));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Export'));
    await tester.pumpAndSettle();

    expect(result, {PdfSection.expenses, PdfSection.income, PdfSection.balance});
  });

  testWidgets('export is disabled when nothing is selected', (tester) async {
    await tester.pumpWidget(_buildTestApp(Builder(
      builder: (context) => ElevatedButton(
        onPressed: () => showDialog(
          context: context,
          builder: (context) => const PdfExportSectionsDialog(),
        ),
        child: const Text('Show Dialog'),
      ),
    )));
    await _openDialog(tester);

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Select all'));
    await tester.pump();

    final exportButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Export'));
    expect(exportButton.onPressed, isNull);
  });
}