import 'package:nomad_core/nomad_core.dart';
import '../build_result.dart';
import 'build_provider.dart';

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
    for (final provider in providers) {
      final caps = await provider.getCapabilities();
      if (caps.isAvailable) {
        return provider;
      }
    }
    return providers.first;
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
