import 'package:nomad_core/nomad_core.dart';
import '../database/app_database.dart';

class FileNodeMapper {
  static Map<String, dynamic> toMap(FileNode node) {
    return {
      AppDatabase.columnId: node.id.value,
      AppDatabase.columnProjectId: node.projectId.value,
      AppDatabase.columnParentId: node.parentId?.value,
      AppDatabase.columnName: node.name,
      AppDatabase.columnType: node.type.name,
      AppDatabase.columnCreatedAt: node.createdAt.toIso8601String(),
      AppDatabase.columnUpdatedAt: node.updatedAt.toIso8601String(),
    };
  }

  static FileNode fromMap(Map<String, dynamic> map) {
    final parentIdStr = map[AppDatabase.columnParentId] as String?;
    return FileNode(
      id: EntityId(map[AppDatabase.columnId] as String),
      projectId: EntityId(map[AppDatabase.columnProjectId] as String),
      parentId: parentIdStr != null ? EntityId(parentIdStr) : null,
      name: map[AppDatabase.columnName] as String,
      type: FileNodeType.values.byName(map[AppDatabase.columnType] as String),
      createdAt: DateTime.parse(map[AppDatabase.columnCreatedAt] as String),
      updatedAt: DateTime.parse(map[AppDatabase.columnUpdatedAt] as String),
    );
  }
}
