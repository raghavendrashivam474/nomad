/// Web Lab preview surface for Nomad.
library;

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:nomad_core/nomad_core.dart';

const _kIndexHtml = 'index.html';
const _kStyleCss = 'style.css';
const _kScriptJs = 'script.js';

class WebPreviewView extends StatefulWidget {
  final Project project;
  final WorkspaceRepository workspaceRepository;
  final FileContentRepository contentRepository;
  final int previewVersion;
  final VoidCallback? onClose;

  const WebPreviewView({
    super.key,
    required this.project,
    required this.workspaceRepository,
    required this.contentRepository,
    required this.previewVersion,
    this.onClose,
  });

  @override
  State<WebPreviewView> createState() => _WebPreviewViewState();
}

class _WebPreviewViewState extends State<WebPreviewView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0F172A))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (err) {
            debugPrint('WebView resource error: ${err.description}');
          },
        ),
      );
    _renderPreview();
  }

  @override
  void didUpdateWidget(covariant WebPreviewView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.id != widget.project.id ||
        oldWidget.previewVersion != widget.previewVersion) {
      _renderPreview();
    }
  }

  Future<void> _renderPreview() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final fileNodes = await widget.workspaceRepository.getNodesForProject(widget.project.id);
      final indexNode = _findFile(fileNodes, _kIndexHtml);
      if (indexNode == null) {
        if (mounted) {
          setState(() {
            _error = 'missing_entry';
            _isLoading = false;
          });
        }
        return;
      }

      final html = await widget.contentRepository.readFile(
        widget.project.id,
        indexNode.id,
      );

      if (html.trim().isEmpty) {
        if (mounted) {
          setState(() {
            _error = 'empty_entry';
            _isLoading = false;
          });
        }
        return;
      }

      final assembled = await _assembleDocument(fileNodes, html);
      if (mounted) {
        // Set baseUrl to https://localhost/ so window.localStorage and web APIs have a valid origin.
        await _controller.loadHtmlString(assembled, baseUrl: 'https://localhost/');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'render_failed';
          _isLoading = false;
        });
        debugPrint('Preview render failed: $e');
      }
    }
  }

  Future<String> _assembleDocument(List<FileNode> fileNodes, String html) async {
    var result = html;

    // Inline CSS
    final cssNode = _findFile(fileNodes, _kStyleCss);
    if (cssNode != null) {
      final css = await widget.contentRepository.readFile(
        widget.project.id,
        cssNode.id,
      );
      if (css.trim().isNotEmpty) {
        result = result.replaceFirst(
          '</head>',
          '<style>\n$css\n</style>\n</head>',
        );
      }
      result = result.replaceAll(
        RegExp(r'<link[^>]+style\.css[^>]*>'),
        '',
      );
    }

    // Inline JS
    final jsNode = _findFile(fileNodes, _kScriptJs);
    if (jsNode != null) {
      final js = await widget.contentRepository.readFile(
        widget.project.id,
        jsNode.id,
      );
      if (js.trim().isNotEmpty) {
        result = result.replaceFirst(
          '</body>',
          '<script>\n$js\n</script>\n</body>',
        );
      }
      result = result.replaceAll(
        RegExp(r'<script[^>]+script\.js[^>]*>\s*</script>'),
        '',
      );
    }

    return result;
  }

  FileNode? _findFile(List<FileNode> fileNodes, String name) {
    return fileNodes
        .where((f) => f.isFile && f.name == name)
        .firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: widget.onClose != null
            ? IconButton(
                key: const Key('preview_close_button'),
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back to Editor',
                onPressed: widget.onClose,
              )
            : null,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.preview, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Preview — ${widget.project.name}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('preview_refresh_button'),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Preview',
            onPressed: _renderPreview,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return _buildErrorState();
    }

    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }

  Widget _buildErrorState() {
    final String message;
    final IconData icon;

    switch (_error) {
      case 'missing_entry':
        message = 'No index.html found in this project.\n'
            'Create an index.html file to enable preview.';
        icon = Icons.file_open_outlined;
      case 'empty_entry':
        message = 'index.html is empty.\n'
            'Add some HTML content and save to preview.';
        icon = Icons.note_outlined;
      case 'render_failed':
        message = 'Preview could not be rendered.\n'
            'Check your HTML for syntax errors and try again.';
        icon = Icons.error_outline;
      default:
        message = 'An unexpected error occurred.';
        icon = Icons.error_outline;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('preview_retry_button'),
              onPressed: _renderPreview,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
