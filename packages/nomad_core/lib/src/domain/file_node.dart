import '../errors/nomad_exception.dart';
import '../identifiers/unique_id.dart';
import 'file_node_type.dart';

/// Represents a file or folder within a project workspace.
///
/// Project isolation is enforced via [projectId]. A FileNode from
/// Project A must never be resolvable under Project B.
class FileNode {
  final EntityId id;
  final EntityId projectId;
  final EntityId? parentId;
  final String name;
  final FileNodeType type;
  final DateTime createdAt;
  final DateTime updatedAt;

  FileNode({
    required this.id,
    required this.projectId,
    this.parentId,
    required this.name,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
  }) {
    if (name.trim().isEmpty) {
      throw const ContractViolationException('FileNode name cannot be empty');
    }
    if (name.contains('/') || name.contains('\\')) {
      throw const ContractViolationException(
        'FileNode name cannot contain path separators',
      );
    }
  }

  /// Whether this node is a file.
  bool get isFile => type == FileNodeType.file;

  /// Whether this node is a folder.
  bool get isFolder => type == FileNodeType.folder;

  /// Whether this node lives at the workspace root (no parent).
  bool get isRoot => parentId == null;

  /// Creates a modified copy preserving identity and project scope.
  FileNode copyWith({
    String? name,
    EntityId? parentId,
    DateTime? updatedAt,
  }) {
    return FileNode(
      id: id,
      projectId: projectId,
      parentId: parentId ?? this.parentId,
      name: name ?? this.name,
      type: type,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileNode && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
