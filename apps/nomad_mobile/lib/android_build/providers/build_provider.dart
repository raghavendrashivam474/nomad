import 'package:nomad_core/nomad_core.dart';
import '../build_result.dart';

/// The execution environment hosting the compilation pipeline.
enum BuildProviderType {
  /// Local process execution on workstation (Windows/macOS/Linux).
  hostLocal,
  /// Loopback or IPC companion runtime on the Android device (e.g. Termux / embedded daemon).
  onDeviceCompanion,
  /// LAN-connected workstation agent.
  workstationAgent,
  /// Remote cloud build runner.
  remoteRunner,
}

/// Capabilities and operational status of a [BuildProvider].
class BuildCapabilities {
  final BuildProviderType providerType;
  final String providerName;
  final bool isAvailable;
  final bool supportsCompose;
  final bool supportsOffline;
  final List<String> supportedJdkVersions;
  final String? unavailableReason;

  const BuildCapabilities({
    required this.providerType,
    required this.providerName,
    required this.isAvailable,
    this.supportsCompose = true,
    this.supportsOffline = false,
    this.supportedJdkVersions = const ['17', '21'],
    this.unavailableReason,
  });
}

/// Request to execute an Android build for a specific project.
class BuildRequest {
  final EntityId projectId;
  final String buildType; // 'debug' | 'release'
  final Duration timeout;
  final Map<String, String> environmentOverrides;

  const BuildRequest({
    required this.projectId,
    this.buildType = 'debug',
    this.timeout = const Duration(minutes: 5),
    this.environmentOverrides = const {},
  });
}

/// Distinct types of streaming build events.
enum BuildEventType {
  log,
  phaseChange,
  progress,
  error,
}

/// Live event emitted during build execution.
class BuildEvent {
  final EntityId projectId;
  final BuildEventType type;
  final String message;
  final double? progressPercent;
  final DateTime timestamp;

  BuildEvent({
    required this.projectId,
    required this.type,
    required this.message,
    this.progressPercent,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Universal interface for all Android build execution backends.
abstract class BuildProvider {
  /// Returns the capabilities and readiness of this provider.
  Future<BuildCapabilities> getCapabilities();

  /// Starts building the requested project.
  Future<BuildResult> build(BuildRequest request);

  /// Cancels an in-progress build execution.
  void cancel();
}
