import 'package:flutter/material.dart';

/// Returns whether [text] contains one of the supported inline formatting tags.
bool containsMarkup(String text) =>
    _markupTagRegExp.hasMatch(text);

const _markupTagPattern =
    r'<\/?(?:b|strong|i|em|u)>';

final _markupTagRegExp = RegExp(
  _markupTagPattern,
  caseSensitive: false,
);

/// Converts supported inline markup in [text] into a [TextSpan] tree.
///
/// Supported tags are `<b>`/`<strong>`, `<i>`/`<em>`, and `<u>`. Tags are
/// intentionally kept in the locale strings so translators can move them
/// around the translated word when the sentence structure changes.
TextSpan markupTextSpan(String text, {TextStyle? style}) {
  if (!containsMarkup(text)) {
    return TextSpan(text: text, style: style);
  }

  final children = <TextSpan>[];
  final openTags = <String>[];
  var cursor = 0;

  for (final match in _markupTagRegExp.allMatches(text)) {
    if (match.start > cursor) {
      children.add(_plainTextSpan(
        text.substring(cursor, match.start),
        openTags,
      ));
    }

    final rawTag = match.group(0)!;
    final isClosingTag = rawTag.startsWith('</');
    final tag = rawTag
        .replaceAll(RegExp(r'[</>]'), '')
        .toLowerCase();
    final normalizedTag = tag == 'strong'
        ? 'b'
        : tag == 'em'
            ? 'i'
            : tag;

    if (isClosingTag) {
      final openIndex = openTags.lastIndexOf(normalizedTag);
      if (openIndex != -1) openTags.removeAt(openIndex);
    } else {
      openTags.add(normalizedTag);
    }
    cursor = match.end;
  }

  if (cursor < text.length) {
    children.add(_plainTextSpan(text.substring(cursor), openTags));
  }

  return TextSpan(style: style, children: children);
}

TextSpan _plainTextSpan(String text, List<String> openTags) {
  return TextSpan(
    text: text,
    style: TextStyle(
      fontWeight:
          openTags.contains('b') ? FontWeight.bold : null,
      fontStyle: openTags.contains('i') ? FontStyle.italic : null,
      decoration:
          openTags.contains('u') ? TextDecoration.underline : null,
    ),
  );
}

/// Displays localized text containing supported inline formatting tags.
///
/// When no supported markup is present, this behaves like a regular [Text]
/// widget. This makes it safe to use with ordinary localized strings too.
class MarkupText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow overflow;
  final bool? softWrap;

  const MarkupText(
    this.text, {
    Key? key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.softWrap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!containsMarkup(text)) {
      return Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        softWrap: softWrap,
      );
    }

    final effectiveStyle =
        DefaultTextStyle.of(context).style.merge(style);

    return RichText(
      text: markupTextSpan(
        text,
        style: effectiveStyle,
      ),
      textAlign: textAlign ?? TextAlign.start,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap ?? true,
    );
  }
}
