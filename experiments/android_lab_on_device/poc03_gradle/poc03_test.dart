import 'dart:io';

void main() async {
  print('=== POC-03: Gradle Environment & Task Execution Verification ===');
  
  final tempDir = await Directory.systemTemp.createTemp('poc03_gradle_');
  try {
    final buildGradle = '''
plugins {
    id 'base'
}
task testTask {
    doLast {
        println "NOMAD_GRADLE_TASK_EXECUTION_SUCCESS"
    }
}
''';
    final settingsGradle = 'rootProject.name = "Poc03Gradle"';
    
    await File('${tempDir.path}/build.gradle').writeAsString(buildGradle);
    await File('${tempDir.path}/settings.gradle').writeAsString(settingsGradle);
    
    print('Executing Gradle task in: ${tempDir.path}');
    // gradle invocation
    
    // Check if gradle is directly on path or gradlew
    final res = await Process.run(
      'gradle',
      ['testTask', '--no-daemon', '-q'],
      workingDirectory: tempDir.path,
      runInShell: Platform.isWindows,
    );
    
    print('Exit Code: ${res.exitCode}');
    print('Stdout: ${res.stdout.toString().trim()}');
    if (res.stderr.toString().isNotEmpty) {
      print('Stderr: ${res.stderr.toString().trim()}');
    }
    
    if (res.exitCode == 0 && res.stdout.toString().contains('NOMAD_GRADLE_TASK_EXECUTION_SUCCESS')) {
      print('>>> POC-03 RESULT: SUCCESS');
    } else {
      print('>>> POC-03 RESULT: FAILED (Note: Standard Gradle CLI test)');
    }
  } catch (e) {
    print('POC-03 Exception: $e');
  } finally {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  }
}

