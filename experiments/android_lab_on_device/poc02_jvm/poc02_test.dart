import 'dart:io';

void main() async {
  print('=== POC-02: OpenJDK & Heap Allocation Verification ===');
  
  final javaCode = '''
public class TestJvm {
    public static void main(String[] args) {
        long maxMem = Runtime.getRuntime().maxMemory() / (1024 * 1024);
        long totalMem = Runtime.getRuntime().totalMemory() / (1024 * 1024);
        System.out.println("JVM Initialized Successfully.");
        System.out.println("JVM Vendor: " + System.getProperty("java.vendor"));
        System.out.println("JVM Version: " + System.getProperty("java.version"));
        System.out.println("JVM Max Heap: " + maxMem + " MB");
        System.out.println("JVM Total Heap: " + totalMem + " MB");
    }
}
''';
  
  final tempDir = await Directory.systemTemp.createTemp('poc02_jvm_');
  try {
    final javaSourceFile = File('${tempDir.path}/TestJvm.java');
    await javaSourceFile.writeAsString(javaCode);
    
    print('Compiling TestJvm.java...');
    final compileRes = await Process.run('javac', [javaSourceFile.path]);
    if (compileRes.exitCode != 0) {
      print('javac failed: ${compileRes.stderr}');
      exitCode = 1;
      return;
    }
    
    print('Executing TestJvm with -Xmx512m...');
    final runRes = await Process.run('java', ['-Xmx512m', '-cp', tempDir.path, 'TestJvm']);
    print('Exit Code: ${runRes.exitCode}');
    print('Stdout:\n${runRes.stdout.toString().trim()}');
    
    if (runRes.exitCode == 0 && runRes.stdout.toString().contains('JVM Initialized Successfully')) {
      print('>>> POC-02 RESULT: SUCCESS');
    } else {
      print('>>> POC-02 RESULT: FAILED');
      exitCode = 1;
    }
  } finally {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  }
}
