import 'package:flutter/material.dart';
import 'package:nomad_core/nomad_core.dart';
import 'package:uuid/uuid.dart';
import '../branding/nomad_brand.dart';
import '../data/templates/web_template.dart';

class ProjectsView extends StatefulWidget {
  final ProjectRepository repository;
  final WorkspaceRepository? workspaceRepository;
  final FileContentRepository? contentRepository;
  final ValueChanged<Project>? onProjectSelected;

  const ProjectsView({
    super.key,
    required this.repository,
    this.workspaceRepository,
    this.contentRepository,
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

  /// Materialises a new project and, for Web projects, its starter
  /// HTML/CSS/JS workspace files.
  ///
  /// If any step fails after the project row is written, the partially
  /// created project, workspace nodes and file contents are removed so the
  /// user is never left with a half-created project.
  Future<void> _createProject(String name, ProjectType type) async {
    final now = DateTime.now();
    final projectId = EntityId(const Uuid().v4());
    final newProject = Project(
      id: projectId,
      name: name,
      type: type,
      createdAt: now,
      updatedAt: now,
    );

    try {
      await widget.repository.saveProject(newProject);

      final workspace = widget.workspaceRepository;
      final contents = widget.contentRepository;

      if (type == ProjectType.web && workspace != null && contents != null) {
        final starters = <String, String>{
          'index.html': WebTemplate.indexHtml,
          'style.css': WebTemplate.styleCss,
          'script.js': WebTemplate.scriptJs,
        };

        for (final entry in starters.entries) {
          final node = FileNode(
            id: EntityId(const Uuid().v4()),
            projectId: projectId,
            name: entry.key,
            type: FileNodeType.file,
            createdAt: now,
            updatedAt: now,
          );
          await workspace.createNode(node);
          await contents.writeFile(projectId, node.id, entry.value);
        }
      }
    } catch (e) {
      // Partial failure: roll back everything we may have written.
      try {
        await widget.repository.deleteProject(projectId);
        await widget.workspaceRepository?.deleteAllNodesForProject(projectId);
        await widget.contentRepository?.deleteAllContentForProject(projectId);
      } catch (_) {
        // Surface the original failure, not the cleanup failure.
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create project: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    await _loadProjects();
  }

  Future<void> _createProjectDialog() async {
    final nameController = TextEditingController();
    var selectedType = ProjectType.web;
    var confirmed = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(NomadBrand.radiusLarge),
              ),
              title: const Text(
                'Create Project',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: 320,
                child: SingleChildScrollView(
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
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: NomadBrand.space16),
                      DropdownButtonFormField<ProjectType>(
                        // ignore: deprecated_member_use
                        value: selectedType,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Project Type',
                          border: OutlineInputBorder(),
                        ),
                        items: ProjectType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type == ProjectType.web
                                ? 'Web Application'
                                : 'Android App'),
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
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  key: const Key('save_project_button'),
                  onPressed: () {
                    if (nameController.text.trim().isEmpty) return;
                    confirmed = true;
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!confirmed) return;
    await _createProject(nameController.text.trim(), selectedType);
  }

  Future<void> _deleteProject(EntityId id) async {
    await widget.repository.deleteProject(id);
    await widget.workspaceRepository?.deleteAllNodesForProject(id);
    await widget.contentRepository?.deleteAllContentForProject(id);
    await _loadProjects();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _projects.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(NomadBrand.space32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_open_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: NomadBrand.space16),
                        Text(
                          'No projects yet',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: NomadBrand.space8),
                        Text(
                          'Create your first project and start building.',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: NomadBrand.space16,
                    vertical: NomadBrand.space12,
                  ),
                  itemCount: _projects.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: NomadBrand.space8),
                  itemBuilder: (context, index) {
                    final project = _projects[index];
                    final isWeb = project.type == ProjectType.web;
                    return Card(
                      child: ListTile(
                        key: Key('project_item_${project.name}'),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(NomadBrand.radiusMedium),
                        ),
                        leading: CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                          child: Icon(isWeb ? Icons.language : Icons.android),
                        ),
                        title: Text(
                          project.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          isWeb ? 'Type: Web' : 'Type: Android',
                        ),
                        trailing: IconButton(
                          key: Key('delete_project_${project.name}'),
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteProject(project.id),
                        ),
                        onTap: () => widget.onProjectSelected?.call(project),
                      ),
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
