import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_core/nomad_core.dart';
import 'package:nomad_mobile/ui/workspace_view.dart';

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

void main() {
  testWidgets('renders Build APK button for Android project in WorkspaceView', (tester) async {
    final androidProject = Project(
      id: const EntityId('test-android-proj'),
      name: 'Hello Android',
      type: ProjectType.android,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkspaceView(
            project: androidProject,
            workspaceRepository: DummyWorkspaceRepo(),
            contentRepository: DummyContentRepo(),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('build_apk_button')), findsOneWidget);
    expect(find.byTooltip('Build APK'), findsOneWidget);
  });
}
