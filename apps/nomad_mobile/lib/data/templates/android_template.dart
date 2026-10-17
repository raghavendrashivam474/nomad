/// Minimal Android project template for Nomad Android Lab.
///
/// Contains all text files required for a valid Kotlin + Jetpack Compose
/// application. Binary artifacts (gradle-wrapper.jar) are acquired by the
/// build service during materialization.
///
/// Pinned versions:
///   AGP 8.7.3 | Kotlin 2.0.21 | Compose BOM 2024.12.01
///   compileSdk 35 | minSdk 24 | Gradle 8.11.1
class AndroidTemplate {
  const AndroidTemplate._();

  /// All text files keyed by relative path within the project root.
  static const Map<String, String> files = {
    'build.gradle.kts': _rootBuildGradle,
    'settings.gradle.kts': _settingsGradle,
    'gradle.properties': _gradleProperties,
    'gradle/wrapper/gradle-wrapper.properties': _wrapperProperties,
    'app/build.gradle.kts': _appBuildGradle,
    'app/src/main/AndroidManifest.xml': _manifest,
    'app/src/main/java/com/nomad/lab/MainActivity.kt': _mainActivity,
  };

  // ── Root build script ──────────────────────────────────────

  static const String _rootBuildGradle = '''
plugins {
    id("com.android.application") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "2.0.21" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.0.21" apply false
}
''';

  // ── Settings ───────────────────────────────────────────────

  static const String _settingsGradle = '''
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

  // ── Gradle properties ──────────────────────────────────────

  static const String _gradleProperties = '''
android.useAndroidX=true
kotlin.code.style=official
android.nonTransitiveRClass=true
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
''';

  // ── Wrapper properties ─────────────────────────────────────

  static const String _wrapperProperties = '''
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\\://services.gradle.org/distributions/gradle-8.11.1-bin.zip
networkTimeout=10000
validateDistributionUrl=true
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
''';

  // ── App module build script ────────────────────────────────

  static const String _appBuildGradle = '''
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

  // ── Android manifest ───────────────────────────────────────

  static const String _manifest = '''
<?xml version="1.0" encoding="utf-8"?>
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

  // ── MainActivity (Kotlin + Compose) ────────────────────────

  static const String _mainActivity = '''
package com.nomad.lab

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
            text = "Nomad Android Lab",
            style = MaterialTheme.typography.headlineMedium
        )
    }
}
''';
}
