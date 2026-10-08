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

    test('can create and list nodes (sorted folder-first, then alphabetically)', () async {
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

      // Verify empty initial state
      var nodes = await repository.getNodesForProject(projectIdA);
      expect(nodes, isEmpty);

      // Save
      await repository.createNode(file1);
      await repository.createNode(folder1);
      await repository.createNode(file2);

      // Fetch
      nodes = await repository.getNodesForProject(projectIdA);
      expect(nodes.length, equals(3));

      // Assert sorting order (Folder first, then files sorted alphabetically)
      expect(nodes[0].id, equals(const EntityId('fol-1'))); // assets (folder)
      expect(nodes[1].id, equals(const EntityId('f-1')));   // index.html (file)
      expect(nodes[2].id, equals(const EntityId('f-2')));   // style.css (file)
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

      // Rename
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

      // Verify all 4 exist
      var nodes = await repository.getNodesForProject(projectIdA);
      expect(nodes.length, equals(4));

      // Delete root folder
      await repository.deleteNode(const EntityId('root-fol'));

      // Verify children inside src folder are deleted recursively, but package.json stays
      nodes = await repository.getNodesForProject(projectIdA);
      expect(nodes.length, equals(1));
      expect(nodes.first.id, equals(const EntityId('outside-file')));

      expect(await repository.getNodeById(const EntityId('root-fol')), isNull);
      expect(await repository.getNodeById(const EntityId('child-fol')), isNull);
      expect(await repository.getNodeById(const EntityId('nested-file')), isNull);
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

      // Get workspace for Project A
      var workspaceA = await repository.getNodesForProject(projectIdA);
      expect(workspaceA.length, equals(1));
      expect(workspaceA.first.name, equals('index.html'));

      // Get workspace for Project B
      var workspaceB = await repository.getNodesForProject(projectIdB);
      expect(workspaceB.length, equals(1));
      expect(workspaceB.first.name, equals('style.css'));

      // Delete all nodes for Project A
      await repository.deleteAllNodesForProject(projectIdA);

      // Project A must be empty, but Project B must be untouched
      expect(await repository.getNodesForProject(projectIdA), isEmpty);
      expect(await repository.getNodesForProject(projectIdB), isNotEmpty);
    });
  });
}
