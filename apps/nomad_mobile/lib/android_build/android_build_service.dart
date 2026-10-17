import 'dart:async';
import 'dart:io';

import 'package:nomad_core/nomad_core.dart';
import 'package:path/path.dart' as p;

import 'build_result.dart';
import 'project_materializer.dart';

/// Orchestrates a full Android debug build for a Nomad project.
///
/// Lifecycle:
///   1. Materialize project from SQLite to a temp directory.
///   2. Inject Gradle wrapper files (sourced from the Flutter host).
///   3. Execute `gradlew assembleDebug` with a bounded timeout.
///   4. On success, copy the APK to a persistent artifact location.
///   5. Clean up the temp directory regardless of outcome.
///
/// The command, arguments, and working directory are hardcoded.
/// No user-supplied shell input is accepted.
class AndroidBuildService {
  final ProjectMaterializer materializer;

  /// Directory containing the Flutter host's Android project, used as the
  /// source for gradlew / gradlew.bat / gradle-wrapper.jar.
  final String hostAndroidDir;

  /// Maximum wall-clock time for the Gradle invocation.
  static const Duration _buildTimeout = Duration(minutes: 5);

  /// Maximum retained log size (100 KB).
  static const int _maxLogChars = 100 * 1024;

  AndroidBuildService({
    required this.materializer,
    required this.hostAndroidDir,
  });

  /// Executes a debug build for [projectId] and returns the result.
  Future<BuildResult> build(EntityId projectId) async {
    final stopwatch = Stopwatch()..start();
    String? tempDirPath;

    try {
      // 1. Materialize project files from SQLite to disk.
      tempDirPath = await materializer.materialize(projectId);

      // 2. Inject Gradle wrapper from the Flutter host.
      final wrapperOk = await _injectGradleWrapper(tempDirPath);
      if (!wrapperOk) {
        return BuildResult(
          status: BuildStatus.failure,
          log: '',
          duration: stopwatch.elapsed,
          errorMessage:
              'Gradle wrapper not found in host Android project '
              '($hostAndroidDir). Ensure the Flutter host has been '
              'initialized (flutter build apk or flutter run).',
        );
      }

      // 3. Execute build.
      final isWindows = Platform.isWindows;
      final executable = isWindows ? 'gradlew.bat' : './gradlew';

      final process = await Process.start(
        executable,
        ['assembleDebug', '--no-daemon', '--console=plain'],
        workingDirectory: tempDirPath,
      );

      // Collect output streams.
      final stdoutBuf = StringBuffer();
      final stderrBuf = StringBuffer();
      process.stdout.listen((chunk) {
        stdoutBuf.write(String.fromCharCodes(chunk));
      });
      process.stderr.listen((chunk) {
        stderrBuf.write(String.fromCharCodes(chunk));
      });

      // Wait with timeout.
      int exitCode;
      try {
        exitCode = await process.exitCode.timeout(_buildTimeout);
      } on TimeoutException {
        process.kill(ProcessSignal.sigterm);
        return BuildResult(
          status: BuildStatus.timeout,
          log: _truncate('$stdoutBuf\n$stderrBuf'),
          duration: stopwatch.elapsed,
          errorMessage:
              'Build timed out after ${_buildTimeout.inMinutes} minutes',
        );
      }

      final log = _truncate('$stdoutBuf\n$stderrBuf');

      if (exitCode != 0) {
        return BuildResult(
          status: BuildStatus.failure,
          log: log,
          duration: stopwatch.elapsed,
          errorMessage: 'Gradle exited with code $exitCode',
        );
      }

      // 4. Locate APK.
      final apkPath = p.join(
        tempDirPath,
        'app',
        'build',
        'outputs',
        'apk',
        'debug',
        'app-debug.apk',
      );

      if (!await File(apkPath).exists()) {
        return BuildResult(
          status: BuildStatus.failure,
          log: log,
          duration: stopwatch.elapsed,
          errorMessage:
              'Build reported success but APK not found at $apkPath',
        );
      }

      // 5. Copy APK to persistent artifact location.
      final artifactDir =
          Directory(p.join(Directory.systemTemp.path, 'nomad_builds'));
      await artifactDir.create(recursive: true);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final artifactPath =
          p.join(artifactDir.path, '${projectId.value}-$timestamp.apk');
      await File(apkPath).copy(artifactPath);

      return BuildResult(
        status: BuildStatus.success,
        apkPath: artifactPath,
        log: log,
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      return BuildResult(
        status: BuildStatus.failure,
        log: '',
        duration: stopwatch.elapsed,
        errorMessage: e.toString(),
      );
    } finally {
      if (tempDirPath != null) {
        await materializer.cleanup(tempDirPath);
      }
      stopwatch.stop();
    }
  }

  /// Copies gradlew, gradlew.bat, and gradle-wrapper.jar from the Flutter
  /// host's android/ directory into the materialized project.
  ///
  /// Returns true if all three files were successfully copied.
  Future<bool> _injectGradleWrapper(String projectDir) async {
    final files = [
      ['gradlew', 'gradlew'],
      ['gradlew.bat', 'gradlew.bat'],
      [p.join('gradle', 'wrapper', 'gradle-wrapper.jar'),
       p.join('gradle', 'wrapper', 'gradle-wrapper.jar')],
    ];

    var allCopied = true;

    for (final pair in files) {
      final src = File(p.join(hostAndroidDir, pair[0]));
      final dst = File(p.join(projectDir, pair[1]));

      if (await src.exists()) {
        await dst.parent.create(recursive: true);
        await src.copy(dst.path);
      } else {
        allCopied = false;
      }
    }

    return allCopied;
  }

  String _truncate(String log) {
    if (log.length <= _maxLogChars) return log;
    return '...[truncated]...\n${log.substring(log.length - _maxLogChars)}';
  }
}
