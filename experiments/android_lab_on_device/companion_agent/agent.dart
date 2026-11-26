import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

class CompanionJob {
  final String jobId;
  final String? buildId;
  final String projectId;
  final String buildType;
  final Directory workspaceDir;
  final DateTime startedAt;
  String status; // 'queued' | 'building' | 'success' | 'failure' | 'cancelled' | 'timeout'
  String? apkPath;
  String? apkSha256;
  int? apkByteSize;
  final StringBuffer logBuffer = StringBuffer();
  String? errorMessage;
  Process? process;

  CompanionJob({
    required this.jobId,
    this.buildId,
    required this.projectId,
    required this.buildType,
    required this.workspaceDir,
    required this.startedAt,
    this.status = 'queued',
  });

  Duration get duration => DateTime.now().difference(startedAt);

  String get log {
    final str = logBuffer.toString();
    const maxChars = 200 * 1024; // 200 KB max log payload
    if (str.length <= maxChars) return str;
    return '...[earlier log truncated]...\n${str.substring(str.length - maxChars)}';
  }

  void appendLog(String chunk) {
    logBuffer.write(chunk);
    // Keep internal buffer bounded to avoid runaway memory on giant builds
    if (logBuffer.length > 500 * 1024) {
      final text = logBuffer.toString();
      logBuffer.clear();
      logBuffer.write(text.substring(text.length - 200 * 1024));
    }
  }

  Map<String, dynamic> toJson() => {
    'jobId': jobId,
    if (buildId != null) 'buildId': buildId,
    'projectId': projectId,
    'status': status,
    'durationMs': duration.inMilliseconds,
    'log': log,
    'errorMessage': errorMessage,
    'apkAvailable': apkPath != null && File(apkPath!).existsSync(),
    'apkSha256': apkSha256,
    'apkByteSize': apkByteSize,
  };
}

class CompanionBuildAgent {
  final int port;
  HttpServer? _server;
  final Map<String, CompanionJob> _jobs = {};

  CompanionBuildAgent({this.port = 8089});

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    print('[CompanionAgent] Listening on http://127.0.0.1:$port');

