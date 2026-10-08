import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nomad_core/nomad_core.dart';

class EditorView extends StatefulWidget {
  final FileNode fileNode;
  final FileContentRepository contentRepository;
  final VoidCallback? onClose;

  const EditorView({
    super.key,
    required this.fileNode,
    required this.contentRepository,
    this.onClose,
  });

  @override
  State<EditorView> createState() => _EditorViewState();
}

class _EditorViewState extends State<EditorView> {
  late final TextEditingController _controller;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDirty = false;
  String? _errorMessage;
  String _initialContent = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _loadContent();
  }

  @override
  void didUpdateWidget(covariant EditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fileNode.id != widget.fileNode.id) {
      _loadContent();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadContent() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final content = await widget.contentRepository.readFile(
        widget.fileNode.projectId,
        widget.fileNode.id,
      );
      if (mounted) {
        _controller.text = content;
        _initialContent = content;
        setState(() {
          _isLoading = false;
          _isDirty = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load file content: $e';
        });
      }
    }
  }

  Future<void> _saveContent() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final textToSave = _controller.text;
      await widget.contentRepository.writeFile(
        widget.fileNode.projectId,
        widget.fileNode.id,
        textToSave,
      );

      if (mounted) {
        _initialContent = textToSave;
        setState(() {
          _isSaving = false;
          _isDirty = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved "${widget.fileNode.name}"'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _onTextChanged(String value) {
    final dirty = value != _initialContent;
    if (dirty != _isDirty) {
      setState(() {
        _isDirty = dirty;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = '${widget.fileNode.name}${_isDirty ? ' *' : ''}';

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            _saveContent,
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
            _saveContent,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            leading: widget.onClose != null
                ? IconButton(
                    key: const Key('editor_close_button'),
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Close Editor',
                    onPressed: widget.onClose,
                  )
                : null,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.code, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            actions: [
              if (_isSaving)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                FilledButton.icon(
                  key: const Key('editor_save_button'),
                  onPressed: _isDirty ? _saveContent : null,
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text('Save'),
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline,
                                size: 48,
                                color: Theme.of(context).colorScheme.error),
                            const SizedBox(height: 12),
                            Text(_errorMessage!, textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _loadContent,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: TextField(
                        key: const Key('editor_text_field'),
                        controller: _controller,
                        maxLines: null,
                        expands: true,
                        keyboardType: TextInputType.multiline,
                        autofocus: true,
                        onChanged: _onTextChanged,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14.0,
                          height: 1.4,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Type your code here...',
                        ),
                      ),
                    ),
        ),
      ),
    );
  }
}
