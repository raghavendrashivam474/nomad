/// Outcome of an Android build execution.
///
/// Immutable. Exactly one of [apkPath] or [errorMessage] is non-null
/// depending on [status].
class BuildResult {
  final BuildStatus status;

  /// Absolute path to the produced APK. Non-null only when [status] is
  /// [BuildStatus.success].
  final String? apkPath;

  /// Bounded build output (stdout + stderr). Kept for diagnostics.
  final String log;

  /// Wall-clock duration of the build attempt.
  final Duration duration;

  /// Human-readable error description. Non-null when [status] is not
  /// [BuildStatus.success].
  final String? errorMessage;

  const BuildResult({
    required this.status,
    this.apkPath,
    required this.log,
    required this.duration,
    this.errorMessage,
  });

  bool get isSuccess => status == BuildStatus.success;
}

enum BuildStatus {
  success,
  failure,
  timeout,
  cancelled,
}
