import 'package:flutter/material.dart';
import 'package:nomad_core/nomad_core.dart';
import '../activity/activity_controller.dart';
import '../branding/nomad_brand.dart';
import '../branding/nomad_logo_widget.dart';
import '../ui/editor_view.dart';
import '../ui/projects_view.dart';
import '../ui/workspace_view.dart';
import '../ui/web_preview_view.dart';
import '../terminal/terminal_controller.dart';
import '../terminal/terminal_view.dart';

const double kTabletBreakpoint = 600.0;
const double kMinExplorerWidth = 180.0;
const double kMinEditorWidth = 240.0;
const double kDefaultExplorerWidth = 280.0;
const double kMaxExplorerFraction = 0.50;

class AppShell extends StatefulWidget {
  final ProjectRepository repository;
  final WorkspaceRepository workspaceRepository;
  final FileContentRepository contentRepository;

  const AppShell({
    super.key,
    required this.repository,
    required this.workspaceRepository,
    required this.contentRepository,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  Project? _selectedProject;
  final List<FileNode> _openTabs = [];
  FileNode? _activeFileNode;
  bool _showPreview = false;
  bool _showTerminalPanel = false;
  int _previewVersion = 0;
  double _explorerWidth = kDefaultExplorerWidth;

  final ActivityController _activityController = ActivityController();
  late final TerminalController _terminalController;

  @override
  void initState() {
    super.initState();
    _terminalController = TerminalController(
      workspaceRepository: widget.workspaceRepository,
      contentRepository: widget.contentRepository,
    );
  }

  @override
  void dispose() {
    _terminalController.dispose();
    _activityController.dispose();
    super.dispose();
  }

  void _onFileSelected(FileNode node) {
    setState(() {
      if (!_openTabs.any((t) => t.id == node.id)) {
        _openTabs.add(node);
      }
      _activeFileNode = node;
    });
  }

  void _closeTab(FileNode node) {
    setState(() {
      _openTabs.removeWhere((t) => t.id == node.id);
      if (_activeFileNode?.id == node.id) {
        _activeFileNode = _openTabs.isNotEmpty ? _openTabs.last : null;
      }
    });
  }

  void _closeEditor() {
    setState(() {
      if (_activeFileNode != null) {
        _closeTab(_activeFileNode!);
      }
    });
  }

  void _onProjectDeselected() {
    _activityController.clear();
    _terminalController.setActiveProject(null);
    setState(() {
      _selectedProject = null;
      _openTabs.clear();
      _activeFileNode = null;
      _showPreview = false;
      _showTerminalPanel = false;
      _previewVersion = 0;
    });
  }

  void _handleSaveCompleted(FileNode node) {
    final name = node.name;
    if (name == 'index.html' || name == 'style.css' || name == 'script.js') {
      setState(() {
        _previewVersion++;
      });
    }
  }

  void _onResizeDividerDrag(
      DragUpdateDetails details, double maxAvailableWidth) {
    final maxAllowedWidth = (maxAvailableWidth * kMaxExplorerFraction)
        .clamp(kMinExplorerWidth, maxAvailableWidth - kMinEditorWidth);

    setState(() {
      _explorerWidth = (_explorerWidth + details.delta.dx)
          .clamp(kMinExplorerWidth, maxAllowedWidth);
    });
  }

  Future<void> _navigateToSource(String sourceUri, int? line, int? column) async {
    if (_selectedProject == null) return;
    try {
      final nodes = await widget.workspaceRepository
          .getNodesForProject(_selectedProject!.id);

      final filename = sourceUri.split('/').where((s) => s.isNotEmpty).lastOrNull ?? sourceUri;
      final targetNode = nodes.where((n) => n.isFile && n.name == filename).firstOrNull;

      if (targetNode != null) {
        setState(() {
          _onFileSelected(targetNode);
          _showPreview = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to navigate to source: $e');
    }
  }

  void _selectProject(Project project) {
    setState(() {
      _selectedProject = project;
      _terminalController.setActiveProject(project);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= kTabletBreakpoint;

        if (!isTablet && _selectedProject != null && _showPreview) {
          return WebPreviewView(
            key: ValueKey('preview_${_selectedProject!.id.value}'),
            project: _selectedProject!,
            workspaceRepository: widget.workspaceRepository,
            contentRepository: widget.contentRepository,
            previewVersion: _previewVersion,
            activityController: _activityController,
            onNavigateToSource: _navigateToSource,
            onClose: () => setState(() => _showPreview = false),
          );
        }

        if (!isTablet && _activeFileNode != null) {
          return EditorView(
            key: ValueKey(_activeFileNode!.id.value),
            fileNode: _activeFileNode!,
            contentRepository: widget.contentRepository,
            onClose: _closeEditor,
            onPreview: () => setState(() => _showPreview = true),
            isPreviewActive: _showPreview,
            onSaveCompleted: () => _handleSaveCompleted(_activeFileNode!),
          );
        }

        return Scaffold(
          appBar: _selectedProject != null
              ? null
              : AppBar(
                  title: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const NomadLogo(size: 24, showBorder: true),
                      const SizedBox(width: 8),
                      Text(
                        _selectedIndex == 0
                            ? NomadBrand.productName
                            : 'Projects',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  centerTitle: false,
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 16.0),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isTablet ? 'Tablet View' : 'Phone View',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
          body: _selectedProject != null
              ? isTablet
                  ? Row(
                      children: [
                        SizedBox(
                          width: _explorerWidth.clamp(
                            kMinExplorerWidth,
                            (constraints.maxWidth * kMaxExplorerFraction).clamp(
                                kMinExplorerWidth,
                                constraints.maxWidth - kMinEditorWidth),
                          ),
                          child: WorkspaceView(
                            project: _selectedProject!,
                            workspaceRepository: widget.workspaceRepository,
                            selectedNodeId: _activeFileNode?.id,
                            onFileSelected: _onFileSelected,
                            onBack: _onProjectDeselected,
                          ),
                        ),
                        _ResizableDivider(
                          key: const Key('workspace_resizable_divider'),
                          onDragUpdate: (details) => _onResizeDividerDrag(
                              details, constraints.maxWidth),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                          Container(
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              icon: Icon(
                                _showTerminalPanel
                                    ? Icons.terminal
                                    : Icons.terminal_outlined,
                                size: 18,
                              ),
                              onPressed: () => setState(
                                  () => _showTerminalPanel = !_showTerminalPanel),
                              tooltip: 'Toggle Terminal',
                              constraints: const BoxConstraints(
                                  minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                              if (_openTabs.isNotEmpty)
                                Container(
                                  height: 42,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withAlpha(80),
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _openTabs.length,
                                    itemBuilder: (context, idx) {
                                      final tab = _openTabs[idx];
                                      final isActive =
                                          _activeFileNode?.id == tab.id;
                                      return InkWell(
                                        key: Key('tab_${tab.name}'),
                                        onTap: () => setState(
                                            () => _activeFileNode = tab),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12),
                                          decoration: BoxDecoration(
                                            color: isActive
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .surface
                                                : Colors.transparent,
                                            border: Border(
                                              bottom: BorderSide(
                                                color: isActive
                                                    ? Theme.of(context)
                                                        .colorScheme
                                                        .primary
                                                    : Colors.transparent,
                                                width: 2,
                                              ),
                                              right: BorderSide(
                                                color: Theme.of(context)
                                                    .dividerColor
                                                    .withAlpha(50),
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.description_outlined,
                                                  size: 16,
                                                  color: isActive
                                                      ? Theme.of(context)
                                                          .colorScheme
                                                          .primary
                                                      : null),
                                              const SizedBox(width: 6),
                                              Text(
                                                tab.name,
                                                style: TextStyle(
                                                  fontWeight: isActive
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                  color: isActive
                                                      ? Theme.of(context)
                                                          .colorScheme
                                                          .primary
                                                      : null,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              GestureDetector(
                                                key: Key(
                                                    'close_tab_${tab.name}'),
                                                onTap: () => _closeTab(tab),
                                                child: const Icon(Icons.close,
                                                    size: 14),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              Expanded(
                                child: _activeFileNode != null
                                    ? Row(
                                        children: [
                                          Expanded(
                                            child: EditorView(
                                              key: ValueKey(
                                                  _activeFileNode!.id.value),
                                              fileNode: _activeFileNode!,
                                              contentRepository:
                                                  widget.contentRepository,
                                              onClose: _closeEditor,
                                              onPreview: () => setState(() =>
                                                  _showPreview = !_showPreview),
                                              isPreviewActive: _showPreview,
                                              onSaveCompleted: () =>
                                                  _handleSaveCompleted(
                                                      _activeFileNode!),
                                            ),
                                          ),
                                          if (_showPreview) ...[
                                            const VerticalDivider(
                                                thickness: 1, width: 1),
                                            Expanded(
                                              child: WebPreviewView(
                                                key: ValueKey(
                                                    'preview_${_selectedProject!.id.value}'),
                                                project: _selectedProject!,
                                                workspaceRepository:
                                                    widget.workspaceRepository,
                                                contentRepository:
                                                    widget.contentRepository,
                                                previewVersion: _previewVersion,
                                                activityController: _activityController,
                                                onNavigateToSource: _navigateToSource,
                                                onClose: () => setState(
                                                    () => _showPreview = false),
                                              ),
                                            ),
                                          ],
                                        ],
                                      )
                                    : Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.code,
                                              size: 64,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .outline,
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              'Select a file from the workspace to edit',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyLarge
                                                  ?.copyWith(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                          if (_showTerminalPanel) ...[
                            const Divider(height: 1),
                            SizedBox(
                              height: 200,
                              child: TerminalView(controller: _terminalController),
                            ),
                          ],
                            ],
                          ),
                        ),
                      ],
                    )
                  : _selectedIndex == 0
                      ? TerminalView(controller: _terminalController)
                      : WorkspaceView(
                          project: _selectedProject!,
                          workspaceRepository: widget.workspaceRepository,
                          selectedNodeId: _activeFileNode?.id,
                          onFileSelected: _onFileSelected,
                          onBack: _onProjectDeselected,
                        )
              : isTablet
                  ? _TabletLayout(
                      selectedIndex: _selectedIndex,
                      terminalController: _terminalController,
                      onDestinationSelected: (idx) =>
                          setState(() => _selectedIndex = idx),
                      repository: widget.repository,
                      workspaceRepository: widget.workspaceRepository,
                      contentRepository: widget.contentRepository,
                      onProjectSelected: _selectProject,
                    )
                  : _selectedIndex == 0
                      ? Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(NomadBrand.space16),
                              child: Column(
                                children: [
                                  const NomadLogo(size: 48, showBorder: true),
                                  const SizedBox(height: NomadBrand.space8),
                                  Text(
                                    NomadBrand.productName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                            fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    NomadBrand.subTagline,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                  const SizedBox(height: NomadBrand.space12),
                                  FilledButton.icon(
                                    key: const Key('get_started_button'),
                                    onPressed: () =>
                                        setState(() => _selectedIndex = 1),
                                    icon: const Icon(Icons.play_arrow_rounded),
                                    label: const Text('Get Started'),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: TerminalView(
                                  controller: _terminalController),
                            ),
                          ],
                        )
                      : ProjectsView(
                          repository: widget.repository,
                          workspaceRepository: widget.workspaceRepository,
                          contentRepository: widget.contentRepository,
                          onProjectSelected: _selectProject,
                        ),
          bottomNavigationBar: isTablet
              ? null
              : NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (idx) =>
                      setState(() => _selectedIndex = idx),
                  destinations: const [
                    NavigationDestination(
                      key: Key('nav_lab'),
                      icon: Icon(Icons.terminal_outlined),
                      selectedIcon: Icon(Icons.terminal),
                      label: 'Lab',
                    ),
                    NavigationDestination(
                      key: Key('nav_projects'),
                      icon: Icon(Icons.folder_outlined),
                      selectedIcon: Icon(Icons.folder),
                      label: 'Projects',
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _ResizableDivider extends StatelessWidget {
  final ValueChanged<DragUpdateDetails> onDragUpdate;

  const _ResizableDivider({
    super.key,
    required this.onDragUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: onDragUpdate,
        child: SizedBox(
          width: 16.0,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VerticalDivider(
                thickness: 1.0,
                width: 1.0,
                color: Theme.of(context).dividerColor.withAlpha(120),
              ),
              Container(
                width: 4.0,
                height: 32.0,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2.0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhoneHomeLayout extends StatelessWidget {
  final VoidCallback onOpenProjects;

  const _PhoneHomeLayout({required this.onOpenProjects});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(NomadBrand.space24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const NomadLogo(size: 96, showBorder: true),
              const SizedBox(height: NomadBrand.space24),
              Text(
                NomadBrand.productName,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
              ),
              const SizedBox(height: NomadBrand.space8),
              Text(
                NomadBrand.subTagline,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: NomadBrand.space32),
              FilledButton.icon(
                key: const Key('get_started_button'),
                onPressed: onOpenProjects,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Get Started'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabletLayout extends StatelessWidget {
  final TerminalController terminalController;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final ProjectRepository repository;
  final WorkspaceRepository workspaceRepository;
  final FileContentRepository contentRepository;
  final ValueChanged<Project> onProjectSelected;

  const _TabletLayout({
    required this.terminalController,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.repository,
    required this.workspaceRepository,
    required this.contentRepository,
    required this.onProjectSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: NomadLogo(size: 40, showBorder: true),
            ),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.terminal_outlined),
                selectedIcon: Icon(Icons.terminal),
                label: Text('Lab'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.folder_outlined),
                selectedIcon: Icon(Icons.folder),
                label: Text('Projects'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: selectedIndex == 0
                ? Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(NomadBrand.space24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const NomadLogo(size: 80, showBorder: true),
                            const SizedBox(height: NomadBrand.space16),
                            Text(
                              '${NomadBrand.productName} — ${NomadBrand.tagline}',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: NomadBrand.space12),
                            Text(
                              NomadBrand.subTagline,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          const SizedBox(height: NomadBrand.space12),
                          FilledButton.icon(
                            key: const Key('get_started_button'),
                            onPressed: () => onDestinationSelected(1),
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Get Started'),
                          ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: TerminalView(
                            controller: terminalController),
                      ),
                    ],
                  )
                : ProjectsView(
                    repository: repository,
                    workspaceRepository: workspaceRepository,
                    contentRepository: contentRepository,
                    onProjectSelected: onProjectSelected,
                  ),
          ),
        ],
      ),
    );
  }
}
