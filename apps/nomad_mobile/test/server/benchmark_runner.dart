import 'dart:convert';
import 'dart:io';
import 'package:nomad_core/nomad_core.dart';
import 'package:nomad_mobile/server/project_file_resolver.dart';
import 'package:nomad_mobile/server/project_file_server.dart';

class BenchmarkWorkspaceRepo implements WorkspaceRepository {
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

class BenchmarkContentRepo implements FileContentRepository {
  final Map<String, List<int>> _storage = {};
  String _key(EntityId p, EntityId f) => '${p.value}_${f.value}';

  @override
  Future<String> readFile(EntityId projectId, EntityId fileNodeId) async {
    final b = _storage[_key(projectId, fileNodeId)];
    return b != null ? utf8.decode(b) : '';
  }

  @override
  Future<void> writeFile(
          EntityId projectId, EntityId fileNodeId, String content) async =>
      _storage[_key(projectId, fileNodeId)] = utf8.encode(content);

  @override
  Future<List<int>> readFileBytes(
          EntityId projectId, EntityId fileNodeId) async =>
      _storage[_key(projectId, fileNodeId)] ?? <int>[];

  @override
  Future<void> writeFileBytes(
          EntityId projectId, EntityId fileNodeId, List<int> bytes) async =>
      _storage[_key(projectId, fileNodeId)] = List<int>.from(bytes);

  @override
  Future<void> deleteContent(EntityId projectId, EntityId fileNodeId) async {}
  @override
  Future<void> deleteAllContentForProject(EntityId projectId) async {}
}

double median(List<double> values) {
  if (values.isEmpty) return 0;
  final sorted = List<double>.from(values)..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid]
      : (sorted[mid - 1] + sorted[mid]) / 2.0;
}

double p95(List<double> values) {
  if (values.isEmpty) return 0;
  final sorted = List<double>.from(values)..sort();
  final index = (sorted.length * 0.95).ceil() - 1;
  return sorted[index.clamp(0, sorted.length - 1)];
}

