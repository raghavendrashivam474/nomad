import 'package:nomad_core/nomad_core.dart';
import '../database/app_database.dart';

class ProjectMapper {
  static Map<String, dynamic> toMap(Project project) {
    return {
      AppDatabase.columnId: project.id.value,
      AppDatabase.columnName: project.name,
      AppDatabase.columnType: project.type.name,
      AppDatabase.columnCreatedAt: project.createdAt.toIso8601String(),
      AppDatabase.columnUpdatedAt: project.updatedAt.toIso8601String(),
    };
  }

  static Project fromMap(Map<String, dynamic> map) {
    return Project(
      id: EntityId(map[AppDatabase.columnId] as String),
      name: map[AppDatabase.columnName] as String,
      type: ProjectType.values.byName(map[AppDatabase.columnType] as String),
      createdAt: DateTime.parse(map[AppDatabase.columnCreatedAt] as String),
      updatedAt: DateTime.parse(map[AppDatabase.columnUpdatedAt] as String),
    );
  }
}
