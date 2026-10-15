import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'terminal_controller.dart';

class TerminalView extends StatefulWidget {
  final TerminalController controller;

  const TerminalView({super.key, required this.controller});

  @override
  State<TerminalView> createState() => _TerminalViewState();
}

class _TerminalViewState extends State<TerminalView> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _isExecuting = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant TerminalView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients &&
          _scrollController.position.maxScrollExtent > 0) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _submit() async {
    final input = _inputController.text;
    if (input.trim().isEmpty) return;

    _inputController.clear();
    setState(() => _isExecuting = true);

    try {
      await widget.controller.executeCommand(input);
    } finally {
      if (mounted) setState(() => _isExecuting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark
        ? const Color(0xFF1E1E1E)
        : const Color(0xFFF5F5F5);
    final fgColor = isDark
        ? const Color(0xFFD4D4D4)
        : const Color(0xFF1E1E1E);
    final errorColor = isDark
        ? const Color(0xFFF48771)
        : const Color(0xFFCD3131);
    final promptColor = isDark
        ? const Color(0xFF569CD6)
        : const Color(0xFF0451A5);

    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF2D2D2D)
                  : const Color(0xFFE0E0E0),
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? const Color(0xFF404040)
                      : const Color(0xFFBDBDBD),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.terminal,
                    size: 16, color: fgColor.withValues(alpha: 0.6)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Nomad Terminal',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: fgColor.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.controller.activeProject != null
                        ? widget.controller.cwdDisplayPath
                        : 'no project',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: promptColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Container(
            color: bgColor,
            child: GestureDetector(
              onTap: () => _focusNode.requestFocus(),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(8),
                itemCount: widget.controller.outputLines.length,
                itemBuilder: (context, index) {
                  final line = widget.controller.outputLines[index];
                  final isError = line.startsWith('! ');
                  final isPrompt = line.startsWith('> ');
                  final displayText =
                      isError || isPrompt ? line.substring(2) : line;

                  return Text(
                    displayText,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.4,
                      color: isError
                          ? errorColor
                          : isPrompt
                              ? promptColor
                              : fgColor,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF2D2D2D)
                : const Color(0xFFE8E8E8),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? const Color(0xFF404040)
                    : const Color(0xFFBDBDBD),
              ),
            ),
          ),
          padding: EdgeInsets.only(
            left: 12,
            right: 8,
            top: 6,
            bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 6 : 12,
          ),
          child: Row(
            children: [
              Text(
                '\$',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: promptColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _inputController,
                  focusNode: _focusNode,
                  enabled: !_isExecuting,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'type a command...',
                    hintStyle: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  textInputAction: TextInputAction.send,
                  keyboardType: TextInputType.text,
                  autocorrect: false,
                  enableSuggestions: false,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'[\n\r\t]')),
                  ],
                  onSubmitted: (_) => _submit(),
                ),
              ),
              IconButton(
                icon: _isExecuting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, size: 20),
                onPressed: _isExecuting ? null : _submit,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ),
      ],
    );
  }
}