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
      if (await file.exists()) {
        return await file.readAsString();
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
      await file.create(recursive: true);
      await file.writeAsString(content);
    } catch (e) {
      throw DomainException('Failed to write file content', cause: e);
    }
  }

  @override
  Future<void> deleteContent(EntityId projectId, EntityId fileNodeId) async {
    try {
      final file = await _getFile(projectId, fileNodeId);
      if (await file.exists()) {
        await file.delete();
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
      if (await projectDir.exists()) {
        await projectDir.delete(recursive: true);
      }
    } catch (e) {
      throw DomainException('Failed to delete project file contents', cause: e);
    }
  }
}
