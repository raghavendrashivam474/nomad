import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_mobile/android_build/build_error_classifier.dart';

void main() {
  group('BuildErrorClassifier', () {
    test('classifies missing JDK / JAVA_HOME', () {
      final classification = BuildErrorClassifier.classify(
        errorMessage: 'ERROR: JAVA_HOME is not set and no java command could be found in your PATH.',
        log: '',
        isTimeout: false,
        isCancelled: false,
      );
      expect(classification.kind, equals(BuildErrorKind.missingJdk));
      expect(classification.title, contains('Java / JDK'));
      expect(classification.suggestion, contains('JAVA_HOME'));
    });

    test('classifies missing Android SDK', () {
      final classification = BuildErrorClassifier.classify(
        errorMessage: null,
        log: 'SDK location not found. Define a valid SDK location with an ANDROID_HOME environment variable.',
        isTimeout: false,
        isCancelled: false,
      );
      expect(classification.kind, equals(BuildErrorKind.missingSdk));
      expect(classification.title, contains('Android SDK'));
      expect(classification.suggestion, contains('Android SDK'));
    });

    test('classifies Kotlin compilation errors', () {
      final classification = BuildErrorClassifier.classify(
        errorMessage: 'Execution failed for task :app:compileDebugKotlin',
        log: 'e: C:/project/app/src/main/java/MainActivity.kt: (14, 5): Unresolved reference: NonExistentClass',
        isTimeout: false,
        isCancelled: false,
      );
      expect(classification.kind, equals(BuildErrorKind.compilationError));
      expect(classification.title, contains('Kotlin Compilation Error'));
    });

    test('classifies build timeout', () {
      final classification = BuildErrorClassifier.classify(
        errorMessage: 'Timeout',
        log: '',
        isTimeout: true,
        isCancelled: false,
      );
      expect(classification.kind, equals(BuildErrorKind.timeout));
      expect(classification.title, contains('Timed Out'));
    });

    test('classifies cancelled build', () {
      final classification = BuildErrorClassifier.classify(
        errorMessage: null,
        log: '',
        isTimeout: false,
        isCancelled: true,
      );
      expect(classification.kind, equals(BuildErrorKind.cancelled));
      expect(classification.title, contains('Cancelled'));
    });
  });
}
