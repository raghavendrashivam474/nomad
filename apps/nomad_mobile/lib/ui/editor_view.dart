import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nomad_core/nomad_core.dart';
import '../android_build/android_build_controller.dart';
import '../editor/code_accessory_bar.dart';
import '../editor/code_editing_controller.dart';
import '../editor/contextual_code_panel.dart';
import '../editor/source_language.dart';

class EditorView extends StatefulWidget {
  final FileNode fileNode;
  final FileContentRepository contentRepository;
  final VoidCallback? onClose;
  final VoidCallback? onPreview;
  final VoidCallback? onSaveCompleted;
  final bool isPreviewActive;
  final ProjectType? projectType;
  final AndroidBuildController? buildController;
  final VoidCallback? onBuild;
  final VoidCallback? onDiagnostics;

  const EditorView({
    super.key,
    required this.fileNode,
    required this.contentRepository,
    this.onClose,
    this.onPreview,
    this.onSaveCompleted,
    this.isPreviewActive = false,
    this.projectType,
    this.buildController,
    this.onBuild,
    this.onDiagnostics,
  });

  @override
  State<EditorView> createState() => _EditorViewState();
}

class _EditorViewState extends State<EditorView> {
  late CodeEditingController _controller;
  late FocusNode _focusNode;
  late SourceLanguage _language;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDirty = false;
  bool _isPanelExpanded = false;
  String? _errorMessage;
  String _initialContent = '';

  @override
  void initState() {
    super.initState();
    _language = SourceLanguage.fromFileName(widget.fileNode.name);
    _controller = CodeEditingController(language: _language);
    _controller.addListener(_onControllerChanged);
    _focusNode = FocusNode();
    _loadContent();
  }

  @override
  void didUpdateWidget(covariant EditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fileNode.id != widget.fileNode.id ||
        oldWidget.fileNode.name != widget.fileNode.name) {
      _language = SourceLanguage.fromFileName(widget.fileNode.name);
      _controller.removeListener(_onControllerChanged);
      _controller.dispose();
      _controller = CodeEditingController(language: _language);
      _controller.addListener(_onControllerChanged);
      _loadContent();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final isDirty = _controller.text != _initialContent;
    if (isDirty != _isDirty) {
      setState(() => _isDirty = isDirty);
    }
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
        _initialContent = content;
        _controller.text = content;
        setState(() {
          _isLoading = false;
          _isDirty = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _saveContent() async {
    if (_isSaving || !_isDirty) return;

    setState(() => _isSaving = true);
    try {
      await widget.contentRepository.writeFile(
        widget.fileNode.projectId,
        widget.fileNode.id,
        _controller.text,
      );
      if (mounted) {
        _initialContent = _controller.text;
        setState(() {
          _isSaving = false;
          _isDirty = false;
        });
        widget.onSaveCompleted?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved "${widget.fileNode.name}"'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  IconData _getLanguageIcon() {
    switch (_language) {
      case SourceLanguage.html:
        return Icons.html;
      case SourceLanguage.css:
        return Icons.css;
      case SourceLanguage.javascript:
        return Icons.javascript;
      case SourceLanguage.kotlin:
        return Icons.android;
      case SourceLanguage.gradle:
        return Icons.build_circle_outlined;
      case SourceLanguage.xml:
        return Icons.code;
      default:
        return Icons.description_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAndroid = widget.projectType == ProjectType.android;
    final title = _isDirty ? '${widget.fileNode.name} *' : widget.fileNode.name;

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
                Icon(_getLanguageIcon(), size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .secondaryContainer
                        .withAlpha(120),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _language.displayName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              if (isAndroid && widget.buildController != null)
                ListenableBuilder(
                  listenable: widget.buildController!,
                  builder: (ctx, _) {
                    final controller = widget.buildController!;
                    final isBusy = controller.isBusy;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isBusy)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.0),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            ),
                          )
                        else
                          IconButton(
                            key: const Key('editor_build_apk_button'),
                            tooltip: 'Build APK (Gradle)',
                            icon: const Icon(Icons.build_circle_outlined, color: Colors.green),
                            onPressed: widget.onBuild,
                          ),
                        if (controller.lastResult != null)
                          IconButton(
                            key: const Key('editor_build_diagnostics_button'),
                            tooltip: 'Build Diagnostics',
                            icon: Icon(
                              controller.lastResult!.isSuccess
                                  ? Icons.assignment_turned_in_outlined
                                  : Icons.assignment_late_outlined,
                              color: controller.lastResult!.isSuccess ? Colors.green : Colors.red,
                            ),
                            onPressed: widget.onDiagnostics,
                          ),
                      ],
                    );
                  },
                ),
              if (widget.onPreview != null && !isAndroid)
                IconButton(
                  key: const Key('editor_preview_button'),
                  icon: Icon(widget.isPreviewActive
                      ? Icons.preview
                      : Icons.preview_outlined),
                  tooltip: 'Toggle Preview',
                  onPressed: widget.onPreview,
                ),
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
                            const Icon(Icons.error_outline,
                                size: 48, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(
                              'Failed to load file:\n$_errorMessage',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _loadContent,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('editor_text_field'),
                            controller: _controller,
                            focusNode: _focusNode,
                            maxLines: null,
                            expands: true,
                            keyboardType: TextInputType.multiline,
                            textAlignVertical: TextAlignVertical.top,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 14,
                              height: 1.5,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(16.0),
                            ),
                          ),
                        ),
                        if (_isPanelExpanded)
                          Flexible(
                            fit: FlexFit.loose,
                            child: SingleChildScrollView(
                              child: ContextualCodePanel(
                                language: _language,
                                controller: _controller,
                                focusNode: _focusNode,
                                onClose: () =>
                                    setState(() => _isPanelExpanded = false),
                              ),
                            ),
                          ),
                        CodeAccessoryBar(
                          controller: _controller,
                          focusNode: _focusNode,
                          language: _language,
                          isPanelExpanded: _isPanelExpanded,
                          onTogglePanel: () => setState(
                              () => _isPanelExpanded = !_isPanelExpanded),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}