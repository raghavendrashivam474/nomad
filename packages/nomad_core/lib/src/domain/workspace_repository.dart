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

  /// Moves an existing node to a new parent folder, or to root if [newParentId] is null.
  ///
  /// Throws [DomainException] or [ContractViolationException] on invalid moves:
  /// - Node does not exist
  /// - Destination folder does not exist or is not a folder
  /// - Moving a folder into itself or a descendant
  /// - Destination already contains an item with the same name
  /// - Cross-project moves
  Future<void> moveNode(EntityId id, EntityId? newParentId);

  /// Deletes a node. If the node is a folder, all children
  /// are deleted recursively.
  Future<void> deleteNode(EntityId id);

  /// Deletes all nodes belonging to a project.
  /// Called when a project is removed.
  Future<void> deleteAllNodesForProject(EntityId projectId);
}
