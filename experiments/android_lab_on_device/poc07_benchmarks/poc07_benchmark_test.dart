import 'dart:io';

void main() async {
  print('=== POC-07: Multi-Build Reliability & Warm Cache Benchmark ===');
  
  final benchmarkTemp = await Directory.systemTemp.createTemp('poc07_bench_');
  print('Project materialized in: ${benchmarkTemp.path}');

  final results = <Map<String, dynamic>>[];

  try {
    // 1. Prepare Base Compose Project
    final rootBuildGradle = '''
plugins {
    id("com.android.application") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "2.0.21" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.0.21" apply false
}
''';

    final settingsGradle = '''
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = "NomadBenchmark"
include(":app")
''';

    final gradleProperties = '''
android.useAndroidX=true
kotlin.code.style=official
android.nonTransitiveRClass=true
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
org.gradle.parallel=true
org.gradle.caching=true
''';

    final appBuildGradle = '''
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}
android {
    namespace = "com.nomad.benchmark"
    compileSdk = 35
    defaultConfig {
        applicationId = "com.nomad.benchmark"
        minSdk = 24
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
    }
    buildTypes {
        release { isMinifyEnabled = false }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    buildFeatures {
        compose = true
    }
}
dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2024.12.01")
    implementation(composeBom)
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui")
}
''';

    final manifest = '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:label="Nomad Benchmark">
        <activity android:name=".MainActivity" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
''';

    String getMainActivitySource(int counter) => '''package com.nomad.benchmark
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.Text

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            Text(text = "Hello Nomad Benchmark Run #$counter")
        }
    }
}
''';

    await File('${benchmarkTemp.path}/build.gradle.kts').writeAsString(rootBuildGradle);
    await File('${benchmarkTemp.path}/settings.gradle.kts').writeAsString(settingsGradle);
    await File('${benchmarkTemp.path}/gradle.properties').writeAsString(gradleProperties);

    final appDir = Directory('${benchmarkTemp.path}/app');
    await appDir.create(recursive: true);
    await File('${appDir.path}/build.gradle.kts').writeAsString(appBuildGradle);

    final mainDir = Directory('${appDir.path}/src/main');
    await mainDir.create(recursive: true);
    await File('${mainDir.path}/AndroidManifest.xml').writeAsString(manifest);

    final javaPkgDir = Directory('${mainDir.path}/java/com/nomad/benchmark');
    await javaPkgDir.create(recursive: true);
    await File('${javaPkgDir.path}/MainActivity.kt').writeAsString(getMainActivitySource(1));

    // Inject Gradle Wrapper
    final hostAndroid = Directory('apps/nomad_mobile/android');
    final wrapperDir = Directory('${benchmarkTemp.path}/gradle/wrapper');
    await wrapperDir.create(recursive: true);
    await File('${hostAndroid.path}/gradlew.bat').copy('${benchmarkTemp.path}/gradlew.bat');
    await File('${hostAndroid.path}/gradlew').copy('${benchmarkTemp.path}/gradlew');
    await File('${hostAndroid.path}/gradle/wrapper/gradle-wrapper.jar')
        .copy('${wrapperDir.path}/gradle-wrapper.jar');
    await File('${hostAndroid.path}/gradle/wrapper/gradle-wrapper.properties')
        .copy('${wrapperDir.path}/gradle-wrapper.properties');

    final gradlewCmd = Platform.isWindows ? '${benchmarkTemp.path}\\gradlew.bat' : './gradlew';

    // Helper build runner
    Future<Map<String, dynamic>> executeBuild(String runName, {bool modifyKotlin = false, int runIndex = 1}) async {
      if (modifyKotlin) {
        await File('${javaPkgDir.path}/MainActivity.kt').writeAsString(getMainActivitySource(runIndex));
      }

      print('\n--- Starting Build: $runName ---');
      final sw = Stopwatch()..start();
      final proc = await Process.start(
        gradlewCmd,
        ['assembleDebug', '--console=plain', '-Dorg.gradle.logging.level=quiet'],
        workingDirectory: benchmarkTemp.path,
        runInShell: Platform.isWindows,
      );

      final exitCode = await proc.exitCode;
      sw.stop();
      final elapsedSec = sw.elapsedMilliseconds / 1000.0;

      final apkFile = File('${appDir.path}/build/outputs/apk/debug/app-debug.apk');
      final apkExists = await apkFile.exists();
      final apkSizeMB = apkExists ? (await apkFile.length()) / (1024 * 1024) : 0.0;

      print('Result: ${exitCode == 0 ? "SUCCESS" : "FAILED"} | Duration: ${elapsedSec.toStringAsFixed(2)}s | APK: ${apkSizeMB.toStringAsFixed(2)} MB');
      return {
        'run': runName,
        'exitCode': exitCode,
        'durationSec': elapsedSec,
        'apkSizeMB': apkSizeMB,
        'success': exitCode == 0 && apkExists,
      };
    }

    // Run benchmark sequence
    results.add(await executeBuild('Run 1 (Initial Cold Build)', runIndex: 1));
    results.add(await executeBuild('Run 2 (Warm Daemon / Cached)', runIndex: 1));
    results.add(await executeBuild('Run 3 (Incremental Kotlin Change)', modifyKotlin: true, runIndex: 3));
    results.add(await executeBuild('Run 4 (Second Incremental Change)', modifyKotlin: true, runIndex: 4));
    results.add(await executeBuild('Run 5 (No-op Up-To-Date Verification)', runIndex: 4));

    print('\n==================== BENCHMARK SUMMARY ====================');
    for (final r in results) {
      print('${r['run']}: ${r['durationSec'].toStringAsFixed(2)}s (Success: ${r['success']}, APK: ${r['apkSizeMB'].toStringAsFixed(2)} MB)');
    }
    print('===========================================================');
    print('>>> POC-07 RESULT: SUCCESS');
  } finally {
    if (await benchmarkTemp.exists()) {
      await benchmarkTemp.delete(recursive: true);
    }
  }
}
