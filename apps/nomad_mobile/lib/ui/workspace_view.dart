import 'package:flutter/material.dart';
import 'package:nomad_core/nomad_core.dart';
import 'package:uuid/uuid.dart';
import '../android_build/adb_service.dart';
import '../android_build/android_build_controller.dart';
import '../android_build/providers/build_orchestrator.dart';
import '../android_build/providers/local_host_build_provider.dart';
import '../android_build/providers/companion_build_provider.dart';
import '../android_build/android_build_service.dart';
import '../android_build/artifact_manager.dart';
import '../android_build/project_materializer.dart';
import '../branding/nomad_brand.dart';
import 'android/build_diagnostics_sheet.dart';

class WorkspaceView extends StatefulWidget {
  final Project project;
  final WorkspaceRepository workspaceRepository;
  final FileContentRepository? contentRepository;
  final EntityId? selectedNodeId;
  final ValueChanged<FileNode>? onFileSelected;
  final VoidCallback? onBack;
  final AndroidBuildController? buildController;
  final AdbService? adbService;

  const WorkspaceView({
    super.key,
    required this.project,
    required this.workspaceRepository,
    this.contentRepository,
    this.selectedNodeId,
    this.onFileSelected,
    this.onBack,
    this.buildController,
    this.adbService,
  });

  @override
  State<WorkspaceView> createState() => _WorkspaceViewState();
}

class _WorkspaceViewState extends State<WorkspaceView> {
  List<FileNode> _allNodes = [];
  EntityId? _currentFolderId;
  final List<FileNode> _folderBreadcrumbs = [];
  bool _isLoading = true;

  AndroidBuildController? _internalBuildController;
  AndroidBuildController get _buildController =>
      widget.buildController ?? _internalBuildController!;

  @override
  void initState() {
    super.initState();
    _loadNodes();
    if (widget.project.type == ProjectType.android && widget.buildController == null) {
      if (widget.contentRepository != null) {
        final materializer = ProjectMaterializer(
          workspace: widget.workspaceRepository,
          content: widget.contentRepository!,
        );
        final artifactManager = ArtifactManager();
        final buildService = AndroidBuildService(
          materializer: materializer,
          hostAndroidDir: 'android',
          artifactManager: artifactManager,
        );
        final orchestrator = BuildOrchestrator(
          providers: [
            LocalHostBuildProvider(buildService: buildService),
            CompanionBuildProvider(
              workspaceRepository: widget.workspaceRepository,
              contentRepository: widget.contentRepository!,
              artifactManager: artifactManager,
            ),
          ],
        );
        _internalBuildController = AndroidBuildController(
          provider: orchestrator,
          artifactManager: artifactManager,
          buildService: buildService,
        );
      }
    }
  }

  @override
  void dispose() {
    _internalBuildController?.dispose();
    super.dispose();
  }

  Future<void> _loadNodes() async {
    final nodes =
        await widget.workspaceRepository.getNodesForProject(widget.project.id);
    if (mounted) {
      setState(() {
        _allNodes = nodes;
        _isLoading = false;
      });
    }
  }

  List<FileNode> get _currentLevelNodes {
    return _allNodes
        .where((node) => node.parentId == _currentFolderId)
        .toList();
  }

  void _navigateToFolder(FileNode folder) {
    setState(() {
      _currentFolderId = folder.id;
      _folderBreadcrumbs.add(folder);
    });
  }

  void _navigateUp() {
    if (_folderBreadcrumbs.isNotEmpty) {
      setState(() {
        _folderBreadcrumbs.removeLast();
        _currentFolderId =
            _folderBreadcrumbs.isEmpty ? null : _folderBreadcrumbs.last.id;
      });
    }
  }

