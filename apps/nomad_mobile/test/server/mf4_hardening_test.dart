import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_core/nomad_core.dart';
import 'package:nomad_mobile/server/project_file_resolver.dart';
import 'package:nomad_mobile/server/project_file_server.dart';

class _InMemWorkspace implements WorkspaceRepository {
  @override
  Future<void> moveNode(EntityId id, EntityId? newParentId) async {}
  final List<FileNode> nodes = [];
  @override
  Future<List<FileNode>> getNodesForProject(EntityId projectId) async =>
      nodes.where((n) => n.projectId == projectId).toList();
  @override
  Future<FileNode?> getNodeById(EntityId id) async => null;
  @override
  Future<void> createNode(FileNode node) async {}
  @override
  Future<void> renameNode(EntityId id, String newName) async {}
  @override
  Future<void> deleteNode(EntityId id) async {}
  @override
  Future<void> deleteAllNodesForProject(EntityId projectId) async {}
}

class _InMemContent implements FileContentRepository {
  final Map<String, List<int>> _store = {};
  String _k(EntityId p, EntityId f) => '${p.value}_${f.value}';

  @override
  Future<String> readFile(EntityId projectId, EntityId fileNodeId) async {
    final b = _store[_k(projectId, fileNodeId)];
    return b != null ? utf8.decode(b) : '';
  }

  @override
  Future<void> writeFile(
          EntityId projectId, EntityId fileNodeId, String content) async =>
      _store[_k(projectId, fileNodeId)] = utf8.encode(content);

  @override
  Future<List<int>> readFileBytes(
          EntityId projectId, EntityId fileNodeId) async =>
      _store[_k(projectId, fileNodeId)] ?? <int>[];

  @override
  Future<void> writeFileBytes(
          EntityId projectId, EntityId fileNodeId, List<int> bytes) async =>
      _store[_k(projectId, fileNodeId)] = List<int>.from(bytes);

  @override
  Future<void> deleteContent(EntityId projectId, EntityId fileNodeId) async {}
  @override
  Future<void> deleteAllContentForProject(EntityId projectId) async {}
}

