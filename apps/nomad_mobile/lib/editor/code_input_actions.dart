import 'package:flutter/material.dart';

/// Safe, tested text-editing operations for the coding accessory.
///
/// All operations work on a [TextEditingController] and preserve
/// selection, cursor position, and change notifications so that
/// the existing dirty-state tracking and syntax highlighting
/// continue to work without modification.
class CodeInputActions {
  CodeInputActions._();

  // ------------------------------------------------------------------
  // Symbol / text insertion
  // ------------------------------------------------------------------

  /// Inserts [text] at the current cursor, replacing any selection.
  /// Returns the new cursor offset after insertion.
  static int insertText(TextEditingController controller, String text) {
    final selection = controller.selection;
    final value = controller.text;

    if (!selection.isValid) {
      final newOffset = value.length + text.length;
      controller.value = TextEditingValue(
        text: value + text,
        selection: TextSelection.collapsed(offset: newOffset),
      );
      return newOffset;
    }

    final start = selection.start;
    final end = selection.end;
    final newText = value.substring(0, start) + text + value.substring(end);
    final newOffset = start + text.length;

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
    return newOffset;
  }

  // ------------------------------------------------------------------
  // Paired delimiters
  // ------------------------------------------------------------------

  /// Inserts a paired delimiter around the selection or at the cursor.
  ///
  /// * Collapsed cursor → inserts `open` + `close`, cursor between them.
  /// * Non-empty selection → wraps selected text, keeps it selected.
  static int insertPaired(
    TextEditingController controller,
    String open,
    String close,
  ) {
    final selection = controller.selection;
    final value = controller.text;

    if (!selection.isValid) {
      final pair = open + close;
      final newOffset = value.length + open.length;
      controller.value = TextEditingValue(
        text: value + pair,
        selection: TextSelection.collapsed(offset: newOffset),
      );
      return newOffset;
    }

    final start = selection.start;
    final end = selection.end;
    final selected = value.substring(start, end);
    final newText = value.substring(0, start) +
        open +
        selected +
        close +
        value.substring(end);

    if (selection.isCollapsed) {
      final cursor = start + open.length;
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: cursor),
      );
      return cursor;
    }

    final newStart = start + open.length;
    final newEnd = newStart + selected.length;
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection(baseOffset: newStart, extentOffset: newEnd),
    );
    return newEnd;
  }

  // ------------------------------------------------------------------
  // Cursor navigation
  // ------------------------------------------------------------------

  /// Moves the cursor left by [count] characters.
  static void moveCursorLeft(TextEditingController controller,
      {int count = 1}) {
    final sel = controller.selection;
    if (!sel.isValid) return;
    final offset = (sel.extentOffset - count).clamp(0, controller.text.length);
    controller.selection = TextSelection.collapsed(offset: offset);
  }

  /// Moves the cursor right by [count] characters.
  static void moveCursorRight(TextEditingController controller,
      {int count = 1}) {
    final sel = controller.selection;
    if (!sel.isValid) return;
    final offset = (sel.extentOffset + count).clamp(0, controller.text.length);
    controller.selection = TextSelection.collapsed(offset: offset);
  }

  /// Moves the cursor to the start of the current line.
  static void moveCursorToLineStart(TextEditingController controller) {
    final sel = controller.selection;
    if (!sel.isValid) return;
    final text = controller.text;
    final pos = sel.extentOffset;
    final searchPos = (pos - 1).clamp(0, text.length);
    final lineStart = pos == 0 ? 0 : text.lastIndexOf('\n', searchPos) + 1;
    controller.selection =
        TextSelection.collapsed(offset: lineStart.clamp(0, text.length));
  }

  /// Moves the cursor to the end of the current line.
  static void moveCursorToLineEnd(TextEditingController controller) {
    final sel = controller.selection;
    if (!sel.isValid) return;
    final text = controller.text;
    final pos = sel.extentOffset;
    var lineEnd = text.indexOf('\n', pos);
    if (lineEnd == -1) lineEnd = text.length;
    controller.selection = TextSelection.collapsed(offset: lineEnd);
  }

  // ------------------------------------------------------------------
  // Indentation
  // ------------------------------------------------------------------

  /// Indents the current line or all selected lines by prepending
  /// [indent] (default two spaces) to each line.
  static void indent(TextEditingController controller, {String indent = '  '}) {
    final sel = controller.selection;
    final text = controller.text;
    if (!sel.isValid) return;

    final start = sel.start;
    final end = sel.end;

    final searchStart = (start - 1).clamp(0, text.length);
    final lineStart = start == 0 ? 0 : text.lastIndexOf('\n', searchStart) + 1;
    var lineEnd = text.indexOf('\n', end);
    if (lineEnd == -1) lineEnd = text.length;

    final block = text.substring(lineStart, lineEnd);
    final lines = block.split('\n');
    final indented = lines.map((l) => indent + l).toList();
    final newBlock = indented.join('\n');
    final newText =
        text.substring(0, lineStart) + newBlock + text.substring(lineEnd);

    final indentLen = indent.length;
    final newStart = start + indentLen;
    final added = indentLen * lines.length;
    final newEnd = end + added;

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: newStart.clamp(0, newText.length),
        extentOffset: newEnd.clamp(0, newText.length),
      ),
    );
  }

  /// Unindents the current line or all selected lines by removing up
  /// to [indent] characters from the start of each line.
  static void unindent(TextEditingController controller,
      {String indent = '  '}) {
    final sel = controller.selection;
    final text = controller.text;
    if (!sel.isValid) return;

    final start = sel.start;
    final end = sel.end;

    final searchStart = (start - 1).clamp(0, text.length);
    final lineStart = start == 0 ? 0 : text.lastIndexOf('\n', searchStart) + 1;
    var lineEnd = text.indexOf('\n', end);
    if (lineEnd == -1) lineEnd = text.length;

    final block = text.substring(lineStart, lineEnd);
    final lines = block.split('\n');

    int totalRemoved = 0;
    int firstLineRemoved = 0;
    final result = <String>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      int remove = 0;
      for (var j = 0; j < indent.length && j < line.length; j++) {
        if (line[j] == indent[j]) {
          remove++;
        } else {
          break;
        }
      }
      if (i == 0) firstLineRemoved = remove;
      totalRemoved += remove;
      result.add(line.substring(remove));
    }

    final newBlock = result.join('\n');
    final newText =
        text.substring(0, lineStart) + newBlock + text.substring(lineEnd);

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: (start - firstLineRemoved).clamp(0, newText.length),
        extentOffset: (end - totalRemoved).clamp(0, newText.length),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Templates / snippets
  // ------------------------------------------------------------------

  /// Inserts [template] at the cursor and places the cursor at
  /// [cursorOffset] characters from the start of the inserted text.
  static int insertTemplate(
    TextEditingController controller,
    String template,
    int cursorOffset,
  ) {
    final insertPos = insertText(controller, template);
    final newCursor = (insertPos - template.length + cursorOffset)
        .clamp(0, controller.text.length);
    controller.selection = TextSelection.collapsed(offset: newCursor);
    return newCursor;
  }
}
