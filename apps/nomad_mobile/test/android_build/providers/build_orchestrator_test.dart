import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_core/nomad_core.dart';
import 'package:nomad_mobile/android_build/build_result.dart';
import 'package:nomad_mobile/android_build/providers/build_provider.dart';
import 'package:nomad_mobile/android_build/providers/build_orchestrator.dart';

class FakeBuildProvider implements BuildProvider {
  final BuildCapabilities capabilities;
  final BuildResult buildResult;
  bool wasCalled = false;
  bool wasCancelled = false;
  Duration delay;

  FakeBuildProvider({
    required this.capabilities,
    required this.buildResult,
    this.delay = Duration.zero,
  });

  @override
  Future<BuildCapabilities> getCapabilities() async => capabilities;

  @override
  Future<BuildResult> build(BuildRequest request) async {
    wasCalled = true;
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }
    return buildResult;
  }

  @override
  void cancel() {
    wasCancelled = true;
  }
}

void main() {
  group('BuildProvider Contracts & Orchestrator', () {
    test('BuildRequest retains configuration', () {
      const req = BuildRequest(
        projectId: EntityId('p1'),
        buildType: 'release',
        timeout: Duration(minutes: 2),
      );
      expect(req.projectId.value, 'p1');
      expect(req.buildType, 'release');
      expect(req.timeout.inMinutes, 2);
    });

    test('BuildEvent retains properties', () {
      final event = BuildEvent(
        projectId: const EntityId('p1'),
        type: BuildEventType.progress,
        message: 'Compiling Kotlin...',
        progressPercent: 0.75,
      );
      expect(event.type, BuildEventType.progress);
      expect(event.progressPercent, 0.75);
      expect(event.message, 'Compiling Kotlin...');
    });

    test('BuildOrchestrator selects first available provider', () async {
      final unavailableProvider = FakeBuildProvider(
        capabilities: const BuildCapabilities(
          providerType: BuildProviderType.onDeviceCompanion,
          providerName: 'OnDevice',
          isAvailable: false,
        ),
        buildResult: const BuildResult(
          status: BuildStatus.failure,
          log: '',
          duration: Duration.zero,
        ),
      );

      final availableProvider = FakeBuildProvider(
        capabilities: const BuildCapabilities(
          providerType: BuildProviderType.hostLocal,
          providerName: 'HostLocal',
          isAvailable: true,
        ),
        buildResult: const BuildResult(
          status: BuildStatus.success,
          log: 'Success',
          duration: Duration(seconds: 10),
          apkPath: '/dummy/path.apk',
        ),
      );

      final orchestrator = BuildOrchestrator(
        providers: [unavailableProvider, availableProvider],
      );

      final caps = await orchestrator.getCapabilities();
      expect(caps.isAvailable, true);
      expect(caps.providerType, BuildProviderType.hostLocal);

      final result = await orchestrator.buildProject(const EntityId('proj_1'));
      expect(result.status, BuildStatus.success);
      expect(unavailableProvider.wasCalled, false);
      expect(availableProvider.wasCalled, true);
    });

    test('BuildOrchestrator propagates cancellation to active provider', () async {
      final availableProvider = FakeBuildProvider(
        capabilities: const BuildCapabilities(
          providerType: BuildProviderType.hostLocal,
          providerName: 'HostLocal',
          isAvailable: true,
        ),
        buildResult: const BuildResult(
          status: BuildStatus.cancelled,
          log: '',
          duration: Duration.zero,
        ),
        delay: const Duration(milliseconds: 50),
      );

      final orchestrator = BuildOrchestrator(providers: [availableProvider]);

      // Trigger build and cancel immediately
      final future = orchestrator.build(const BuildRequest(projectId: EntityId('p1')));
      orchestrator.cancel();
      await future;
      expect(availableProvider.wasCancelled, true);
    });
  });
}
