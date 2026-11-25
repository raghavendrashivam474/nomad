import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_core/nomad_core.dart';
import 'package:nomad_mobile/android_build/artifact_manager.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late ArtifactManager manager;
  const testProjectId = EntityId('test-proj');

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nomad_artifact_test_');
    manager = ArtifactManager(baseDirectory: tempDir, maxRetainedPerProject: 3);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('stores, lists and limits retained APK artifacts', () async {
    final dummyApkDir = await Directory.systemTemp.createTemp('dummy_apk_');
    final dummyApk = File(p.join(dummyApkDir.path, 'app-debug.apk'));
    await dummyApk.writeAsString('FAKE_APK_CONTENT_1234567890');

    for (int i = 1; i <= 5; i++) {
      await Future.delayed(const Duration(milliseconds: 10));
      await manager.storeArtifact(
        projectId: testProjectId,
        sourceApkPath: dummyApk.path,
      );
    }

    final artifacts = await manager.listArtifacts(testProjectId);
    expect(artifacts.length, equals(3));
    expect(File(artifacts.first.filePath).existsSync(), isTrue);
    expect(artifacts.first.formattedSize, contains('KB'));

    final latest = await manager.getLatestArtifact(testProjectId);
    expect(latest, isNotNull);
    expect(latest!.filePath, equals(artifacts.first.filePath));

    await dummyApkDir.delete(recursive: true);
  });
}