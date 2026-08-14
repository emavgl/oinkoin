import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/components/markup_text.dart';

void main() {
  test('detects supported markup and ignores ordinary text', () {
    expect(containsMarkup('Select the <b>origin</b> wallet'), isTrue);
    expect(containsMarkup('Select the origin wallet'), isFalse);
  });

  test('converts formatting tags into styled spans', () {
    final span = markupTextSpan('Move <b>origin</b> <i>now</i> <u>here</u>');

    expect(span.toPlainText(), 'Move origin now here');
    expect(span.children![1].style?.fontWeight, FontWeight.bold);
    expect(span.children![3].style?.fontStyle, FontStyle.italic);
    expect(span.children![5].style?.decoration, TextDecoration.underline);
  });

  testWidgets('renders ordinary localized text without markup as Text',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MarkupText('A regular localized string'),
        ),
      ),
    );

    expect(find.byType(Text), findsOneWidget);
  });

  testWidgets('preserves the surrounding font when applying a custom style',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DefaultTextStyle(
          style: const TextStyle(fontFamily: 'AppFont', fontSize: 14),
          child: const MarkupText(
            'Select the <b>origin</b> wallet',
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    );

    final richText = tester.widget<RichText>(find.byType(RichText));
    final rootSpan = richText.text as TextSpan;
    expect(rootSpan.style?.fontFamily, 'AppFont');
    expect(rootSpan.style?.fontSize, 18);
  });

  testWidgets('renders localized markup as RichText without visible tags',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MarkupText('Select the <b>origin</b> wallet'),
        ),
      ),
    );

    final richText = tester.widget<RichText>(find.byType(RichText));
    expect(richText.text.toPlainText(), 'Select the origin wallet');
    expect(find.textContaining('<b>'), findsNothing);
  });
}
