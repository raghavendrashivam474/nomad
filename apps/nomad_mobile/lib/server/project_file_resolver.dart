import 'dart:convert';
import 'package:nomad_core/nomad_core.dart';

/// Represents the outcome of a project file path resolution attempt.
abstract class FileResolutionResult {
  const FileResolutionResult();
}

/// A successful resolution containing the resolved node and its content.
class FileResolutionSuccess extends FileResolutionResult {
  final FileNode node;
  final List<int> bytes;

  const FileResolutionSuccess(this.node, this.bytes);
}

/// A failure outcome with a specific failure reason and message.
class FileResolutionFailure extends FileResolutionResult {
  final FileResolutionErrorType errorType;
  final String message;

  const FileResolutionFailure(this.errorType, this.message);
}

enum FileResolutionErrorType {
  invalidPath,
  pathTraversal,
  notFound,
  targetIsDirectory,
  crossProjectAccess,
}

/// Resolves logical project paths against a specific project's workspace hierarchy.
class ProjectFileResolver {
  final WorkspaceRepository workspaceRepository;
  final FileContentRepository contentRepository;

  ProjectFileResolver({
    required this.workspaceRepository,
    required this.contentRepository,
  });

  /// Resolves the requested [logicalPath] (e.g., 'css/app.css') within the workspace of [projectId].
  ///
  /// Path segment validations are strictly enforced to prevent directory traversal
  /// and access violations.
  Future<FileResolutionResult> resolve(
      EntityId projectId, String logicalPath) async {
    // 1. Path sanity checks & normalization
    final trimmedPath = logicalPath.trim();
    if (trimmedPath.isEmpty) {
      return const FileResolutionFailure(
        FileResolutionErrorType.invalidPath,
        'Path cannot be empty',
      );
    }

    // Reject absolute paths and backslashes
    if (trimmedPath.startsWith('/') || trimmedPath.contains('\\')) {
      return const FileResolutionFailure(
        FileResolutionErrorType.invalidPath,
        'Path must be logical and forward-slash separated without leading slash',
      );
    }

    // Split and filter empty/traversal segments
    final segments = trimmedPath.split('/');
    for (final segment in segments) {
      if (segment.isEmpty) {
        return const FileResolutionFailure(
          FileResolutionErrorType.invalidPath,
          'Path segments cannot be empty',
        );
      }
      if (segment == '.' || segment == '..') {
        return const FileResolutionFailure(
          FileResolutionErrorType.pathTraversal,
          'Path traversal elements (. or ..) are strictly prohibited',
        );
      }
    }

    try {
      // 2. Fetch all nodes belonging to this project
      final nodes = await workspaceRepository.getNodesForProject(projectId);

      // Enforce project boundary: verify all retrieved nodes belong to this project
      for (final n in nodes) {
        if (n.projectId != projectId) {
          return const FileResolutionFailure(
            FileResolutionErrorType.crossProjectAccess,
            'Project isolation boundary violated by workspace data',
          );
        }
      }

      // 3. Tree Walk
      FileNode? currentNode;
      EntityId? currentParentId; // Root level has parentId == null

      for (int i = 0; i < segments.length; i++) {
        final segment = segments[i];
        final isLast = (i == segments.length - 1);

        // Find match at the current folder level
        final match = _findChildByName(nodes, currentParentId, segment);
        if (match == null) {
          return FileResolutionFailure(
            FileResolutionErrorType.notFound,
            'Resource not found: "$segment" under parent "${currentParentId?.value ?? "root"}"',
          );
        }

        if (isLast) {
          if (!match.isFile) {
            return FileResolutionFailure(
              FileResolutionErrorType.targetIsDirectory,
              'Target is a directory: "${match.name}"',
            );
          }
          currentNode = match;
        } else {
          if (!match.isFolder) {
            return const FileResolutionFailure(
              FileResolutionErrorType.notFound,
              'Invalid path segment: is a file, not a directory',
            );
          }
          currentParentId = match.id;
        }
      }

      if (currentNode == null) {
        return const FileResolutionFailure(
          FileResolutionErrorType.notFound,
          'Path could not be resolved',
        );
      }

      // 4. Retrieve content safely
      // Read using existing repository contract (returns String).
      // UTF-8 encodes the returned string to obtain byte representation.
      final textContent =
          await contentRepository.readFile(projectId, currentNode.id);
      final bytes = utf8.encode(textContent);

      return FileResolutionSuccess(currentNode, bytes);
    } catch (e) {
      return FileResolutionFailure(
        FileResolutionErrorType.notFound,
        'Resolution failed due to an internal error: $e',
      );
    }
  }

  FileNode? _findChildByName(
      List<FileNode> nodes, EntityId? parentId, String name) {
    for (final node in nodes) {
      if (node.name == name && node.parentId == parentId) {
        return node;
      }
    }
    return null;
  }
}
