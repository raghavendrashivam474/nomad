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

  group('CompanionBuildProvider & Protocol Integration', () {
    late HttpServer mockCompanionServer;
    late int serverPort;
    late ArtifactManager artifactManager;
    late Directory tempArtifactDir;

    setUp(() async {
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
              'status': 'success',
              'log': 'Gradle assembleDebug succeeded (mock).',
              'apkAvailable': true,
              'apkSha256': sha256.convert(utf8.encode('MOCK_APK_BYTES')).toString(),
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

    test('successfully probes capabilities, transfers snapshot, polls status and stores APK', () async {
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
    });

    test('AndroidBuildController executes build through BuildOrchestrator and companion provider', () async {
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

      final orchestrator = BuildOrchestrator(
        providers: [companionProvider],
      );

      final controller = AndroidBuildController(
        provider: orchestrator,
        artifactManager: artifactManager,
      );

      expect(controller.phase, equals(BuildPhase.idle));
      final res = await controller.startBuild(projId);

      expect(res.status, equals(BuildStatus.success));
      expect(controller.phase, equals(BuildPhase.success));
      expect(controller.lastArtifact, isNotNull);
      expect(controller.lastResult?.isSuccess, isTrue);
    });
  });
}
