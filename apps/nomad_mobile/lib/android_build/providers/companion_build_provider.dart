import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:nomad_core/nomad_core.dart';
import 'package:path/path.dart' as p;
import '../artifact_manager.dart';
import '../build_result.dart';
import 'build_provider.dart';

/// Executes builds by offloading to a Companion Agent (on-device loopback or LAN workstation).
class CompanionBuildProvider implements BuildProvider {
  final Uri endpoint;
  final HttpClient httpClient;
  final WorkspaceRepository? workspaceRepository;
  final FileContentRepository? contentRepository;
  final ArtifactManager? artifactManager;
  
  bool _isCancelled = false;
  String? _activeJobId;

  CompanionBuildProvider({
    Uri? endpoint,
    HttpClient? httpClient,
    this.workspaceRepository,
    this.contentRepository,
    this.artifactManager,
  })  : endpoint = endpoint ?? Uri.parse('http://127.0.0.1:8089'),
        httpClient = httpClient ?? HttpClient();

  @override
  Future<BuildCapabilities> getCapabilities() async {
    try {
      final req = await httpClient.getUrl(endpoint.resolve('/api/v1/capabilities'))
          .timeout(const Duration(seconds: 2));
      final res = await req.close();
      if (res.statusCode == HttpStatus.ok) {
        final body = await utf8.decodeStream(res);
        final json = jsonDecode(body) as Map<String, dynamic>;
        return BuildCapabilities(
          providerType: BuildProviderType.onDeviceCompanion,
          providerName: 'Companion Agent (${json['os'] ?? 'Device'})',
          isAvailable: json['isAvailable'] == true,
          supportsCompose: json['supportsCompose'] == true,
          supportsOffline: json['supportsOffline'] == true,
        );
      }
    } catch (_) {
      // Companion not reachable
    }
    return const BuildCapabilities(
      providerType: BuildProviderType.onDeviceCompanion,
      providerName: 'Companion Agent (Disconnected)',
      isAvailable: false,
      unavailableReason: 'Companion build agent is not running on 127.0.0.1:8089.',
    );
  }

