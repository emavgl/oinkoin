import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/components/markup_text.dart';
import 'package:piggybank/records/components/transfer_wallet_selector.dart';

void main() {
  Future<void> pumpInstruction(
      WidgetTester tester, bool hasOrigin) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TransferWalletInstruction(hasOrigin: hasOrigin),
        ),
      ),
    );
  }

  testWidgets('shows and emphasizes the origin instruction initially',
      (tester) async {
    await pumpInstruction(tester, false);

    final markupText = tester.widget<MarkupText>(find.byType(MarkupText));
    final richText = tester.widget<RichText>(find.byType(RichText));

    expect(markupText.text, 'Select the <b>origin</b> wallet');
    expect(richText.text.toPlainText(), 'Select the origin wallet');
    final rootSpan = richText.text as TextSpan;
    expect(rootSpan.children![1].style?.fontWeight, FontWeight.bold);
  });

  testWidgets('shows and emphasizes the destination instruction after origin',
      (tester) async {
    await pumpInstruction(tester, true);

    final markupText = tester.widget<MarkupText>(find.byType(MarkupText));
    final richText = tester.widget<RichText>(find.byType(RichText));

    expect(markupText.text, 'Select the <b>destination</b> wallet');
    expect(richText.text.toPlainText(), 'Select the destination wallet');
    final rootSpan = richText.text as TextSpan;
    expect(rootSpan.children![1].style?.fontWeight, FontWeight.bold);
  });
}
