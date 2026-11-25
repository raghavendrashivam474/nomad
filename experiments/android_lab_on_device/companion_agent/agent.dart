import 'dart:convert';
import 'dart:io';

class CompanionBuildAgent {
  final int port;
  HttpServer? _server;
  final Map<String, Process> _runningBuilds = {};

  CompanionBuildAgent({this.port = 8089});

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    print('[CompanionAgent] Listening on http://127.0.0.1:$port');

    _server!.listen((HttpRequest request) async {
      final path = request.uri.path;
      final method = request.method;

      // Handle CORS for local requests
      request.response.headers.add('Access-Control-Allow-Origin', '*');
      request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
      request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type, X-Nomad-Token');

      if (method == 'OPTIONS') {
        request.response.statusCode = HttpStatus.ok;
        await request.response.close();
        return;
      }

      try {
        if (path == '/api/v1/capabilities' && method == 'GET') {
          final caps = {
            'providerType': 'companion',
            'isAvailable': true,
            'supportsCompose': true,
            'os': Platform.operatingSystem,
            'osVersion': Platform.operatingSystemVersion,
            'jdk': 'OpenJDK 17/21/25',
            'gradle': '8.11.1',
          };
          request.response
            ..headers.contentType = ContentType.json
            ..statusCode = HttpStatus.ok
            ..write(jsonEncode(caps));
          await request.response.close();
          return;
        }

        if (path == '/api/v1/builds' && method == 'POST') {
          final body = await utf8.decodeStream(request);
          final payload = jsonDecode(body) as Map<String, dynamic>;
          final projectId = payload['projectId'] as String? ?? 'unknown';
          final jobId = 'job_${DateTime.now().millisecondsSinceEpoch}';

          final tempDir = await Directory.systemTemp.createTemp('companion_build_');
          final files = (payload['files'] as Map<String, dynamic>?) ?? {};

          for (final entry in files.entries) {
            final fPath = '${tempDir.path}/${entry.key}';
            final f = File(fPath);
            await f.parent.create(recursive: true);
            await f.writeAsString(entry.value.toString());
          }

          // Return Job ID immediately
          request.response
            ..headers.contentType = ContentType.json
            ..statusCode = HttpStatus.accepted
            ..write(jsonEncode({
              'jobId': jobId,
              'status': 'queued',
              'projectId': projectId,
            }));
          await request.response.close();
          return;
        }

        if (path.startsWith('/api/v1/builds/') && path.endsWith('/cancel') && method == 'POST') {
          final parts = path.split('/');
          final jobId = parts[parts.length - 2];
          final proc = _runningBuilds[jobId];
          if (proc != null) {
            proc.kill(ProcessSignal.sigterm);
            _runningBuilds.remove(jobId);
          }
          request.response
            ..statusCode = HttpStatus.ok
            ..write(jsonEncode({'status': 'cancelled'}));
          await request.response.close();
          return;
        }

        request.response
          ..statusCode = HttpStatus.notFound
          ..write(jsonEncode({'error': 'Not found'}));
        await request.response.close();
      } catch (e) {
        request.response
          ..statusCode = HttpStatus.internalServerError
          ..write(jsonEncode({'error': e.toString()}));
        await request.response.close();
      }
    });
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    print('[CompanionAgent] Server stopped.');
  }
}

void main() async {
  final agent = CompanionBuildAgent();
  await agent.start();
  print('Press Ctrl+C to stop or send test requests.');
}
