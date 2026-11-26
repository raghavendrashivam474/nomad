import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_core/nomad_core.dart';
import 'package:nomad_mobile/android_build/android_build_controller.dart';
import 'package:nomad_mobile/android_build/artifact_manager.dart';
import 'package:nomad_mobile/android_build/build_result.dart';
import 'package:nomad_mobile/android_build/providers/build_orchestrator.dart';
import 'package:nomad_mobile/android_build/providers/build_provider.dart';
import 'package:nomad_mobile/android_build/providers/companion_build_provider.dart';

class FakeWorkspaceRepository implements WorkspaceRepository {
  final List<FileNode> nodes;
  FakeWorkspaceRepository(this.nodes);

  @override
  Future<List<FileNode>> getNodesForProject(EntityId projectId) async => nodes;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFileContentRepository implements FileContentRepository {
  final Map<String, String> content;
  FakeFileContentRepository(this.content);

  @override
  Future<String> readFile(EntityId projectId, EntityId nodeId) async {
    return content[nodeId.value] ?? '';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final now = DateTime.utc(2026, 1, 1);

  group('CompanionBuildProvider & Protocol Full Lifecycle Integration (AL-4)', () {
    late HttpServer mockCompanionServer;
    late int serverPort;
    late ArtifactManager artifactManager;
    late Directory tempArtifactDir;
    String statusToReturn = 'building';
    String? customSha256;
    bool cancelEndpointCalled = false;

    setUp(() async {
      statusToReturn = 'building';
      customSha256 = null;
      cancelEndpointCalled = false;

      tempArtifactDir = await Directory.systemTemp.createTemp('artifact_test_');
      artifactManager = ArtifactManager(baseDirectory: tempArtifactDir);

      mockCompanionServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      serverPort = mockCompanionServer.port;

      mockCompanionServer.listen((HttpRequest req) async {
        final path = req.uri.path;

        if (path == '/api/v1/capabilities' && req.method == 'GET') {
          req.response
            ..headers.contentType = ContentType.json
            ..statusCode = HttpStatus.ok
            ..write(jsonEncode({
              'providerType': 'companion',
              'isAvailable': true,
              'supportsCompose': true,
              'supportsOffline': true,
              'os': 'android',
            }));
          await req.response.close();
          return;
        }

        if (path == '/api/v1/builds' && req.method == 'POST') {
          final body = await utf8.decodeStream(req);
          final payload = jsonDecode(body) as Map<String, dynamic>;
          final files = payload['files'] as Map<String, dynamic>? ?? {};

          expect(payload['projectId'], equals('test_proj_1'));
          expect(files.containsKey('MainActivity.kt'), isTrue);

          req.response
            ..headers.contentType = ContentType.json
            ..statusCode = HttpStatus.accepted
            ..write(jsonEncode({
              'jobId': 'job_mock_999',
              'status': 'building',
              'projectId': 'test_proj_1',
            }));
          await req.response.close();
          return;
        }

        if (path == '/api/v1/builds/job_mock_999/status' && req.method == 'GET') {
          req.response
            ..headers.contentType = ContentType.json
            ..statusCode = HttpStatus.ok
            ..write(jsonEncode({
              'jobId': 'job_mock_999',
              'status': statusToReturn,
              'durationMs': 1200,
              'log': 'Gradle status: $statusToReturn',
              'apkAvailable': statusToReturn == 'success',
              'apkSha256': customSha256 ?? sha256.convert(utf8.encode('MOCK_APK_BYTES')).toString(),
            }));
          await req.response.close();
          return;
        }

        if (path == '/api/v1/builds/job_mock_999/artifact' && req.method == 'GET') {
          req.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType('application', 'vnd.android.package-archive')
            ..write('MOCK_APK_BYTES');
          await req.response.close();
          return;
        }

        if (path == '/api/v1/builds/job_mock_999/cancel' && req.method == 'POST') {
          cancelEndpointCalled = true;
          req.response
            ..headers.contentType = ContentType.json
            ..statusCode = HttpStatus.ok
            ..write(jsonEncode({'status': 'cancelled'}));
          await req.response.close();
          return;
        }

        req.response
          ..statusCode = HttpStatus.notFound
          ..write('Not found');
        await req.response.close();
      });
    });

    tearDown(() async {
      await mockCompanionServer.close(force: true);
      if (await tempArtifactDir.exists()) {
        await tempArtifactDir.delete(recursive: true);
      }
    });

    test('1. Successfully probes capabilities, transfers snapshot, polls status, verifies SHA-256 and stores APK', () async {
      statusToReturn = 'success';
      const projId = EntityId('test_proj_1');
      final rootNode = FileNode(
        id: const EntityId('node_main'),
        projectId: projId,
        name: 'MainActivity.kt',
        type: FileNodeType.file,
        createdAt: now,
        updatedAt: now,
      );
      final fakeWorkspace = FakeWorkspaceRepository([rootNode]);
      final fakeContent = FakeFileContentRepository({'node_main': 'package com.nomad.app'});

      final progressUpdates = <String>[];
      final companionProvider = CompanionBuildProvider(
        endpoint: Uri.parse('http://127.0.0.1:$serverPort'),
        workspaceRepository: fakeWorkspace,
        contentRepository: fakeContent,
        artifactManager: artifactManager,
        onProgress: (status, _) => progressUpdates.add(status),
      );

      final caps = await companionProvider.getCapabilities();
      expect(caps.isAvailable, isTrue);
      expect(caps.providerType, equals(BuildProviderType.onDeviceCompanion));

      final result = await companionProvider.build(const BuildRequest(projectId: projId));
      expect(result.status, equals(BuildStatus.success));
      expect(result.apkPath, isNotNull);
      expect(File(result.apkPath!).existsSync(), isTrue);

      final storedArtifact = await artifactManager.getLatestArtifact(projId);
      expect(storedArtifact, isNotNull);
      expect(storedArtifact!.filePath, equals(result.apkPath));
      expect(progressUpdates, isNotEmpty);
    });

    test('2. Disconnected companion returns isAvailable=false and bounded failure result', () async {
      final companionProvider = CompanionBuildProvider(
        endpoint: Uri.parse('http://127.0.0.1:59999'), // Unbound port
      );

      final caps = await companionProvider.getCapabilities();
      expect(caps.isAvailable, isFalse);
      expect(caps.unavailableReason, contains('not running'));

      final orchestrator = BuildOrchestrator(providers: [companionProvider]);
      final result = await orchestrator.build(const BuildRequest(projectId: EntityId('test_p')));
      expect(result.status, equals(BuildStatus.failure));
      expect(result.errorMessage, anyOf(contains('companion agent required'), contains('start the companion agent')));
    });

    test('3. Detects SHA-256 checksum mismatch, discards corrupt APK, and reports cleanly', () async {
      statusToReturn = 'success';
      customSha256 = 'bad_corrupt_sha256_hash_value_that_does_not_match_bytes';

      const projId = EntityId('test_proj_1');
      final rootNode = FileNode(
        id: const EntityId('node_main'),
        projectId: projId,
        name: 'MainActivity.kt',
        type: FileNodeType.file,
        createdAt: now,
        updatedAt: now,
      );
      final fakeWorkspace = FakeWorkspaceRepository([rootNode]);
      final fakeContent = FakeFileContentRepository({'node_main': 'package com.nomad.app'});

      final companionProvider = CompanionBuildProvider(
        endpoint: Uri.parse('http://127.0.0.1:$serverPort'),
        workspaceRepository: fakeWorkspace,
        contentRepository: fakeContent,
        artifactManager: artifactManager,
      );

      final result = await companionProvider.build(const BuildRequest(projectId: projId));
      expect(result.status, equals(BuildStatus.success));
      // APK path is null because corrupt artifact was discarded
      expect(result.apkPath, isNull);
      final storedArtifact = await artifactManager.getLatestArtifact(projId);
      expect(storedArtifact, isNull);
    });

    test('4. Build cancellation stops polling immediately and reaches terminal cancelled state', () async {
      statusToReturn = 'building'; // Remains building so we can cancel it mid-flight

      const projId = EntityId('test_proj_1');
      final rootNode = FileNode(
        id: const EntityId('node_main'),
        projectId: projId,
        name: 'MainActivity.kt',
        type: FileNodeType.file,
        createdAt: now,
        updatedAt: now,
      );
      final fakeWorkspace = FakeWorkspaceRepository([rootNode]);
      final fakeContent = FakeFileContentRepository({'node_main': 'package com.nomad.app'});

      final companionProvider = CompanionBuildProvider(
        endpoint: Uri.parse('http://127.0.0.1:$serverPort'),
        workspaceRepository: fakeWorkspace,
        contentRepository: fakeContent,
        artifactManager: artifactManager,
      );

      final controller = AndroidBuildController(
        provider: companionProvider,
        artifactManager: artifactManager,
      );

      final buildFuture = controller.startBuild(projId);
      expect(controller.isBusy, isTrue);

      // Give it a moment to submit and begin polling
      await Future.delayed(const Duration(milliseconds: 600));

      // Cancel the active build
      controller.cancelBuild();
      expect(controller.phase, equals(BuildPhase.cancelling));

      final res = await buildFuture;
      expect(res.status, equals(BuildStatus.cancelled));
      expect(controller.phase, equals(BuildPhase.cancelled));
      expect(controller.isBusy, isFalse);
      expect(cancelEndpointCalled, isTrue);
    });

    test('5. Bounded timeout transitions to timeout phase and clears isBusy', () async {
      statusToReturn = 'building'; // Keeps returning building until timeout

      const projId = EntityId('test_proj_1');
      final rootNode = FileNode(
        id: const EntityId('node_main'),
        projectId: projId,
        name: 'MainActivity.kt',
        type: FileNodeType.file,
        createdAt: now,
        updatedAt: now,
      );
      final fakeWorkspace = FakeWorkspaceRepository([rootNode]);
      final fakeContent = FakeFileContentRepository({'node_main': 'package com.nomad.app'});

      final companionProvider = CompanionBuildProvider(
        endpoint: Uri.parse('http://127.0.0.1:$serverPort'),
        workspaceRepository: fakeWorkspace,
        contentRepository: fakeContent,
        artifactManager: artifactManager,
      );

      // Run build with a short 1 second timeout
      final result = await companionProvider.build(
        const BuildRequest(projectId: projId, timeout: Duration(seconds: 1)),
      );

      expect(result.status, equals(BuildStatus.timeout));
      expect(result.errorMessage, contains('timed out'));
    });

    test('6. Retry after failure creates independent session without stale state', () async {
      statusToReturn = 'failure';

      const projId = EntityId('test_proj_1');
      final rootNode = FileNode(
        id: const EntityId('node_main'),
        projectId: projId,
        name: 'MainActivity.kt',
        type: FileNodeType.file,
        createdAt: now,
        updatedAt: now,
      );
      final fakeWorkspace = FakeWorkspaceRepository([rootNode]);
      final fakeContent = FakeFileContentRepository({'node_main': 'package com.nomad.app'});

      final companionProvider = CompanionBuildProvider(
        endpoint: Uri.parse('http://127.0.0.1:$serverPort'),
        workspaceRepository: fakeWorkspace,
        contentRepository: fakeContent,
        artifactManager: artifactManager,
      );

      final controller = AndroidBuildController(
        provider: companionProvider,
        artifactManager: artifactManager,
      );

      // First run: Fails
      final res1 = await controller.startBuild(projId);
      expect(res1.status, equals(BuildStatus.failure));
      expect(controller.phase, equals(BuildPhase.failure));
      expect(controller.isBusy, isFalse);

      // Now server heals and succeeds
      statusToReturn = 'success';
      customSha256 = null;

      // Second run: Retry succeeds independently
      final res2 = await controller.startBuild(projId);
      expect(res2.status, equals(BuildStatus.success));
      expect(controller.phase, equals(BuildPhase.success));
      expect(controller.isBusy, isFalse);
      expect(controller.lastArtifact, isNotNull);
    });
  });
}

