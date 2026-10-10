import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_core/nomad_core.dart';
import 'package:nomad_mobile/server/project_file_resolver.dart';
import 'package:nomad_mobile/server/project_file_server.dart';

class InMemoryWorkspaceRepository implements WorkspaceRepository {
  final List<FileNode> nodes = [];

  @override
  Future<List<FileNode>> getNodesForProject(EntityId projectId) async {
    return nodes.where((n) => n.projectId == projectId).toList();
  }

  @override
  Future<FileNode?> getNodeById(EntityId id) async =>
      throw UnimplementedError();
  @override
  Future<void> createNode(FileNode node) async => throw UnimplementedError();
  @override
  Future<void> renameNode(EntityId id, String newName) async =>
      throw UnimplementedError();
  @override
  Future<void> deleteNode(EntityId id) async => throw UnimplementedError();
  @override
  Future<void> deleteAllNodesForProject(EntityId projectId) async =>
      throw UnimplementedError();
}

class InMemoryFileContentRepository implements FileContentRepository {
  final Map<String, String> contents = {};

  String _key(EntityId projectId, EntityId fileNodeId) =>
      '${projectId.value}_${fileNodeId.value}';

  @override
  Future<String> readFile(EntityId projectId, EntityId fileNodeId) async {
    return contents[_key(projectId, fileNodeId)] ?? '';
  }

  @override
  Future<void> writeFile(
      EntityId projectId, EntityId fileNodeId, String content) async {
    contents[_key(projectId, fileNodeId)] = content;
  }

  @override
  Future<void> deleteContent(EntityId projectId, EntityId fileNodeId) async =>
      throw UnimplementedError();
  @override
  Future<void> deleteAllContentForProject(EntityId projectId) async =>
      throw UnimplementedError();
}

