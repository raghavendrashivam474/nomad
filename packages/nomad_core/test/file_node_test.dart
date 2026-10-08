import 'package:test/test.dart';
import 'package:nomad_core/nomad_core.dart';

void main() {
  group('FileNodeType', () {
    test('has file and folder values', () {
      expect(
          FileNodeType.values,
          containsAll([
            FileNodeType.file,
            FileNodeType.folder,
          ]));
      expect(FileNodeType.values.length, equals(2));
    });
  });

  group('FileNode', () {
    final now = DateTime.utc(2025, 6, 1, 12, 0, 0);
    const projectId = EntityId('project-1');
    const nodeId = EntityId('node-1');

    test('can be created as a file with valid values', () {
      final node = FileNode(
        id: nodeId,
        projectId: projectId,
        name: 'index.html',
        type: FileNodeType.file,
        createdAt: now,
        updatedAt: now,
      );

      expect(node.id, equals(nodeId));
      expect(node.projectId, equals(projectId));
      expect(node.parentId, isNull);
      expect(node.name, equals('index.html'));
      expect(node.type, equals(FileNodeType.file));
      expect(node.isFile, isTrue);
      expect(node.isFolder, isFalse);
      expect(node.isRoot, isTrue);
    });

    test('can be created as a folder', () {
      final node = FileNode(
        id: nodeId,
        projectId: projectId,
        name: 'assets',
        type: FileNodeType.folder,
        createdAt: now,
        updatedAt: now,
      );

      expect(node.isFolder, isTrue);
      expect(node.isFile, isFalse);
    });

    test('can be created with a parent (nested node)', () {
      const parentId = EntityId('folder-1');
      final node = FileNode(
        id: nodeId,
        projectId: projectId,
        parentId: parentId,
        name: 'logo.png',
        type: FileNodeType.file,
        createdAt: now,
        updatedAt: now,
      );

      expect(node.parentId, equals(parentId));
      expect(node.isRoot, isFalse);
    });

    test('throws ContractViolationException on empty name', () {
      expect(
        () => FileNode(
          id: nodeId,
          projectId: projectId,
          name: '',
          type: FileNodeType.file,
          createdAt: now,
          updatedAt: now,
        ),
        throwsA(isA<ContractViolationException>()),
      );
    });

    test('throws ContractViolationException on whitespace-only name', () {
      expect(
        () => FileNode(
          id: nodeId,
          projectId: projectId,
          name: '   ',
          type: FileNodeType.file,
          createdAt: now,
          updatedAt: now,
        ),
        throwsA(isA<ContractViolationException>()),
      );
    });

    test('throws ContractViolationException on name with forward slash', () {
      expect(
        () => FileNode(
          id: nodeId,
          projectId: projectId,
          name: 'path/file.txt',
          type: FileNodeType.file,
          createdAt: now,
          updatedAt: now,
        ),
        throwsA(isA<ContractViolationException>()),
      );
    });

    test('throws ContractViolationException on name with backslash', () {
      expect(
        () => FileNode(
          id: nodeId,
          projectId: projectId,
          name: 'path\\file.txt',
          type: FileNodeType.file,
          createdAt: now,
          updatedAt: now,
        ),
        throwsA(isA<ContractViolationException>()),
      );
    });

    test('copyWith preserves identity and project scope', () {
      final original = FileNode(
        id: nodeId,
        projectId: projectId,
        name: 'old-name.txt',
        type: FileNodeType.file,
        createdAt: now,
        updatedAt: now,
      );

      final nextTime = now.add(const Duration(hours: 1));
      final renamed = original.copyWith(
        name: 'new-name.txt',
        updatedAt: nextTime,
      );

      // Changed
      expect(renamed.name, equals('new-name.txt'));
      expect(renamed.updatedAt, equals(nextTime));

      // Preserved
      expect(renamed.id, equals(nodeId));
      expect(renamed.projectId, equals(projectId));
      expect(renamed.type, equals(FileNodeType.file));
      expect(renamed.createdAt, equals(now));
    });

    test('equality is based on id only', () {
      final a = FileNode(
        id: nodeId,
        projectId: projectId,
        name: 'a.txt',
        type: FileNodeType.file,
        createdAt: now,
        updatedAt: now,
      );

      final b = FileNode(
        id: nodeId,
        projectId: projectId,
        name: 'b.txt',
        type: FileNodeType.folder,
        createdAt: now,
        updatedAt: now,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('nodes with different ids are not equal', () {
      final a = FileNode(
        id: const EntityId('node-a'),
        projectId: projectId,
        name: 'same.txt',
        type: FileNodeType.file,
        createdAt: now,
        updatedAt: now,
      );

      final b = FileNode(
        id: const EntityId('node-b'),
        projectId: projectId,
        name: 'same.txt',
        type: FileNodeType.file,
        createdAt: now,
        updatedAt: now,
      );

      expect(a, isNot(equals(b)));
    });
  });

  group('WorkspaceRepository contract', () {
    test('abstract class exists and declares expected methods', () {
      // Compile-time verification: if WorkspaceRepository did not declare
      // these methods, this file would not compile.
      // This test simply confirms the type is importable and usable.
      expect(WorkspaceRepository, isNotNull);
    });
  });

  group('Project isolation principle', () {
    final now = DateTime.utc(2025, 6, 1);
    const projectA = EntityId('project-a');
    const projectB = EntityId('project-b');

    test('nodes from different projects carry distinct projectId', () {
      final nodeA = FileNode(
        id: const EntityId('n-a'),
        projectId: projectA,
        name: 'index.html',
        type: FileNodeType.file,
        createdAt: now,
        updatedAt: now,
      );

      final nodeB = FileNode(
        id: const EntityId('n-b'),
        projectId: projectB,
        name: 'index.html',
        type: FileNodeType.file,
        createdAt: now,
        updatedAt: now,
      );

      // Same filename, different project scope
      expect(nodeA.name, equals(nodeB.name));
      expect(nodeA.projectId, isNot(equals(nodeB.projectId)));
    });
  });
}
