import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:nomad_core/nomad_core.dart';
import 'package:path/path.dart' as p;
import 'artifact_manager.dart';
import 'build_result.dart';
import 'project_materializer.dart';

/// Orchestrates a full Android debug build for a Nomad project.
///
/// Lifecycle:
///   1. Materialize project from SQLite to a temp directory.
///   2. Inject Gradle wrapper files (sourced from the Flutter host).
///   3. Execute `gradlew assembleDebug` with a bounded timeout.
///   4. On success, store the APK via [ArtifactManager].
///   5. Clean up the temp directory regardless of outcome.
///
/// The command, arguments, and working directory are hardcoded.
/// No user-supplied shell input is accepted.
class AndroidBuildService {
  final ProjectMaterializer materializer;
  final ArtifactManager artifactManager;

  /// Directory containing the Flutter host's Android project, used as the
  /// source for gradlew / gradlew.bat / gradle-wrapper.jar / properties.
  final String hostAndroidDir;

  /// Maximum wall-clock time for the Gradle invocation.
  static const Duration _buildTimeout = Duration(minutes: 5);

  /// Maximum retained log size (100 KB).
  static const int _maxLogChars = 100 * 1024;

  Process? _activeProcess;
  bool _isCancelled = false;

  AndroidBuildService({
    required this.materializer,
    required this.hostAndroidDir,
    ArtifactManager? artifactManager,
  }) : artifactManager = artifactManager ?? ArtifactManager();