void main() {
  late InMemoryWorkspaceRepository workspaceRepo;
  late InMemoryFileContentRepository contentRepo;
  late ProjectFileResolver resolver;
  late ProjectFileServer server;
  late HttpClient httpClient;

  const project1 = EntityId('p1');
  const project2 = EntityId('p2');

  // Use dynamic/test-friendly port (0 assigns an ephemeral free port)
  setUp(() {
    workspaceRepo = InMemoryWorkspaceRepository();
    contentRepo = InMemoryFileContentRepository();
    resolver = ProjectFileResolver(
      workspaceRepository: workspaceRepo,
      contentRepository: contentRepo,
    );
    server = ProjectFileServer(resolver: resolver, port: 0);
    httpClient = HttpClient();
  });

  tearDown(() async {
    httpClient.close(force: true);
    if (server.isRunning) {
      await server.stop(force: true);
    }
  });

  FileNode addNode({
    required String id,
    required EntityId projectId,
    String? parentId,
    required String name,
    required FileNodeType type,
  }) {
    final node = FileNode(
      id: EntityId(id),
      projectId: projectId,
      parentId: parentId != null ? EntityId(parentId) : null,
      name: name,
      type: type,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    workspaceRepo.nodes.add(node);
    return node;
  }

  group('ProjectFileServer Lifecycle Tests', () {
    test('starts and binds successfully to loopback, stops cleanly', () async {
      expect(server.isRunning, isFalse);
      await server.start();
      expect(server.isRunning, isTrue);
      expect(server.boundPort, isNotNull);
      expect(server.boundPort, isPositive);

      await server.stop();
      expect(server.isRunning, isFalse);
      expect(server.boundPort, isNull);
    });

    test('restarting works properly', () async {
      await server.start();
      await server.stop();

      await server.start();
      expect(server.isRunning, isTrue);
      await server.stop();
    });

    test('reports startup failure explicitly when binding to invalid port',
        () async {
      final invalidServer = ProjectFileServer(resolver: resolver, port: 99999);
      expect(invalidServer.start(),
          throwsA(anyOf(isA<SocketException>(), isA<ArgumentError>())));
    });
  });

  group('ProjectFileServer HTTP Serving Tests', () {
    test('serves root HTML file with correct Content-Type header and body',
        () async {
      final node = addNode(
          id: 'html-node',
          projectId: project1,
          name: 'index.html',
          type: FileNodeType.file);
      await contentRepo.writeFile(
          project1, node.id, '<!DOCTYPE html><html><body>Nomad</body></html>');

      await server.start();
      final req = await httpClient.getUrl(
          Uri.parse('http://127.0.0.1:${server.boundPort}/p1/index.html'));
      final res = await req.close();

      expect(res.statusCode, equals(HttpStatus.ok));
      expect(res.headers.value(HttpHeaders.contentTypeHeader),
          equals('text/html; charset=utf-8'));
      final body = await utf8.decoder.bind(res).join();
      expect(body, equals('<!DOCTYPE html><html><body>Nomad</body></html>'));
    });

    test('serves nested CSS file with correct Content-Type header', () async {
      final cssDir = addNode(
          id: 'dir-css',
          projectId: project1,
          name: 'css',
          type: FileNodeType.folder);
      final cssNode = addNode(
          id: 'css-node',
          projectId: project1,
          parentId: cssDir.id.value,
          name: 'style.css',
          type: FileNodeType.file);
      await contentRepo.writeFile(
          project1, cssNode.id, 'h1 { font-size: 24px; }');

      await server.start();
      final req = await httpClient.getUrl(
          Uri.parse('http://127.0.0.1:${server.boundPort}/p1/css/style.css'));
      final res = await req.close();

      expect(res.statusCode, equals(HttpStatus.ok));
      expect(res.headers.value(HttpHeaders.contentTypeHeader),
          equals('text/css; charset=utf-8'));
      final body = await utf8.decoder.bind(res).join();
      expect(body, equals('h1 { font-size: 24px; }'));
    });

    test(
        'serves JS file with application/javascript Content-Type for ES module loading',
        () async {
      final jsNode = addNode(
          id: 'js-node',
          projectId: project1,
          name: 'main.js',
          type: FileNodeType.file);
      await contentRepo.writeFile(
          project1, jsNode.id, 'export const version = "1.0";');

      await server.start();
      final req = await httpClient
          .getUrl(Uri.parse('http://127.0.0.1:${server.boundPort}/p1/main.js'));
      final res = await req.close();

      expect(res.statusCode, equals(HttpStatus.ok));
      expect(res.headers.value(HttpHeaders.contentTypeHeader),
          equals('application/javascript; charset=utf-8'));
      final body = await utf8.decoder.bind(res).join();
      expect(body, equals('export const version = "1.0";'));
    });

    test('returns 404 for missing resources', () async {
      await server.start();
      final req = await httpClient.getUrl(
          Uri.parse('http://127.0.0.1:${server.boundPort}/p1/missing.js'));
      final res = await req.close();

      expect(res.statusCode, equals(HttpStatus.notFound));
    });

    test('returns 403 Forbidden for path traversal attempts', () async {
      await server.start();
      final req = await httpClient.getUrl(
          Uri.parse('http://127.0.0.1:${server.boundPort}/p1/../secret.txt'));
      final res = await req.close();

      expect(
          res.statusCode, isIn([HttpStatus.forbidden, HttpStatus.badRequest]));
    });

    test(
        'returns 400 Bad Request for requests without project ID or resource path',
        () async {
      await server.start();

      final req1 = await httpClient
          .getUrl(Uri.parse('http://127.0.0.1:${server.boundPort}/'));
      final res1 = await req1.close();
      expect(res1.statusCode, equals(HttpStatus.badRequest));

      final req2 = await httpClient
          .getUrl(Uri.parse('http://127.0.0.1:${server.boundPort}/p1'));
      final res2 = await req2.close();
      expect(res2.statusCode, equals(HttpStatus.badRequest));
    });

    test('enforces strict project boundary isolation across requests',
        () async {
      final nodeP1 = addNode(
          id: 'node-1',
          projectId: project1,
          name: 'app.js',
          type: FileNodeType.file);
      final nodeP2 = addNode(
          id: 'node-2',
          projectId: project2,
          name: 'app.js',
          type: FileNodeType.file);

      await contentRepo.writeFile(project1, nodeP1.id, 'console.log("P1");');
      await contentRepo.writeFile(project2, nodeP2.id, 'console.log("P2");');

      await server.start();

      final req1 = await httpClient
          .getUrl(Uri.parse('http://127.0.0.1:${server.boundPort}/p1/app.js'));
      final res1 = await req1.close();
      final body1 = await utf8.decoder.bind(res1).join();
      expect(body1, equals('console.log("P1");'));

      final req2 = await httpClient
          .getUrl(Uri.parse('http://127.0.0.1:${server.boundPort}/p2/app.js'));
      final res2 = await req2.close();
      final body2 = await utf8.decoder.bind(res2).join();
      expect(body2, equals('console.log("P2");'));
    });

    test('handles concurrent requests cleanly', () async {
      for (int i = 0; i < 5; i++) {
        final node = addNode(
            id: 'file-$i',
            projectId: project1,
            name: 'file$i.txt',
            type: FileNodeType.file);
        await contentRepo.writeFile(project1, node.id, 'Content $i');
      }

      await server.start();

      final futures = List.generate(5, (i) async {
        final req = await httpClient.getUrl(
            Uri.parse('http://127.0.0.1:${server.boundPort}/p1/file$i.txt'));
        final res = await req.close();
        final body = await utf8.decoder.bind(res).join();
        return body;
      });

      final results = await Future.wait(futures);
      for (int i = 0; i < 5; i++) {
        expect(results[i], equals('Content $i'));
      }
    });
  });
}
