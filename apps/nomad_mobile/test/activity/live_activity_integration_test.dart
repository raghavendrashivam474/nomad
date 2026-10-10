import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_core/nomad_core.dart';
import 'package:nomad_mobile/activity/activity_controller.dart';
import 'package:nomad_mobile/activity/activity_event.dart';
import 'package:nomad_mobile/ui/web_preview_view.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

class FakeWorkspaceRepository implements WorkspaceRepository {
  @override
  Future<void> moveNode(EntityId id, EntityId? newParentId) async {}
  final List<FileNode> nodes;
  FakeWorkspaceRepository(this.nodes);

  @override
  Future<List<FileNode>> getNodesForProject(EntityId projectId) async => nodes;
  @override
  Future<FileNode?> getNodeById(EntityId id) async => null;
  @override
  Future<void> createNode(FileNode node) async {}
  @override
  Future<void> renameNode(EntityId id, String newName) async {}
  @override
  Future<void> deleteNode(EntityId id) async {}
  @override
  Future<void> deleteAllNodesForProject(EntityId projectId) async {}
}

class FakeFileContentRepository implements FileContentRepository {
  final Map<String, String> contents = {};

  @override
  Future<List<int>> readFileBytes(EntityId projectId, EntityId fileNodeId) async {
    final text = await readFile(projectId, fileNodeId);
    return utf8.encode(text);
  }

  @override
  Future<void> writeFileBytes(EntityId projectId, EntityId fileNodeId, List<int> bytes) async {
    await writeFile(projectId, fileNodeId, utf8.decode(bytes));
  }

  @override
  Future<String> readFile(EntityId projectId, EntityId fileNodeId) async {
    return contents[fileNodeId.value] ?? '';
  }

  @override
  Future<void> writeFile(EntityId projectId, EntityId fileNodeId, String content) async {
    contents[fileNodeId.value] = content;
  }

  @override
  Future<void> deleteContent(EntityId projectId, EntityId fileNodeId) async {}
  @override
  Future<void> deleteAllContentForProject(EntityId projectId) async {}
}

class TestWebViewPlatform extends WebViewPlatform {
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    return TestPlatformWebViewController(params);
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) {
    return TestPlatformWebViewWidget(params);
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) {
    return TestPlatformNavigationDelegate(params);
  }
}

class TestPlatformWebViewController extends PlatformWebViewController {
  PlatformNavigationDelegate? delegate;
  Uri? lastLoadedUri;
  final Map<String, JavaScriptChannelParams> javaScriptChannels = {};

  TestPlatformWebViewController(super.params) : super.implementation();

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setBackgroundColor(Color color) async {}

  @override
  Future<void> setPlatformNavigationDelegate(
      PlatformNavigationDelegate handler) async {
    delegate = handler;
  }

  @override
  Future<void> addJavaScriptChannel(
      JavaScriptChannelParams javaScriptChannelParams) async {
    javaScriptChannels[javaScriptChannelParams.name] = javaScriptChannelParams;
  }

  @override
  Future<void> removeJavaScriptChannel(String javaScriptChannelName) async {
    javaScriptChannels.remove(javaScriptChannelName);
  }

  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) async {
    if (delegate is TestPlatformNavigationDelegate) {
      (delegate as TestPlatformNavigationDelegate)
          .triggerPageFinished('about:blank');
    }
  }

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    lastLoadedUri = params.uri;
    if (delegate is TestPlatformNavigationDelegate) {
      (delegate as TestPlatformNavigationDelegate)
          .triggerPageFinished(params.uri.toString());
    }
  }

  void triggerJavaScriptMessage(String channelName, String message) {
    javaScriptChannels[channelName]?.onMessageReceived(
      JavaScriptMessage(message: message),
    );
  }
}

class TestPlatformWebViewWidget extends PlatformWebViewWidget {
  TestPlatformWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink(key: Key('test_webview_surface'));
  }
}

class TestPlatformNavigationDelegate extends PlatformNavigationDelegate {
  PageEventCallback? _onPageStarted;
  PageEventCallback? _onPageFinished;
  WebResourceErrorCallback? _onWebResourceError;

  TestPlatformNavigationDelegate(super.params) : super.implementation();

