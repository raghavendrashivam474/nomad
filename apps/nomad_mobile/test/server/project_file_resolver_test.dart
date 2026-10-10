import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_core/nomad_core.dart';
import 'package:nomad_mobile/server/project_file_resolver.dart';

// Simple in-memory fakes for tests
class FakeWorkspaceRepository implements WorkspaceRepository {
  final List<FileNode> nodes = [];

  @override
  Future<List<FileNode>> getNodesForProject(EntityId projectId) async {
    return nodes.where((n) => n.projectId == projectId).toList();
  }

  @override
  Future<FileNode?> getNodeById(EntityId id) async =>
      throw UnimplementedError();
  @override
  Future<void> createNode(FileNode node) async => throw UnimplementedError();
  @override
  Future<void> renameNode(EntityId id, String newName) async =>
      throw UnimplementedError();
  @override
  Future<void> deleteNode(EntityId id) async => throw UnimplementedError();
  @override
  Future<void> deleteAllNodesForProject(EntityId projectId) async =>
      throw UnimplementedError();
}

class FakeFileContentRepository implements FileContentRepository {
  final Map<String, String> contents = {};

  String _key(EntityId projectId, EntityId fileNodeId) =>
      '${projectId.value}_${fileNodeId.value}';

  @override
  Future<String> readFile(EntityId projectId, EntityId fileNodeId) async {
    return contents[_key(projectId, fileNodeId)] ?? '';
  }

  @override
  Future<void> writeFile(
      EntityId projectId, EntityId fileNodeId, String content) async {
    contents[_key(projectId, fileNodeId)] = content;
  }

  @override
  Future<void> deleteContent(EntityId projectId, EntityId fileNodeId) async =>
      throw UnimplementedError();
  @override
  Future<void> deleteAllContentForProject(EntityId projectId) async =>
      throw UnimplementedError();
}

