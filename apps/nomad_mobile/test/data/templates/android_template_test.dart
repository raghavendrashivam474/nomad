import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_mobile/data/templates/android_template.dart';

void main() {
  group('AndroidTemplate', () {
    test('contains all required project files', () {
      final files = AndroidTemplate.files;

      expect(files.containsKey('build.gradle.kts'), isTrue);
      expect(files.containsKey('settings.gradle.kts'), isTrue);
      expect(files.containsKey('gradle.properties'), isTrue);
      expect(
        files.containsKey('gradle/wrapper/gradle-wrapper.properties'),
        isTrue,
      );
      expect(files.containsKey('app/build.gradle.kts'), isTrue);
      expect(
        files.containsKey('app/src/main/AndroidManifest.xml'),
        isTrue,
      );
      expect(
        files.containsKey(
            'app/src/main/java/com/nomad/lab/MainActivity.kt'),
        isTrue,
      );
    });

    test('no file has empty content', () {
      for (final entry in AndroidTemplate.files.entries) {
        expect(
          entry.value.trim().isNotEmpty,
          isTrue,
          reason: '${entry.key} has empty content',
        );
      }
    });

    test('root build script pins AGP and Kotlin versions', () {
      final root = AndroidTemplate.files['build.gradle.kts']!;
      expect(root, contains('8.7.3'));
      expect(root, contains('2.0.21'));
    });

    test('app build script targets compileSdk 35', () {
      final app = AndroidTemplate.files['app/build.gradle.kts']!;
      expect(app, contains('compileSdk = 35'));
      expect(app, contains('minSdk = 24'));
    });

    test('manifest declares MainActivity with launcher intent', () {
      final manifest =
          AndroidTemplate.files['app/src/main/AndroidManifest.xml']!;
      expect(manifest, contains('.MainActivity'));
      expect(manifest, contains('android.intent.action.MAIN'));
      expect(manifest, contains('android.intent.category.LAUNCHER'));
    });

    test('MainActivity contains Nomad Android Lab label', () {
      final main = AndroidTemplate
          .files['app/src/main/java/com/nomad/lab/MainActivity.kt']!;
      expect(main, contains('Nomad Android Lab'));
      expect(main, contains('@Composable'));
    });

    test('wrapper properties pin Gradle 8.11.1', () {
      final wrapper =
          AndroidTemplate.files['gradle/wrapper/gradle-wrapper.properties']!;
      expect(wrapper, contains('gradle-8.11.1'));
    });

    test('file count is exactly 7', () {
      expect(AndroidTemplate.files.length, equals(7));
    });
  });
}
