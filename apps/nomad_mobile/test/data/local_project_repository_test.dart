import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_core/nomad_core.dart';
import 'package:nomad_mobile/data/database/app_database.dart';
import 'package:nomad_mobile/data/repositories/local_project_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database db;
  late LocalProjectRepository repository;

  setUp(() async {
    final dbFactory = databaseFactoryFfi;
    db = await dbFactory.openDatabase(inMemoryDatabasePath);
    await AppDatabase.createSchema(db);
    repository = LocalProjectRepository(dbProvider: () async => db);
  });

  tearDown(() async {
    await db.close();
  });

  group('LocalProjectRepository CRUD', () {
    final now = DateTime.utc(2025, 1, 1, 12, 0, 0);

    test('can save, read, list, update, and delete projects', () async {
      final project1 = Project(
        id: const EntityId('p-1'),
        name: 'Alpha Web',
        type: ProjectType.web,
        createdAt: now,
        updatedAt: now,
      );

      final project2 = Project(
        id: const EntityId('p-2'),
        name: 'Beta Android',
        type: ProjectType.android,
        createdAt: now,
        updatedAt: now.add(const Duration(hours: 1)),
      );

      // 1. Initial state is empty
      var projects = await repository.getAllProjects();
      expect(projects, isEmpty);

      // 2. Save projects
      await repository.saveProject(project1);
      await repository.saveProject(project2);

      // 3. List projects (ordered by updatedAt DESC)
      projects = await repository.getAllProjects();
      expect(projects.length, equals(2));
      expect(projects.first.id, equals(const EntityId('p-2')));
      expect(projects.last.id, equals(const EntityId('p-1')));

      // 4. Get by ID
      final fetched = await repository.getProjectById(const EntityId('p-1'));
      expect(fetched, isNotNull);
      expect(fetched!.name, equals('Alpha Web'));
      expect(fetched.type, equals(ProjectType.web));

      // 5. Update project
      final updatedProject1 = project1.copyWith(
        name: 'Alpha Web Updated',
        updatedAt: now.add(const Duration(hours: 2)),
      );
      await repository.saveProject(updatedProject1);

      final reFetched = await repository.getProjectById(const EntityId('p-1'));
      expect(reFetched!.name, equals('Alpha Web Updated'));

      // 6. Delete project
      await repository.deleteProject(const EntityId('p-1'));
      final deleted = await repository.getProjectById(const EntityId('p-1'));
      expect(deleted, isNull);

      projects = await repository.getAllProjects();
      expect(projects.length, equals(1));
      expect(projects.first.id, equals(const EntityId('p-2')));
    });

    test('returns null for non-existent project id', () async {
      final result = await repository.getProjectById(const EntityId('non-existent'));
      expect(result, isNull);
    });
  });
}
