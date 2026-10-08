import '../identifiers/unique_id.dart';
import 'file_node.dart';

/// Contract boundary for workspace file/folder operations.
/// Pure Dart abstraction — infrastructure-agnostic.
///
/// All operations are scoped to a [projectId] to enforce
/// project isolation.
abstract class WorkspaceRepository {
  /// Lists all nodes belonging to a project workspace.
  Future<List<FileNode>> getNodesForProject(EntityId projectId);

  /// Retrieves a single node by its ID.
  /// Returns null if not found.
  Future<FileNode?> getNodeById(EntityId id);

  /// Creates a new file or folder node in the workspace.
  Future<void> createNode(FileNode node);

  /// Renames an existing node.
  Future<void> renameNode(EntityId id, String newName);

  /// Deletes a node. If the node is a folder, all children
  /// are deleted recursively.
  Future<void> deleteNode(EntityId id);

  /// Deletes all nodes belonging to a project.
  /// Called when a project is removed.
  Future<void> deleteAllNodesForProject(EntityId projectId);
}
