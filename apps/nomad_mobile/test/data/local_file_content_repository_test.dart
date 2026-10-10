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

  group('LocalFileContentRepository Binary Safety (MF-3)', () {
    const projectId = EntityId('proj-bin');
    const binaryFileId = EntityId('file-bin-1');

    test('returns empty byte list when reading non-existent file', () async {
      final bytes = await repository.readFileBytes(projectId, binaryFileId);
      expect(bytes, isEmpty);
    });

    test('preserves exact binary bytes including 0x00 and non-UTF8 sequences',
        () async {
      // 1x1 transparent PNG header + raw byte sequence containing invalid UTF8 and null bytes
      final rawBytes = <int>[
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG magic
        0x00, 0x00, 0x00, 0x0D, // IHDR length
        0x49, 0x48, 0x44, 0x52, // IHDR chunk
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1x1
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, // RGBA, CRC
        0xFF, 0xFE, 0xFD, 0xFC, 0xFB, 0x00, 0x00,
        0x01, // arbitrary non-text bytes
      ];

      await repository.writeFileBytes(projectId, binaryFileId, rawBytes);
      final readBytes = await repository.readFileBytes(projectId, binaryFileId);

      expect(readBytes, equals(rawBytes));
    });

    test('updates binary content with new byte payload', () async {
      final initialBytes = <int>[0x00, 0x01, 0x02, 0x03];
      final updatedBytes = <int>[0xFF, 0xFE, 0xFD, 0xFC, 0xFB, 0xFA];

      await repository.writeFileBytes(projectId, binaryFileId, initialBytes);
      expect(await repository.readFileBytes(projectId, binaryFileId),
          equals(initialBytes));

      await repository.writeFileBytes(projectId, binaryFileId, updatedBytes);
      expect(await repository.readFileBytes(projectId, binaryFileId),
          equals(updatedBytes));
    });

    test('handles larger binary payloads safely', () async {
      // 64 KB pattern of non-trivial byte data
      final largeBytes = List<int>.generate(65536, (i) => i % 256);

      await repository.writeFileBytes(projectId, binaryFileId, largeBytes);
      final readBytes = await repository.readFileBytes(projectId, binaryFileId);

      expect(readBytes, equals(largeBytes));
      expect(readBytes.length, equals(65536));
    });

    test('deleting content removes binary file', () async {
      final bytes = <int>[0xCA, 0xFE, 0xBA, 0xBE];
      await repository.writeFileBytes(projectId, binaryFileId, bytes);
      expect(await repository.readFileBytes(projectId, binaryFileId),
          equals(bytes));

      await repository.deleteContent(projectId, binaryFileId);
      expect(await repository.readFileBytes(projectId, binaryFileId), isEmpty);
    });

    test('text written via writeFile is readable via readFileBytes as UTF-8',
        () async {
      const text = 'Hello, Nomad MF-3!';
      const textFileId = EntityId('file-text-1');

      await repository.writeFile(projectId, textFileId, text);
      final bytes = await repository.readFileBytes(projectId, textFileId);

      // Verify that readFileBytes returns exact UTF-8 bytes of the text
      expect(String.fromCharCodes(bytes), equals(text));
    });
  });
}
