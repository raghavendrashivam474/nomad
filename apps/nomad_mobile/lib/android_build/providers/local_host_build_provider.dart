import 'dart:io';
import '../android_build_service.dart';
import '../build_result.dart';
import 'build_provider.dart';

/// Adapts the mature [AndroidBuildService] to the universal [BuildProvider] interface.
/// Operates on desktop workstations (Windows, macOS, Linux).
class LocalHostBuildProvider implements BuildProvider {
  final AndroidBuildService buildService;

  LocalHostBuildProvider({required this.buildService});

  @override
  Future<BuildCapabilities> getCapabilities() async {
    final isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    return BuildCapabilities(
      providerType: BuildProviderType.hostLocal,
      providerName: 'Workstation Host (${Platform.operatingSystem})',
      isAvailable: isDesktop,
      supportsCompose: true,
      supportsOffline: true,
      supportedJdkVersions: const ['17', '21', '25'],
      unavailableReason: isDesktop
          ? null
          : 'Local host builds require desktop OS (Windows, macOS, or Linux).',
    );
  }

  @override
  Future<BuildResult> build(BuildRequest request) async {
    return buildService.build(request.projectId);
  }

  @override
  void cancel() {
    buildService.cancel();
  }
}
