import 'dart:io';

void main() async {
  print('=== POC-05: Full Kotlin + Jetpack Compose Build Verification ===');
  final stopwatch = Stopwatch()..start();

  final tempDir = await Directory.systemTemp.createTemp('poc05_compose_');
  print('Materializing Nomad Jetpack Compose project into: ${tempDir.path}');

  try {
    // 1. Write the Nomad AndroidTemplate files
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
rootProject.name = "NomadAndroidLab"
include(":app")
''';

    final gradleProperties = '''
android.useAndroidX=true
kotlin.code.style=official
android.nonTransitiveRClass=true
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
''';

    final appBuildGradle = '''
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}
android {
    namespace = "com.nomad.lab"
    compileSdk = 35
    defaultConfig {
        applicationId = "com.nomad.lab"
        minSdk = 24
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
    }
    buildTypes {
        release {
            isMinifyEnabled = false
        }
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
    implementation("androidx.compose.ui:ui-tooling-preview")
    debugImplementation("androidx.compose.ui:ui-tooling")
}
''';

    final manifest = '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:allowBackup="true"
        android:label="Nomad Android Lab"
        android:theme="@android:style/Theme.Material.Light.NoActionBar">
        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
''';

    final mainActivity = '''package com.nomad.lab
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    Greeting()
                }
            }
        }
    }
}

@Composable
fun Greeting() {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = "Nomad Android Lab - Hello Compose",
            style = MaterialTheme.typography.headlineMedium
        )
    }
}
''';

    await File('${tempDir.path}/build.gradle.kts').writeAsString(rootBuildGradle);
    await File('${tempDir.path}/settings.gradle.kts').writeAsString(settingsGradle);
    await File('${tempDir.path}/gradle.properties').writeAsString(gradleProperties);

    final appDir = Directory('${tempDir.path}/app');
    await appDir.create(recursive: true);
    await File('${appDir.path}/build.gradle.kts').writeAsString(appBuildGradle);

    final mainDir = Directory('${appDir.path}/src/main');
    await mainDir.create(recursive: true);
    await File('${mainDir.path}/AndroidManifest.xml').writeAsString(manifest);

    final javaPkgDir = Directory('${mainDir.path}/java/com/nomad/lab');
    await javaPkgDir.create(recursive: true);
    await File('${javaPkgDir.path}/MainActivity.kt').writeAsString(mainActivity);

    // 2. Inject Gradle wrapper from apps/nomad_mobile/android
    print('Injecting Gradle wrapper...');
    final hostAndroid = Directory('apps/nomad_mobile/android');
    final wrapperDir = Directory('${tempDir.path}/gradle/wrapper');
    await wrapperDir.create(recursive: true);

    await File('${hostAndroid.path}/gradlew.bat').copy('${tempDir.path}/gradlew.bat');
    await File('${hostAndroid.path}/gradlew').copy('${tempDir.path}/gradlew');
    await File('${hostAndroid.path}/gradle/wrapper/gradle-wrapper.jar')
        .copy('${wrapperDir.path}/gradle-wrapper.jar');
    await File('${hostAndroid.path}/gradle/wrapper/gradle-wrapper.properties')
        .copy('${wrapperDir.path}/gradle-wrapper.properties');

    // 3. Execute Gradle assembleDebug
    print('Invoking gradlew assembleDebug --no-daemon --console=plain...');
    final gradlewCmd = Platform.isWindows ? '${tempDir.path}\\gradlew.bat' : './gradlew';

    final buildProcess = await Process.start(
      gradlewCmd,
      ['assembleDebug', '--no-daemon', '--console=plain', '-Dorg.gradle.logging.level=lifecycle'],
      workingDirectory: tempDir.path,
      runInShell: Platform.isWindows,
    );

    buildProcess.stdout.transform(const SystemEncoding().decoder).listen((data) {
      if (data.contains('Task :app:') || data.contains('BUILD SUCCESSFUL') || data.contains('BUILD FAILED')) {
        stdout.write(data);
      }
    });
    buildProcess.stderr.transform(const SystemEncoding().decoder).listen((data) {
      stderr.write(data);
    });

    final exitCodeVal = await buildProcess.exitCode;
    stopwatch.stop();

    print('\n========================================');
    print('Gradle assembleDebug Exit Code: $exitCodeVal');
    print('Build Duration: ${(stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1)}s');

    final expectedApk = File('${appDir.path}/build/outputs/apk/debug/app-debug.apk');
    if (exitCodeVal == 0 && await expectedApk.exists()) {
      final apkLength = await expectedApk.length();
      print('Generated APK: ${expectedApk.path}');
      print('APK Byte Size: $apkLength bytes (${(apkLength / (1024 * 1024)).toStringAsFixed(2)} MB)');
      print('========================================');
      print('>>> POC-05 RESULT: SUCCESS');
    } else {
      print('>>> POC-05 RESULT: FAILED');
      exitCode = 1;
    }
  } finally {
    if (await tempDir.exists()) {
      print('Cleaning up materialized temp directory...');
      await tempDir.delete(recursive: true);
    }
  }
}