void main() async {
  print('================================================================');
  print('       NOMAD MF-4 PERFORMANCE & MEMORY BENCHMARK SUITE          ');
  print('================================================================');
  print('Dart SDK: ${Platform.version}');
  print('OS: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
  print('Host Cores: ${Platform.numberOfProcessors}');
  print('----------------------------------------------------------------\n');

  final ws = BenchmarkWorkspaceRepo();
  final ct = BenchmarkContentRepo();
  final resolver = ProjectFileResolver(
    workspaceRepository: ws,
    contentRepository: ct,
  );
  final server = ProjectFileServer(resolver: resolver, port: 0);
  final client = HttpClient();

  final proj = EntityId('bench_proj');

  // Setup test fixtures
  // 1. Small HTML (~1KB)
  final htmlNode = FileNode(
    id: const EntityId('node_html'),
    projectId: proj,
    name: 'index.html',
    type: FileNodeType.file,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
  ws.nodes.add(htmlNode);
  await ct.writeFile(
      proj, htmlNode.id, '<!DOCTYPE html><html><body><h1>Benchmark</h1></body></html>');

  // 2. CSS (~5KB)
  final cssNode = FileNode(
    id: const EntityId('node_css'),
    projectId: proj,
    name: 'style.css',
    type: FileNodeType.file,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
  ws.nodes.add(cssNode);
  await ct.writeFile(proj, cssNode.id, '/* CSS payload */\n' + 'body { margin: 0; padding: 0; }\n' * 150);

  // 3. JavaScript module (~20KB)
  final jsNode = FileNode(
    id: const EntityId('node_js'),
    projectId: proj,
    name: 'app.js',
    type: FileNodeType.file,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
  ws.nodes.add(jsNode);
  await ct.writeFile(proj, jsNode.id, '// JS bundle\n' + 'export function run() { console.log("bench"); }\n' * 400);

  // 4. Nested resource (assets/icons/logo.svg) (~10KB)
  final dirAssets = FileNode(
    id: const EntityId('dir_assets'),
    projectId: proj,
    name: 'assets',
    type: FileNodeType.folder,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
  final dirIcons = FileNode(
    id: const EntityId('dir_icons'),
    projectId: proj,
    parentId: const EntityId('dir_assets'),
    name: 'icons',
    type: FileNodeType.folder,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
  final svgNode = FileNode(
    id: const EntityId('node_svg'),
    projectId: proj,
    parentId: const EntityId('dir_icons'),
    name: 'logo.svg',
    type: FileNodeType.file,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
  ws.nodes.addAll([dirAssets, dirIcons, svgNode]);
  await ct.writeFile(proj, svgNode.id, '<svg viewBox="0 0 100 100">\n' + '<circle cx="50" cy="50" r="40" />\n' * 200 + '</svg>');

  // 5. Binary PNG (~64KB)
  final pngNode = FileNode(
    id: const EntityId('node_png'),
    projectId: proj,
    name: 'image.png',
    type: FileNodeType.file,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
  ws.nodes.add(pngNode);
  final rawPng = List<int>.generate(64 * 1024, (i) => i % 256);
  await ct.writeFileBytes(proj, pngNode.id, rawPng);

  // 6. Large resource (~500KB bundle + ~2MB image)
  final largeHtmlNode = FileNode(
    id: const EntityId('node_lg_html'),
    projectId: proj,
    name: 'bundle.html',
    type: FileNodeType.file,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
  ws.nodes.add(largeHtmlNode);
  await ct.writeFile(proj, largeHtmlNode.id, '<div>' * 10000 + 'Large Webpack Bundle Simulator' + '</div>' * 10000);

  final largeImgNode = FileNode(
    id: const EntityId('node_lg_img'),
    projectId: proj,
    name: 'large_photo.jpg',
    type: FileNodeType.file,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
  ws.nodes.add(largeImgNode);
  final raw2Mb = List<int>.generate(2 * 1024 * 1024, (i) => (i * 7) % 256);
  await ct.writeFileBytes(proj, largeImgNode.id, raw2Mb);

  await server.start();
  final port = server.boundPort!;
  final baseUrl = 'http://127.0.0.1:$port/bench_proj';

  final initialRss = ProcessInfo.currentRss / (1024 * 1024);
  print('Initial Process RSS Memory: ${initialRss.toStringAsFixed(2)} MB\n');

  // Benchmark helper
  Future<void> runScenario({
    required String name,
    required String path,
    required int iterations,
    int concurrency = 1,
  }) async {
    final latencies = <double>[];
    int successCount = 0;
    int failCount = 0;

    final swTotal = Stopwatch()..start();

    if (concurrency == 1) {
      for (int i = 0; i < iterations; i++) {
        final swReq = Stopwatch()..start();
        try {
          final req = await client.getUrl(Uri.parse('$baseUrl/$path'));
          final res = await req.close();
          final bytes = await res.fold<List<int>>([], (p, e) => p..addAll(e));
          swReq.stop();
          if (res.statusCode == 200 && bytes.isNotEmpty) {
            successCount++;
            latencies.add(swReq.elapsedMicroseconds / 1000.0);
          } else {
            failCount++;
          }
        } catch (_) {
          failCount++;
        }
      }
    } else {
      final batches = (iterations / concurrency).ceil();
      for (int b = 0; b < batches; b++) {
        final futures = List.generate(concurrency, (c) async {
          final swReq = Stopwatch()..start();
          try {
            final req = await client.getUrl(Uri.parse('$baseUrl/$path'));
            final res = await req.close();
            final bytes = await res.fold<List<int>>([], (p, e) => p..addAll(e));
            swReq.stop();
            if (res.statusCode == 200 && bytes.isNotEmpty) {
              return swReq.elapsedMicroseconds / 1000.0;
            }
            return -1.0;
          } catch (_) {
            return -1.0;
          }
        });

        final results = await Future.wait(futures);
        for (final r in results) {
          if (r >= 0) {
            successCount++;
            latencies.add(r);
          } else {
            failCount++;
          }
        }
      }
    }

    swTotal.stop();
    final totalMs = swTotal.elapsedMilliseconds;
    final rps = (successCount / (totalMs / 1000.0)).toStringAsFixed(1);
    final med = median(latencies).toStringAsFixed(3);
    final p95Val = p95(latencies).toStringAsFixed(3);

    print('[$name]');
    print('  Iterations: $iterations | Concurrency: $concurrency');
    print('  Success: $successCount | Failed: $failCount');
    print('  Total Time: ${totalMs}ms | Throughput: $rps req/sec');
    print('  Latency: Median = ${med}ms | P95 = ${p95Val}ms\n');
  }

  // --- Workloads ---
  await runScenario(name: '1. Small HTML (~1KB)', path: 'index.html', iterations: 200);
  await runScenario(name: '2. CSS Stylesheet (~5KB)', path: 'style.css', iterations: 200);
  await runScenario(name: '3. JavaScript Bundle (~20KB)', path: 'app.js', iterations: 200);
  await runScenario(name: '4. Nested SVG Resource (~10KB)', path: 'assets/icons/logo.svg', iterations: 200);
  await runScenario(name: '5. Binary PNG Asset (~64KB)', path: 'image.png', iterations: 200);

  // Concurrency workloads
  await runScenario(name: '6a. Concurrent CSS (C=5)', path: 'style.css', iterations: 200, concurrency: 5);
  await runScenario(name: '6b. Concurrent JS (C=10)', path: 'app.js', iterations: 200, concurrency: 10);
  await runScenario(name: '6c. Concurrent Binary (C=10)', path: 'image.png', iterations: 200, concurrency: 10);

  // Large file workloads
  await runScenario(name: '7a. Large HTML Bundle (~500KB)', path: 'bundle.html', iterations: 50);
  await runScenario(name: '7b. Large Image Asset (~2MB)', path: 'large_photo.jpg', iterations: 50);

  final midRss = ProcessInfo.currentRss / (1024 * 1024);
  print('Process RSS Memory after request workloads: ${midRss.toStringAsFixed(2)} MB (Delta: +${(midRss - initialRss).toStringAsFixed(2)} MB)\n');

  // Lifecycle stress benchmark
  print('[8. Lifecycle Stress: 50 Repeated Start/Stop Cycles]');
  final swLife = Stopwatch()..start();
  for (int i = 0; i < 50; i++) {
    await server.stop();
    await server.start();
  }
  swLife.stop();
  print('  Completed 50 start/stop cycles in ${swLife.elapsedMilliseconds}ms (${(swLife.elapsedMilliseconds / 50).toStringAsFixed(2)}ms / cycle)\n');

  final finalRss = ProcessInfo.currentRss / (1024 * 1024);
  print('Final Process RSS Memory: ${finalRss.toStringAsFixed(2)} MB (Total Delta: +${(finalRss - initialRss).toStringAsFixed(2)} MB)');
  print('================================================================');

  await server.stop();
  client.close(force: true);
}
