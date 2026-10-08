import '../errors/nomad_exception.dart';
import '../identifiers/unique_id.dart';
import 'project_type.dart';

/// Represents a Nomad development project.
class Project {
  final EntityId id;
  final String name;
  final ProjectType type;
  final DateTime createdAt;
  final DateTime updatedAt;

  Project({
    required this.id,
    required this.name,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
  }) {
    if (name.trim().isEmpty) {
      throw const ContractViolationException('Project name cannot be empty');
    }
  }

  /// Creates a modified copy of the project ensuring immutability.
  Project copyWith({
    String? name,
    ProjectType? type,
    DateTime? updatedAt,
  }) {
    return Project(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