  /// Resolves the optimal JAVA_HOME for Gradle builds (preferring JDK 21 or 17).
  static String? resolveCompatibleJavaHome() {
    final explicit = Platform.environment['JAVA_HOME'];
    if (explicit != null && Directory(explicit).existsSync()) {
      return explicit;
    }

    // Windows standard locations
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'] ?? '';
      final candidatePaths = [
        p.join(userProfile, '.tools', 'jdk-21'),
        p.join(userProfile, '.tools', 'jdk-17'),
        'C:\\Program Files\\Java\\jdk-21',
        'C:\\Program Files\\Java\\jdk-17',
        'C:\\Program Files\\Android\\Android Studio\\jbr',
      ];
      for (final candidate in candidatePaths) {
        if (Directory(candidate).existsSync() &&
            File(p.join(candidate, 'bin', 'java.exe')).existsSync()) {
          return candidate;
        }
      }
    }
    return null;
  }

  /// Cancels any currently running build process.
  void cancel() {
    _isCancelled = true;
    _activeProcess?.kill(ProcessSignal.sigterm);
  }

  /// Executes a debug build for [projectId] and returns the result.
  Future<BuildResult> build(EntityId projectId) async {
    final stopwatch = Stopwatch()..start();
    String? tempDirPath;
    _isCancelled = false;

    try {
      // 0. Verify host platform capability.
      if (Platform.isAndroid || Platform.isIOS) {
        return BuildResult(
          status: BuildStatus.failure,
          log: 'Mobile host environment detected ().\n'
               'Local Gradle daemon and JDK 17/21 toolchain are not available on mobile OS.\n'
               'Please run Nomad on your workstation (Windows/macOS/Linux) to build and deploy APKs to devices via ADB.',
          duration: stopwatch.elapsed,
          errorMessage: 'Workstation build host required: Gradle APK builds cannot execute directly inside mobile OS sandbox.',
        );
      }

      // 1. Materialize project files from SQLite to disk.
      tempDirPath = await materializer.materialize(projectId);

      if (_isCancelled) {
        return BuildResult(
          status: BuildStatus.cancelled,
          log: '',
          duration: stopwatch.elapsed,
          errorMessage: 'Build cancelled by user before compilation',
        );
      }

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

      if (_isCancelled) {
        return BuildResult(
          status: BuildStatus.cancelled,
          log: '',
          duration: stopwatch.elapsed,
          errorMessage: 'Build cancelled by user',
        );
      }

      // 3. Prepare absolute executable path for Gradle wrapper.
      final isWindows = Platform.isWindows;
      final executableName = isWindows ? 'gradlew.bat' : 'gradlew';
      final executablePath = p.join(tempDirPath, executableName);

      if (!isWindows) {
        // Ensure execution permissions on POSIX
        await Process.run('chmod', ['+x', executablePath]);
      }

      final env = Map<String, String>.from(Platform.environment);
      final compatibleJavaHome = resolveCompatibleJavaHome();
      if (compatibleJavaHome != null) {
        env['JAVA_HOME'] = compatibleJavaHome;
        final pathSep = Platform.isWindows ? ';' : ':';
        env['PATH'] = '${p.join(compatibleJavaHome, 'bin')}$pathSep${env['PATH'] ?? ''}';
      }

      final process = await Process.start(
        executablePath,
        ['assembleDebug', '--no-daemon', '--console=plain'],
        workingDirectory: tempDirPath,
        environment: env,
        runInShell: isWindows,
      );
      _activeProcess = process;

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
      } finally {
        _activeProcess = null;
      }

      if (_isCancelled) {
        return BuildResult(
          status: BuildStatus.cancelled,
          log: _truncate('$stdoutBuf\n$stderrBuf'),
          duration: stopwatch.elapsed,
          errorMessage: 'Build cancelled by user',
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
      final storedArtifact = await artifactManager.storeArtifact(
        projectId: projectId,
        sourceApkPath: apkPath,
      );

      return BuildResult(
        status: BuildStatus.success,
        apkPath: storedArtifact.filePath,
        log: log,
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      return BuildResult(
        status: _isCancelled ? BuildStatus.cancelled : BuildStatus.failure,
        log: '',
        duration: stopwatch.elapsed,
        errorMessage: e.toString(),
      );
    } finally {
      _activeProcess = null;
      if (tempDirPath != null) {
        await materializer.cleanup(tempDirPath);
      }
      stopwatch.stop();
    }
  }

  /// Copies gradlew, gradlew.bat, and gradle-wrapper.jar from the Flutter
  /// host's android/ directory or asset bundle into the materialized project.
  ///
  /// Returns true if required files were successfully copied.
  Future<bool> _injectGradleWrapper(String projectDir) async {
    final files = [
      ['gradlew', 'gradlew'],
      ['gradlew.bat', 'gradlew.bat'],
      [
        p.join('gradle', 'wrapper', 'gradle-wrapper.jar'),
        p.join('gradle', 'wrapper', 'gradle-wrapper.jar')
      ],
      [
        p.join('gradle', 'wrapper', 'gradle-wrapper.properties'),
        p.join('gradle', 'wrapper', 'gradle-wrapper.properties')
      ],
    ];

    // 1. Try finding a valid host directory on filesystem.
    final candidateDirs = [
      hostAndroidDir,
      p.join(Directory.current.path, 'android'),
      p.join(Directory.current.path, 'apps', 'nomad_mobile', 'android'),
      p.join(Directory.current.path, '..', 'android'),
    ];

    String? validHostDir;
    for (final dir in candidateDirs) {
      if (File(p.join(dir, 'gradlew')).existsSync() ||
          File(p.join(dir, 'gradlew.bat')).existsSync()) {
        validHostDir = dir;
        break;
      }
    }

    if (validHostDir != null) {
      var allRequiredCopied = true;
      for (final pair in files) {
        final src = File(p.join(validHostDir, pair[0]));
        final dst = File(p.join(projectDir, pair[1]));
        if (await src.exists()) {
          await dst.parent.create(recursive: true);
          await src.copy(dst.path);
        } else {
          if (!pair[0].endsWith('.properties')) {
            allRequiredCopied = false;
          }
        }
      }
      if (allRequiredCopied) return true;
    }

    // 2. Fallback: extract from bundled Flutter assets (for packaged APK on device).
    try {
      final assetFiles = [
        ['assets/gradle_wrapper/gradlew', 'gradlew'],
        ['assets/gradle_wrapper/gradlew.bat', 'gradlew.bat'],
        [
          'assets/gradle_wrapper/gradle/wrapper/gradle-wrapper.jar',
          p.join('gradle', 'wrapper', 'gradle-wrapper.jar')
        ],
        [
          'assets/gradle_wrapper/gradle/wrapper/gradle-wrapper.properties',
          p.join('gradle', 'wrapper', 'gradle-wrapper.properties')
        ],
      ];

      var assetsExtracted = 0;
      for (final pair in assetFiles) {
        try {
          final byteData = await rootBundle.load(pair[0]);
          final dst = File(p.join(projectDir, pair[1]));
          await dst.parent.create(recursive: true);
          final buffer = byteData.buffer;
          await dst.writeAsBytes(
            buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
            flush: true,
          );
          assetsExtracted++;
        } catch (_) {
          // Individual asset load failure
        }
      }
      return assetsExtracted >= 2;
    } catch (_) {
      return false;
    }
  }

  String _truncate(String log) {
    if (log.length <= _maxLogChars) return log;
    return '...[truncated]...\n${log.substring(log.length - _maxLogChars)}';
  }
}