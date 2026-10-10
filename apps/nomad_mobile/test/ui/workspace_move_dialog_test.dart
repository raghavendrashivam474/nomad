import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_core/nomad_core.dart';
import 'package:nomad_mobile/ui/workspace_view.dart';

class _FakeWorkspaceRepoForMove implements WorkspaceRepository {
  List<FileNode> nodes;
  EntityId? lastMovedId;
  EntityId? lastTargetParentId;

  _FakeWorkspaceRepoForMove(this.nodes);

  @override
  Future<List<FileNode>> getNodesForProject(EntityId projectId) async {
    return nodes.where((n) => n.projectId == projectId).toList();
  }

  @override
  Future<FileNode?> getNodeById(EntityId id) async {
    return nodes.firstWhere((n) => n.id == id);
  }

  @override
  Future<void> createNode(FileNode node) async {
    nodes.add(node);
  }

  @override
  Future<void> renameNode(EntityId id, String newName) async {}

  @override
  Future<void> moveNode(EntityId id, EntityId? newParentId) async {
    lastMovedId = id;
    lastTargetParentId = newParentId;
    final idx = nodes.indexWhere((n) => n.id == id);
    if (idx != -1) {
      nodes[idx] = nodes[idx].copyWith(parentId: newParentId);
    }
  }

  @override
  Future<void> deleteNode(EntityId id) async {}

  @override
  Future<void> deleteAllNodesForProject(EntityId projectId) async {}
}

void main() {
  final now = DateTime.now();
  final project = Project(
    id: const EntityId('test-proj'),
    name: 'Test Project',
    type: ProjectType.web,
    createdAt: now,
    updatedAt: now,
  );

  testWidgets('displays move option in popup menu and executes move',
      (tester) async {
    final folder = FileNode(
      id: const EntityId('fol-1'),
      projectId: project.id,
      name: 'src',
      type: FileNodeType.folder,
      createdAt: now,
      updatedAt: now,
    );
    final file = FileNode(
      id: const EntityId('file-1'),
      projectId: project.id,
      name: 'app.js',
      type: FileNodeType.file,
      createdAt: now,
      updatedAt: now,
    );

    final repo = _FakeWorkspaceRepoForMove([folder, file]);

    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceView(
          project: project,
          workspaceRepository: repo,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify items are displayed
    expect(find.text('src'), findsOneWidget);
    expect(find.text('app.js'), findsOneWidget);

    // Open popup menu on app.js
    await tester.tap(find.byKey(const Key('node_menu_app.js')));
    await tester.pumpAndSettle();

    // Tap 'Move'
    expect(find.text('Move'), findsOneWidget);
    await tester.tap(find.text('Move'));
    await tester.pumpAndSettle();

    // Verify dialog appears with target destination choices
    expect(find.text('Move "app.js"'), findsOneWidget);
    expect(find.byKey(const Key('move_dest_src')), findsOneWidget);

    // Select src folder and tap Move button
    await tester.tap(find.byKey(const Key('move_dest_src')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirm_move_button')));
    await tester.pumpAndSettle();

    // Verify repository moveNode was called
    expect(repo.lastMovedId, equals(file.id));
    expect(repo.lastTargetParentId, equals(folder.id));
  });

  testWidgets('omits invalid folder targets when moving a folder',
      (tester) async {
    final parentFolder = FileNode(
      id: const EntityId('parent-fol'),
      projectId: project.id,
      name: 'parent',
      type: FileNodeType.folder,
      createdAt: now,
      updatedAt: now,
    );
    final childFolder = FileNode(
      id: const EntityId('child-fol'),
      projectId: project.id,
      parentId: parentFolder.id,
      name: 'child',
      type: FileNodeType.folder,
      createdAt: now,
      updatedAt: now,
    );
    final siblingFolder = FileNode(
      id: const EntityId('sibling-fol'),
      projectId: project.id,
      name: 'sibling',
      type: FileNodeType.folder,
      createdAt: now,
      updatedAt: now,
    );

    final repo =
        _FakeWorkspaceRepoForMove([parentFolder, childFolder, siblingFolder]);

    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceView(
          project: project,
          workspaceRepository: repo,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open popup menu on parent folder
    await tester.tap(find.byKey(const Key('node_menu_parent')));
    await tester.pumpAndSettle();

    // Tap Move
    await tester.tap(find.text('Move'));
    await tester.pumpAndSettle();

    // Verify dialog excludes itself ('parent') and child ('child'), but includes 'sibling'
    expect(find.byKey(const Key('move_dest_sibling')), findsOneWidget);
    expect(find.byKey(const Key('move_dest_parent')), findsNothing);
    expect(find.byKey(const Key('move_dest_child')), findsNothing);
  });
}
