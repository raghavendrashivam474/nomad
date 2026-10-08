import 'package:flutter/material.dart';
import 'package:nomad_core/nomad_core.dart';
import '../ui/editor_view.dart';
import '../ui/projects_view.dart';
import '../ui/workspace_view.dart';

const double kTabletBreakpoint = 600.0;

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
    setState(() {
      _selectedProject = null;
      _openTabs.clear();
      _activeFileNode = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= kTabletBreakpoint;

        // On phone, if an active file is open, show editor full-screen
        if (!isTablet && _activeFileNode != null) {
          return EditorView(
            key: ValueKey(_activeFileNode!.id.value),
            fileNode: _activeFileNode!,
            contentRepository: widget.contentRepository,
            onClose: _closeEditor,
          );
        }

        return Scaffold(
          appBar: _selectedProject != null
              ? null
              : AppBar(
                  title: Text(_selectedIndex == 0 ? 'Nomad' : 'Projects'),
                  centerTitle: !isTablet,
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
                          width: 300,
                          child: WorkspaceView(
                            project: _selectedProject!,
                            workspaceRepository: widget.workspaceRepository,
                            selectedNodeId: _activeFileNode?.id,
                            onFileSelected: _onFileSelected,
                            onBack: _onProjectDeselected,
                          ),
                        ),
                        const VerticalDivider(thickness: 1, width: 1),
                        Expanded(
                          child: Column(
                            children: [
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
                                    ? EditorView(
                                        key:
                                            ValueKey(_activeFileNode!.id.value),
                                        fileNode: _activeFileNode!,
                                        contentRepository:
                                            widget.contentRepository,
                                        onClose: _closeEditor,
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
                            ],
                          ),
                        ),
                      ],
                    )
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
                      onDestinationSelected: (idx) =>
                          setState(() => _selectedIndex = idx),
                      repository: widget.repository,
                      workspaceRepository: widget.workspaceRepository,
                      onProjectSelected: (project) =>
                          setState(() => _selectedProject = project),
                    )
                  : _selectedIndex == 0
                      ? _PhoneHomeLayout(
                          onOpenProjects: () =>
                              setState(() => _selectedIndex = 1),
                        )
                      : ProjectsView(
                          repository: widget.repository,
                          workspaceRepository: widget.workspaceRepository,
                          onProjectSelected: (project) =>
                              setState(() => _selectedProject = project),
                        ),
          bottomNavigationBar: (isTablet || _selectedProject != null)
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

class _PhoneHomeLayout extends StatelessWidget {
  final VoidCallback onOpenProjects;

  const _PhoneHomeLayout({required this.onOpenProjects});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.terminal_rounded,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Nomad',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Development. Everywhere You Go.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 32),
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
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final ProjectRepository repository;
  final WorkspaceRepository workspaceRepository;
  final ValueChanged<Project> onProjectSelected;

  const _TabletLayout({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.repository,
    required this.workspaceRepository,
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
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
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
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.devices_rounded,
                            size: 96,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Nomad — Mobile-First Development Lab',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Responsive Tablet Foundation Active',
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
                          const SizedBox(height: 32),
                          FilledButton.icon(
                            onPressed: () => onDestinationSelected(1),
                            icon: const Icon(Icons.explore_rounded),
                            label: const Text('Explore Workspace'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ProjectsView(
                    repository: repository,
                    workspaceRepository: workspaceRepository,
                    onProjectSelected: onProjectSelected,
                  ),
          ),
        ],
      ),
    );
  }
}
