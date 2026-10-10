import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_core/nomad_core.dart';
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
  @override
  Future<List<int>> readFileBytes(
      EntityId projectId, EntityId fileNodeId) async {
    final text = await readFile(projectId, fileNodeId);
    return utf8.encode(text);
  }

  @override
  Future<void> writeFileBytes(
      EntityId projectId, EntityId fileNodeId, List<int> bytes) async {
    await writeFile(projectId, fileNodeId, utf8.decode(bytes));
  }

  final Map<String, String> contents = {};

  @override
  Future<String> readFile(EntityId projectId, EntityId fileNodeId) async {
    return contents[fileNodeId.value] ?? '';
  }

  @override
  Future<void> writeFile(
      EntityId projectId, EntityId fileNodeId, String content) async {
    contents[fileNodeId.value] = content;
  }

  @override
  Future<void> deleteContent(EntityId projectId, EntityId fileNodeId) async {}
  @override
  Future<void> deleteAllContentForProject(EntityId projectId) async {}
}

// ── Complete Headless Test Stub for WebViewPlatform ─────────────────
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
  PlatformNavigationDelegate? _delegate;
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
    _delegate = handler;
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
    if (_delegate is TestPlatformNavigationDelegate) {
      (_delegate as TestPlatformNavigationDelegate)
          .triggerPageFinished('about:blank');
    }
  }

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    lastLoadedUri = params.uri;
    if (_delegate is TestPlatformNavigationDelegate) {
      (_delegate as TestPlatformNavigationDelegate)
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

void main() {
  late Project project;
  late FileNode indexNode;
  late FakeWorkspaceRepository workspaceRepo;
  late FakeFileContentRepository contentRepo;

  setUpAll(() {
    WebViewPlatform.instance = TestWebViewPlatform();
  });

  setUp(() {
    project = Project(
      id: const EntityId('proj-123'),
      name: 'Web Lab Test',
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
  });

  group('WebPreviewView Widget States', () {
    testWidgets('renders missing entry state when index.html is absent',
        (tester) async {
      final emptyWorkspaceRepo = FakeWorkspaceRepository(const []);

      await tester.pumpWidget(
        MaterialApp(
          home: WebPreviewView(
            project: project,
            workspaceRepository: emptyWorkspaceRepo,
            contentRepository: contentRepo,
            previewVersion: 0,
            serverPort: 0, // ephemeral port for safety
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('No index.html found'), findsOneWidget);
      expect(find.byKey(const Key('preview_retry_button')), findsOneWidget);
    });

    testWidgets('renders empty entry state when index.html content is empty',
        (tester) async {
      contentRepo.contents['file-index'] = '';

      await tester.pumpWidget(
        MaterialApp(
          home: WebPreviewView(
            project: project,
            workspaceRepository: workspaceRepo,
            contentRepository: contentRepo,
            previewVersion: 0,
            serverPort: 0,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('index.html is empty'), findsOneWidget);
      expect(find.byKey(const Key('preview_retry_button')), findsOneWidget);
    });

    testWidgets(
        'renders AppBar and close button when onClose callback is provided',
        (tester) async {
      bool closed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: WebPreviewView(
            project: project,
            workspaceRepository: workspaceRepo,
            contentRepository: contentRepo,
            previewVersion: 0,
            serverPort: 0,
            onClose: () => closed = true,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('preview_close_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('preview_close_button')));
      await tester.pumpAndSettle();

      expect(closed, isTrue);
    });

    testWidgets('starts server and loads the exact project URL over HTTP',
        (tester) async {
      contentRepo.contents['file-index'] = '<h1>Hello</h1>';

      await tester.pumpWidget(
        MaterialApp(
          home: WebPreviewView(
            project: project,
            workspaceRepository: workspaceRepo,
            contentRepository: contentRepo,
            previewVersion: 0,
            serverPort: 0,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('test_webview_surface')), findsOneWidget);

      final state =
          tester.state<WebPreviewViewState>(find.byType(WebPreviewView));
      expect(state.server, isNotNull);
      expect(state.server!.isRunning, isTrue);

      final expectedUrl =
          'http://127.0.0.1:${state.server!.boundPort}/${project.id.value}/index.html';
      final controller = state.controller.platform as TestPlatformWebViewController;
      expect(controller.lastLoadedUri.toString(), expectedUrl);
    });

    testWidgets('cleans up server resources completely on dispose',
        (tester) async {
      contentRepo.contents['file-index'] = '<h1>Hello</h1>';

      await tester.pumpWidget(
        MaterialApp(
          home: WebPreviewView(
            project: project,
            workspaceRepository: workspaceRepo,
            contentRepository: contentRepo,
            previewVersion: 0,
            serverPort: 0,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final state =
          tester.state<WebPreviewViewState>(find.byType(WebPreviewView));
      final server = state.server;
      expect(server, isNotNull);
      expect(server!.isRunning, isTrue);

      // Trigger dispose by replacing widget tree
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(server.isRunning, isFalse);
    });
  });
}