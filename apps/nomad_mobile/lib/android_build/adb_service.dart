import 'dart:io';

class AdbDevice {
  final String serial;
  final String state; // 'device', 'unauthorized', 'offline'
  final String? model;
  final String? product;

  const AdbDevice({
    required this.serial,
    required this.state,
    this.model,
    this.product,
  });

  bool get isAuthorized => state == 'device';

  String get displayName {
    if (model != null && model!.isNotEmpty) {
      return '$model ($serial)';
    }
    return serial;
  }
}

class AdbInstallResult {
  final bool isSuccess;
  final String output;
  final String? errorMessage;

  const AdbInstallResult({
    required this.isSuccess,
    required this.output,
    this.errorMessage,
  });
}

/// Interface for executing system processes, allowing easy mocking/faking in tests.
abstract class ProcessExecutor {
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  });
}

class SystemProcessExecutor implements ProcessExecutor {
  const SystemProcessExecutor();

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) {
    return Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: false,
    );
  }
}

/// Provides safe, restricted ADB device management and APK installation.
class AdbService {
  final ProcessExecutor executor;
  final String? adbExecutablePath;

  AdbService({
    this.executor = const SystemProcessExecutor(),
    this.adbExecutablePath,
  });

  String _resolveAdbPath() {
    if (adbExecutablePath != null && adbExecutablePath!.isNotEmpty) {
      return adbExecutablePath!;
    }
    final androidHome = Platform.environment['ANDROID_HOME'] ??
        Platform.environment['ANDROID_SDK_ROOT'];
    if (androidHome != null && androidHome.isNotEmpty) {
      final exe = Platform.isWindows ? 'adb.exe' : 'adb';
      final path = '$androidHome${Platform.pathSeparator}platform-tools${Platform.pathSeparator}$exe';
      if (File(path).existsSync()) {
        return path;
      }
    }
    return Platform.isWindows ? 'adb.exe' : 'adb';
  }

  /// Parses `adb devices -l` output into a list of [AdbDevice] items.
  static List<AdbDevice> parseDeviceOutput(String output) {
    final devices = <AdbDevice>[];
    final lines = output.split(RegExp(r'\r?\n'));
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('List of devices attached') || line.startsWith('* daemon')) {
        continue;
      }
      final parts = line.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        final serial = parts[0];
        final state = parts[1];

        String? model;
        String? product;
        for (var i = 2; i < parts.length; i++) {
          if (parts[i].startsWith('model:')) {
            model = parts[i].substring('model:'.length);
          } else if (parts[i].startsWith('product:')) {
            product = parts[i].substring('product:'.length);
          }
        }

        devices.add(AdbDevice(
          serial: serial,
          state: state,
          model: model,
          product: product,
        ));
      }
    }
    return devices;
  }

  /// Discovers currently connected ADB devices.
  Future<List<AdbDevice>> getConnectedDevices() async {
    try {
      final res = await executor.run(_resolveAdbPath(), ['devices', '-l']);
      if (res.exitCode == 0) {
        return parseDeviceOutput(res.stdout.toString());
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Installs [apkPath] to the device identified by [serial].
  Future<AdbInstallResult> installApk({
    required String serial,
    required String apkPath,
  }) async {
    if (serial.contains(';') || serial.contains('&') || serial.contains('|')) {
      return const AdbInstallResult(
        isSuccess: false,
        output: '',
        errorMessage: 'Invalid device serial identifier',
      );
    }

    try {
      final res = await executor.run(
        _resolveAdbPath(),
        ['-s', serial, 'install', '-r', apkPath],
      );
      final out = '${res.stdout}\n${res.stderr}'.trim();
      final isSuccess = res.exitCode == 0 && out.toLowerCase().contains('success');

      return AdbInstallResult(
        isSuccess: isSuccess,
        output: out,
        errorMessage: isSuccess ? null : (out.isEmpty ? 'Exit code ${res.exitCode}' : out),
      );
    } catch (e) {
      return AdbInstallResult(
        isSuccess: false,
        output: '',
        errorMessage: e.toString(),
      );
    }
  }

  /// Launches the installed package's main activity on [serial].
  Future<bool> launchApp({
    required String serial,
    required String packageName,
    required String activityName,
  }) async {
    try {
      final component = '$packageName/$activityName';
      final res = await executor.run(
        _resolveAdbPath(),
        ['-s', serial, 'shell', 'am', 'start', '-n', component],
      );
      return res.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
