import 'package:flutter/material.dart';
import 'package:nomad_core/nomad_core.dart';
import '../ui/projects_view.dart';

const double kTabletBreakpoint = 600.0;

class AppShell extends StatefulWidget {
  final ProjectRepository repository;

  const AppShell({super.key, required this.repository});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= kTabletBreakpoint;
        return Scaffold(
          appBar: AppBar(
            title: Text(_selectedIndex == 0 ? 'Nomad' : 'Projects'),
            centerTitle: !isTablet,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isTablet ? 'Tablet View' : 'Phone View',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: isTablet
              ? _TabletLayout(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
                  repository: widget.repository,
                )
              : _selectedIndex == 0
                  ? _PhoneHomeLayout(
                      onOpenProjects: () => setState(() => _selectedIndex = 1),
                    )
                  : ProjectsView(repository: widget.repository),
          bottomNavigationBar: isTablet
              ? null
              : NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
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

  const _TabletLayout({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.repository,
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
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Responsive Tablet Foundation Active',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                : ProjectsView(repository: repository),
          ),
        ],
      ),
    );
  }
}
