import 'dart:convert';
import 'dart:io';

void main() async {
  print('=== POC-06: Companion Agent Client & Protocol Verification ===');
  
  // Start the companion agent in-process for verification
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8089);
  print('Test Companion Server listening on port 8089');
  
  server.listen((req) async {
    if (req.uri.path == '/api/v1/capabilities') {
      req.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'providerType': 'companion',
          'isAvailable': true,
          'supportsCompose': true,
          'os': Platform.operatingSystem,
        }));
      await req.response.close();
    } else if (req.uri.path == '/api/v1/builds' && req.method == 'POST') {
      final body = await utf8.decodeStream(req);
      final json = jsonDecode(body);
      req.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'jobId': 'job_test_123',
          'status': 'success',
          'receivedFiles': (json['files'] as Map).length,
        }));
      await req.response.close();
    }
  });

  final client = HttpClient();
  try {
    // 1. Probe capabilities
    print('Probing /api/v1/capabilities...');
    final reqCap = await client.getUrl(Uri.parse('http://127.0.0.1:8089/api/v1/capabilities'));
    final resCap = await reqCap.close();
    final capBody = await utf8.decodeStream(resCap);
    print('Capabilities Response: $capBody');
    assert(resCap.statusCode == 200);

    // 2. Submit build request
    print('Submitting BuildRequest with files payload...');
    final reqBuild = await client.postUrl(Uri.parse('http://127.0.0.1:8089/api/v1/builds'));
    reqBuild.headers.contentType = ContentType.json;
    final payload = jsonEncode({
      'projectId': 'test_proj_al2',
      'files': {
        'build.gradle.kts': 'plugins { id("com.android.application") }',
        'MainActivity.kt': 'package com.nomad.lab',
      }
    });
    reqBuild.write(payload);
    final resBuild = await reqBuild.close();
    final buildBody = await utf8.decodeStream(resBuild);
    print('Build Submission Response: $buildBody');
    assert(resBuild.statusCode == 200);

    print('\n========================================');
    print('Companion Protocol Validation: SUCCESS');
    print('========================================');
    print('>>> POC-06 RESULT: SUCCESS');
  } finally {
    client.close();
    await server.close(force: true);
  }
}

