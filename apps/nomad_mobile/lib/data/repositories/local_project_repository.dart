import 'package:nomad_core/nomad_core.dart';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../mappers/project_mapper.dart';

class LocalProjectRepository implements ProjectRepository {
  final Future<Database> Function() _dbProvider;

  LocalProjectRepository({Future<Database> Function()? dbProvider})
      : _dbProvider = dbProvider ?? (() => AppDatabase.database);

  @override
  Future<List<Project>> getAllProjects() async {
    final db = await _dbProvider();
    final rows = await db.query(
      AppDatabase.tableProjects,
      orderBy: '${AppDatabase.columnUpdatedAt} DESC',
    );
    return rows.map(ProjectMapper.fromMap).toList();
  }

  @override
  Future<Project?> getProjectById(EntityId id) async {
    final db = await _dbProvider();
    final rows = await db.query(
      AppDatabase.tableProjects,
      where: '${AppDatabase.columnId} = ?',
      whereArgs: [id.value],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return ProjectMapper.fromMap(rows.first);
  }

  @override
  Future<void> saveProject(Project project) async {
    final db = await _dbProvider();
    await db.insert(
      AppDatabase.tableProjects,
      ProjectMapper.toMap(project),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteProject(EntityId id) async {
    final db = await _dbProvider();
    await db.delete(
      AppDatabase.tableProjects,
      where: '${AppDatabase.columnId} = ?',
      whereArgs: [id.value],
    );
  }
}
