enum BuildErrorKind {
  missingJdk,
  missingSdk,
  gradleWrapperMissing,
  mobileHostNotSupported,
  compilationError,
  timeout,
  cancelled,
  unknown,
}

class ClassifiedError {
  final BuildErrorKind kind;
  final String title;
  final String userMessage;
  final String? suggestion;

  const ClassifiedError({
    required this.kind,
    required this.title,
    required this.userMessage,
    this.suggestion,
  });
}

class BuildErrorClassifier {
  /// Classifies a build failure or timeout based on the error message and log.
  static ClassifiedError classify({
    required String? errorMessage,
    required String log,
    required bool isTimeout,
    required bool isCancelled,
  }) {
    if (isCancelled) {
      return const ClassifiedError(
        kind: BuildErrorKind.cancelled,
        title: 'Build Cancelled',
        userMessage: 'The build was cancelled by the user.',
      );
    }

    if (isTimeout) {
      return const ClassifiedError(
        kind: BuildErrorKind.timeout,
        title: 'Build Timed Out',
        userMessage: 'The Android build exceeded the configured time limit.',
        suggestion: 'Review build dependencies and host resources, then try again.',
      );
    }

    final combined = '${errorMessage ?? ''}\n$log'.toLowerCase();

    if (combined.contains('gradle wrapper not found') ||
        combined.contains('gradle-wrapper.jar') && combined.contains('not found')) {
      return const ClassifiedError(
        kind: BuildErrorKind.gradleWrapperMissing,
        title: 'Gradle Wrapper Missing',
        userMessage: 'Gradle wrapper files were not found in the Flutter host project.',
        suggestion: 'Ensure the host project has been initialized by running a build or Flutter project setup.',
      );
    }

    if (combined.contains('java_home is not set') ||
        combined.contains('unrecognized option: --add-opens') ||
        combined.contains('java development kit') ||
        combined.contains('unable to find a javac compiler') ||
        combined.contains('jdk_home')) {
      return const ClassifiedError(
        kind: BuildErrorKind.missingJdk,
        title: 'Java / JDK Missing or Invalid',
        userMessage: 'Java Development Kit not found or incompatible.',
        suggestion: 'Install or configure JDK 17 or newer and set JAVA_HOME.',
      );
    }

    if (combined.contains('sdk location not found') ||
        combined.contains('android_home') ||
        combined.contains('android_sdk_root') ||
        combined.contains('failed to find build tools') ||
        combined.contains('failed to find platform')) {
      return const ClassifiedError(
        kind: BuildErrorKind.missingSdk,
        title: 'Android SDK Missing',
        userMessage: 'Android SDK is unavailable or configured incorrectly.',
        suggestion: 'Verify the Android SDK path and ensure platform 34/35 build-tools are installed.',
      );
    }

    if (combined.contains('e: ') ||
        combined.contains('unresolved reference') ||
        combined.contains('syntax error') ||
        combined.contains('compilation failed') ||
        combined.contains('kotlinc')) {
      return const ClassifiedError(
        kind: BuildErrorKind.compilationError,
        title: 'Kotlin Compilation Error',
        userMessage: 'Kotlin compilation failed. Inspect source code for syntax or type errors.',
        suggestion: 'Open the build log diagnostics to see exact file and line errors.',
      );
    }

    return ClassifiedError(
      kind: BuildErrorKind.unknown,
      title: 'Build Failed',
      userMessage: errorMessage ?? 'An unknown error occurred during the build.',
      suggestion: 'Inspect the full console log for detailed Gradle diagnostics.',
    );
  }
}
