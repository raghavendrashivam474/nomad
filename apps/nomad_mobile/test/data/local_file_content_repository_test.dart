import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_core/nomad_core.dart';
import 'package:nomad_mobile/data/repositories/local_file_content_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late LocalFileContentRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nomad_test_files_');
    repository = LocalFileContentRepository(
      baseDirProvider: () async => tempDir,
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('LocalFileContentRepository CRUD & Isolation', () {
    const projectIdA = EntityId('project-a');
    const projectIdB = EntityId('project-b');
    const fileId1 = EntityId('file-1');

    test('returns empty string when reading non-existent file', () async {
      final content = await repository.readFile(projectIdA, fileId1);
      expect(content, equals(''));
    });

    test('can write, read, and update file content', () async {
      const initialCode = '<html>\n  <body>Hello Nomad</body>\n</html>';
      const updatedCode = '<html>\n  <body>Hello Nomad V0.0!</body>\n</html>';

      // Write
      await repository.writeFile(projectIdA, fileId1, initialCode);
      var content = await repository.readFile(projectIdA, fileId1);
      expect(content, equals(initialCode));

      // Update
      await repository.writeFile(projectIdA, fileId1, updatedCode);
      content = await repository.readFile(projectIdA, fileId1);
      expect(content, equals(updatedCode));
    });

    test('can delete a specific file content', () async {
      await repository.writeFile(projectIdA, fileId1, 'console.log("hi");');
      expect(await repository.readFile(projectIdA, fileId1),
          equals('console.log("hi");'));

      await repository.deleteContent(projectIdA, fileId1);
      expect(await repository.readFile(projectIdA, fileId1), equals(''));
    });

    test('enforces strict project isolation for file contents', () async {
      await repository.writeFile(projectIdA, fileId1, 'content for project A');
      await repository.writeFile(projectIdB, fileId1, 'content for project B');

      // Verify separate contents even with identical file IDs across different projects
      expect(await repository.readFile(projectIdA, fileId1),
          equals('content for project A'));
      expect(await repository.readFile(projectIdB, fileId1),
          equals('content for project B'));

      // Delete all content for project A
      await repository.deleteAllContentForProject(projectIdA);

      // Project A content is gone, Project B content remains
      expect(await repository.readFile(projectIdA, fileId1), equals(''));
      expect(await repository.readFile(projectIdB, fileId1),
          equals('content for project B'));
    });
  });
}
