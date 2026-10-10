import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_core/nomad_core.dart';
import 'package:nomad_mobile/app/app_shell.dart';
import 'package:nomad_mobile/ui/workspace_view.dart';

class _FakeProjRepo implements ProjectRepository {
  final List<Project> projects;
  _FakeProjRepo(this.projects);

  @override
  Future<List<Project>> getAllProjects() async => projects;

  @override
  Future<Project?> getProjectById(EntityId id) async =>
      projects.where((p) => p.id == id).firstOrNull;

  @override
  Future<void> saveProject(Project project) async {
    projects.removeWhere((p) => p.id == project.id);
    projects.add(project);
  }

  @override
  Future<void> deleteProject(EntityId id) async =>
      projects.removeWhere((p) => p.id == id);
}

class _FakeWorkspaceRepo implements WorkspaceRepository {
  final List<FileNode> nodes;
  _FakeWorkspaceRepo(this.nodes);

  @override
  Future<List<FileNode>> getNodesForProject(EntityId projectId) async =>
      nodes.where((n) => n.projectId == projectId).toList();
  @override
  Future<FileNode?> getNodeById(EntityId id) async =>
      nodes.where((n) => n.id == id).firstOrNull;
  @override
  Future<void> createNode(FileNode node) async => nodes.add(node);
  @override
  Future<void> renameNode(EntityId id, String newName) async {}
  @override
  Future<void> moveNode(EntityId id, EntityId? newParentId) async {}
  @override
  Future<void> deleteNode(EntityId id) async =>
      nodes.removeWhere((n) => n.id == id);
  @override
  Future<void> deleteAllNodesForProject(EntityId projectId) async =>
      nodes.removeWhere((n) => n.projectId == projectId);
}

class _FakeContentRepo implements FileContentRepository {
  @override
  Future<String> readFile(EntityId projectId, EntityId fileNodeId) async =>
      'console.log("hello");';
  @override
  Future<void> writeFile(
      EntityId projectId, EntityId fileNodeId, String content) async {}
  @override
  Future<List<int>> readFileBytes(
          EntityId projectId, EntityId fileNodeId) async =>
      [];
  @override
  Future<void> writeFileBytes(
      EntityId projectId, EntityId fileNodeId, List<int> bytes) async {}
  @override
  Future<void> deleteContent(EntityId projectId, EntityId fileNodeId) async {}
  @override
  Future<void> deleteAllContentForProject(EntityId projectId) async {}
}

void main() {
  final now = DateTime.now();
  final testProject = Project(
    id: const EntityId('resizing-proj'),
    name: 'Resize Test Lab',
    type: ProjectType.web,
    createdAt: now,
    updatedAt: now,
  );

  final testFile = FileNode(
    id: const EntityId('file-resizing'),
    projectId: testProject.id,
    name: 'index.html',
    type: FileNodeType.file,
    createdAt: now,
    updatedAt: now,
  );

  testWidgets(
      'Divider is present on tablet layout and drag resizing works with bounds clamping',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final projRepo = _FakeProjRepo([testProject]);
    final wsRepo = _FakeWorkspaceRepo([testFile]);
    final contentRepo = _FakeContentRepo();

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          repository: projRepo,
          workspaceRepository: wsRepo,
          contentRepository: contentRepo,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Open the project from tablet projects list
    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Resize Test Lab'));
    await tester.pumpAndSettle();

    // 2. Verify Resizable Divider is visible
    final dividerFinder = find.byKey(const Key('workspace_resizable_divider'));
    expect(dividerFinder, findsOneWidget);

    final workspaceFinder = find.byType(WorkspaceView);
    expect(workspaceFinder, findsOneWidget);
    Size initialSize = tester.getSize(workspaceFinder);
    expect(initialSize.width, equals(280.0));

    // 3. Drag divider to the right by +60px
    await tester.drag(dividerFinder, const Offset(60.0, 0));
    await tester.pumpAndSettle();

    Size expandedSize = tester.getSize(workspaceFinder);
    expect(expandedSize.width, equals(340.0));

    // 4. Drag divider far to the left (-500px) -> verify clamping at min (180.0)
    await tester.drag(dividerFinder, const Offset(-500.0, 0));
    await tester.pumpAndSettle();

    Size clampedMinSize = tester.getSize(workspaceFinder);
    expect(clampedMinSize.width, equals(180.0));

    // 5. Drag divider far to the right (+800px) -> verify clamping at 50% max (500.0)
    await tester.drag(dividerFinder, const Offset(800.0, 0));
    await tester.pumpAndSettle();

    Size clampedMaxSize = tester.getSize(workspaceFinder);
    expect(clampedMaxSize.width, equals(500.0));
  });
}
