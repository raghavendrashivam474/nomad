import 'dart:io';

import 'package:nomad_core/nomad_core.dart';
import 'package:path/path.dart' as p;

/// Projects a Nomad workspace from SQLite onto the real filesystem so that
/// external toolchains (e.g. Gradle) can operate on it.
///
/// The materialized directory is a **read-only projection** — modifications
/// made by the build tool are not written back to SQLite.
class ProjectMaterializer {
  final WorkspaceRepository workspace;
  final FileContentRepository content;

  ProjectMaterializer({
    required this.workspace,
    required this.content,
  });

  /// Materializes all files for [projectId] into a new temporary directory.
  ///
  /// Returns the absolute path to the created directory. The caller is
  /// responsible for calling [cleanup] when the directory is no longer needed.
  Future<String> materialize(EntityId projectId) async {
    final tempDir = await Directory.systemTemp.createTemp('nomad_android_');
    final nodes = await workspace.getNodesForProject(projectId);

    if (nodes.isEmpty) {
      throw StateError('Project $projectId has no workspace nodes');
    }

    // 1. Build lookup: nodeId → FileNode
    final nodeMap = <EntityId, FileNode>{};
    for (final node in nodes) {
      nodeMap[node.id] = node;
    }

    // 2. Resolve each node to a relative filesystem path by walking the
    //    parentId chain up to the root.
    String resolveRelativePath(FileNode node) {
      final segments = <String>[];
      FileNode? current = node;
      while (current != null) {
        segments.insert(0, current.name);
        current =
            current.parentId != null ? nodeMap[current.parentId] : null;
      }
      return p.joinAll(segments);
    }

    // 3. Create all directories first (order does not matter because
    //    create(recursive: true) handles missing parents).
    for (final node in nodes) {
      if (node.isFolder) {
        final dirPath = p.join(tempDir.path, resolveRelativePath(node));
        await Directory(dirPath).create(recursive: true);
      }
    }

    // 4. Write all file contents.
    for (final node in nodes) {
      if (node.isFile) {
        final filePath = p.join(tempDir.path, resolveRelativePath(node));

        // Ensure the parent directory exists even if no explicit folder
        // node was created (defensive).
        final parentDir = Directory(p.dirname(filePath));
        if (!await parentDir.exists()) {
          await parentDir.create(recursive: true);
        }

        final text = await content.readFile(projectId, node.id);
        await File(filePath).writeAsString(text, flush: true);
      }
    }

    return tempDir.path;
  }

  /// Removes a previously materialized directory and all its contents.
  ///
  /// Silently succeeds if the directory does not exist.
  Future<void> cleanup(String directoryPath) async {
    final dir = Directory(directoryPath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}
