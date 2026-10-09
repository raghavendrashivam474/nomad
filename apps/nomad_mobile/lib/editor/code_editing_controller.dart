import 'package:flutter/material.dart';
import 'source_language.dart';

/// A lightweight, dependency-free syntax-highlighting TextEditingController.
/// Uses deterministic regex tokenization designed to never throw on malformed code.
class CodeEditingController extends TextEditingController {
  final SourceLanguage language;

  CodeEditingController({
    this.language = SourceLanguage.plainText,
    super.text,
  });

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final textVal = text;
    if (textVal.isEmpty || language == SourceLanguage.plainText) {
      return TextSpan(text: textVal, style: style);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (language) {
      case SourceLanguage.html:
        return _buildHtmlSpans(textVal, style, isDark);
      case SourceLanguage.css:
        return _buildCssSpans(textVal, style, isDark);
      case SourceLanguage.javascript:
        return _buildJsSpans(textVal, style, isDark);
      case SourceLanguage.plainText:
        return TextSpan(text: textVal, style: style);
    }
  }

  TextSpan _buildHtmlSpans(String code, TextStyle? baseStyle, bool isDark) {
    final spans = <TextSpan>[];

    // Syntax colors
    final tagColor = isDark ? const Color(0xFF569CD6) : const Color(0xFF0000FF);
    final attrColor = isDark ? const Color(0xFF9CDCFE) : const Color(0xFFFF0000);
    final stringColor = isDark ? const Color(0xFFCE9178) : const Color(0xFFA31515);
    final commentColor = isDark ? const Color(0xFF6A9955) : const Color(0xFF008000);
    final entityColor = isDark ? const Color(0xFFDCDCAA) : const Color(0xFF795E26);

    // Regex matching HTML tokens safely
    final htmlRegex = RegExp(
      r'(<!--[\s\S]*?-->)|' // 1: Comments
      r'(<!DOCTYPE[\s\S]*?>)|' // 2: DOCTYPE
      r'(</?[a-zA-Z0-9\-]+)|' // 3: Tag names
      r'(/?>)|' // 4: Tag close
      r'([a-zA-Z\-:]+)(?=\s*=)|' // 5: Attribute names
      r'("(?:[^"\\]|\\.)*"|' r"'(?:[^'\\]|\\.)*')|" // 6: Strings (attribute values)
      r'(&[a-zA-Z0-9#]+;)', // 7: Entities
      caseSensitive: false,
    );

    int lastMatchEnd = 0;

    try {
      for (final match in htmlRegex.allMatches(code)) {
        if (match.start > lastMatchEnd) {
          spans.add(TextSpan(
            text: code.substring(lastMatchEnd, match.start),
            style: baseStyle,
          ));
        }

        TextStyle? tokenStyle = baseStyle;

        if (match.group(1) != null) {
          // Comment
          tokenStyle = baseStyle?.copyWith(
            color: commentColor,
            fontStyle: FontStyle.italic,
          );
        } else if (match.group(2) != null) {
          // DOCTYPE
          tokenStyle = baseStyle?.copyWith(
            color: tagColor,
            fontWeight: FontWeight.bold,
          );
        } else if (match.group(3) != null) {
          // Tag name (<div, </span)
          tokenStyle = baseStyle?.copyWith(
            color: tagColor,
            fontWeight: FontWeight.bold,
          );
        } else if (match.group(4) != null) {
          // Tag brackets (> or />)
          tokenStyle = baseStyle?.copyWith(color: tagColor);
        } else if (match.group(5) != null) {
          // Attribute name (class=, href=)
          tokenStyle = baseStyle?.copyWith(color: attrColor);
        } else if (match.group(6) != null) {
          // Quoted string
          tokenStyle = baseStyle?.copyWith(color: stringColor);
        } else if (match.group(7) != null) {
          // HTML entity
          tokenStyle = baseStyle?.copyWith(color: entityColor);
        }

        spans.add(TextSpan(
          text: code.substring(match.start, match.end),
          style: tokenStyle,
        ));
        lastMatchEnd = match.end;
      }

      if (lastMatchEnd < code.length) {
        spans.add(TextSpan(
          text: code.substring(lastMatchEnd),
          style: baseStyle,
        ));
      }
    } catch (_) {
      // Fallback cleanly on any unexpected regex edge case
      return TextSpan(text: code, style: baseStyle);
    }

    return TextSpan(children: spans, style: baseStyle);
  }

  // Placeholder for CSS (implemented in S0.1.3)
  TextSpan _buildCssSpans(String code, TextStyle? baseStyle, bool isDark) {
    return _buildHtmlSpans(code, baseStyle, isDark);
  }

  // Placeholder for JS (implemented in S0.1.4)
  TextSpan _buildJsSpans(String code, TextStyle? baseStyle, bool isDark) {
    return _buildHtmlSpans(code, baseStyle, isDark);
  }
}