void main() {
  late _InMemWorkspace wsRepo;
  late _InMemContent ctRepo;
  late ProjectFileResolver resolver;
  late HttpClient httpClient;
  const proj = EntityId('p1');

  setUp(() {
    wsRepo = _InMemWorkspace();
    ctRepo = _InMemContent();
    resolver = ProjectFileResolver(
        workspaceRepository: wsRepo, contentRepository: ctRepo);
    httpClient = HttpClient();
  });

  tearDown(() async {
    httpClient.close(force: true);
  });

  group('MF-4: Bind-failure hardening', () {
    test('occupied port throws SocketException and leaves server not running',
        () async {
      final blocker =
          await HttpServer.bind(InternetAddress.loopbackIPv4, 0, shared: false);
      final occupiedPort = blocker.port;

      final server = ProjectFileServer(resolver: resolver, port: occupiedPort);

      expect(server.isRunning, isFalse);

      await expectLater(
        server.start(),
        throwsA(isA<SocketException>()),
      );

      expect(server.isRunning, isFalse,
          reason:
              'Server must not report isRunning after a failed bind attempt');

      await blocker.close(force: true);
    });

    test('recovery after occupied port becomes available', () async {
      final blocker =
          await HttpServer.bind(InternetAddress.loopbackIPv4, 0, shared: false);
      final port = blocker.port;

      final server = ProjectFileServer(resolver: resolver, port: port);

      // First attempt fails
      try {
        await server.start();
      } on SocketException {
        // expected
      }
      expect(server.isRunning, isFalse);

      // Release the port
      await blocker.close(force: true);
      // Allow OS to release socket
      await Future.delayed(const Duration(milliseconds: 50));

      // Second attempt succeeds
      await server.start();
      expect(server.isRunning, isTrue);
      expect(server.boundPort, equals(port));

      await server.stop();
    });
  });

  group('MF-4: Lifecycle stress', () {
    test('repeated start/stop cycles maintain consistent state', () async {
      final server = ProjectFileServer(resolver: resolver, port: 0);

      for (int i = 0; i < 5; i++) {
        expect(server.isRunning, isFalse,
            reason: 'Cycle $i: should be stopped before start');
        await server.start();
        expect(server.isRunning, isTrue,
            reason: 'Cycle $i: should be running after start');
        expect(server.boundPort, isPositive,
            reason: 'Cycle $i: should have a valid port');
        await server.stop();
        expect(server.isRunning, isFalse,
            reason: 'Cycle $i: should be stopped after stop');
        expect(server.boundPort, isNull,
            reason: 'Cycle $i: port should be null after stop');
      }
    });

    test('stop on already-stopped server is safe (idempotent)', () async {
      final server = ProjectFileServer(resolver: resolver, port: 0);
      expect(server.isRunning, isFalse);

      await server.stop();
      expect(server.isRunning, isFalse);

      await server.start();
      await server.stop();
      await server.stop();
      expect(server.isRunning, isFalse);
    });

    test('shutdown during active requests completes cleanly', () async {
      final server = ProjectFileServer(resolver: resolver, port: 0);

      final node = FileNode(
        id: const EntityId('f1'),
        projectId: proj,
        name: 'data.txt',
        type: FileNodeType.file,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      wsRepo.nodes.add(node);
      await ctRepo.writeFile(proj, node.id, 'Hello');

      await server.start();
      final port = server.boundPort!;

      final futures = List.generate(3, (i) async {
        try {
          final req = await httpClient
              .getUrl(Uri.parse('http://127.0.0.1:$port/p1/data.txt'));
          final res = await req.close();
          await res.drain();
          return res.statusCode;
        } catch (_) {
          return -1;
        }
      });

      await server.stop(force: true);

      final results =
          await Future.wait(futures).timeout(const Duration(seconds: 5));

      expect(server.isRunning, isFalse);
      for (final r in results) {
        expect(r == 200 || r == -1, isTrue);
      }
    });
  });

  group('MF-4: Concurrent request integrity', () {
    test('concurrent binary and text requests do not corrupt responses',
        () async {
      final server = ProjectFileServer(resolver: resolver, port: 0);

      final textNode = FileNode(
        id: const EntityId('txt1'),
        projectId: proj,
        name: 'readme.txt',
        type: FileNodeType.file,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      wsRepo.nodes.add(textNode);
      await ctRepo.writeFile(proj, textNode.id, 'TEXT_CONTENT');

      final binNode = FileNode(
        id: const EntityId('bin1'),
        projectId: proj,
        name: 'image.png',
        type: FileNodeType.file,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      wsRepo.nodes.add(binNode);
      final pngBytes = <int>[0x89, 0x50, 0x4E, 0x47, 0xFF, 0x00, 0xAA, 0xBB];
      await ctRepo.writeFileBytes(proj, binNode.id, pngBytes);

      await server.start();
      final port = server.boundPort!;

      final futures = <Future<Map<String, dynamic>>>[];
      for (int i = 0; i < 10; i++) {
        final isText = i.isEven;
        futures.add(() async {
          final path = isText ? 'readme.txt' : 'image.png';
          final req = await httpClient
              .getUrl(Uri.parse('http://127.0.0.1:$port/p1/$path'));
          final res = await req.close();
          final bytes = <int>[];
          await for (final chunk in res) {
            bytes.addAll(chunk);
          }
          return {
            'type': isText ? 'text' : 'binary',
            'status': res.statusCode,
            'bytes': bytes,
          };
        }());
      }

      final results = await Future.wait(futures);

      for (final r in results) {
        expect(r['status'], equals(200));
        if (r['type'] == 'text') {
          expect(utf8.decode(r['bytes'] as List<int>), equals('TEXT_CONTENT'));
        } else {
          expect(r['bytes'], equals(pngBytes));
        }
      }

      await server.stop();
    });
  });

  group('MF-4: Content-Length header verification', () {
    test('GET request includes exact Content-Length matching payload bytes',
        () async {
      final server = ProjectFileServer(resolver: resolver, port: 0);

      final node = FileNode(
        id: const EntityId('f-len'),
        projectId: proj,
        name: 'sample.html',
        type: FileNodeType.file,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      wsRepo.nodes.add(node);
      const content = '<p>Content-Length Test Payload</p>';
      final expectedLength = utf8.encode(content).length;
      await ctRepo.writeFile(proj, node.id, content);

      await server.start();
      final port = server.boundPort!;

      final req = await httpClient
          .getUrl(Uri.parse('http://127.0.0.1:$port/p1/sample.html'));
      final res = await req.close();

      expect(res.statusCode, equals(HttpStatus.ok));
      expect(res.contentLength, equals(expectedLength));

      final body = await utf8.decoder.bind(res).join();
      expect(body, equals(content));

      await server.stop();
    });

    test('HEAD request includes exact Content-Length without sending body',
        () async {
      final server = ProjectFileServer(resolver: resolver, port: 0);

      final node = FileNode(
        id: const EntityId('f-head-len'),
        projectId: proj,
        name: 'data.bin',
        type: FileNodeType.file,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      wsRepo.nodes.add(node);
      final rawBytes = <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
      await ctRepo.writeFileBytes(proj, node.id, rawBytes);

      await server.start();
      final port = server.boundPort!;

      final req = await httpClient
          .headUrl(Uri.parse('http://127.0.0.1:$port/p1/data.bin'));
      final res = await req.close();

      expect(res.statusCode, equals(HttpStatus.ok));
      expect(res.contentLength, equals(10));

      final receivedBytes = <int>[];
      await for (final chunk in res) {
        receivedBytes.addAll(chunk);
      }
      expect(receivedBytes, isEmpty);

      await server.stop();
    });
  });
}
