import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_core/nomad_core.dart';
import 'package:nomad_mobile/android_build/project_materializer.dart';

/// In-memory fake implementations for testing without SQLite.
class FakeWorkspaceRepository implements WorkspaceRepository {
  final List<FileNode> nodes;
  FakeWorkspaceRepository(this.nodes);

  @override
  Future<List<FileNode>> getNodesForProject(EntityId projectId) async =>
      nodes.where((n) => n.projectId == projectId).toList();

  @override
  Future<FileNode?> getNodeById(EntityId id) async =>
      nodes.where((n) => n.id == id).firstOrNull;

  @override
  Future<void> createNode(FileNode node) async {}
  @override
  Future<void> renameNode(EntityId id, String newName) async {}
  @override
  Future<void> moveNode(EntityId id, EntityId? newParentId) async {}
  @override
  Future<void> deleteNode(EntityId id) async {}
  @override
  Future<void> deleteAllNodesForProject(EntityId projectId) async {}
}

class FakeFileContentRepository extends FileContentRepository {
  final Map<String, String> contents; // "projectId:nodeId" → content
  FakeFileContentRepository(this.contents);

  String _key(EntityId projectId, EntityId nodeId) =>
      '${projectId.value}:${nodeId.value}';

  @override
  Future<String> readFile(EntityId projectId, EntityId fileNodeId) async =>
      contents[_key(projectId, fileNodeId)] ?? '';

  @override
  Future<void> writeFile(
      EntityId projectId, EntityId fileNodeId, String content) async {}
  @override
  Future<void> deleteContent(
      EntityId projectId, EntityId fileNodeId) async {}
  @override
  Future<void> deleteAllContentForProject(EntityId projectId) async {}
}

void main() {
  group('ProjectMaterializer', () {
    late ProjectMaterializer materializer;
    late EntityId projectId;
    late String tempPath;

    setUp(() {
      projectId = EntityId('test-project-1');
      final now = DateTime.now();

      // Build a small tree: root → app/ → build.gradle.kts
      final appFolderId = EntityId('folder-app');
      final buildFileId = EntityId('file-build');

      final nodes = [
        FileNode(
          id: appFolderId,
          projectId: projectId,
          name: 'app',
          type: FileNodeType.folder,
          createdAt: now,
          updatedAt: now,
        ),
        FileNode(
          id: buildFileId,
          projectId: projectId,
          parentId: appFolderId,
          name: 'build.gradle.kts',
          type: FileNodeType.file,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final contents = {
        '${projectId.value}:${buildFileId.value}': 'plugins { }',
      };

      materializer = ProjectMaterializer(
        workspace: FakeWorkspaceRepository(nodes),
        content: FakeFileContentRepository(contents),
      );
    });

    tearDown(() async {
      if (tempPath.isNotEmpty) {
        await materializer.cleanup(tempPath);
      }
    });

    test('materializes files to temp directory', () async {
      tempPath = await materializer.materialize(projectId);

      expect(await Directory(tempPath).exists(), isTrue);

      final buildFile = File('$tempPath/app/build.gradle.kts');
      expect(await buildFile.exists(), isTrue);
      expect(await buildFile.readAsString(), equals('plugins { }'));
    });

    test('throws on empty project', () async {
      final emptyMaterializer = ProjectMaterializer(
        workspace: FakeWorkspaceRepository([]),
        content: FakeFileContentRepository({}),
      );

      expect(
        () => emptyMaterializer.materialize(projectId),
        throwsA(isA<StateError>()),
      );
      tempPath = ''; // nothing to clean up
    });

    test('cleanup removes directory', () async {
      tempPath = await materializer.materialize(projectId);
      expect(await Directory(tempPath).exists(), isTrue);

      await materializer.cleanup(tempPath);
      expect(await Directory(tempPath).exists(), isFalse);
      tempPath = ''; // already cleaned
    });

    test('cleanup is safe on non-existent path', () async {
      tempPath = '';
      await materializer.cleanup('/tmp/nonexistent_nomad_test_dir');
      // Should not throw
    });
  });
}
