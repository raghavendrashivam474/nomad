import 'package:flutter/material.dart';
import 'code_input_actions.dart';
import 'source_language.dart';

/// An expandable contextual panel providing navigation controls,
/// extended symbol collections, and language-specific code snippets.
class ContextualCodePanel extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final SourceLanguage language;
  final VoidCallback onClose;
  final double maxHeight;

  const ContextualCodePanel({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.language,
    required this.onClose,
    this.maxHeight = 220,
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

    final panelBg = isDark ? const Color(0xFF252526) : const Color(0xFFE8E8E8);
    final sectionBorder =
        isDark ? const Color(0xFF383838) : const Color(0xFFD4D4D4);

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: panelBg,
        border: Border(
          top: BorderSide(color: sectionBorder, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Bar
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: sectionBorder)),
            ),
            child: Row(
              children: [
                Text(
                  '${language.displayName} Tools',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  key: const Key('contextual_panel_close'),
                  icon: const Icon(Icons.close, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Close Panel',
                  onPressed: onClose,
                ),
              ],
            ),
          ),

          // Content body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                // 1. Navigation & Line Movement Section
                _buildSectionTitle('Navigation'),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildActionButton(
                      key: const Key('panel_nav_line_start'),
                      label: 'Line Start',
                      icon: Icons.first_page,
                      onTap: () => _keepFocus(() =>
                          CodeInputActions.moveCursorToLineStart(controller)),
                    ),
                    _buildActionButton(
                      key: const Key('panel_nav_line_end'),
                      label: 'Line End',
                      icon: Icons.last_page,
                      onTap: () => _keepFocus(() =>
                          CodeInputActions.moveCursorToLineEnd(controller)),
                    ),
                    _buildActionButton(
                      key: const Key('panel_nav_indent'),
                      label: 'Indent',
                      icon: Icons.format_indent_increase,
                      onTap: () =>
                          _keepFocus(() => CodeInputActions.indent(controller)),
                    ),
                    _buildActionButton(
                      key: const Key('panel_nav_unindent'),
                      label: 'Unindent',
                      icon: Icons.format_indent_decrease,
                      onTap: () => _keepFocus(
                          () => CodeInputActions.unindent(controller)),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // 2. Language-Specific Snippets & Templates
                _buildSectionTitle('${language.displayName} Snippets'),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _buildLanguageSnippets(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    Key? key,
    required String label,
    IconData? icon,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      key: key,
      avatar: icon != null ? Icon(icon, size: 14) : null,
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  List<Widget> _buildLanguageSnippets(BuildContext context) {
    switch (language) {
      case SourceLanguage.html:
        return [
          _buildSnippetChip('<div>', '<div>\n  \n</div>', 8),
          _buildSnippetChip('<p>', '<p></p>', 3),
          _buildSnippetChip('<button>', '<button></button>', 8),
          _buildSnippetChip('<script>', '<script>\n  \n</script>', 11),
          _buildSnippetChip('class=""', 'class=""', 7),
          _buildSnippetChip('id=""', 'id=""', 4),
          _buildSnippetChip('<!-- comment -->', '<!--  -->', 5),
        ];

      case SourceLanguage.css:
        return [
          _buildSnippetChip('rule {}', 'selector {\n  \n}', 13),
          _buildSnippetChip(
              'flex center',
              'display: flex;\njustify-content: center;\nalign-items: center;',
              58),
          _buildSnippetChip('color: ;', 'color: ;', 7),
          _buildSnippetChip('margin: ;', 'margin: 0;', 8),
          _buildSnippetChip('padding: ;', 'padding: 0;', 9),
          _buildSnippetChip('/* comment */', '/*  */', 3),
        ];

      case SourceLanguage.javascript:
        return [
          _buildSnippetChip('function()', 'function () {\n  \n}', 9),
          _buildSnippetChip('() => {}', '() => {\n  \n}', 9),
          _buildSnippetChip('const = ', 'const name = value;', 6),
          _buildSnippetChip('let = ', 'let name = value;', 4),
          _buildSnippetChip('console.log()', 'console.log();', 12),
          _buildSnippetChip('if () {}', 'if () {\n  \n}', 4),
          _buildSnippetChip('// comment', '// ', 3),
        ];

      case SourceLanguage.plainText:
        return [
          _buildSnippetChip('Tab', '  ', 2),
          _buildSnippetChip('List Item', '- ', 2),
          _buildSnippetChip('Todo Item', '- [ ] ', 6),
        ];
    }
  }

  Widget _buildSnippetChip(String label, String template, int cursorOffset) {
    return ActionChip(
      label: Text(
        label,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
      ),
      onPressed: () => _keepFocus(
        () =>
            CodeInputActions.insertTemplate(controller, template, cursorOffset),
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
