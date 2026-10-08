import 'project.dart';
import '../identifiers/unique_id.dart';

/// Contract boundary for Project persistence.
/// Pure Dart abstraction — infrastructure-agnostic.
abstract class ProjectRepository {
  /// Retrieves all projects.
  Future<List<Project>> getAllProjects();

  /// Retrieves a project by its unique ID. Returns null if not found.
  Future<Project?> getProjectById(EntityId id);

  /// Saves a project (creates new or replaces existing).
  Future<void> saveProject(Project project);

  /// Deletes a project by its unique ID.
  Future<void> deleteProject(EntityId id);
}
