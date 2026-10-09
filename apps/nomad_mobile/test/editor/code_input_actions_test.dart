import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_mobile/editor/code_input_actions.dart';

void main() {
  late TextEditingController ctrl;

  setUp(() {
    ctrl = TextEditingController();
  });

  tearDown(() {
    ctrl.dispose();
  });

  // ================================================================
  // insertText
  // ================================================================
  group('insertText', () {
    test('into empty document', () {
      final offset = CodeInputActions.insertText(ctrl, 'hello');
      expect(ctrl.text, 'hello');
      expect(offset, 5);
      expect(ctrl.selection.baseOffset, 5);
    });

    test('at beginning of existing text', () {
      ctrl.text = 'world';
      ctrl.selection = const TextSelection.collapsed(offset: 0);
      CodeInputActions.insertText(ctrl, 'hello ');
      expect(ctrl.text, 'hello world');
      expect(ctrl.selection.baseOffset, 6);
    });

    test('at end of existing text', () {
      ctrl.text = 'hello';
      ctrl.selection = const TextSelection.collapsed(offset: 5);
      CodeInputActions.insertText(ctrl, ' world');
      expect(ctrl.text, 'hello world');
      expect(ctrl.selection.baseOffset, 11);
    });

    test('in middle of existing text', () {
      ctrl.text = 'helo';
      ctrl.selection = const TextSelection.collapsed(offset: 2);
      CodeInputActions.insertText(ctrl, 'l');
      expect(ctrl.text, 'hello');
      expect(ctrl.selection.baseOffset, 3);
    });

    test('replaces selected text', () {
      ctrl.text = 'hello world';
      ctrl.selection = const TextSelection(baseOffset: 6, extentOffset: 11);
      CodeInputActions.insertText(ctrl, 'dart');
      expect(ctrl.text, 'hello dart');
      expect(ctrl.selection.baseOffset, 10);
    });

    test('handles invalid selection by appending', () {
      ctrl.text = 'abc';
      ctrl.selection = const TextSelection(baseOffset: -1, extentOffset: -1);
      CodeInputActions.insertText(ctrl, 'd');
      expect(ctrl.text, 'abcd');
      expect(ctrl.selection.baseOffset, 4);
    });
  });

  // ================================================================
  // insertPaired
  // ================================================================
  group('insertPaired', () {
    test('collapsed cursor inserts pair with cursor between', () {
      ctrl.text = 'log';
      ctrl.selection = const TextSelection.collapsed(offset: 3);
      CodeInputActions.insertPaired(ctrl, '(', ')');
      expect(ctrl.text, 'log()');
      expect(ctrl.selection.baseOffset, 4); // between ( and )
    });

    test('wraps selected text and keeps selection', () {
      ctrl.text = 'console.logmsg';
      ctrl.selection = const TextSelection(baseOffset: 11, extentOffset: 14);
      CodeInputActions.insertPaired(ctrl, '(', ')');
      expect(ctrl.text, 'console.log(msg)');
      expect(ctrl.selection.baseOffset, 12);
      expect(ctrl.selection.extentOffset, 15);
    });

    test('braces at beginning of empty doc', () {
      CodeInputActions.insertPaired(ctrl, '{', '}');
      expect(ctrl.text, '{}');
      expect(ctrl.selection.baseOffset, 1);
    });

    test('quotes around selection', () {
      ctrl.text = 'hello';
      ctrl.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
      CodeInputActions.insertPaired(ctrl, '"', '"');
      expect(ctrl.text, '"hello"');
      expect(ctrl.selection.baseOffset, 1);
      expect(ctrl.selection.extentOffset, 6);
    });
  });

  // ================================================================
  // Cursor navigation
  // ================================================================
  group('cursor navigation', () {
    test('moveCursorLeft', () {
      ctrl.text = 'abcdef';
      ctrl.selection = const TextSelection.collapsed(offset: 3);
      CodeInputActions.moveCursorLeft(ctrl);
      expect(ctrl.selection.baseOffset, 2);
    });

    test('moveCursorLeft clamps at 0', () {
      ctrl.text = 'abc';
      ctrl.selection = const TextSelection.collapsed(offset: 0);
      CodeInputActions.moveCursorLeft(ctrl);
      expect(ctrl.selection.baseOffset, 0);
    });

    test('moveCursorRight', () {
      ctrl.text = 'abcdef';
      ctrl.selection = const TextSelection.collapsed(offset: 3);
      CodeInputActions.moveCursorRight(ctrl);
      expect(ctrl.selection.baseOffset, 4);
    });

    test('moveCursorRight clamps at end', () {
      ctrl.text = 'abc';
      ctrl.selection = const TextSelection.collapsed(offset: 3);
      CodeInputActions.moveCursorRight(ctrl);
      expect(ctrl.selection.baseOffset, 3);
    });

    test('moveCursorToLineStart', () {
      ctrl.text = 'hello\nworld\nfoo';
      ctrl.selection = const TextSelection.collapsed(offset: 9); // 'r' in world
      CodeInputActions.moveCursorToLineStart(ctrl);
      expect(ctrl.selection.baseOffset, 6); // start of 'world'
    });

    test('moveCursorToLineStart on first line', () {
      ctrl.text = 'hello\nworld';
      ctrl.selection = const TextSelection.collapsed(offset: 3);
      CodeInputActions.moveCursorToLineStart(ctrl);
      expect(ctrl.selection.baseOffset, 0);
    });

    test('moveCursorToLineEnd', () {
      ctrl.text = 'hello\nworld\nfoo';
      ctrl.selection = const TextSelection.collapsed(offset: 8); // 'o' in world
      CodeInputActions.moveCursorToLineEnd(ctrl);
      expect(ctrl.selection.baseOffset, 11); // end of 'world'
    });

    test('moveCursorToLineEnd on last line', () {
      ctrl.text = 'hello\nworld';
      ctrl.selection = const TextSelection.collapsed(offset: 8);
      CodeInputActions.moveCursorToLineEnd(ctrl);
      expect(ctrl.selection.baseOffset, 11);
    });

    test('no-op on invalid selection', () {
      ctrl.text = 'abc';
      ctrl.selection = const TextSelection(baseOffset: -1, extentOffset: -1);
      CodeInputActions.moveCursorLeft(ctrl);
      expect(ctrl.selection.baseOffset, -1);
    });
  });

  // ================================================================
  // Indentation
  // ================================================================
  group('indent', () {
    test('single line collapsed cursor', () {
      ctrl.text = 'hello';
      ctrl.selection = const TextSelection.collapsed(offset: 3);
      CodeInputActions.indent(ctrl);
      expect(ctrl.text, '  hello');
      expect(ctrl.selection.baseOffset, 5); // 3 + 2
    });

    test('multiline selection', () {
      ctrl.text = 'aaa\nbbb\nccc';
      ctrl.selection = const TextSelection(baseOffset: 0, extentOffset: 11);
      CodeInputActions.indent(ctrl);
      expect(ctrl.text, '  aaa\n  bbb\n  ccc');
      expect(ctrl.selection.baseOffset, 2);
      expect(ctrl.selection.extentOffset, 17);
    });

    test('empty line', () {
      ctrl.text = '\n';
      ctrl.selection = const TextSelection.collapsed(offset: 0);
      CodeInputActions.indent(ctrl);
      expect(ctrl.text, '  \n');
    });
  });

  group('unindent', () {
    test('single indented line', () {
      ctrl.text = '  hello';
      ctrl.selection = const TextSelection.collapsed(offset: 5);
      CodeInputActions.unindent(ctrl);
      expect(ctrl.text, 'hello');
      expect(ctrl.selection.baseOffset, 3);
    });

    test('multiline indented', () {
      ctrl.text = '  aaa\n  bbb\n  ccc';
      ctrl.selection = const TextSelection(baseOffset: 2, extentOffset: 17);
      CodeInputActions.unindent(ctrl);
      expect(ctrl.text, 'aaa\nbbb\nccc');
      expect(ctrl.selection.baseOffset, 0);
      expect(ctrl.selection.extentOffset, 11);
    });

    test('line with no indent is unchanged', () {
      ctrl.text = 'hello';
      ctrl.selection = const TextSelection.collapsed(offset: 3);
      CodeInputActions.unindent(ctrl);
      expect(ctrl.text, 'hello');
      expect(ctrl.selection.baseOffset, 3);
    });

    test('partially indented line removes what it can', () {
      ctrl.text = ' hello';
      ctrl.selection = const TextSelection.collapsed(offset: 4);
      CodeInputActions.unindent(ctrl);
      expect(ctrl.text, 'hello');
      expect(ctrl.selection.baseOffset, 3);
    });
  });

  // ================================================================
  // Templates
  // ================================================================
  group('insertTemplate', () {
    test('HTML div template with cursor inside', () {
      ctrl.text = '';
      ctrl.selection = const TextSelection.collapsed(offset: 0);
      // Template: <div></div>  cursor at 5 (between ><)
      CodeInputActions.insertTemplate(ctrl, '<div></div>', 5);
      expect(ctrl.text, '<div></div>');
      expect(ctrl.selection.baseOffset, 5);
    });

    test('JS function template with cursor on name', () {
      ctrl.text = '';
      ctrl.selection = const TextSelection.collapsed(offset: 0);
      // Template: "function () {\n  \n}"  cursor at 9 (on the space for name)
      const tpl = 'function () {\n  \n}';
      CodeInputActions.insertTemplate(ctrl, tpl, 9);
      expect(ctrl.text, tpl);
      expect(ctrl.selection.baseOffset, 9);
    });

    test('replaces selection before inserting', () {
      ctrl.text = 'placeholder';
      ctrl.selection = const TextSelection(baseOffset: 0, extentOffset: 11);
      CodeInputActions.insertTemplate(ctrl, '<p></p>', 3);
      expect(ctrl.text, '<p></p>');
      expect(ctrl.selection.baseOffset, 3);
    });
  });
}
