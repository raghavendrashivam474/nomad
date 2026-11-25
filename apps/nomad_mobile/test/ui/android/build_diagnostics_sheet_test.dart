import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_core/nomad_core.dart';
import 'package:nomad_mobile/android_build/adb_service.dart';
import 'package:nomad_mobile/android_build/android_build_controller.dart';
import 'package:nomad_mobile/android_build/android_build_service.dart';
import 'package:nomad_mobile/android_build/artifact_manager.dart';
import 'package:nomad_mobile/android_build/build_result.dart';
import 'package:nomad_mobile/android_build/project_materializer.dart';
import 'package:nomad_mobile/ui/android/build_diagnostics_sheet.dart';

class DummyWorkspaceRepo implements WorkspaceRepository {
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

class DummyContentRepo implements FileContentRepository {
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

class FakeSuccessBuildService extends AndroidBuildService {
  FakeSuccessBuildService({
    required super.materializer,
    required super.hostAndroidDir,
    super.artifactManager,
  });

  @override
  Future<BuildResult> build(EntityId projectId, {Duration? timeout}) async {
    return const BuildResult(
      status: BuildStatus.success,
      apkPath: '/dummy/app-debug.apk',
      log: 'Gradle BUILD SUCCESSFUL',
      duration: Duration(seconds: 45),
    );
  }
}

class FakeAdbService extends AdbService {
  final List<AdbDevice> devices;
  FakeAdbService({this.devices = const []});

  @override
  Future<List<AdbDevice>> getConnectedDevices() async => devices;
}

void main() {
  testWidgets('renders build diagnostics sheet on successful build with devices', (tester) async {
    final controller = AndroidBuildController(
      buildService: FakeSuccessBuildService(
        materializer: ProjectMaterializer(
          workspace: DummyWorkspaceRepo(),
          content: DummyContentRepo(),
        ),
        hostAndroidDir: '.',
      ),
      artifactManager: ArtifactManager(),
    );

    await tester.runAsync(() async {
      await controller.startBuild(const EntityId('test-proj'));
    });

    const testDevices = [
      AdbDevice(
        serial: 'emulator-5554',
        state: 'device',
        model: 'Pixel_7',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BuildDiagnosticsSheet(
            buildController: controller,
            adbService: FakeAdbService(devices: testDevices),
            initialDevices: testDevices,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('close_diagnostics_button')), findsOneWidget);
    expect(find.text('Build Succeeded'), findsOneWidget);
    expect(find.text('ADB Devices:'), findsOneWidget);
    expect(find.text('Pixel_7 (emulator-5554)'), findsOneWidget);
    expect(find.byKey(const Key('install_btn_emulator-5554')), findsOneWidget);
    expect(find.text('Gradle BUILD SUCCESSFUL'), findsOneWidget);
  });
}
