import '../identifiers/unique_id.dart';

/// Contract boundary for file content persistence.
/// Pure Dart abstraction — infrastructure-agnostic.
abstract class FileContentRepository {
  /// Reads the content of a file. Returns empty string if file has no content yet.
  Future<String> readFile(EntityId projectId, EntityId fileNodeId);

  /// Writes content to a file.
  Future<void> writeFile(EntityId projectId, EntityId fileNodeId, String content);

  /// Deletes the content file.
  Future<void> deleteContent(EntityId projectId, EntityId fileNodeId);

  /// Deletes all file contents associated with a project.
  Future<void> deleteAllContentForProject(EntityId projectId);
}
