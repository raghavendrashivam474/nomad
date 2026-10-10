/// Web Lab preview surface for Nomad.
library;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:nomad_core/nomad_core.dart';
import 'package:nomad_mobile/activity/activity_controller.dart';
import 'package:nomad_mobile/activity/activity_event.dart';
import 'package:nomad_mobile/ui/activity/live_activity_panel.dart';
import '../server/project_file_server.dart';
import '../server/project_file_resolver.dart';

const _kIndexHtml = 'index.html';

class WebPreviewView extends StatefulWidget {
  final Project project;
  final WorkspaceRepository workspaceRepository;
  final FileContentRepository contentRepository;
  final int previewVersion;
  final VoidCallback? onClose;

  /// Port for the embedded HTTP server. Defaults to 18080.
  /// Pass 0 in tests to get an ephemeral port.
  final int serverPort;

  /// Optional activity controller for Live Activity event reporting.
  final ActivityController? activityController;

  /// Optional callback to navigate to source file/line from an activity event.
  final void Function(String sourceUri, int? line, int? column)? onNavigateToSource;

  const WebPreviewView({
    super.key,
    required this.project,
    required this.workspaceRepository,
    required this.contentRepository,
    required this.previewVersion,
    this.onClose,
    this.serverPort = 18080,
    this.activityController,
    this.onNavigateToSource,
  });

  @override
  State<WebPreviewView> createState() => WebPreviewViewState();
}

class WebPreviewViewState extends State<WebPreviewView> {
  late final WebViewController _controller;
  ProjectFileServer? _server;
  bool _isLoading = true;
  String? _error;

  /// Expose the controller for test verification.
  WebViewController get controller => _controller;

  /// Expose the server instance for test verification.
  ProjectFileServer? get server => _server;

