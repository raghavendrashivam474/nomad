import 'dart:io';
import 'package:nomad_core/nomad_core.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LocalFileContentRepository implements FileContentRepository {
  final Future<Directory> Function() _baseDirProvider;

  LocalFileContentRepository({Future<Directory> Function()? baseDirProvider})
      : _baseDirProvider = baseDirProvider ?? getApplicationDocumentsDirectory;

  Future<File> _getFile(EntityId projectId, EntityId fileNodeId) async {
    final baseDir = await _baseDirProvider();
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
    try {
      final file = await _getFile(projectId, fileNodeId);
      file.createSync(recursive: true);
      file.writeAsStringSync(content);
    } catch (e) {
      throw DomainException('Failed to write file content', cause: e);
    }
  }

  @override
  Future<void> deleteContent(EntityId projectId, EntityId fileNodeId) async {
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
    try {
      final baseDir = await _baseDirProvider();
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