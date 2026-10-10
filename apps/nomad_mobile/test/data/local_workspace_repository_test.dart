import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_core/nomad_core.dart';
import 'package:nomad_mobile/data/database/app_database.dart';
import 'package:nomad_mobile/data/repositories/local_workspace_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database db;
  late LocalWorkspaceRepository repository;

  setUp(() async {
    final dbFactory = databaseFactoryFfi;
    db = await dbFactory.openDatabase(inMemoryDatabasePath);
    await AppDatabase.createSchema(db);
    repository = LocalWorkspaceRepository(dbProvider: () async => db);
  });

  tearDown(() async {
    await db.close();
  });

  group('LocalWorkspaceRepository Lifecycle & Isolation', () {
    final now = DateTime.utc(2025, 6, 1, 12, 0, 0);
    const projectIdA = EntityId('project-a');
    const projectIdB = EntityId('project-b');

    test('can create and list nodes (sorted folder-first, then alphabetically)',
        () async {
      final file1 = FileNode(
        id: const EntityId('f-1'),
        projectId: projectIdA,
        name: 'index.html',
        type: FileNodeType.file,
        createdAt: now,
        updatedAt: now,
      );

      final folder1 = FileNode(
        id: const EntityId('fol-1'),
        projectId: projectIdA,
        name: 'assets',
        type: FileNodeType.folder,
        createdAt: now,
        updatedAt: now,
      );

      final file2 = FileNode(
        id: const EntityId('f-2'),
        projectId: projectIdA,
        name: 'style.css',
        type: FileNodeType.file,
        createdAt: now,
        updatedAt: now,
      );

      var nodes = await repository.getNodesForProject(projectIdA);
      expect(nodes, isEmpty);

      await repository.createNode(file1);
      await repository.createNode(folder1);
      await repository.createNode(file2);

      nodes = await repository.getNodesForProject(projectIdA);
      expect(nodes.length, equals(3));
      expect(nodes[0].id, equals(const EntityId('fol-1')));
      expect(nodes[1].id, equals(const EntityId('f-1')));
      expect(nodes[2].id, equals(const EntityId('f-2')));
    });

    test('can rename nodes and retrieve by id', () async {
      final file = FileNode(
        id: const EntityId('f-id'),
        projectId: projectIdA,
        name: 'old_name.txt',
        type: FileNodeType.file,
        createdAt: now,
        updatedAt: now,
      );

      await repository.createNode(file);

      final fetched = await repository.getNodeById(const EntityId('f-id'));
      expect(fetched, isNotNull);
      expect(fetched!.name, equals('old_name.txt'));

      await repository.renameNode(const EntityId('f-id'), 'new_name.txt');

      final renamed = await repository.getNodeById(const EntityId('f-id'));
      expect(renamed!.name, equals('new_name.txt'));
      expect(renamed.updatedAt.isAfter(now), isTrue);
    });

    test('recursive folder deletion cleans up all children nodes', () async {
      final rootFolder = FileNode(
        id: const EntityId('root-fol'),
        projectId: projectIdA,
        name: 'src',
        type: FileNodeType.folder,
        createdAt: now,
        updatedAt: now,
      );

      final childFolder = FileNode(
        id: const EntityId('child-fol'),
        projectId: projectIdA,
        parentId: const EntityId('root-fol'),
        name: 'components',
        type: FileNodeType.folder,
        createdAt: now,
        updatedAt: now,
      );

      final nestedFile = FileNode(
        id: const EntityId('nested-file'),
        projectId: projectIdA,
        parentId: const EntityId('child-fol'),
        name: 'Button.js',
        type: FileNodeType.file,
        createdAt: now,
        updatedAt: now,
      );

      final outsideFile = FileNode(
        id: const EntityId('outside-file'),
        projectId: projectIdA,
        name: 'package.json',
        type: FileNodeType.file,
        createdAt: now,
        updatedAt: now,
      );

      await repository.createNode(rootFolder);
      await repository.createNode(childFolder);
      await repository.createNode(nestedFile);
      await repository.createNode(outsideFile);

      var nodes = await repository.getNodesForProject(projectIdA);
      expect(nodes.length, equals(4));

      await repository.deleteNode(const EntityId('root-fol'));

      nodes = await repository.getNodesForProject(projectIdA);
      expect(nodes.length, equals(1));
      expect(nodes.first.id, equals(const EntityId('outside-file')));

      expect(await repository.getNodeById(const EntityId('root-fol')), isNull);
      expect(await repository.getNodeById(const EntityId('child-fol')), isNull);
      expect(
          await repository.getNodeById(const EntityId('nested-file')), isNull);
    });

    test('project isolation is strictly enforced', () async {
      final nodeA = FileNode(
        id: const EntityId('shared-id'),
        projectId: projectIdA,
        name: 'index.html',
        type: FileNodeType.file,
        createdAt: now,
        updatedAt: now,
      );

      final nodeB = FileNode(
        id: const EntityId('shared-id-b'),
        projectId: projectIdB,
        name: 'style.css',
        type: FileNodeType.file,
        createdAt: now,
        updatedAt: now,
      );

      await repository.createNode(nodeA);
      await repository.createNode(nodeB);

      var workspaceA = await repository.getNodesForProject(projectIdA);
      expect(workspaceA.length, equals(1));
      expect(workspaceA.first.name, equals('index.html'));

      var workspaceB = await repository.getNodesForProject(projectIdB);
      expect(workspaceB.length, equals(1));
      expect(workspaceB.first.name, equals('style.css'));

      await repository.deleteAllNodesForProject(projectIdA);

      expect(await repository.getNodesForProject(projectIdA), isEmpty);
      expect(await repository.getNodesForProject(projectIdB), isNotEmpty);
    });
  });

  group('LocalWorkspaceRepository Move Operations (WX-2A)', () {
    final now = DateTime.utc(2025, 6, 1, 12, 0, 0);
    const projectIdA = EntityId('project-a');
    const projectIdB = EntityId('project-b');

    test('successfully moves a file into a folder', () async {
      final folder = FileNode(
        id: const EntityId('target-folder'),
        projectId: projectIdA,
        name: 'lib',
        type: FileNodeType.folder,
        createdAt: now,
        updatedAt: now,
      );
      final file = FileNode(
        id: const EntityId('source-file'),
        projectId: projectIdA,
        name: 'main.dart',
        type: FileNodeType.file,
        createdAt: now,
        updatedAt: now,
      );

      await repository.createNode(folder);
      await repository.createNode(file);

      // Move main.dart to lib/
      await repository.moveNode(file.id, folder.id);

      final moved = await repository.getNodeById(file.id);
      expect(moved?.parentId, equals(folder.id));
      expect(moved?.name, equals('main.dart'));
    });

    test('successfully moves a file to root (parentId = null)', () async {
      final folder = FileNode(
        id: const EntityId('src-folder'),
        projectId: projectIdA,
        name: 'src',
        type: FileNodeType.folder,
        createdAt: now,
        updatedAt: now,
      );
      final file = FileNode(
        id: const EntityId('nested-file'),
        projectId: projectIdA,
        parentId: folder.id,
        name: 'app.js',
        type: FileNodeType.file,
        createdAt: now,
        updatedAt: now,
      );

      await repository.createNode(folder);
      await repository.createNode(file);

      // Move to root
      await repository.moveNode(file.id, null);

      final moved = await repository.getNodeById(file.id);
      expect(moved?.parentId, isNull);
    });

    test('successfully moves a populated folder preserving subtree', () async {
      final folderA = FileNode(
        id: const EntityId('fol-a'),
        projectId: projectIdA,
        name: 'folderA',
        type: FileNodeType.folder,
        createdAt: now,
        updatedAt: now,
      );
      final childFolder = FileNode(
        id: const EntityId('child-fol'),
        projectId: projectIdA,
        parentId: folderA.id,
        name: 'subfolder',
        type: FileNodeType.folder,
        createdAt: now,
        updatedAt: now,
      );
      final childFile = FileNode(
        id: const EntityId('child-file'),
        projectId: projectIdA,
        parentId: childFolder.id,
        name: 'nested.txt',
        type: FileNodeType.file,
        createdAt: now,
        updatedAt: now,
      );
      final folderB = FileNode(
        id: const EntityId('fol-b'),
        projectId: projectIdA,
        name: 'folderB',
        type: FileNodeType.folder,
        createdAt: now,
        updatedAt: now,
      );

      await repository.createNode(folderA);
      await repository.createNode(childFolder);
      await repository.createNode(childFile);
      await repository.createNode(folderB);

      // Move folderA into folderB
      await repository.moveNode(folderA.id, folderB.id);

      final movedA = await repository.getNodeById(folderA.id);
      expect(movedA?.parentId, equals(folderB.id));

      // Children are still parented to their original parents (intact subtree)
      final sub = await repository.getNodeById(childFolder.id);
      expect(sub?.parentId, equals(folderA.id));
      final file = await repository.getNodeById(childFile.id);
      expect(file?.parentId, equals(childFolder.id));
    });

    test('rejects move to a non-existent parent folder', () async {
      final file = FileNode(
        id: const EntityId('orphan-file'),
        projectId: projectIdA,
        name: 'file.txt',
        type: FileNodeType.file,
        createdAt: now,
        updatedAt: now,
      );
      await repository.createNode(file);

      expect(
        () => repository.moveNode(file.id, const EntityId('non-existent-id')),
        throwsA(isA<DomainException>()),
      );
    });

    test('rejects moving a node into a file (must be folder)', () async {
      final file1 = FileNode(
        id: const EntityId('f-1'),
        projectId: projectIdA,
        name: 'index.html',
        type: FileNodeType.file,
        createdAt: now,
        updatedAt: now,
      );
      final file2 = FileNode(
        id: const EntityId('f-2'),
        projectId: projectIdA,
        name: 'style.css',
        type: FileNodeType.file,
        createdAt: now,
        updatedAt: now,
      );
      await repository.createNode(file1);
      await repository.createNode(file2);

      expect(
        () => repository.moveNode(file1.id, file2.id),
        throwsA(isA<DomainException>()),
      );
    });

    test('rejects moving a node into itself', () async {
      final folder = FileNode(
        id: const EntityId('loop-fol'),
        projectId: projectIdA,
        name: 'loop',
        type: FileNodeType.folder,
        createdAt: now,
        updatedAt: now,
      );
      await repository.createNode(folder);

      expect(
        () => repository.moveNode(folder.id, folder.id),
        throwsA(isA<DomainException>()),
      );
    });

    test('rejects moving a folder into its own descendant (cycle prevention)',
        () async {
      final parentFolder = FileNode(
        id: const EntityId('p-fol'),
        projectId: projectIdA,
        name: 'parent',
        type: FileNodeType.folder,
        createdAt: now,
        updatedAt: now,
      );
      final childFolder = FileNode(
        id: const EntityId('c-fol'),
        projectId: projectIdA,
        parentId: parentFolder.id,
        name: 'child',
        type: FileNodeType.folder,
        createdAt: now,
        updatedAt: now,
      );
      final deepChildFolder = FileNode(
        id: const EntityId('deep-c-fol'),
        projectId: projectIdA,
        parentId: childFolder.id,
        name: 'deep',
        type: FileNodeType.folder,
        createdAt: now,
        updatedAt: now,
      );

      await repository.createNode(parentFolder);
      await repository.createNode(childFolder);
      await repository.createNode(deepChildFolder);

      // Attempting to move parent into its grand-child must throw DomainException
      expect(
        () => repository.moveNode(parentFolder.id, deepChildFolder.id),
        throwsA(isA<DomainException>()),
      );
    });

    test('rejects moving when a node with identical name exists at destination',
        () async {
      final targetFolder = FileNode(
        id: const EntityId('target-fol'),
        projectId: projectIdA,
        name: 'assets',
        type: FileNodeType.folder,
        createdAt: now,
        updatedAt: now,
      );
      final existingFile = FileNode(
        id: const EntityId('existing-file'),
        projectId: projectIdA,
        parentId: targetFolder.id,
        name: 'logo.png',
        type: FileNodeType.file,
        createdAt: now,
        updatedAt: now,
      );
      final duplicateFile = FileNode(
        id: const EntityId('dup-file'),
        projectId: projectIdA,
        name: 'logo.png', // same name at root
        type: FileNodeType.file,
        createdAt: now,
        updatedAt: now,
      );

      await repository.createNode(targetFolder);
      await repository.createNode(existingFile);
      await repository.createNode(duplicateFile);

      expect(
        () => repository.moveNode(duplicateFile.id, targetFolder.id),
        throwsA(isA<DomainException>()),
      );
    });

    test('rejects cross-project moves', () async {
      final folderProjectB = FileNode(
        id: const EntityId('fol-proj-b'),
        projectId: projectIdB,
        name: 'b-folder',
        type: FileNodeType.folder,
        createdAt: now,
        updatedAt: now,
      );
      final fileProjectA = FileNode(
        id: const EntityId('file-proj-a'),
        projectId: projectIdA,
        name: 'a-file.txt',
        type: FileNodeType.file,
        createdAt: now,
        updatedAt: now,
      );

      await repository.createNode(folderProjectB);
      await repository.createNode(fileProjectA);

      expect(
        () => repository.moveNode(fileProjectA.id, folderProjectB.id),
        throwsA(isA<DomainException>()),
      );
    });

    test('moving to same parent is a no-op without error', () async {
      final file = FileNode(
        id: const EntityId('noop-file'),
        projectId: projectIdA,
        name: 'noop.txt',
        type: FileNodeType.file,
        createdAt: now,
        updatedAt: now,
      );
      await repository.createNode(file);

      // Move to current parent (null) -> no-op
      await repository.moveNode(file.id, null);
      final node = await repository.getNodeById(file.id);
      expect(node?.parentId, isNull);
    });
  });
}
