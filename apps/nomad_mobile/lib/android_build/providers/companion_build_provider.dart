import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../build_result.dart';
import '../project_materializer.dart';
import 'build_provider.dart';

/// Executes builds by offloading to a Companion Agent (on-device loopback or LAN workstation).
class CompanionBuildProvider implements BuildProvider {
  final Uri endpoint;
  final HttpClient httpClient;
  final ProjectMaterializer? materializer;
  bool _isCancelled = false;

  CompanionBuildProvider({
    Uri? endpoint,
    HttpClient? httpClient,
    this.materializer,
  })  : endpoint = endpoint ?? Uri.parse('http://127.0.0.1:8089'),
        httpClient = httpClient ?? HttpClient();

  @override
  Future<BuildCapabilities> getCapabilities() async {
    try {
      final req = await httpClient.getUrl(endpoint.resolve('/api/v1/capabilities'))
          .timeout(const Duration(seconds: 2));
      final res = await req.close();
      if (res.statusCode == HttpStatus.ok) {
        final body = await utf8.decodeStream(res);
        final json = jsonDecode(body) as Map<String, dynamic>;
        return BuildCapabilities(
          providerType: BuildProviderType.onDeviceCompanion,
          providerName: 'Companion Agent (${json['os'] ?? 'Device'})',
          isAvailable: json['isAvailable'] == true,
          supportsCompose: json['supportsCompose'] == true,
        );
      }
    } catch (_) {
      // Companion not reachable
    }

    return const BuildCapabilities(
      providerType: BuildProviderType.onDeviceCompanion,
      providerName: 'Companion Agent (Disconnected)',
      isAvailable: false,
      unavailableReason: 'Companion build agent is not running on 127.0.0.1:8089.',
    );
  }

  @override
  Future<BuildResult> build(BuildRequest request) async {
    final sw = Stopwatch()..start();
    _isCancelled = false;

    try {
      final req = await httpClient.postUrl(endpoint.resolve('/api/v1/builds'))
          .timeout(const Duration(seconds: 5));
      req.headers.contentType = ContentType.json;

      final payload = jsonEncode({
        'projectId': request.projectId.value,
        'buildType': request.buildType,
      });
      req.write(payload);

      final res = await req.close();
      final body = await utf8.decodeStream(res);
      sw.stop();

      if (res.statusCode == HttpStatus.ok || res.statusCode == HttpStatus.accepted) {
        final json = jsonDecode(body) as Map<String, dynamic>;
        final isSuccess = json['status'] == 'success';
        return BuildResult(
          status: isSuccess ? BuildStatus.success : BuildStatus.failure,
          apkPath: json['apkPath'] as String?,
          log: json['log'] as String? ?? 'Build completed via companion agent.',
          duration: sw.elapsed,
          errorMessage: isSuccess ? null : (json['errorMessage'] as String? ?? 'Companion build failed'),
        );
      } else {
        return BuildResult(
          status: BuildStatus.failure,
          log: body,
          duration: sw.elapsed,
          errorMessage: 'Companion server returned HTTP ${res.statusCode}',
        );
      }
    } catch (e) {
      sw.stop();
      return BuildResult(
        status: _isCancelled ? BuildStatus.cancelled : BuildStatus.failure,
        log: '',
        duration: sw.elapsed,
        errorMessage: 'Companion communication error: $e',
      );
    }
  }

  @override
  void cancel() {
    _isCancelled = true;
    try {
      httpClient.postUrl(endpoint.resolve('/api/v1/builds/current/cancel')).then((req) => req.close());
    } catch (_) {}
  }
}
