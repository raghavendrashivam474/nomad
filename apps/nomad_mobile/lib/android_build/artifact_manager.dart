import 'dart:io';
import 'package:nomad_core/nomad_core.dart';
import 'package:path/path.dart' as p;

/// Represents an existing APK artifact stored on the host filesystem.
class ApkArtifact {
  final EntityId projectId;
  final String filePath;
  final int byteSize;
  final DateTime modifiedAt;

  const ApkArtifact({
    required this.projectId,
    required this.filePath,
    required this.byteSize,
    required this.modifiedAt,
  });

  String get fileName => p.basename(filePath);

  /// Human-friendly file size formatted in megabytes or kilobytes.
  String get formattedSize {
    if (byteSize < 1024 * 1024) {
      return '${(byteSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(byteSize / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

/// Manages build artifact persistence, indexing, and cleanup outside the SQLite workspace.
class ArtifactManager {
  final Directory baseDirectory;
  final int maxRetainedPerProject;

  ArtifactManager({
    Directory? baseDirectory,
    this.maxRetainedPerProject = 3,
  }) : baseDirectory = baseDirectory ??
            Directory(p.join(Directory.systemTemp.path, 'nomad_builds'));

  /// Returns the target directory for a project's artifacts.
  Directory getProjectDir(EntityId projectId) {
    return Directory(p.join(baseDirectory.path, projectId.value));
  }

  /// Copies an APK produced by Gradle into the project's artifact directory,
  /// prunes older builds beyond [maxRetainedPerProject], and returns the new [ApkArtifact].
  Future<ApkArtifact> storeArtifact({
    required EntityId projectId,
    required String sourceApkPath,
  }) async {
    final sourceFile = File(sourceApkPath);
    if (!await sourceFile.exists()) {
      throw FileSystemException('Source APK not found', sourceApkPath);
    }

    final projectDir = getProjectDir(projectId);
    await projectDir.create(recursive: true);

    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final destFileName = 'app-debug-$timestamp.apk';
    final destPath = p.join(projectDir.path, destFileName);

    await sourceFile.copy(destPath);
    final stat = await File(destPath).stat();

    // Prune older artifacts
    await pruneOldArtifacts(projectId);

    return ApkArtifact(
      projectId: projectId,
      filePath: destPath,
      byteSize: stat.size,
      modifiedAt: stat.modified,
    );
  }

  /// Lists all stored artifacts for [projectId], sorted newest first.
  Future<List<ApkArtifact>> listArtifacts(EntityId projectId) async {
    final projectDir = getProjectDir(projectId);
    if (!await projectDir.exists()) return [];

    final artifacts = <ApkArtifact>[];
    await for (final entity in projectDir.list(followLinks: false)) {
      if (entity is File && entity.path.endsWith('.apk')) {
        final stat = await entity.stat();
        artifacts.add(ApkArtifact(
          projectId: projectId,
          filePath: entity.path,
          byteSize: stat.size,
          modifiedAt: stat.modified,
        ));
      }
    }

    // Sort by modification time descending; if equal, sort by path name descending
    artifacts.sort((a, b) {
      final comp = b.modifiedAt.compareTo(a.modifiedAt);
      if (comp != 0) return comp;
      return b.filePath.compareTo(a.filePath);
    });
    return artifacts;
  }

  /// Gets the most recent artifact for [projectId], or null if none exist.
  Future<ApkArtifact?> getLatestArtifact(EntityId projectId) async {
    final list = await listArtifacts(projectId);
    return list.isNotEmpty ? list.first : null;
  }

  /// Retains at most [maxRetainedPerProject] artifacts, deleting the oldest.
  Future<void> pruneOldArtifacts(EntityId projectId) async {
    final list = await listArtifacts(projectId);
    if (list.length > maxRetainedPerProject) {
      for (var i = maxRetainedPerProject; i < list.length; i++) {
        final file = File(list[i].filePath);
        if (await file.exists()) {
          await file.delete();
        }
      }
    }
  }

  /// Deletes all artifacts stored for [projectId].
  Future<void> clearProjectArtifacts(EntityId projectId) async {
    final projectDir = getProjectDir(projectId);
    if (await projectDir.exists()) {
      await projectDir.delete(recursive: true);
    }
  }
}
