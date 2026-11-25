import 'package:flutter/material.dart';
import '../../android_build/adb_service.dart';
import '../../android_build/android_build_controller.dart';
import '../../android_build/build_result.dart';
import '../../branding/nomad_brand.dart';

class BuildDiagnosticsSheet extends StatefulWidget {
  final AndroidBuildController buildController;
  final AdbService? adbService;
  final List<AdbDevice>? initialDevices;

  const BuildDiagnosticsSheet({
    super.key,
    required this.buildController,
    this.adbService,
    this.initialDevices,
  });

  static Future<void> show(
    BuildContext context, {
    required AndroidBuildController buildController,
    AdbService? adbService,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(NomadBrand.radiusLarge)),
      ),
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.85,
        child: BuildDiagnosticsSheet(
          buildController: buildController,
          adbService: adbService,
        ),
      ),
    );
  }

  @override
  State<BuildDiagnosticsSheet> createState() => _BuildDiagnosticsSheetState();
}

class _BuildDiagnosticsSheetState extends State<BuildDiagnosticsSheet> {
  late final AdbService _adbService;
  List<AdbDevice> _devices = [];
  bool _isLoadingDevices = false;
  bool _isInstalling = false;
  String? _installStatusMessage;

  @override
  void initState() {
    super.initState();
    _adbService = widget.adbService ?? AdbService();
    if (widget.initialDevices != null) {
      _devices = widget.initialDevices!;
    } else {
      _loadDevices();
    }
  }

  Future<void> _loadDevices() async {
    setState(() => _isLoadingDevices = true);
    final list = await _adbService.getConnectedDevices();
    if (mounted) {
      setState(() {
        _devices = list;
        _isLoadingDevices = false;
      });
    }
  }

  Future<void> _installToDevice(AdbDevice device) async {
    final apkPath = widget.buildController.lastArtifact?.filePath ??
        widget.buildController.lastResult?.apkPath;

    if (apkPath == null) {
      setState(() => _installStatusMessage = 'No APK available to install');
      return;
    }

    setState(() {
      _isInstalling = true;
      _installStatusMessage = 'Installing to ${device.displayName}...';
    });

    final res = await _adbService.installApk(serial: device.serial, apkPath: apkPath);

    if (mounted) {
      setState(() {
        _isInstalling = false;
        _installStatusMessage = res.isSuccess
            ? 'Installed successfully to ${device.displayName}!'
            : 'Install failed: ${res.errorMessage ?? res.output}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.buildController.lastResult;
    final artifact = widget.buildController.lastArtifact;
    final classified = widget.buildController.classifiedError;
    final status = result?.status ?? BuildStatus.failure;
    final duration = result?.duration ?? Duration.zero;

    final isSuccess = status == BuildStatus.success;

    final statusColor = isSuccess
        ? Colors.green
        : (status == BuildStatus.timeout ? Colors.orange : Colors.red);

    final statusLabel = isSuccess
        ? 'Build Succeeded'
        : (status == BuildStatus.timeout
            ? 'Build Timed Out'
            : (status == BuildStatus.cancelled ? 'Build Cancelled' : 'Build Failed'));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: NomadBrand.space16, vertical: NomadBrand.space12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor.withAlpha(120),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Icon(
                  isSuccess
                      ? Icons.check_circle
                      : (status == BuildStatus.timeout ? Icons.timer_off : Icons.error),
                  color: statusColor,
                  size: 28,
                ),
                const SizedBox(width: NomadBrand.space8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusLabel,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                      ),
                      Text(
                        'Duration: ${(duration.inMilliseconds / 1000).toStringAsFixed(1)}s'
                        '${artifact != null ? ' • Size: ${artifact.formattedSize}' : ''}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('close_diagnostics_button'),
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 24),
            if (!isSuccess && classified != null) ...[
              Container(
                padding: const EdgeInsets.all(NomadBrand.space12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer.withAlpha(80),
                  borderRadius: BorderRadius.circular(NomadBrand.radiusMedium),
                  border: Border.all(color: Theme.of(context).colorScheme.error.withAlpha(120)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline, size: 18, color: Theme.of(context).colorScheme.error),
                        const SizedBox(width: 6),
                        Text(
                          classified.title,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      classified.userMessage,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (classified.suggestion != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        classified.suggestion!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: NomadBrand.space12),
            ],
            if (isSuccess && (artifact != null || result?.apkPath != null)) ...[
              Container(
                padding: const EdgeInsets.all(NomadBrand.space12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withAlpha(50),
                  borderRadius: BorderRadius.circular(NomadBrand.radiusMedium),
                  border: Border.all(color: Theme.of(context).colorScheme.primary.withAlpha(80)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Artifact: ${artifact?.fileName ?? "app-debug.apk"}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Location: ${artifact?.filePath ?? result!.apkPath}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontFamily: 'monospace',
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'ADB Devices:',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        if (_isLoadingDevices)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Refresh devices',
                            onPressed: _loadDevices,
                          ),
                      ],
                    ),
                    if (_devices.isEmpty && !_isLoadingDevices)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          'No connected Android devices found via ADB.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
                        ),
                      )
                    else
                      ..._devices.map(
                        (dev) => Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            children: [
                              Icon(
                                dev.isAuthorized ? Icons.phone_android : Icons.phonelink_erase,
                                size: 16,
                                color: dev.isAuthorized ? Colors.green : Colors.red,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  dev.displayName,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              if (dev.isAuthorized)
                                FilledButton.tonal(
                                  key: Key('install_btn_${dev.serial}'),
                                  style: FilledButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                  ),
                                  onPressed: _isInstalling ? null : () => _installToDevice(dev),
                                  child: const Text('Install', style: TextStyle(fontSize: 12)),
                                ),
                            ],
                          ),
                        ),
                      ),
                    if (_installStatusMessage != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _installStatusMessage!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _installStatusMessage!.contains('failed')
                                  ? Colors.red
                                  : Colors.green,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: NomadBrand.space12),
            ],
            Text(
              'Build Output & Diagnostics:',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(NomadBrand.space8),
                decoration: BoxDecoration(
                  color: NomadBrand.surfaceDark,
                  borderRadius: BorderRadius.circular(NomadBrand.radiusMedium),
                ),
                child: SingleChildScrollView(
                  key: const Key('build_log_scroll_view'),
                  child: Text(
                    result?.log.isNotEmpty == true ? result!.log : '(No build output recorded)',
                    key: const Key('build_log_text'),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
