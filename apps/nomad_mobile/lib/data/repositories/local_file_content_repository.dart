import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:nomad_core/nomad_core.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LocalFileContentRepository implements FileContentRepository {
  final Future<Directory> Function()? _baseDirProvider;
  final Map<String, List<int>> _webInMemoryBytes = <String, List<int>>{};
  final Map<String, String> _webInMemoryText = <String, String>{};

  LocalFileContentRepository({Future<Directory> Function()? baseDirProvider})
      : _baseDirProvider = baseDirProvider;

  String _webKey(EntityId projectId, EntityId fileNodeId) =>
      '${projectId.value}/${fileNodeId.value}';

  Future<File> _getFile(EntityId projectId, EntityId fileNodeId) async {
    final provider = _baseDirProvider;
    final baseDir = provider != null
        ? await provider()
        : await getApplicationDocumentsDirectory();
    final filePath = p.join(
      baseDir.path,
      'nomad_workspaces',
      projectId.value,
      '${fileNodeId.value}.txt',
    );
    return File(filePath);
  }

  @override
  Future<String> readFile(EntityId projectId, EntityId fileNodeId) async {
    if (kIsWeb && _baseDirProvider == null) {
      final key = _webKey(projectId, fileNodeId);
      return _webInMemoryText[key] ?? '';
    }
    try {
      final file = await _getFile(projectId, fileNodeId);
      if (file.existsSync()) {
        return file.readAsStringSync();
      }
      return '';
    } catch (e) {
      throw DomainException('Failed to read file content', cause: e);
    }
  }

  @override
  Future<void> writeFile(
      EntityId projectId, EntityId fileNodeId, String content) async {
    if (kIsWeb && _baseDirProvider == null) {
      final key = _webKey(projectId, fileNodeId);
      _webInMemoryText[key] = content;
      return;
    }
    try {
      final file = await _getFile(projectId, fileNodeId);
      file.createSync(recursive: true);
      file.writeAsStringSync(content);
    } catch (e) {
      throw DomainException('Failed to write file content', cause: e);
    }
  }

  @override
  Future<List<int>> readFileBytes(
      EntityId projectId, EntityId fileNodeId) async {
    if (kIsWeb && _baseDirProvider == null) {
      final key = _webKey(projectId, fileNodeId);
      if (_webInMemoryBytes.containsKey(key)) {
        return _webInMemoryBytes[key]!;
      }
      if (_webInMemoryText.containsKey(key)) {
        return _webInMemoryText[key]!.codeUnits;
      }
      return <int>[];
    }
    try {
      final file = await _getFile(projectId, fileNodeId);
      if (file.existsSync()) {
        return file.readAsBytesSync();
      }
      return <int>[];
    } catch (e) {
      throw DomainException('Failed to read file bytes', cause: e);
    }
  }

  @override
  Future<void> writeFileBytes(
      EntityId projectId, EntityId fileNodeId, List<int> bytes) async {
    if (kIsWeb && _baseDirProvider == null) {
      final key = _webKey(projectId, fileNodeId);
      _webInMemoryBytes[key] = bytes;
      return;
    }
    try {
      final file = await _getFile(projectId, fileNodeId);
      file.createSync(recursive: true);
      file.writeAsBytesSync(bytes);
    } catch (e) {
      throw DomainException('Failed to write file bytes', cause: e);
    }
  }

  @override
  Future<void> deleteContent(EntityId projectId, EntityId fileNodeId) async {
    if (kIsWeb && _baseDirProvider == null) {
      final key = _webKey(projectId, fileNodeId);
      _webInMemoryText.remove(key);
      _webInMemoryBytes.remove(key);
      return;
    }
    try {
      final file = await _getFile(projectId, fileNodeId);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (e) {
      throw DomainException('Failed to delete file content', cause: e);
    }
  }

  @override
  Future<void> deleteAllContentForProject(EntityId projectId) async {
    if (kIsWeb && _baseDirProvider == null) {
      final prefix = '${projectId.value}/';
      _webInMemoryText.removeWhere((k, _) => k.startsWith(prefix));
      _webInMemoryBytes.removeWhere((k, _) => k.startsWith(prefix));
      return;
    }
    try {
      final provider = _baseDirProvider;
      final baseDir = provider != null
          ? await provider()
          : await getApplicationDocumentsDirectory();
      final projectDir = Directory(
        p.join(baseDir.path, 'nomad_workspaces', projectId.value),
      );
      if (projectDir.existsSync()) {
        projectDir.deleteSync(recursive: true);
      }
    } catch (e) {
      throw DomainException('Failed to delete project file contents', cause: e);
    }
  }
}