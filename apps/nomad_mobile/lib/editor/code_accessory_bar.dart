import 'package:flutter/material.dart';
import 'code_input_actions.dart';
import 'source_language.dart';

/// A compact, single-row coding accessory bar positioned above the keyboard.
/// Provides immediate one-tap access to frequent programming symbols,
/// paired delimiters, navigation, and panel expand toggle.
class CodeAccessoryBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final SourceLanguage language;
  final bool isPanelExpanded;
  final VoidCallback onTogglePanel;

  const CodeAccessoryBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.language,
    required this.isPanelExpanded,
    required this.onTogglePanel,
  });

  void _keepFocus(void Function() action) {
    action();
    if (!focusNode.hasFocus) {
      focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final barColor = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F0F0);
    final borderColor =
        isDark ? const Color(0xFF333333) : const Color(0xFFD0D0D0);

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: barColor,
        border: Border(
          top: BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Expand / Collapse Contextual Panel Toggle Button
          Material(
            color: isPanelExpanded
                ? theme.colorScheme.primaryContainer
                : Colors.transparent,
            child: InkWell(
              key: const Key('accessory_panel_toggle'),
              onTap: onTogglePanel,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  isPanelExpanded
                      ? Icons.keyboard_arrow_down
                      : Icons.grid_view_rounded,
                  size: 20,
                  color: isPanelExpanded
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          VerticalDivider(width: 1, thickness: 1, color: borderColor),

          // Horizontally scrollable quick-action symbol buttons
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                // Paired Delimiters
                _buildPairButton('{}', '{', '}'),
                _buildPairButton('()', '(', ')'),
                _buildPairButton('[]', '[', ']'),
                _buildPairButton('""', '"', '"'),
                _buildPairButton("''", "'", "'"),
                _buildPairButton('``', '`', '`'),
                if (language == SourceLanguage.html)
                  _buildPairButton('<>', '<', '>'),

                _buildDivider(borderColor),

                // Common Symbols
                _buildInsertButton('='),
                _buildInsertButton(';'),
                _buildInsertButton(':'),
                _buildInsertButton('/'),
                _buildInsertButton('.'),
                _buildInsertButton(','),
                _buildInsertButton('!'),
                _buildInsertButton('&'),
                _buildInsertButton('|'),
                _buildInsertButton('+'),
                _buildInsertButton('-'),
                _buildInsertButton('*'),
                _buildInsertButton('?'),

                _buildDivider(borderColor),

                // Indentation
                _buildIconButton(
                  key: const Key('accessory_indent'),
                  icon: Icons.format_indent_increase,
                  tooltip: 'Indent',
                  onTap: () =>
                      _keepFocus(() => CodeInputActions.indent(controller)),
                ),
                _buildIconButton(
                  key: const Key('accessory_unindent'),
                  icon: Icons.format_indent_decrease,
                  tooltip: 'Unindent',
                  onTap: () =>
                      _keepFocus(() => CodeInputActions.unindent(controller)),
                ),

                _buildDivider(borderColor),

                // Navigation
                _buildIconButton(
                  key: const Key('accessory_cursor_left'),
                  icon: Icons.arrow_back_ios_new,
                  tooltip: 'Cursor Left',
                  onTap: () => _keepFocus(
                      () => CodeInputActions.moveCursorLeft(controller)),
                ),
                _buildIconButton(
                  key: const Key('accessory_cursor_right'),
                  icon: Icons.arrow_forward_ios,
                  tooltip: 'Cursor Right',
                  onTap: () => _keepFocus(
                      () => CodeInputActions.moveCursorRight(controller)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPairButton(String label, String open, String close) {
    return _TextBarButton(
      label: label,
      onTap: () => _keepFocus(
        () => CodeInputActions.insertPaired(controller, open, close),
      ),
    );
  }

  Widget _buildInsertButton(String text) {
    return _TextBarButton(
      label: text,
      onTap: () => _keepFocus(
        () => CodeInputActions.insertText(controller, text),
      ),
    );
  }

  Widget _buildIconButton({
    required Key key,
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: key,
          onTap: onTap,
          child: Container(
            width: 40,
            alignment: Alignment.center,
            child: Icon(icon, size: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(Color color) {
    return SizedBox(
      height: 24,
      child: VerticalDivider(
        width: 8,
        thickness: 1,
        indent: 10,
        endIndent: 10,
        color: color,
      ),
    );
  }
}

class _TextBarButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TextBarButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 38),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
