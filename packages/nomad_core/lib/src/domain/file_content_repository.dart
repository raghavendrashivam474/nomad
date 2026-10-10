import 'dart:convert';

import '../identifiers/unique_id.dart';

/// Contract boundary for file content persistence.
/// Pure Dart abstraction — infrastructure-agnostic.
abstract class FileContentRepository {
  /// Reads the content of a file as a UTF-8 string.
  /// Returns empty string if file has no content yet.
  Future<String> readFile(EntityId projectId, EntityId fileNodeId);

  /// Writes string content to a file.
  Future<void> writeFile(
      EntityId projectId, EntityId fileNodeId, String content);

  /// Reads the content of a file as raw bytes.
  /// Returns an empty list if the file has no content yet.
  ///
  /// The default implementation delegates to [readFile] and UTF-8 encodes
  /// the result. Override for true binary-safe storage.
  Future<List<int>> readFileBytes(
      EntityId projectId, EntityId fileNodeId) async {
    final text = await readFile(projectId, fileNodeId);
    return utf8.encode(text);
  }

  /// Writes raw bytes to a file.
  ///
  /// The default implementation UTF-8 decodes the bytes and delegates to
  /// [writeFile]. Override for true binary-safe storage.
  Future<void> writeFileBytes(
      EntityId projectId, EntityId fileNodeId, List<int> bytes) async {
    await writeFile(projectId, fileNodeId, utf8.decode(bytes));
  }

  /// Deletes the content file.
  Future<void> deleteContent(EntityId projectId, EntityId fileNodeId);

  /// Deletes all file contents associated with a project.
  Future<void> deleteAllContentForProject(EntityId projectId);
}
