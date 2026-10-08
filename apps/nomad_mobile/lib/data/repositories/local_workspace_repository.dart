import 'package:nomad_core/nomad_core.dart';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../mappers/file_node_mapper.dart';

class LocalWorkspaceRepository implements WorkspaceRepository {
  final Future<Database> Function() _dbProvider;

  LocalWorkspaceRepository({Future<Database> Function()? dbProvider})
      : _dbProvider = dbProvider ?? (() => AppDatabase.database);

  @override
  Future<List<FileNode>> getNodesForProject(EntityId projectId) async {
    final db = await _dbProvider();
    final rows = await db.query(
      AppDatabase.tableFileNodes,
      where: '${AppDatabase.columnProjectId} = ?',
      whereArgs: [projectId.value],
      orderBy: '${AppDatabase.columnType} DESC, ${AppDatabase.columnName} ASC',
    );
    return rows.map(FileNodeMapper.fromMap).toList();
  }

  @override
  Future<FileNode?> getNodeById(EntityId id) async {
    final db = await _dbProvider();
    final rows = await db.query(
      AppDatabase.tableFileNodes,
      where: '${AppDatabase.columnId} = ?',
      whereArgs: [id.value],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return FileNodeMapper.fromMap(rows.first);
  }

  @override
  Future<void> createNode(FileNode node) async {
    final db = await _dbProvider();
    await db.insert(
      AppDatabase.tableFileNodes,
      FileNodeMapper.toMap(node),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> renameNode(EntityId id, String newName) async {
    if (newName.trim().isEmpty || newName.contains('/') || newName.contains('\\')) {
      throw const ContractViolationException('Invalid file name');
    }

    final db = await _dbProvider();
    final now = DateTime.now().toIso8601String();
    await db.update(
      AppDatabase.tableFileNodes,
      {
        AppDatabase.columnName: newName,
        AppDatabase.columnUpdatedAt: now,
      },
      where: '${AppDatabase.columnId} = ?',
      whereArgs: [id.value],
    );
  }

  @override
  Future<void> deleteNode(EntityId id) async {
    final db = await _dbProvider();

    // Recursively collect all descendant IDs if the node is a folder
    final idsToDelete = <String>[id.value];
    var frontier = <String>[id.value];

    while (frontier.isNotEmpty) {
      final placeholders = List.filled(frontier.length, '?').join(',');
      final childRows = await db.query(
        AppDatabase.tableFileNodes,
        columns: [AppDatabase.columnId],
        where: '${AppDatabase.columnParentId} IN ($placeholders)',
        whereArgs: frontier,
      );

      final childIds = childRows
          .map((r) => r[AppDatabase.columnId] as String)
          .toList();

      idsToDelete.addAll(childIds);
      frontier = childIds;
    }

    final deletePlaceholders = List.filled(idsToDelete.length, '?').join(',');
    await db.delete(
      AppDatabase.tableFileNodes,
      where: '${AppDatabase.columnId} IN ($deletePlaceholders)',
      whereArgs: idsToDelete,
    );
  }

  @override
  Future<void> deleteAllNodesForProject(EntityId projectId) async {
    final db = await _dbProvider();
    await db.delete(
      AppDatabase.tableFileNodes,
      where: '${AppDatabase.columnProjectId} = ?',
      whereArgs: [projectId.value],
    );
  }
}