  @override
  Future<void> setOnPageStarted(PageEventCallback onPageStarted) async {
    _onPageStarted = onPageStarted;
  }

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async {
    _onPageFinished = onPageFinished;
  }

  @override
  Future<void> setOnWebResourceError(
      WebResourceErrorCallback onWebResourceError) async {
    _onWebResourceError = onWebResourceError;
  }

  void triggerPageStarted(String url) => _onPageStarted?.call(url);
  void triggerPageFinished(String url) => _onPageFinished?.call(url);
  void triggerError(WebResourceError err) => _onWebResourceError?.call(err);
}

class FakeWebResourceError implements WebResourceError {
  @override
  final int errorCode;
  @override
  final String description;
  @override
  final WebResourceErrorType? errorType;
  @override
  final bool? isForMainFrame;
  @override
  final String? url;

  const FakeWebResourceError({
    required this.errorCode,
    required this.description,
    this.errorType,
    this.isForMainFrame,
    this.url,
  });
}

void main() {
  late Project project;
  late FileNode indexNode;
  late FakeWorkspaceRepository workspaceRepo;
  late FakeFileContentRepository contentRepo;
  late ActivityController activityController;

  setUpAll(() {
    WebViewPlatform.instance = TestWebViewPlatform();
  });

  setUp(() {
    project = Project(
      id: const EntityId('proj-live-1'),
      name: 'Live Test Project',
      type: ProjectType.web,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    indexNode = FileNode(
      id: const EntityId('file-index'),
      projectId: project.id,
      name: 'index.html',
      type: FileNodeType.file,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    workspaceRepo = FakeWorkspaceRepository([indexNode]);
    contentRepo = FakeFileContentRepository();
    contentRepo.contents['file-index'] = '<h1>Live Activity</h1>';
    activityController = ActivityController(maxEvents: 10);
  });

  tearDown(() {
    activityController.dispose();
  });

  Widget buildPreviewHarness({
    void Function(String uri, int? line, int? col)? onNavigate,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: WebPreviewView(
          project: project,
          workspaceRepository: workspaceRepo,
          contentRepository: contentRepo,
          previewVersion: 0,
          serverPort: 0,
          activityController: activityController,
          onNavigateToSource: onNavigate,
        ),
      ),
    );
  }

  group('Live Activity Full Lifecycle Integration', () {
    testWidgets('captures page start and page finish lifecycle events',
        (tester) async {
      await tester.pumpWidget(buildPreviewHarness());
      await tester.pumpAndSettle();

      // Controller should have received lifecycle events
      final events = activityController.events;
      expect(events.isNotEmpty, isTrue);

      final hasReady = events.any((e) =>
          e.category == ActivityCategory.lifecycle &&
          e.message == 'Preview ready');
      expect(hasReady, isTrue);
    });

    testWidgets('captures sub-resource failure as warning and main-frame as error',
        (tester) async {
      await tester.pumpWidget(buildPreviewHarness());
      await tester.pumpAndSettle();

      final state = tester.state<WebPreviewViewState>(find.byType(WebPreviewView));
      final controller = state.controller.platform as TestPlatformWebViewController;
      final delegate = controller.delegate as TestPlatformNavigationDelegate;

      // Simulate sub-resource error
      delegate.triggerError(const FakeWebResourceError(
        errorCode: 404,
        description: 'Failed to load script.js',
        errorType: WebResourceErrorType.fileNotFound,
        isForMainFrame: false,
        url: 'http://127.0.0.1:18080/proj-live-1/script.js',
      ));

      expect(activityController.events.last.category, ActivityCategory.resource);
      expect(activityController.events.last.severity, ActivitySeverity.warning);
      expect(activityController.events.last.message, contains('Resource error'));

      // Simulate main frame error
      delegate.triggerError(const FakeWebResourceError(
        errorCode: 500,
        description: 'Server error on index.html',
        errorType: WebResourceErrorType.failedSslHandshake,
        isForMainFrame: true,
        url: 'http://127.0.0.1:18080/proj-live-1/index.html',
      ));

      expect(activityController.events.last.category, ActivityCategory.resource);
      expect(activityController.events.last.severity, ActivitySeverity.error);
    });

    testWidgets('captures JavaScript runtime error via NomadDiag channel',
        (tester) async {
      await tester.pumpWidget(buildPreviewHarness());
      await tester.pumpAndSettle();

      final state = tester.state<WebPreviewViewState>(find.byType(WebPreviewView));
      final controller = state.controller.platform as TestPlatformWebViewController;

      // Verify NomadDiag channel is registered
      expect(controller.javaScriptChannels.containsKey('NomadDiag'), isTrue);

      // Trigger a JS error message payload
      final jsPayload = jsonEncode({
        'level': 'error',
        'message': 'Uncaught ReferenceError: x is not defined',
        'details': 'at main (index.html:12:3)',
        'source': 'index.html',
        'line': 12,
        'column': 3,
      });

      controller.triggerJavaScriptMessage('NomadDiag', jsPayload);

      final lastEvent = activityController.events.last;
      expect(lastEvent.category, ActivityCategory.runtime);
      expect(lastEvent.severity, ActivitySeverity.error);
      expect(lastEvent.message, 'Uncaught ReferenceError: x is not defined');
      expect(lastEvent.details, 'at main (index.html:12:3)');
      expect(lastEvent.sourceUri, 'index.html');
      expect(lastEvent.line, 12);
      expect(lastEvent.column, 3);
    });

    testWidgets('captures JavaScript warning via NomadDiag channel',
        (tester) async {
      await tester.pumpWidget(buildPreviewHarness());
      await tester.pumpAndSettle();

      final state = tester.state<WebPreviewViewState>(find.byType(WebPreviewView));
      final controller = state.controller.platform as TestPlatformWebViewController;

      final jsWarning = jsonEncode({
        'level': 'warn',
        'message': 'Deprecation warning: synchronous XHR',
        'source': 'app.js',
      });

      controller.triggerJavaScriptMessage('NomadDiag', jsWarning);

      final lastEvent = activityController.events.last;
      expect(lastEvent.category, ActivityCategory.runtime);
      expect(lastEvent.severity, ActivitySeverity.warning);
      expect(lastEvent.message, 'Deprecation warning: synchronous XHR');
    });

    testWidgets('safely ignores malformed or oversized JavaScript diagnostic payloads',
        (tester) async {
      await tester.pumpWidget(buildPreviewHarness());
      await tester.pumpAndSettle();

      final state = tester.state<WebPreviewViewState>(find.byType(WebPreviewView));
      final controller = state.controller.platform as TestPlatformWebViewController;

      final countBefore = activityController.length;

      // 1. Malformed JSON
      controller.triggerJavaScriptMessage('NomadDiag', '{not valid json}');
      expect(activityController.length, countBefore);

      // 2. Empty message
      controller.triggerJavaScriptMessage('NomadDiag', jsonEncode({'message': ''}));
      expect(activityController.length, countBefore);

      // 3. Oversized payload (> 4096 bytes)
      final oversized = jsonEncode({
        'message': 'A' * 5000,
      });
      controller.triggerJavaScriptMessage('NomadDiag', oversized);
      expect(activityController.length, countBefore);
    });

    testWidgets('enforces session boundaries: ignores callbacks from previous session',
        (tester) async {
      await tester.pumpWidget(buildPreviewHarness());
      await tester.pumpAndSettle();

      final currentSession = activityController.currentSessionId;

      // Manually add an event stamped with a prior session ID
      final staleEvent = ActivityEvent(
        id: 'stale-1',
        timestamp: DateTime.now(),
        category: ActivityCategory.runtime,
        severity: ActivitySeverity.error,
        message: 'Stale error from disposed session',
        sessionId: currentSession - 1,
      );

      activityController.add(staleEvent);

      // Stale event should have been silently rejected
      expect(activityController.events.any((e) => e.id == 'stale-1'), isFalse);
    });

    testWidgets('opens Live Activity sheet from AppBar action button',
        (tester) async {
      await tester.pumpWidget(buildPreviewHarness());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('preview_activity_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('preview_activity_button')));
      await tester.pumpAndSettle();

      // Modal bottom sheet should be visible with Live Activity header
      expect(find.text('Live Activity'), findsOneWidget);
    });
  });
}