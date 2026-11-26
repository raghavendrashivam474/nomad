import 'dart:async';
import 'dart:io';
import 'package:nomad_core/nomad_core.dart';
import '../build_result.dart';
import 'build_provider.dart';

/// Fallback provider invoked when no registered provider is currently available.
class UnavailableFallbackProvider implements BuildProvider {
  final List<BuildCapabilities> probedCapabilities;

  const UnavailableFallbackProvider({required this.probedCapabilities});

  @override
  Future<BuildCapabilities> getCapabilities() async {
    return const BuildCapabilities(
      providerType: BuildProviderType.onDeviceCompanion,
      providerName: 'No Available Provider',
      isAvailable: false,
      unavailableReason: 'No registered build provider is currently available.',
    );
  }

  @override
  Future<BuildResult> build(BuildRequest request) async {
    final isMobile = Platform.isAndroid || Platform.isIOS;
    final msg = isMobile
        ? 'No on-device build provider available.\n\n'
          'The Nomad Companion Daemon was not detected on 127.0.0.1:8089.\n'
          'To build APKs directly on your phone:\n'
          '  1. Open Termux on this device\n'
          '  2. Start the daemon: dart run experiments/android_lab_on_device/companion_agent/agent.dart\n'
          '  3. Return to Nomad and press Build again.'
        : 'No build provider available on this host. Ensure JDK 17/21 and Android SDK are configured.';

    return BuildResult(
      status: BuildStatus.failure,
      log: msg,
      duration: Duration.zero,
      errorMessage: isMobile
          ? 'On-device companion agent required: Start the Termux daemon on 127.0.0.1:8089 to build on phone.'
          : 'Workstation build host required: Configure JDK and Android SDK or start the companion agent.',
    );
  }

  @override
  void cancel() {}
}

/// Coordinates multiple [BuildProvider] backends and automatically selects
/// the best available provider based on runtime capabilities.
class BuildOrchestrator implements BuildProvider {
  final List<BuildProvider> providers;
  BuildProvider? _activeProvider;
  bool _isCancelled = false;

  BuildOrchestrator({required this.providers}) {
    if (providers.isEmpty) {
      throw ArgumentError('BuildOrchestrator requires at least one BuildProvider.');
    }
  }

  /// Probes all registered providers in priority order and returns the first available one.
  Future<BuildProvider> selectOptimalProvider() async {
    final probed = <BuildCapabilities>[];
    for (final provider in providers) {
      try {
        final caps = await provider.getCapabilities().timeout(const Duration(seconds: 3));
        probed.add(caps);
        if (caps.isAvailable) {
          return provider;
        }
      } catch (e) {
        probed.add(BuildCapabilities(
          providerType: BuildProviderType.onDeviceCompanion,
          providerName: 'Provider Probe Error',
          isAvailable: false,
          unavailableReason: 'Capability check timed out or failed: $e',
        ));
      }
    }
    return UnavailableFallbackProvider(probedCapabilities: probed);
  }

  @override
  Future<BuildCapabilities> getCapabilities() async {
    final selected = await selectOptimalProvider();
    return selected.getCapabilities();
  }

  @override
  Future<BuildResult> build(BuildRequest request) async {
    _isCancelled = false;
    final provider = await selectOptimalProvider();
    _activeProvider = provider;

    if (_isCancelled) {
      provider.cancel();
      return const BuildResult(
        status: BuildStatus.cancelled,
        log: '',
        duration: Duration.zero,
        errorMessage: 'Build cancelled by user before execution',
      );
    }

    try {
      return await provider.build(request);
    } finally {
      _activeProvider = null;
    }
  }

  /// Helper method matching AndroidBuildService signature for seamless integration.
  Future<BuildResult> buildProject(EntityId projectId) {
    return build(BuildRequest(projectId: projectId));
  }

  @override
  void cancel() {
    _isCancelled = true;
    _activeProvider?.cancel();
  }
}
