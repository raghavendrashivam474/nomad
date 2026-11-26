import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:nomad_core/nomad_core.dart';
import 'package:path/path.dart' as p;
import '../artifact_manager.dart';
import '../build_result.dart';
import 'build_provider.dart';

/// Callback invoked when build status/progress changes during companion execution.
typedef BuildProgressCallback = void Function(String statusMessage, String? logSnippet);

/// Executes builds by offloading to a Companion Agent (on-device loopback or LAN workstation).
class CompanionBuildProvider implements BuildProvider {
  final Uri endpoint;
  final HttpClient httpClient;
  final WorkspaceRepository? workspaceRepository;
  final FileContentRepository? contentRepository;
  final ArtifactManager? artifactManager;
  final BuildProgressCallback? onProgress;

  bool _isCancelled = false;
  String? _activeJobId;

  CompanionBuildProvider({
    Uri? endpoint,
    HttpClient? httpClient,
    this.workspaceRepository,
    this.contentRepository,
    this.artifactManager,
    this.onProgress,
  })  : endpoint = endpoint ?? Uri.parse('http://127.0.0.1:8089'),
        httpClient = httpClient ?? HttpClient();

  @override
  Future<BuildCapabilities> getCapabilities() async {
    try {
      final req = await httpClient.getUrl(endpoint.resolve('/api/v1/capabilities'))
          .timeout(const Duration(seconds: 2));
      final res = await req.close().timeout(const Duration(seconds: 2));
      if (res.statusCode == HttpStatus.ok) {
        final body = await utf8.decodeStream(res).timeout(const Duration(seconds: 2));
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

  String _generateBuildId() {
    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final nonce = Random().nextInt(10000).toString().padLeft(4, '0');
    return 'nomad-$dateStr-$timeStr-$nonce';
  }

  @override
  Future<BuildResult> build(BuildRequest request) async {
    final sw = Stopwatch()..start();
    _isCancelled = false;
    _activeJobId = null;
    final buildId = _generateBuildId();

    try {
      // 1. Snapshot workspace files from repository
      onProgress?.call('Snapshotting project workspace...', null);
      final files = await _snapshotProjectFiles(request.projectId);

      if (_isCancelled) {
        sw.stop();
        return BuildResult(
          status: BuildStatus.cancelled,
          log: '',
          duration: sw.elapsed,
          errorMessage: 'Build cancelled by user before submission',
        );
      }

      // 2. Submit build request
      onProgress?.call('Submitting build request to companion daemon...', null);
      final req = await httpClient.postUrl(endpoint.resolve('/api/v1/builds'))
          .timeout(const Duration(seconds: 5));
      req.headers.contentType = ContentType.json;
      req.headers.set('X-Nomad-Build-ID', buildId);

      final payload = jsonEncode({
        'buildId': buildId,
        'projectId': request.projectId.value,
        'buildType': request.buildType,
        'files': files,
      });
      req.write(payload);

      final res = await req.close().timeout(const Duration(seconds: 5));
      final body = await utf8.decodeStream(res).timeout(const Duration(seconds: 5));

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

        try {
          final statusReq = await httpClient.getUrl(endpoint.resolve('/api/v1/builds/$jobId/status'))
              .timeout(const Duration(seconds: 3));
          final statusRes = await statusReq.close().timeout(const Duration(seconds: 3));
          if (statusRes.statusCode != HttpStatus.ok) continue;

          final statusBody = await utf8.decodeStream(statusRes).timeout(const Duration(seconds: 3));
          final statusJson = jsonDecode(statusBody) as Map<String, dynamic>;
          final currentStatus = statusJson['status'] as String?;
          final log = statusJson['log'] as String? ?? '';
          final durationMs = statusJson['durationMs'] as int? ?? sw.elapsedMilliseconds;

          onProgress?.call('Compiling APK (${(durationMs / 1000).toStringAsFixed(1)}s)...', log);

          if (currentStatus == 'success') {
            // 4. Download and verify APK artifact
            onProgress?.call('Downloading & verifying APK artifact...', null);
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
        } catch (_) {
          // Ignore transient polling network hiccups up to the global deadline
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
        errorMessage: 'Build timed out waiting for companion agent (${request.timeout.inSeconds}s)',
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
    File? tempApk;
    try {
      final req = await httpClient.getUrl(endpoint.resolve('/api/v1/builds/$jobId/artifact'))
          .timeout(const Duration(seconds: 10));
      final res = await req.close().timeout(const Duration(seconds: 10));
      if (res.statusCode != HttpStatus.ok) return null;

      tempApk = File(p.join(Directory.systemTemp.path, 'downloaded_${jobId}_${DateTime.now().microsecondsSinceEpoch}.apk'));
      final sink = tempApk.openWrite();
      await res.pipe(sink).timeout(const Duration(seconds: 60));

      // Verify SHA-256
      if (expectedSha256 != null && expectedSha256.isNotEmpty && expectedSha256 != '_') {
        final bytes = await tempApk.readAsBytes();
        final actualSha256 = sha256.convert(bytes).toString();
        if (actualSha256.toLowerCase() != expectedSha256.toLowerCase()) {
          if (await tempApk.exists()) await tempApk.delete();
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
    } catch (e) {
      if (tempApk != null && await tempApk.exists()) {
        try {
          await tempApk.delete();
        } catch (_) {}
      }
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
      httpClient.postUrl(cancelUri).then((req) {
        req.close().timeout(const Duration(seconds: 2));
      }).catchError((_) {});
    } catch (_) {}
  }
}
