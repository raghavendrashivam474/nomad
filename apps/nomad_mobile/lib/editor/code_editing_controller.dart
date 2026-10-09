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

    final tagColor = isDark ? const Color(0xFF569CD6) : const Color(0xFF0000FF);
    final attrColor = isDark ? const Color(0xFF9CDCFE) : const Color(0xFFFF0000);
    final stringColor = isDark ? const Color(0xFFCE9178) : const Color(0xFFA31515);
    final commentColor = isDark ? const Color(0xFF6A9955) : const Color(0xFF008000);
    final entityColor = isDark ? const Color(0xFFDCDCAA) : const Color(0xFF795E26);

    final htmlRegex = RegExp(
      r'(<!--[\s\S]*?-->)|' // 1: Comments
      r'(<!DOCTYPE[\s\S]*?>)|' // 2: DOCTYPE
      r'(</?[a-zA-Z0-9\-]+)|' // 3: Tag names
      r'(/?>)|' // 4: Tag close
      r'([a-zA-Z\-:]+)(?=\s*=)|' // 5: Attribute names
      r'("(?:[^"\\]|\\.)*"|' r"'(?:[^'\\]|\\.)*')|" // 6: Strings
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
          tokenStyle = baseStyle?.copyWith(
            color: commentColor,
            fontStyle: FontStyle.italic,
          );
        } else if (match.group(2) != null) {
          tokenStyle = baseStyle?.copyWith(
            color: tagColor,
            fontWeight: FontWeight.bold,
          );
        } else if (match.group(3) != null) {
          tokenStyle = baseStyle?.copyWith(
            color: tagColor,
            fontWeight: FontWeight.bold,
          );
        } else if (match.group(4) != null) {
          tokenStyle = baseStyle?.copyWith(color: tagColor);
        } else if (match.group(5) != null) {
          tokenStyle = baseStyle?.copyWith(color: attrColor);
        } else if (match.group(6) != null) {
          tokenStyle = baseStyle?.copyWith(color: stringColor);
        } else if (match.group(7) != null) {
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
      return TextSpan(text: code, style: baseStyle);
    }

    return TextSpan(children: spans, style: baseStyle);
  }

  TextSpan _buildCssSpans(String code, TextStyle? baseStyle, bool isDark) {
    final spans = <TextSpan>[];

    final commentColor = isDark ? const Color(0xFF6A9955) : const Color(0xFF008000);
    final atRuleColor = isDark ? const Color(0xFFC586C0) : const Color(0xFFAF00DB);
    final selectorColor = isDark ? const Color(0xFFD7BA7D) : const Color(0xFF800000);
    final propertyColor = isDark ? const Color(0xFF9CDCFE) : const Color(0xFF001080);
    final valueColor = isDark ? const Color(0xFFB5CEA8) : const Color(0xFF098658);
    final stringColor = isDark ? const Color(0xFFCE9178) : const Color(0xFFA31515);

    final cssRegex = RegExp(
      r'(/\*[\s\S]*?\*/)|' // 1: Comments /* ... */
      r'(@[a-zA-Z\-]+)|' // 2: At-rules (@media, @import, @keyframes)
      r'("(?:[^"\\]|\\.)*"|' r"'(?:[^'\\]|\\.)*')|" // 3: Strings
      r'([a-zA-Z\-]+)(?=\s*:)|' // 4: Property names (color, margin-top)
      r'(#[a-fA-F0-9]{3,8}\b)|' // 5: Hex Colors (#fff, #38bdf8)
      r'(\b\d+(?:\.\d+)?(?:px|rem|em|vh|vw|%|s|ms|deg)?\b)|' // 6: Numbers & units
      r'(\.[a-zA-Z0-9_\-]+|#[a-zA-Z0-9_\-]+|::?[a-zA-Z\-]+)', // 7: Selectors (.class, #id, :hover)
      caseSensitive: false,
    );

    int lastMatchEnd = 0;

    try {
      for (final match in cssRegex.allMatches(code)) {
        if (match.start > lastMatchEnd) {
          spans.add(TextSpan(
            text: code.substring(lastMatchEnd, match.start),
            style: baseStyle,
          ));
        }

        TextStyle? tokenStyle = baseStyle;

        if (match.group(1) != null) {
          tokenStyle = baseStyle?.copyWith(
            color: commentColor,
            fontStyle: FontStyle.italic,
          );
        } else if (match.group(2) != null) {
          tokenStyle = baseStyle?.copyWith(
            color: atRuleColor,
            fontWeight: FontWeight.bold,
          );
        } else if (match.group(3) != null) {
          tokenStyle = baseStyle?.copyWith(color: stringColor);
        } else if (match.group(4) != null) {
          tokenStyle = baseStyle?.copyWith(color: propertyColor);
        } else if (match.group(5) != null || match.group(6) != null) {
          tokenStyle = baseStyle?.copyWith(color: valueColor);
        } else if (match.group(7) != null) {
          tokenStyle = baseStyle?.copyWith(
            color: selectorColor,
            fontWeight: FontWeight.w600,
          );
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
      return TextSpan(text: code, style: baseStyle);
    }

    return TextSpan(children: spans, style: baseStyle);
  }

  TextSpan _buildJsSpans(String code, TextStyle? baseStyle, bool isDark) {
    final spans = <TextSpan>[];

    final commentColor = isDark ? const Color(0xFF6A9955) : const Color(0xFF008000);
    final keywordColor = isDark ? const Color(0xFF569CD6) : const Color(0xFF0000FF);
    final controlColor = isDark ? const Color(0xFFC586C0) : const Color(0xFFAF00DB);
    final stringColor = isDark ? const Color(0xFFCE9178) : const Color(0xFFA31515);
    final numberColor = isDark ? const Color(0xFFB5CEA8) : const Color(0xFF098658);
    final functionColor = isDark ? const Color(0xFFDCDCAA) : const Color(0xFF795E26);
    final globalColor = isDark ? const Color(0xFF4EC9B0) : const Color(0xFF267F99);

    final jsRegex = RegExp(
      r'(/\*[\s\S]*?\*/|//[^\r\n]*)|' // 1: Comments (single or multi-line)
      r'("(?:[^"\\]|\\.)*"|' r"'(?:[^'\\]|\\.)*'|" r'`(?:[^`\\]|\\.)*`)|' // 2: Strings & template literals
      r'(\b(?:break|case|catch|continue|default|do|else|finally|for|if|return|switch|throw|try|while|yield|await)\b)|' // 3: Control flow keywords
      r'(\b(?:const|let|var|function|class|extends|new|this|super|import|export|from|as|async|typeof|instanceof|void|delete|in|of)\b)|' // 4: Declaration & operator keywords
      r'(\b(?:true|false|null|undefined|NaN|Infinity)\b)|' // 5: Built-in literals
      r'(\b(?:document|window|console|Math|JSON|Object|Array|Promise|Set|Map|String|Number|Boolean|Event)\b)|' // 6: Standard globals
      r'(\b[a-zA-Z_$][a-zA-Z0-9_$]*(?=\s*\())|' // 7: Function calls: identifier(
      r'(\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b|0x[a-fA-F0-9]+)', // 8: Numbers (decimal/scientific/hex)
    );

    int lastMatchEnd = 0;

    try {
      for (final match in jsRegex.allMatches(code)) {
        if (match.start > lastMatchEnd) {
          spans.add(TextSpan(
            text: code.substring(lastMatchEnd, match.start),
            style: baseStyle,
          ));
        }

        TextStyle? tokenStyle = baseStyle;

        if (match.group(1) != null) {
          // Comments
          tokenStyle = baseStyle?.copyWith(
            color: commentColor,
            fontStyle: FontStyle.italic,
          );
        } else if (match.group(2) != null) {
          // Strings
          tokenStyle = baseStyle?.copyWith(color: stringColor);
        } else if (match.group(3) != null) {
          // Control flow keywords
          tokenStyle = baseStyle?.copyWith(
            color: controlColor,
            fontWeight: FontWeight.bold,
          );
        } else if (match.group(4) != null) {
          // Declaration & operator keywords
          tokenStyle = baseStyle?.copyWith(
            color: keywordColor,
            fontWeight: FontWeight.bold,
          );
        } else if (match.group(5) != null) {
          // Literals
          tokenStyle = baseStyle?.copyWith(
            color: keywordColor,
          );
        } else if (match.group(6) != null) {
          // Globals
          tokenStyle = baseStyle?.copyWith(
            color: globalColor,
          );
        } else if (match.group(7) != null) {
          // Function calls
          tokenStyle = baseStyle?.copyWith(
            color: functionColor,
          );
        } else if (match.group(8) != null) {
          // Numbers
          tokenStyle = baseStyle?.copyWith(
            color: numberColor,
          );
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
      return TextSpan(text: code, style: baseStyle);
    }

    return TextSpan(children: spans, style: baseStyle);
  }
}