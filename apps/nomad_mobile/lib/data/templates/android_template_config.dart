import 'android_template.dart';

/// Versioned configuration for L0–L2 mobile-customizable Android projects.
///
/// Separates WHAT the user customizes from WHERE the project is compiled.
/// Produces standard Kotlin + Jetpack Compose files 100% compatible with
/// both on-device and desktop Gradle toolchains.
class AndroidTemplateConfig {
  final String templateVersion;
  final String appName;
  final String packageName;
  final String greetingText;
  final String primaryColorHex;
  final bool includeCounterComponent;

  const AndroidTemplateConfig({
    this.templateVersion = '1.0.0-AL2',
    this.appName = 'Hello Nomad',
    this.packageName = 'com.nomad.lab',
    this.greetingText = 'Hello Nomad',
    this.primaryColorHex = '0xFF6750A4',
    this.includeCounterComponent = true,
  });

  /// Generates the complete project file map for this configuration.
  Map<String, String> generateFiles() {
    final baseFiles = Map<String, String>.from(AndroidTemplate.files);
    final packagePath = packageName.replaceAll('.', '/');

    // Remove default MainActivity path if package name was customized
    baseFiles.remove('app/src/main/java/com/nomad/lab/MainActivity.kt');

    // Customize settings.gradle.kts
    final safeProjectName = appName.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
    baseFiles['settings.gradle.kts'] = baseFiles['settings.gradle.kts']!
        .replaceAll('NomadAndroidLab', safeProjectName.isEmpty ? 'NomadApp' : safeProjectName);

    // Customize app/build.gradle.kts namespace and applicationId
    baseFiles['app/build.gradle.kts'] = baseFiles['app/build.gradle.kts']!
        .replaceAll('namespace = "com.nomad.lab"', 'namespace = "$packageName"')
        .replaceAll('applicationId = "com.nomad.lab"', 'applicationId = "$packageName"');

    // Customize AndroidManifest.xml label
    baseFiles['app/src/main/AndroidManifest.xml'] = baseFiles['app/src/main/AndroidManifest.xml']!
        .replaceAll('android:label="Nomad Android Lab"', 'android:label="$appName"');

    // Generate customized Kotlin + Jetpack Compose MainActivity.kt (with optional Counter L1/L2)
    baseFiles['app/src/main/java/$packagePath/MainActivity.kt'] = _buildMainActivity();

    return baseFiles;
  }

  String _buildMainActivity() {
    if (!includeCounterComponent) {
      return '''package $packageName

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color

private val CustomColorScheme = lightColorScheme(
    primary = Color($primaryColorHex)
)

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme(colorScheme = CustomColorScheme) {
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
            text = "$greetingText",
            style = MaterialTheme.typography.headlineMedium
        )
    }
}
''';
    }

    return '''package $packageName

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

private val CustomColorScheme = lightColorScheme(
    primary = Color($primaryColorHex)
)

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme(colorScheme = CustomColorScheme) {
                Surface(modifier = Modifier.fillMaxSize()) {
                    HelloNomadScreen()
                }
            }
        }
    }
}

@Composable
fun HelloNomadScreen() {
    var count by remember { mutableIntStateOf(0) }
    Column(
        modifier = Modifier.fillMaxSize().padding(24.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = "$greetingText",
            style = MaterialTheme.typography.headlineMedium
        )
        Spacer(modifier = Modifier.height(16.dp))
        Text(
            text = "Counter: \$count",
            style = MaterialTheme.typography.bodyLarge
        )
        Spacer(modifier = Modifier.height(12.dp))
        Button(onClick = { count++ }) {
            Text("Increment")
        }
    }
}
''';
  }
}
