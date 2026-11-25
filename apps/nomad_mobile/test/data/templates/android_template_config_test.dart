import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_mobile/data/templates/android_template_config.dart';

void main() {
  group('AndroidTemplateConfig (L0-L2 Customization)', () {
    test('generates valid base files with default parameters', () {
      const config = AndroidTemplateConfig();
      final files = config.generateFiles();

      expect(files.containsKey('build.gradle.kts'), isTrue);
      expect(files.containsKey('settings.gradle.kts'), isTrue);
      expect(files.containsKey('app/build.gradle.kts'), isTrue);
      expect(files.containsKey('app/src/main/AndroidManifest.xml'), isTrue);
      expect(files.containsKey('app/src/main/java/com/nomad/lab/MainActivity.kt'), isTrue);

      final mainActivity = files['app/src/main/java/com/nomad/lab/MainActivity.kt']!;
      expect(mainActivity.contains('package com.nomad.lab'), isTrue);
      expect(mainActivity.contains('HelloNomadScreen'), isTrue);
      expect(mainActivity.contains('Counter:'), isTrue);
    });

    test('customizes appName, packageName, greeting, and theme color', () {
      const config = AndroidTemplateConfig(
        appName: 'Cool Nomad App',
        packageName: 'io.nomad.custom',
        greetingText: 'Welcome to Custom World',
        primaryColorHex: '0xFF00AA55',
        includeCounterComponent: false,
      );
      final files = config.generateFiles();

      expect(files.containsKey('app/src/main/java/io/nomad/custom/MainActivity.kt'), isTrue);
      expect(files.containsKey('app/src/main/java/com/nomad/lab/MainActivity.kt'), isFalse);

      final manifest = files['app/src/main/AndroidManifest.xml']!;
      expect(manifest.contains('android:label="Cool Nomad App"'), isTrue);

      final appGradle = files['app/build.gradle.kts']!;
      expect(appGradle.contains('namespace = "io.nomad.custom"'), isTrue);
      expect(appGradle.contains('applicationId = "io.nomad.custom"'), isTrue);

      final mainActivity = files['app/src/main/java/io/nomad/custom/MainActivity.kt']!;
      expect(mainActivity.contains('Welcome to Custom World'), isTrue);
      expect(mainActivity.contains('0xFF00AA55'), isTrue);
      expect(mainActivity.contains('Counter:'), isFalse); // includeCounterComponent was false
    });
  });
}
