import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_mobile/android_build/adb_service.dart';

class MockProcessExecutor implements ProcessExecutor {
  final Future<ProcessResult> Function(String executable, List<String> arguments) onRun;
  MockProcessExecutor(this.onRun);

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    return onRun(executable, arguments);
  }
}

void main() {
  group('AdbDevice serialization & parsing', () {
    test('parses device line with model and product', () {
      const output = '''List of devices attached
emulator-5554          device product:sdk_gphone64_x86_64 model:Pixel_7 device:emulator64_x86_64_arm64 transport_id:1
192.168.1.100:5555     unauthorized
''';
      final devices = AdbService.parseDeviceOutput(output);
      expect(devices.length, equals(2));

      expect(devices[0].serial, equals('emulator-5554'));
      expect(devices[0].state, equals('device'));
      expect(devices[0].model, equals('Pixel_7'));
      expect(devices[0].product, equals('sdk_gphone64_x86_64'));
      expect(devices[0].isAuthorized, isTrue);
      expect(devices[0].displayName, equals('Pixel_7 (emulator-5554)'));

      expect(devices[1].serial, equals('192.168.1.100:5555'));
      expect(devices[1].state, equals('unauthorized'));
      expect(devices[1].isAuthorized, isFalse);
      expect(devices[1].displayName, equals('192.168.1.100:5555'));
    });

    test('ignores daemon logs and empty lines', () {
      const output = '''* daemon not running; starting now at tcp:5037
* daemon started successfully
List of devices attached

''';
      final devices = AdbService.parseDeviceOutput(output);
      expect(devices, isEmpty);
    });
  });

  group('AdbService Serial Sanitization', () {
    test('rejects shell injection characters in installApk', () async {
      final service = AdbService();
      final res = await service.installApk(
        serial: 'emulator-5554; rm -rf /',
        apkPath: '/dummy.apk',
      );
      expect(res.isSuccess, isFalse);
      expect(res.errorMessage, contains('Invalid device serial'));
    });
  });
}
