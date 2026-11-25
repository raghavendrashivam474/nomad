import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_mobile/android_build/build_result.dart';

void main() {
  group('BuildResult', () {
    test('success result has apkPath and no error', () {
      const result = BuildResult(
        status: BuildStatus.success,
        apkPath: '/tmp/app-debug.apk',
        log: 'BUILD SUCCESSFUL',
        duration: Duration(seconds: 30),
      );
      expect(result.isSuccess, isTrue);
      expect(result.apkPath, isNotNull);
      expect(result.errorMessage, isNull);
    });

    test('failure result has error and no apkPath', () {
      const result = BuildResult(
        status: BuildStatus.failure,
        log: 'error output',
        duration: Duration(seconds: 5),
        errorMessage: 'Gradle exited with code 1',
      );
      expect(result.isSuccess, isFalse);
      expect(result.apkPath, isNull);
      expect(result.errorMessage, isNotNull);
    });

    test('timeout result is not success', () {
      const result = BuildResult(
        status: BuildStatus.timeout,
        log: '',
        duration: Duration(minutes: 5),
        errorMessage: 'Timed out',
      );
      expect(result.isSuccess, isFalse);
      expect(result.status, equals(BuildStatus.timeout));
    });
  });
}