  /// Monotonically increasing token to discard stale async callbacks.
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0F172A))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            widget.activityController?.beginSession();
            _reportActivity(
              category: ActivityCategory.lifecycle,
              severity: ActivitySeverity.info,
              message: 'Preview loading...',
              details: url,
            );
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (url) {
            _reportActivity(
              category: ActivityCategory.lifecycle,
              severity: ActivitySeverity.info,
              message: 'Preview ready',
              details: url,
            );
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (err) {
            debugPrint('WebView resource error: ${err.description}');
            _reportActivity(
              category: ActivityCategory.resource,
              severity: err.isForMainFrame == true
                  ? ActivitySeverity.error
                  : ActivitySeverity.warning,
              message: 'Resource error: ${err.description}',
              details: 'URL: ${err.url ?? "unknown"}, '
                  'type: ${err.errorType}, '
                  'mainFrame: ${err.isForMainFrame}',
            );
          },
        ),
      )
      ..addJavaScriptChannel(
        'NomadDiag',
        onMessageReceived: (JavaScriptMessage msg) {
          _handleJavaScriptDiagnostic(msg.message);
        },
      );
    _startServerAndLoad();
  }

  @override
  void didUpdateWidget(covariant WebPreviewView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.id != widget.project.id) {
      // Project changed — tear down old server, start fresh.
      _disposeServer();
      _startServerAndLoad();
    } else if (oldWidget.previewVersion != widget.previewVersion) {
      // Same project, content saved — reload over existing server.
      _refreshPreview();
    }
  }

  // ── Server lifecycle ────────────────────────────────────────────────────────

  /// Full startup sequence: pre-check → start server → load URL.
  Future<void> _startServerAndLoad() async {
    final token = ++_loadToken;

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // 1. Pre-check: verify index.html exists and is non-empty so we can
    //    show a meaningful error instead of a raw 404 from the server.
    try {
      final fileNodes = await widget.workspaceRepository
          .getNodesForProject(widget.project.id);
      final indexNode =
          fileNodes.where((f) => f.isFile && f.name == _kIndexHtml).firstOrNull;

      if (indexNode == null) {
        if (mounted && token == _loadToken) {
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
        if (mounted && token == _loadToken) {
          setState(() {
            _error = 'empty_entry';
            _isLoading = false;
          });
        }
        return;
      }
    } catch (e) {
      if (mounted && token == _loadToken) {
        setState(() {
          _error = 'render_failed';
          _isLoading = false;
        });
        debugPrint('Preview pre-check failed: $e');
      }
      return;
    }

    // 2. Stop any previous server before binding a new one.
    await _stopServer();
    if (token != _loadToken || !mounted) return;

    // 3. Start the embedded HTTP server.
    try {
      final resolver = ProjectFileResolver(
        workspaceRepository: widget.workspaceRepository,
        contentRepository: widget.contentRepository,
      );
      _server = ProjectFileServer(
        resolver: resolver,
        port: widget.serverPort,
        onResolutionFailure: (path, failure) {
          _reportActivity(
            category: ActivityCategory.resource,
            severity: failure.errorType == FileResolutionErrorType.invalidPath ||
                    failure.errorType == FileResolutionErrorType.pathTraversal
                ? ActivitySeverity.error
                : ActivitySeverity.warning,
            message: 'Resource failed: $path',
            details: failure.message,
            sourceUri: path,
          );
        },
      );
      await _server!.start();
    } catch (e) {
      if (mounted && token == _loadToken) {
        setState(() {
          _error = 'server_failed';
          _isLoading = false;
        });
        debugPrint('Preview server failed to start: $e');
      }
      return;
    }

    // 4. Load the project entry document over HTTP.
    if (mounted && token == _loadToken) {
      final url = Uri.parse(
        'http://127.0.0.1:${_server!.boundPort}'
        '/${widget.project.id.value}/$_kIndexHtml',
      );
      await _controller.loadRequest(url);
    }
  }

  /// Reload the current document over the running server.
  /// Falls back to a full restart if the server is not running.
  Future<void> _refreshPreview() async {
    if (_server == null || !_server!.isRunning) {
      await _startServerAndLoad();
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);

    final url = Uri.parse(
      'http://127.0.0.1:${_server!.boundPort}'
      '/${widget.project.id.value}/$_kIndexHtml',
    );
    await _controller.loadRequest(url);
  }

  /// Graceful async stop for use between restarts.
  Future<void> _stopServer() async {
    try {
      await _server?.stop();
    } catch (e) {
      debugPrint('Error stopping preview server: $e');
    }
    _server = null;
  }

  /// Synchronous fire-and-forget stop for use in dispose().
  void _disposeServer() {
    _server?.stop(force: true).catchError((_) {});
    _server = null;
  }

  @override
  void dispose() {
    _disposeServer();
    super.dispose();
  }

  void _reportActivity({
    required ActivityCategory category,
    required ActivitySeverity severity,
    required String message,
    String? details,
    String? sourceUri,
    int? line,
    int? column,
  }) {
    final controller = widget.activityController;
    if (controller == null) return;
    controller.add(controller.createEvent(
      category: category,
      severity: severity,
      message: message,
      details: details,
      sourceUri: sourceUri,
      line: line,
      column: column,
    ));
  }

  /// Parse and validate JavaScript error diagnostic messages.
  /// Enforces schema and maximum size limits to protect architecture.
  void _handleJavaScriptDiagnostic(String rawJson) {
    if (rawJson.length > 4096) return;

    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, dynamic>) return;

      final message = decoded['message'] as String?;
      if (message == null || message.trim().isEmpty) return;

      final level = decoded['level'] as String?;
      final severity =
          level == 'warn' ? ActivitySeverity.warning : ActivitySeverity.error;

      final details = decoded['details'] as String?;
      final source = decoded['source'] as String?;
      final line = decoded['line'] as int?;
      final column = decoded['column'] as int?;

      _reportActivity(
        category: ActivityCategory.runtime,
        severity: severity,
        message: message,
        details: details,
        sourceUri: source,
        line: line,
        column: column,
      );
    } catch (_) {
      // Ignore malformed payloads to protect app stability
    }
  }

  void _showActivitySheet() {
    if (widget.activityController == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.65,
          child: LiveActivityPanel(
            controller: widget.activityController!,
            onClose: () => Navigator.of(ctx).pop(),
            onNavigateToSource: (uri, line, col) {
              Navigator.of(ctx).pop();
              widget.onNavigateToSource?.call(uri, line, col);
            },
          ),
        );
      },
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

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
          if (widget.activityController != null)
            ListenableBuilder(
              listenable: widget.activityController!,
              builder: (context, _) {
                final count = widget.activityController!.length;
                return IconButton(
                  key: const Key('preview_activity_button'),
                  icon: Badge(
                    isLabelVisible: count > 0,
                    label: Text('$count'),
                    child: const Icon(Icons.bolt),
                  ),
                  tooltip: 'Live Activity',
                  onPressed: _showActivitySheet,
                );
              },
            ),
          IconButton(
            key: const Key('preview_refresh_button'),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Preview',
            onPressed: _refreshPreview,
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
      case 'server_failed':
        message = 'Preview server could not start.\n'
            'The local HTTP port may be in use. '
            'Close other previews and try again.';
        icon = Icons.cloud_off_outlined;
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
              onPressed: () {
                _disposeServer();
                _startServerAndLoad();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}