    _server!.listen((HttpRequest request) async {
      final path = request.uri.path;
      final method = request.method;

      request.response.headers.add('Access-Control-Allow-Origin', '*');
      request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
      request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type, X-Nomad-Token, X-Nomad-Build-ID');

      if (method == 'OPTIONS') {
        request.response.statusCode = HttpStatus.ok;
        await request.response.close();
        return;
      }

      try {
        // 1. GET /api/v1/capabilities
        if (path == '/api/v1/capabilities' && method == 'GET') {
          final caps = {
            'providerType': 'companion',
            'isAvailable': true,
            'supportsCompose': true,
            'supportsOffline': true,
            'os': Platform.operatingSystem,
            'osVersion': Platform.operatingSystemVersion,
            'hostName': Platform.localHostname,
            'supportedJdkVersions': ['17', '21'],
            'port': port,
            'version': '1.1.0-AL4',
          };
          request.response
            ..headers.contentType = ContentType.json
            ..statusCode = HttpStatus.ok
            ..write(jsonEncode(caps));
          await request.response.close();
          return;
        }

        // 2. POST /api/v1/builds (Submit and execute build)
        if (path == '/api/v1/builds' && method == 'POST') {
          final body = await utf8.decodeStream(request);
          final payload = jsonDecode(body) as Map<String, dynamic>;
          final projectId = payload['projectId'] as String? ?? 'unknown';
          final buildId = payload['buildId'] as String? ?? request.headers.value('x-nomad-build-id');
          final buildType = payload['buildType'] as String? ?? 'debug';
          final files = (payload['files'] as Map<String, dynamic>?) ?? {};

          final jobId = 'job_${DateTime.now().millisecondsSinceEpoch}';
          final tempDir = await Directory.systemTemp.createTemp('nomad_companion_${jobId}_');

          // Materialize files to temp workspace
          for (final entry in files.entries) {
            final relPath = entry.key;
            if (relPath.contains('..')) continue; // Guard against directory traversal
            final f = File(p.join(tempDir.path, relPath));
            await f.parent.create(recursive: true);
            await f.writeAsString(entry.value.toString(), flush: true);
          }

          final job = CompanionJob(
            jobId: jobId,
            buildId: buildId,
            projectId: projectId,
            buildType: buildType,
            workspaceDir: tempDir,
            startedAt: DateTime.now(),
          );
          _jobs[jobId] = job;

          // Start build asynchronously in background
          _executeBuildJob(job);

          request.response
            ..headers.contentType = ContentType.json
            ..statusCode = HttpStatus.accepted
            ..write(jsonEncode({
              'jobId': jobId,
              if (buildId != null) 'buildId': buildId,
              'status': 'building',
              'projectId': projectId,
            }));
          await request.response.close();
          return;
        }

        // 3. GET /api/v1/builds/{jobId}/status
        if (path.startsWith('/api/v1/builds/') && path.endsWith('/status') && method == 'GET') {
          final segments = path.split('/');
          final jobId = segments[segments.length - 2];
          final job = _jobs[jobId];

          if (job == null) {
            request.response
              ..statusCode = HttpStatus.notFound
              ..headers.contentType = ContentType.json
              ..write(jsonEncode({'error': 'Job not found: $jobId'}));
          } else {
            request.response
              ..headers.contentType = ContentType.json
              ..statusCode = HttpStatus.ok
              ..write(jsonEncode(job.toJson()));
          }
          await request.response.close();
          return;
        }

        // 4. GET /api/v1/builds/{jobId}/artifact
        if (path.startsWith('/api/v1/builds/') && path.endsWith('/artifact') && method == 'GET') {
          final segments = path.split('/');
          final jobId = segments[segments.length - 2];
          final job = _jobs[jobId];

          if (job == null || job.apkPath == null || !File(job.apkPath!).existsSync()) {
            request.response
              ..statusCode = HttpStatus.notFound
              ..headers.contentType = ContentType.json
              ..write(jsonEncode({'error': 'Artifact not found for job $jobId'}));
            await request.response.close();
            return;
          }

          final apkFile = File(job.apkPath!);
          final fileLength = await apkFile.length();

          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType('application', 'vnd.android.package-archive')
            ..headers.set('Content-Disposition', 'attachment; filename="app-debug-$jobId.apk"')
            ..headers.set('Content-Length', fileLength.toString())
            ..headers.set('X-APK-SHA256', job.apkSha256 ?? '');

          await apkFile.openRead().pipe(request.response);
          return;
        }

        // 5. POST /api/v1/builds/{jobId}/cancel
        if (path.startsWith('/api/v1/builds/') && path.endsWith('/cancel') && method == 'POST') {
          final segments = path.split('/');
          final jobId = segments[segments.length - 2];
          final job = _jobs[jobId];

          if (job != null) {
            job.status = 'cancelled';
            job.errorMessage = 'Build cancelled by client.';
            _terminateJobProcess(job);
          }

          request.response
            ..headers.contentType = ContentType.json
            ..statusCode = HttpStatus.ok
            ..write(jsonEncode({'status': 'cancelled', 'jobId': jobId}));
          await request.response.close();
          return;
        }

        // 6. POST /api/v1/builds/current/cancel
        if (path == '/api/v1/builds/current/cancel' && method == 'POST') {
          // Cancel all active jobs
          for (final job in _jobs.values) {
            if (job.status == 'building' || job.status == 'queued') {
              job.status = 'cancelled';
              job.errorMessage = 'Build cancelled by client.';
              _terminateJobProcess(job);
            }
          }
          request.response
            ..headers.contentType = ContentType.json
            ..statusCode = HttpStatus.ok
            ..write(jsonEncode({'status': 'cancelled', 'count': _jobs.length}));
          await request.response.close();
          return;
        }

        request.response
          ..statusCode = HttpStatus.notFound
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'error': 'Endpoint not found'}));
        await request.response.close();
      } catch (e) {
        request.response
          ..statusCode = HttpStatus.internalServerError
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'error': e.toString()}));
        await request.response.close();
      }
    });
  }

  void _terminateJobProcess(CompanionJob job) {
    if (job.process != null) {
      try {
        job.process!.kill(ProcessSignal.sigterm);
        // Backup kill if process does not exit promptly
        Timer(const Duration(seconds: 2), () {
          try {
            job.process?.kill(ProcessSignal.sigkill);
          } catch (_) {}
        });
      } catch (_) {}
    }
  }

  void _executeBuildJob(CompanionJob job) async {
    job.status = 'building';
    print('[CompanionAgent] Starting execution for job ${job.jobId} (Project: ${job.projectId})');

    try {
      // Determine executable
      final gradlew = File(p.join(job.workspaceDir.path, Platform.isWindows ? 'gradlew.bat' : 'gradlew'));
      String cmd;
      List<String> args = ['assembleDebug', '--no-daemon', '--console=plain'];

      if (await gradlew.exists()) {
        cmd = gradlew.path;
        if (!Platform.isWindows) {
          await Process.run('chmod', ['+x', cmd]);
        }
      } else {
        // Fall back to system gradle in PATH
        cmd = 'gradle';
      }

      final proc = await Process.start(
        cmd,
        args,
        workingDirectory: job.workspaceDir.path,
        runInShell: Platform.isWindows,
      );
      job.process = proc;

      proc.stdout.transform(utf8.decoder).listen((chunk) {
        job.appendLog(chunk);
      });

      proc.stderr.transform(utf8.decoder).listen((chunk) {
        job.appendLog(chunk);
      });

      final exitCode = await proc.exitCode.timeout(const Duration(minutes: 5));
      job.process = null;

      if (job.status == 'cancelled') return;

      if (exitCode != 0) {
        job.status = 'failure';
        job.errorMessage = 'Gradle process exited with code $exitCode';
        print('[CompanionAgent] Job ${job.jobId} failed with code $exitCode');
        return;
      }

      // Locate APK
      final apkCandidates = [
        File(p.join(job.workspaceDir.path, 'app', 'build', 'outputs', 'apk', 'debug', 'app-debug.apk')),
        File(p.join(job.workspaceDir.path, 'build', 'outputs', 'apk', 'debug', 'app-debug.apk')),
      ];

      File? producedApk;
      for (final candidate in apkCandidates) {
        if (await candidate.exists()) {
          producedApk = candidate;
          break;
        }
      }

      if (producedApk == null) {
        job.status = 'failure';
        job.errorMessage = 'Build finished with code 0 but APK artifact was not found in outputs.';
        print('[CompanionAgent] Job ${job.jobId} produced no APK artifact.');
        return;
      }

      // Compute REAL SHA-256 and store metadata
      final bytes = await producedApk.readAsBytes();
      final digest = sha256.convert(bytes);
      job.apkSha256 = digest.toString();
      job.apkByteSize = bytes.length;
      job.apkPath = producedApk.path;
      job.status = 'success';
      print('[CompanionAgent] Job ${job.jobId} succeeded. APK size: ${job.apkByteSize} bytes. SHA-256: ${job.apkSha256}');
    } on TimeoutException {
      _terminateJobProcess(job);
      job.status = 'timeout';
      job.errorMessage = 'Build timed out after 5 minutes';
      print('[CompanionAgent] Job ${job.jobId} timed out.');
    } catch (e) {
      if (job.status != 'cancelled') {
        job.status = 'failure';
        job.errorMessage = e.toString();
        print('[CompanionAgent] Job ${job.jobId} exception: $e');
      }
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    print('[CompanionAgent] Server stopped.');
  }
}

void main(List<String> args) async {
  final port = args.isNotEmpty ? int.tryParse(args[0]) ?? 8089 : 8089;
  final agent = CompanionBuildAgent(port: port);
  await agent.start();
  print('====================================================');
  print('Nomad Companion Build Daemon (v1.1.0-AL4)');
  print('Listening on http://127.0.0.1:$port');
  print('Ready for on-device and LAN compilation requests.');
  print('====================================================');
}