  Future<void> _triggerAndroidBuild() async {
    final controller = _buildController;
    if (controller.isBusy) return;

    try {
      final res = await controller.startBuild(widget.project.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.isSuccess ? 'APK build succeeded!' : 'APK build failed: ${res.errorMessage ?? "Check diagnostics"}'),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Diagnostics',
              onPressed: () => _openDiagnosticsSheet(),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Build error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _openDiagnosticsSheet() {
    BuildDiagnosticsSheet.show(
      context,
      buildController: _buildController,
      adbService: widget.adbService,
    );
  }

  Future<void> _showCreateDialog(FileNodeType type) async {
    final nameController = TextEditingController();
    final isFolder = type == FileNodeType.folder;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NomadBrand.radiusLarge),
        ),
        title: Text(
          isFolder ? 'New Folder' : 'New File',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          key: const Key('node_name_input'),
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: isFolder ? 'Folder Name' : 'File Name',
            hintText: isFolder ? 'e.g. assets' : 'e.g. index.html',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('save_node_button'),
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty || name.contains('/') || name.contains('\\')) {
                return;
              }

              final now = DateTime.now();
              final newNode = FileNode(
                id: EntityId(const Uuid().v4()),
                projectId: widget.project.id,
                parentId: _currentFolderId,
                name: name,
                type: type,
                createdAt: now,
                updatedAt: now,
              );

              await widget.workspaceRepository.createNode(newNode);
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
              }
              await _loadNodes();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRenameDialog(FileNode node) async {
    final nameController = TextEditingController(text: node.name);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NomadBrand.radiusLarge),
        ),
        title: Text(
          'Rename ${node.name}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          key: const Key('rename_node_input'),
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'New Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm_rename_button'),
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isEmpty ||
                  newName.contains('/') ||
                  newName.contains('\\') ||
                  newName == node.name) {
                return;
              }

              await widget.workspaceRepository.renameNode(node.id, newName);
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
              }
              await _loadNodes();
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  Set<EntityId> _getDescendantFolderIds(EntityId folderId) {
    final descendants = <EntityId>{};
    final queue = <EntityId>[folderId];

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final children = _allNodes
          .where((n) => n.isFolder && n.parentId == current)
          .map((n) => n.id);
      for (final child in children) {
        if (descendants.add(child)) {
          queue.add(child);
        }
      }
    }
    return descendants;
  }

  Future<void> _showMoveDialog(FileNode node) async {
    final invalidTargets = <EntityId?>{node.parentId};
    if (node.isFolder) {
      invalidTargets.add(node.id);
      invalidTargets.addAll(_getDescendantFolderIds(node.id));
    }

    final targetFolders = _allNodes
        .where((n) => n.isFolder && !invalidTargets.contains(n.id))
        .toList();

    EntityId? selectedTargetId = node.parentId == null
        ? (targetFolders.isNotEmpty ? targetFolders.first.id : null)
        : null;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(NomadBrand.radiusLarge),
            ),
            title: Text(
              'Move "${node.name}"',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select destination folder:'),
                  const SizedBox(height: NomadBrand.space12),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RadioGroup<EntityId?>(
                            groupValue: selectedTargetId,
                            onChanged: (val) =>
                                setDialogState(() => selectedTargetId = val),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                RadioListTile<EntityId?>(
                                  key: const Key('move_dest_root'),
                                  title: const Text('/ (Workspace Root)'),
                                  value: null,
                                  enabled: node.parentId != null,
                                ),
                                ...targetFolders.map((folder) {
                                  final isCurrentParent = node.parentId == folder.id;
                                  return RadioListTile<EntityId?>(
                                    key: Key('move_dest_${folder.name}'),
                                    title: Text(folder.name),
                                    secondary: const Icon(Icons.folder_outlined),
                                    value: folder.id,
                                    enabled: !isCurrentParent,
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('confirm_move_button'),
                onPressed: selectedTargetId == node.parentId
                    ? null
                    : () => Navigator.of(ctx).pop(true),
                child: const Text('Move'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await widget.workspaceRepository.moveNode(node.id, selectedTargetId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Moved "${node.name}" successfully'),
              duration: const Duration(seconds: 2),
            ),
          );
          await _loadNodes();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Move failed: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteNode(FileNode node) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NomadBrand.radiusLarge),
        ),
        title: Text(
          'Delete ${node.name}?',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          node.isFolder
              ? 'This will permanently delete this folder and all its contents.'
              : 'This will permanently delete this file.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm_delete_button'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.workspaceRepository.deleteNode(node.id);
      await _loadNodes();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentNodes = _currentLevelNodes;
    final isAndroidProject = widget.project.type == ProjectType.android;

    return Scaffold(
      appBar: AppBar(
        leading: widget.onBack != null
            ? IconButton(
                key: const Key('workspace_back_button'),
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back to Projects',
                onPressed: widget.onBack,
              )
            : null,
        title: Text(
          _folderBreadcrumbs.isEmpty
              ? widget.project.name
              : _folderBreadcrumbs.map((f) => f.name).join('/'),
          style: const TextStyle(fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (isAndroidProject && (widget.buildController != null || _internalBuildController != null))
            ListenableBuilder(
              listenable: _buildController,
              builder: (ctx, _) {
                final controller = _buildController;
                final isBusy = controller.isBusy;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isBusy)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      )
                    else
                      IconButton(
                        key: const Key('build_apk_button'),
                        tooltip: 'Build APK',
                        icon: const Icon(Icons.build_circle_outlined),
                        onPressed: _triggerAndroidBuild,
                      ),
                    if (controller.lastResult != null)
                      IconButton(
                        key: const Key('build_diagnostics_button'),
                        tooltip: 'Build Diagnostics',
                        icon: Icon(
                          controller.lastResult!.isSuccess
                              ? Icons.assignment_turned_in_outlined
                              : Icons.assignment_late_outlined,
                          color: controller.lastResult!.isSuccess ? Colors.green : Colors.red,
                        ),
                        onPressed: _openDiagnosticsSheet,
                      ),
                  ],
                );
              },
            ),
          IconButton(
            key: const Key('add_folder_button'),
            tooltip: 'New Folder',
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: () => _showCreateDialog(FileNodeType.folder),
          ),
          IconButton(
            key: const Key('add_file_button'),
            tooltip: 'New File',
            icon: const Icon(Icons.note_add_outlined),
            onPressed: () => _showCreateDialog(FileNodeType.file),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_folderBreadcrumbs.isNotEmpty)
                  ListTile(
                    key: const Key('navigate_up_tile'),
                    leading: const Icon(Icons.drive_folder_upload_outlined),
                    title: const Text('.. (Go up)'),
                    onTap: _navigateUp,
                  ),
                Expanded(
                  child: currentNodes.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(NomadBrand.space32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.folder_open_outlined,
                                  size: 56,
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                                const SizedBox(height: NomadBrand.space12),
                                Text(
                                  'Workspace is empty',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: NomadBrand.space4),
                                Text(
                                  'Tap + above to create files or folders',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: currentNodes.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final node = currentNodes[index];
                            final isSelected = widget.selectedNodeId == node.id;
                            return ListTile(
                              key: Key('node_${node.name}'),
                              selected: isSelected,
                              selectedTileColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withAlpha(80),
                              leading: Icon(
                                node.isFolder
                                    ? Icons.folder
                                    : Icons.description_outlined,
                                color: node.isFolder
                                    ? Theme.of(context).colorScheme.primary
                                    : isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context)
                                            .colorScheme
                                            .secondary,
                              ),
                              title: Text(
                                node.name,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              onTap: () {
                                if (node.isFolder) {
                                  _navigateToFolder(node);
                                } else {
                                  widget.onFileSelected?.call(node);
                                }
                              },
                              trailing: PopupMenuButton<String>(
                                key: Key('node_menu_${node.name}'),
                                onSelected: (action) {
                                  if (action == 'rename') {
                                    _showRenameDialog(node);
                                  } else if (action == 'move') {
                                    _showMoveDialog(node);
                                  } else if (action == 'delete') {
                                    _deleteNode(node);
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'rename',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined, size: 18),
                                        SizedBox(width: 8),
                                        Text('Rename'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'move',
                                    child: Row(
                                      children: [
                                        Icon(Icons.drive_file_move_outlined,
                                            size: 18),
                                        SizedBox(width: 8),
                                        Text('Move'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline,
                                            size: 18, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Delete',
                                            style:
                                                TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

