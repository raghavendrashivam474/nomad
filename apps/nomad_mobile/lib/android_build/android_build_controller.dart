import 'package:flutter/foundation.dart';
import 'package:nomad_core/nomad_core.dart';
import 'artifact_manager.dart';
import 'android_build_service.dart';
import 'build_error_classifier.dart';
import 'build_result.dart';
import 'providers/build_provider.dart';
import 'providers/local_host_build_provider.dart';

enum BuildPhase {
  idle,
  preparing,
  building,
  cancelling,
  success,
  failure,
  timeout,
  cancelled,
}

/// State notifier coordinating build execution, concurrency guards, and diagnostics.
class AndroidBuildController extends ChangeNotifier {
  final BuildProvider provider;
  final ArtifactManager artifactManager;
  final AndroidBuildService? buildService;

  BuildPhase _phase = BuildPhase.idle;
  EntityId? _activeProjectId;
  BuildResult? _lastResult;
  ApkArtifact? _lastArtifact;
  ClassifiedError? _classifiedError;
  String _statusMessage = 'Idle';

  AndroidBuildController({
    BuildProvider? provider,
    AndroidBuildService? buildService,
    ArtifactManager? artifactManager,
  })  : buildService = buildService,
        provider = provider ??
            (buildService != null
                ? LocalHostBuildProvider(buildService: buildService)
                : throw ArgumentError('Either provider or buildService must be supplied to AndroidBuildController')),
        artifactManager = artifactManager ??
            (buildService != null ? buildService.artifactManager : ArtifactManager());

  BuildPhase get phase => _phase;
  EntityId? get activeProjectId => _activeProjectId;
  BuildResult? get lastResult => _lastResult;
  ApkArtifact? get lastArtifact => _lastArtifact;
  ClassifiedError? get classifiedError => _classifiedError;
  String get statusMessage => _statusMessage;

  bool get isBusy =>
      _phase == BuildPhase.preparing ||
      _phase == BuildPhase.building ||
      _phase == BuildPhase.cancelling;

  /// Updates status message and notifies UI listeners during long-running builds.
  void updateProgress(String message) {
    if (isBusy && _statusMessage != message) {
      _statusMessage = message;
      notifyListeners();
    }
  }

  /// Starts building [projectId]. Returns the final [BuildResult].
  /// Throws [StateError] if another build is already in progress.
  Future<BuildResult> startBuild(EntityId projectId) async {
    if (isBusy) {
      throw StateError('A build is already in progress');
    }

    _activeProjectId = projectId;
    _phase = BuildPhase.preparing;
    _statusMessage = 'Negotiating build provider...';
    _lastResult = null;
    _lastArtifact = null;
    _classifiedError = null;
    notifyListeners();

    try {
      _phase = BuildPhase.building;
      _statusMessage = 'Compiling Android APK...';
      notifyListeners();

      final result = await provider.build(BuildRequest(projectId: projectId));
      _lastResult = result;

      switch (result.status) {
        case BuildStatus.success:
          _phase = BuildPhase.success;
          _statusMessage = 'Build succeeded';
          if (result.apkPath != null) {
            _lastArtifact = await artifactManager.getLatestArtifact(projectId);
          }
          break;
        case BuildStatus.failure:
          _phase = BuildPhase.failure;
          _statusMessage = 'Build failed: ${result.errorMessage ?? "Check diagnostics"}';
          _classifiedError = BuildErrorClassifier.classify(
            errorMessage: result.errorMessage,
            log: result.log,
            isTimeout: false,
            isCancelled: false,
          );
          break;
        case BuildStatus.timeout:
          _phase = BuildPhase.timeout;
          _statusMessage = 'Build timed out';
          _classifiedError = BuildErrorClassifier.classify(
            errorMessage: result.errorMessage,
            log: result.log,
            isTimeout: true,
            isCancelled: false,
          );
          break;
        case BuildStatus.cancelled:
          _phase = BuildPhase.cancelled;
          _statusMessage = 'Build cancelled';
          _classifiedError = BuildErrorClassifier.classify(
            errorMessage: result.errorMessage,
            log: result.log,
            isTimeout: false,
            isCancelled: true,
          );
          break;
      }
      notifyListeners();
      return result;
    } catch (e) {
      _phase = BuildPhase.failure;
      _statusMessage = 'Build error: $e';
      _classifiedError = BuildErrorClassifier.classify(
        errorMessage: e.toString(),
        log: '',
        isTimeout: false,
        isCancelled: false,
      );
      final fallbackResult = BuildResult(
        status: BuildStatus.failure,
        log: '',
        duration: Duration.zero,
        errorMessage: e.toString(),
      );
      _lastResult = fallbackResult;
      notifyListeners();
      return fallbackResult;
    }
  }

  /// Cancels the currently active build.
  void cancelBuild() {
    if (isBusy && _phase != BuildPhase.cancelling) {
      _phase = BuildPhase.cancelling;
      _statusMessage = 'Cancelling build...';
      notifyListeners();
      provider.cancel();
    }
  }

  /// Resets status back to idle without clearing [lastResult] or [lastArtifact].
  void resetState() {
    if (!isBusy) {
      _phase = BuildPhase.idle;
      _statusMessage = 'Idle';
      notifyListeners();
    }
  }
}