void main() {
  late FakeWorkspaceRepository workspaceRepo;
  late FakeFileContentRepository contentRepo;
  late ProjectFileResolver resolver;

  const projectA = EntityId('project-A');
  const projectB = EntityId('project-B');

  setUp(() {
    workspaceRepo = FakeWorkspaceRepository();
    contentRepo = FakeFileContentRepository();
    resolver = ProjectFileResolver(
      workspaceRepository: workspaceRepo,
      contentRepository: contentRepo,
    );
  });

  FileNode makeNode({
    required String id,
    required EntityId projectId,
    String? parentId,
    required String name,
    required FileNodeType type,
  }) {
    return FileNode(
      id: EntityId(id),
      projectId: projectId,
      parentId: parentId != null ? EntityId(parentId) : null,
      name: name,
      type: type,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  group('ProjectFileResolver Validation Tests', () {
    test('rejects empty or whitespace paths', () async {
      final res1 = await resolver.resolve(projectA, '');
      expect(res1, isA<FileResolutionFailure>());
      expect((res1 as FileResolutionFailure).errorType,
          equals(FileResolutionErrorType.invalidPath));

      final res2 = await resolver.resolve(projectA, '   ');
      expect(res2, isA<FileResolutionFailure>());
    });

    test('rejects absolute paths and backslashes', () async {
      final res1 = await resolver.resolve(projectA, '/index.html');
      expect(res1, isA<FileResolutionFailure>());
      expect((res1 as FileResolutionFailure).errorType,
          equals(FileResolutionErrorType.invalidPath));

      final res2 = await resolver.resolve(projectA, 'css\\style.css');
      expect(res2, isA<FileResolutionFailure>());
      expect((res2 as FileResolutionFailure).errorType,
          equals(FileResolutionErrorType.invalidPath));
    });

    test('rejects path traversal and dots', () async {
      final traversals = [
        '../index.html',
        'css/../../index.html',
        './index.html',
        'css/./style.css',
        'css/../style.css',
      ];
      for (final p in traversals) {
        final res = await resolver.resolve(projectA, p);
        expect(res, isA<FileResolutionFailure>(), reason: 'Should reject: $p');
        expect((res as FileResolutionFailure).errorType,
            equals(FileResolutionErrorType.pathTraversal));
      }
    });

    test('rejects empty segments', () async {
      final res = await resolver.resolve(projectA, 'css//style.css');
      expect(res, isA<FileResolutionFailure>());
      expect((res as FileResolutionFailure).errorType,
          equals(FileResolutionErrorType.invalidPath));
    });
  });

  group('ProjectFileResolver Resolution Tests', () {
    test('resolves root level file successfully', () async {
      final node = makeNode(
          id: 'f1',
          projectId: projectA,
          name: 'index.html',
          type: FileNodeType.file);
      workspaceRepo.nodes.add(node);
      await contentRepo.writeFile(projectA, node.id, '<h1>Hello World</h1>');

      final res = await resolver.resolve(projectA, 'index.html');
      expect(res, isA<FileResolutionSuccess>());
      final success = res as FileResolutionSuccess;
      expect(success.node.id, equals(node.id));
      expect(utf8.decode(success.bytes), equals('<h1>Hello World</h1>'));
    });

    test('resolves nested folder file successfully', () async {
      final cssFolder = makeNode(
          id: 'dir1',
          projectId: projectA,
          name: 'css',
          type: FileNodeType.folder);
      final styleCss = makeNode(
          id: 'f2',
          projectId: projectA,
          parentId: 'dir1',
          name: 'style.css',
          type: FileNodeType.file);
      workspaceRepo.nodes.addAll([cssFolder, styleCss]);
      await contentRepo.writeFile(
          projectA, styleCss.id, 'body { color: red; }');

      final res = await resolver.resolve(projectA, 'css/style.css');
      expect(res, isA<FileResolutionSuccess>());
      final success = res as FileResolutionSuccess;
      expect(success.node.id, equals(styleCss.id));
      expect(utf8.decode(success.bytes), equals('body { color: red; }'));
    });

    test('returns targetIsDirectory when path points to a folder', () async {
      final cssFolder = makeNode(
          id: 'dir1',
          projectId: projectA,
          name: 'css',
          type: FileNodeType.folder);
      workspaceRepo.nodes.add(cssFolder);

      final res = await resolver.resolve(projectA, 'css');
      expect(res, isA<FileResolutionFailure>());
      expect((res as FileResolutionFailure).errorType,
          equals(FileResolutionErrorType.targetIsDirectory));
    });

    test('returns notFound when segment does not exist', () async {
      final res = await resolver.resolve(projectA, 'nonexistent.html');
      expect(res, isA<FileResolutionFailure>());
      expect((res as FileResolutionFailure).errorType,
          equals(FileResolutionErrorType.notFound));
    });

    test('returns notFound when trying to use file as parent directory',
        () async {
      final indexHtml = makeNode(
          id: 'f1',
          projectId: projectA,
          name: 'index.html',
          type: FileNodeType.file);
      workspaceRepo.nodes.add(indexHtml);

      final res = await resolver.resolve(projectA, 'index.html/sub.css');
      expect(res, isA<FileResolutionFailure>());
      expect((res as FileResolutionFailure).errorType,
          equals(FileResolutionErrorType.notFound));
    });

    test('enforces strict project boundary isolation', () async {
      // Create identical file names in Project A and Project B
      final nodeA = makeNode(
          id: 'f-a',
          projectId: projectA,
          name: 'style.css',
          type: FileNodeType.file);
      final nodeB = makeNode(
          id: 'f-b',
          projectId: projectB,
          name: 'style.css',
          type: FileNodeType.file);
      workspaceRepo.nodes.addAll([nodeA, nodeB]);

      await contentRepo.writeFile(projectA, nodeA.id, 'A_CSS');
      await contentRepo.writeFile(projectB, nodeB.id, 'B_CSS');

      // Querying with projectA must only return Project A content
      final resA = await resolver.resolve(projectA, 'style.css');
      expect(resA, isA<FileResolutionSuccess>());
      expect(
          utf8.decode((resA as FileResolutionSuccess).bytes), equals('A_CSS'));

      // Querying with projectB must only return Project B content
      final resB = await resolver.resolve(projectB, 'style.css');
      expect(resB, isA<FileResolutionSuccess>());
      expect(
          utf8.decode((resB as FileResolutionSuccess).bytes), equals('B_CSS'));
    });
  });
}
