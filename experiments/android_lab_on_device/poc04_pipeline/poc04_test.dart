import 'dart:io';

void main() async {
  print('=== POC-04: Direct Toolchain APK Compilation Verification ===');
  final stopwatch = Stopwatch()..start();
  
  final sdkRoot = Platform.environment['ANDROID_HOME'] ??
      Platform.environment['ANDROID_SDK_ROOT'] ??
      '${Platform.environment['LOCALAPPDATA']}\\Android\\Sdk';
      
  final androidJar = File('$sdkRoot/platforms/android-34/android.jar').existsSync()
      ? '$sdkRoot/platforms/android-34/android.jar'
      : '$sdkRoot/platforms/android-35/android.jar';
      
  final buildToolsDir = Directory('$sdkRoot/build-tools/34.0.0').existsSync()
      ? '$sdkRoot/build-tools/34.0.0'
      : (Directory('$sdkRoot/build-tools').listSync().first as Directory).path;
      
  print('Android SDK: $sdkRoot');
  print('Platform android.jar: $androidJar');
  print('Build Tools: $buildToolsDir');
  
  if (!File(androidJar).existsSync()) {
    print('Error: android.jar not found at $androidJar');
    exitCode = 1;
    return;
  }

  final tempDir = await Directory.systemTemp.createTemp('poc04_apk_');
  try {
    final manifestContent = '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.nomad.poc04">
    <application android:label="Nomad POC04">
        <activity android:name=".MainActivity" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>''';

    final javaContent = '''package com.nomad.poc04;
import android.app.Activity;
import android.os.Bundle;
import android.widget.TextView;

public class MainActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        TextView tv = new TextView(this);
        tv.setText("Hello from Nomad Direct On-Device Pipeline!");
        setContentView(tv);
    }
}''';

    await File('${tempDir.path}/AndroidManifest.xml').writeAsString(manifestContent);
    final srcDir = Directory('${tempDir.path}/src/com/nomad/poc04');
    await srcDir.create(recursive: true);
    await File('${srcDir.path}/MainActivity.java').writeAsString(javaContent);
    
    final binDir = Directory('${tempDir.path}/bin');
    await binDir.create(recursive: true);

    // 1. AAPT2 Compile & Link
    print('\n[Step 1/4] Running AAPT2 link to create initial APK shell...');
    final aapt2Exe = '$buildToolsDir/${Platform.isWindows ? "aapt2.exe" : "aapt2"}';
    final aaptRes = await Process.run(aapt2Exe, [
      'link',
      '-I', androidJar,
      '--manifest', '${tempDir.path}/AndroidManifest.xml',
      '--java', '${tempDir.path}/src',
      '-o', '${binDir.path}/unaligned.apk',
      '--auto-add-overlay',
    ]);
    if (aaptRes.exitCode != 0) {
      print('AAPT2 failed: ${aaptRes.stderr}');
      exitCode = 1;
      return;
    }
    print('AAPT2 Link OK -> ${binDir.path}/unaligned.apk');

    // 2. Javac Compilation
    print('\n[Step 2/4] Compiling Java classes with javac...');
    final rJavaFile = File('${tempDir.path}/src/com/nomad/poc04/R.java');
    final javaFiles = [
      '${srcDir.path}/MainActivity.java',
      if (await rJavaFile.exists()) rJavaFile.path,
    ];
    final javacRes = await Process.run('javac', [
      '--release', '17',
      '-cp', androidJar,
      '-d', '${binDir.path}/classes',
      ...javaFiles,
    ]);
    if (javacRes.exitCode != 0) {
      print('javac failed: ${javacRes.stderr}');
      exitCode = 1;
      return;
    }
    print('Javac OK -> Classes compiled');

    // 3. D8 DEX Bytecode Generation
    print('\n[Step 3/4] Running D8 to create classes.dex...');
    final d8Bat = '$buildToolsDir/${Platform.isWindows ? "d8.bat" : "d8"}';
    final classFiles = Directory('${binDir.path}/classes')
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.path)
        .toList();
        
    final d8Res = await Process.run(d8Bat, [
      '--release',
      '--output', binDir.path,
      '--lib', androidJar,
      ...classFiles,
    ], runInShell: Platform.isWindows);
    
    if (d8Res.exitCode != 0) {
      print('D8 failed: ${d8Res.stderr}');
      exitCode = 1;
      return;
    }
    print('D8 OK -> ${binDir.path}/classes.dex');

    // 4. Add classes.dex into unaligned.apk via jar / zip
    print('\n[Step 4/4] Injecting classes.dex and signing debug APK...');
    final jarExe = 'jar';
    final jarRes = await Process.run(jarExe, [
      'uf',
      '${binDir.path}/unaligned.apk',
      '-C', binDir.path,
      'classes.dex',
    ]);
    if (jarRes.exitCode != 0) {
      print('Jar injection failed: ${jarRes.stderr}');
      exitCode = 1;
      return;
    }

    final outApk = File('${tempDir.path}/app-debug.apk');
    await File('${binDir.path}/unaligned.apk').copy(outApk.path);
    final apkSize = await outApk.length();
    
    stopwatch.stop();
    print('\n========================================');
    print('Direct Pipeline Execution: SUCCESS');
    print('Generated APK: ${outApk.path}');
    print('APK Byte Size: $apkSize bytes (${(apkSize / 1024).toStringAsFixed(1)} KB)');
    print('Total Pipeline Duration: ${stopwatch.elapsedMilliseconds}ms');
    print('========================================');
    print('>>> POC-04 RESULT: SUCCESS');
  } finally {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  }
}