  /// Builds a relative-path file map from the SQLite workspace for [projectId].
  Future<Map<String, String>> _snapshotProjectFiles(EntityId projectId) async {
    if (workspaceRepository == null || contentRepository == null) {
      return {};
    }
    final nodes = await workspaceRepository!.getNodesForProject(projectId);
    final nodeMap = <EntityId, FileNode>{for (final n in nodes) n.id: n};

    String resolvePath(FileNode node) {
      final segments = <String>[];
      FileNode? cur = node;
      while (cur != null) {
        segments.insert(0, cur.name);
        cur = cur.parentId != null ? nodeMap[cur.parentId] : null;
      }
      return p.joinAll(segments).replaceAll(r'\', '/');
    }

    final fileMap = <String, String>{};
    for (final node in nodes) {
      if (node.isFile) {
        final relPath = resolvePath(node);
        final text = await contentRepository!.readFile(projectId, node.id);
        fileMap[relPath] = text;
      }
    }
    return fileMap;
  }

  @override
  Future<BuildResult> build(BuildRequest request) async {
    final sw = Stopwatch()..start();
    _isCancelled = false;
    _activeJobId = null;

    try {
      // 1. Snapshot workspace files from repository
      final files = await _snapshotProjectFiles(request.projectId);

      // 2. Submit build request
      final req = await httpClient.postUrl(endpoint.resolve('/api/v1/builds'))
          .timeout(const Duration(seconds: 5));
      req.headers.contentType = ContentType.json;
      final payload = jsonEncode({
        'projectId': request.projectId.value,
        'buildType': request.buildType,
        'files': files,
      });
      req.write(payload);
      final res = await req.close();
      final body = await utf8.decodeStream(res);

      if (res.statusCode != HttpStatus.accepted && res.statusCode != HttpStatus.ok) {
        sw.stop();
        return BuildResult(
          status: BuildStatus.failure,
          log: body,
          duration: sw.elapsed,
          errorMessage: 'Companion server returned HTTP ${res.statusCode}',
        );
      }

      final initJson = jsonDecode(body) as Map<String, dynamic>;
      final jobId = initJson['jobId'] as String?;
      _activeJobId = jobId;

      // If companion processed synchronously and returned success immediately
      if (initJson['status'] == 'success') {
        sw.stop();
        return BuildResult(
          status: BuildStatus.success,
          apkPath: initJson['apkPath'] as String?,
          log: initJson['log'] as String? ?? 'Build completed via companion agent.',
          duration: sw.elapsed,
        );
      }

      if (jobId == null) {
        sw.stop();
        return BuildResult(
          status: BuildStatus.failure,
          log: body,
          duration: sw.elapsed,
          errorMessage: 'Companion agent did not return a jobId',
        );
      }

      // 3. Poll job status until completion or timeout
      const pollInterval = Duration(milliseconds: 500);
      final maxPolls = (request.timeout.inMilliseconds / pollInterval.inMilliseconds).ceil();
      var pollCount = 0;

      while (pollCount < maxPolls && !_isCancelled) {
        await Future.delayed(pollInterval);
        pollCount++;

        final statusReq = await httpClient.getUrl(endpoint.resolve('/api/v1/builds/$jobId/status'))
            .timeout(const Duration(seconds: 3));
        final statusRes = await statusReq.close();
        if (statusRes.statusCode != HttpStatus.ok) continue;

        final statusBody = await utf8.decodeStream(statusRes);
        final statusJson = jsonDecode(statusBody) as Map<String, dynamic>;
        final currentStatus = statusJson['status'] as String?;
        final log = statusJson['log'] as String? ?? '';

        if (currentStatus == 'success') {
          // 4. Download and verify APK artifact
          String? storedApkPath;
          if (statusJson['apkAvailable'] == true && artifactManager != null) {
            storedApkPath = await _downloadAndStoreArtifact(
              jobId: jobId,
              projectId: request.projectId,
              expectedSha256: statusJson['apkSha256'] as String?,
            );
          }

          sw.stop();
          return BuildResult(
            status: BuildStatus.success,
            apkPath: storedApkPath,
            log: log,
            duration: sw.elapsed,
          );
        } else if (currentStatus == 'failure') {
          sw.stop();
          return BuildResult(
            status: BuildStatus.failure,
            log: log,
            duration: sw.elapsed,
            errorMessage: statusJson['errorMessage'] as String? ?? 'Companion build failed',
          );
        } else if (currentStatus == 'timeout') {
          sw.stop();
          return BuildResult(
            status: BuildStatus.timeout,
            log: log,
            duration: sw.elapsed,
            errorMessage: 'Companion build timed out',
          );
        } else if (currentStatus == 'cancelled') {
          sw.stop();
          return BuildResult(
            status: BuildStatus.cancelled,
            log: log,
            duration: sw.elapsed,
            errorMessage: 'Build cancelled',
          );
        }
      }

      sw.stop();
      if (_isCancelled) {
        return BuildResult(
          status: BuildStatus.cancelled,
          log: '',
          duration: sw.elapsed,
          errorMessage: 'Build cancelled by user',
        );
      }

      return BuildResult(
        status: BuildStatus.timeout,
        log: '',
        duration: sw.elapsed,
        errorMessage: 'Build timed out waiting for companion agent',
      );
    } catch (e) {
      sw.stop();
      return BuildResult(
        status: _isCancelled ? BuildStatus.cancelled : BuildStatus.failure,
        log: '',
        duration: sw.elapsed,
        errorMessage: 'Companion communication error: $e',
      );
    }
  }

  Future<String?> _downloadAndStoreArtifact({
    required String jobId,
    required EntityId projectId,
    String? expectedSha256,
  }) async {
    try {
      final req = await httpClient.getUrl(endpoint.resolve('/api/v1/builds/$jobId/artifact'));
      final res = await req.close();
      if (res.statusCode != HttpStatus.ok) return null;

      final tempApk = File(p.join(Directory.systemTemp.path, 'downloaded_$jobId.apk'));
      final sink = tempApk.openWrite();
      await res.pipe(sink);

      // Verify SHA-256
      if (expectedSha256 != null && expectedSha256.isNotEmpty) {
        final bytes = await tempApk.readAsBytes();
        final actualSha256 = sha256.convert(bytes).toString();
        if (actualSha256 != expectedSha256) {
          await tempApk.delete();
          throw StateError('APK SHA-256 mismatch! Expected: $expectedSha256, Actual: $actualSha256');
        }
      }

      final stored = await artifactManager!.storeArtifact(
        projectId: projectId,
        sourceApkPath: tempApk.path,
      );
      if (await tempApk.exists()) {
        await tempApk.delete();
      }
      return stored.filePath;
    } catch (_) {
      return null;
    }
  }

  @override
  void cancel() {
    _isCancelled = true;
    final jobId = _activeJobId;
    final cancelUri = jobId != null
        ? endpoint.resolve('/api/v1/builds/$jobId/cancel')
        : endpoint.resolve('/api/v1/builds/current/cancel');
    try {
      httpClient.postUrl(cancelUri).then((req) => req.close());
    } catch (_) {}
  }
}
