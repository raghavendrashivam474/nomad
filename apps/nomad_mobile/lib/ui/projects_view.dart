import 'package:flutter/material.dart';
import 'package:nomad_core/nomad_core.dart';
import 'package:uuid/uuid.dart';

class ProjectsView extends StatefulWidget {
  final ProjectRepository repository;
  final WorkspaceRepository? workspaceRepository;
  final ValueChanged<Project>? onProjectSelected;

  const ProjectsView({
    super.key,
    required this.repository,
    this.workspaceRepository,
    this.onProjectSelected,
  });

  @override
  State<ProjectsView> createState() => _ProjectsViewState();
}

class _ProjectsViewState extends State<ProjectsView> {
  List<Project> _projects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    final projects = await widget.repository.getAllProjects();
    if (mounted) {
      setState(() {
        _projects = projects;
        _isLoading = false;
      });
    }
  }

  Future<void> _createProjectDialog() async {
    final nameController = TextEditingController();
    var selectedType = ProjectType.web;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create Project'),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      key: const Key('project_name_input'),
                      controller: nameController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Project Name',
                        hintText: 'e.g. My Website',
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<ProjectType>(
                      // ignore: deprecated_member_use
                      value: selectedType,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Project Type'),
                      items: ProjectType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type == ProjectType.web ? 'Web Application' : 'Android App'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedType = val);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  key: const Key('save_project_button'),
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;

                    final now = DateTime.now();
                    final newProject = Project(
                      id: EntityId(const Uuid().v4()),
                      name: name,
                      type: selectedType,
                      createdAt: now,
                      updatedAt: now,
                    );

                    await widget.repository.saveProject(newProject);
                    if (ctx.mounted) {
                      Navigator.of(ctx).pop();
                    }
                    await _loadProjects();
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteProject(EntityId id) async {
    await widget.repository.deleteProject(id);
    if (widget.workspaceRepository != null) {
      await widget.workspaceRepository!.deleteAllNodesForProject(id);
    }
    await _loadProjects();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _projects.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_open_outlined,
                        size: 64,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No projects yet',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create a project to get started',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _projects.length,
                  itemBuilder: (context, index) {
                    final project = _projects[index];
                    final isWeb = project.type == ProjectType.web;
                    return ListTile(
                      key: Key('project_item_${project.name}'),
                      leading: CircleAvatar(
                        child: Icon(isWeb ? Icons.language : Icons.android),
                      ),
                      title: Text(project.name),
                      subtitle: Text(
                        isWeb ? 'Type: Web' : 'Type: Android',
                      ),
                      trailing: IconButton(
                        key: Key('delete_project_${project.name}'),
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteProject(project.id),
                      ),
                      onTap: () => widget.onProjectSelected?.call(project),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add_project_fab'),
        onPressed: _createProjectDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Project'),
      ),
    );
  }
}
