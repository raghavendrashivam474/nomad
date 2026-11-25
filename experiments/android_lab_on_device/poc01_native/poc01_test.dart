import 'dart:io';

void main() async {
  print('=== POC-01: Native Execution Verification ===');
  print('OS: ${Platform.operatingSystem} (${Platform.operatingSystemVersion})');
  print('Architecture: ${Platform.version}');
  
  final stopwatch = Stopwatch()..start();
  try {
    final cmd = Platform.isWindows ? 'cmd' : 'sh';
    final args = Platform.isWindows ? ['/c', 'echo Nomad Native Execution OK'] : ['-c', 'echo Nomad Native Execution OK'];
    final result = await Process.run(cmd, args);
    stopwatch.stop();
    
    print('Command exit code: ${result.exitCode}');
    print('Command stdout: ${result.stdout.toString().trim()}');
    print('Execution time: ${stopwatch.elapsedMilliseconds}ms');
    
    if (result.exitCode == 0 && result.stdout.toString().contains('Nomad Native Execution OK')) {
      print('>>> POC-01 RESULT: SUCCESS');
    } else {
      print('>>> POC-01 RESULT: FAILED');
      exitCode = 1;
    }
  } catch (e) {
    print('POC-01 Exception: $e');
    exitCode = 1;
  }
}
