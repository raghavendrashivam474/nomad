import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_core/nomad_core.dart';
import 'package:nomad_mobile/android_build/android_build_controller.dart';
import 'package:nomad_mobile/android_build/android_build_service.dart';
import 'package:nomad_mobile/android_build/artifact_manager.dart';
import 'package:nomad_mobile/android_build/build_result.dart';
import 'package:nomad_mobile/android_build/project_materializer.dart';

class FakeWorkspaceRepository implements WorkspaceRepository {
  @override
  Future<List<FileNode>> getNodesForProject(EntityId projectId) async => [];
  @override
  Future<FileNode> createNode(FileNode node) async => node;
  @override
  Future<FileNode?> getNodeById(EntityId nodeId) async => null;
  @override
  Future<void> moveNode(EntityId nodeId, EntityId? newParentId) async {}
  @override
  Future<void> renameNode(EntityId nodeId, String newName) async {}
  @override
  Future<void> deleteNode(EntityId nodeId) async {}
  @override
  Future<void> deleteAllNodesForProject(EntityId projectId) async {}
}

class FakeContentRepository implements FileContentRepository {
  @override
  Future<String> readFile(EntityId projectId, EntityId fileId) async => '';
  @override
  Future<List<int>> readFileBytes(EntityId projectId, EntityId fileId) async => [];
  @override
  Future<void> writeFile(EntityId projectId, EntityId fileId, String content) async {}
  @override
  Future<void> writeFileBytes(EntityId projectId, EntityId fileId, List<int> bytes) async {}
  @override
  Future<void> deleteContent(EntityId projectId, EntityId fileId) async {}
  @override
  Future<void> deleteAllContentForProject(EntityId projectId) async {}
}

class FakeAndroidBuildService extends AndroidBuildService {
  final Future<BuildResult> Function(EntityId projectId) onBuild;

  FakeAndroidBuildService({
    required this.onBuild,
    required super.materializer,
    required super.hostAndroidDir,
    super.artifactManager,
  });

  @override
  Future<BuildResult> build(EntityId projectId, {Duration? timeout}) async {
    return onBuild(projectId);
  }
}

void main() {
  late Directory tempDir;
  late ArtifactManager artifactManager;
  const testProjectId = EntityId('ctrl-test');

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nomad_ctrl_test_');
    artifactManager = ArtifactManager(baseDirectory: tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('transitions through states and stores successful APK', () async {
    final fakeService = FakeAndroidBuildService(
      materializer: ProjectMaterializer(
        workspace: FakeWorkspaceRepository(),
        content: FakeContentRepository(),
      ),
      hostAndroidDir: tempDir.path,
      artifactManager: artifactManager,
      onBuild: (id) async {
        final dummyApk = File('${tempDir.path}/app-debug.apk');
        await dummyApk.writeAsString('APK_BYTES');
        await artifactManager.storeArtifact(
          projectId: id,
          sourceApkPath: dummyApk.path,
        );
        return BuildResult(
          status: BuildStatus.success,
          apkPath: dummyApk.path,
          log: 'Build success log',
          duration: const Duration(milliseconds: 50),
        );
      },
    );

    final controller = AndroidBuildController(
      buildService: fakeService,
      artifactManager: artifactManager,
    );

    final phases = <BuildPhase>[];
    controller.addListener(() {
      phases.add(controller.phase);
    });

    final result = await controller.startBuild(testProjectId);

    expect(result.status, equals(BuildStatus.success));
    expect(controller.phase, equals(BuildPhase.success));
    expect(phases, contains(BuildPhase.preparing));
    expect(phases, contains(BuildPhase.building));
    expect(phases, contains(BuildPhase.success));
    expect(controller.lastArtifact, isNotNull);
  });

  test('guards against concurrent builds', () async {
    final fakeService = FakeAndroidBuildService(
      materializer: ProjectMaterializer(
        workspace: FakeWorkspaceRepository(),
        content: FakeContentRepository(),
      ),
      hostAndroidDir: tempDir.path,
      artifactManager: artifactManager,
      onBuild: (id) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return const BuildResult(
          status: BuildStatus.failure,
          log: 'fail',
          duration: Duration.zero,
        );
      },
    );

    final controller = AndroidBuildController(
      buildService: fakeService,
      artifactManager: artifactManager,
    );

    final f1 = controller.startBuild(testProjectId);
    expect(() => controller.startBuild(testProjectId), throwsStateError);
    await f1;
  });
}
