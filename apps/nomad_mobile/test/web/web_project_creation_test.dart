import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_core/nomad_core.dart';
import 'package:nomad_mobile/data/templates/web_template.dart';
import 'package:nomad_mobile/ui/projects_view.dart';

// In-memory test doubles to verify contract behavior
class InMemoryProjectRepository implements ProjectRepository {
  final Map<String, Project> _projects = {};

  @override
  Future<List<Project>> getAllProjects() async => _projects.values.toList();

  @override
  Future<Project?> getProjectById(EntityId id) async => _projects[id.value];

  @override
  Future<void> saveProject(Project project) async {
    _projects[project.id.value] = project;
  }

  @override
  Future<void> deleteProject(EntityId id) async {
    _projects.remove(id.value);
  }
}

class InMemoryWorkspaceRepository implements WorkspaceRepository {
  final Map<String, List<FileNode>> _nodes = {};

  @override
  Future<List<FileNode>> getNodesForProject(EntityId projectId) async {
    return _nodes[projectId.value] ?? [];
  }

  @override
  Future<FileNode?> getNodeById(EntityId id) async {
    for (final list in _nodes.values) {
      for (final node in list) {
        if (node.id == id) return node;
      }
    }
    return null;
  }

  @override
  Future<void> createNode(FileNode node) async {
    final list = _nodes.putIfAbsent(node.projectId.value, () => []);
    list.add(node);
  }

  @override
  Future<void> renameNode(EntityId id, String newName) async {
    for (final list in _nodes.values) {
      final idx = list.indexWhere((n) => n.id == id);
      if (idx != -1) {
        list[idx] = list[idx].copyWith(name: newName);
      }
    }
  }

  @override
  Future<void> deleteNode(EntityId id) async {
    for (final list in _nodes.values) {
      list.removeWhere((n) => n.id == id);
    }
  }

  @override
  Future<void> deleteAllNodesForProject(EntityId projectId) async {
    _nodes.remove(projectId.value);
  }
}

class InMemoryFileContentRepository implements FileContentRepository {
  final Map<String, String> _contents = {};

  String _key(EntityId projectId, EntityId fileNodeId) =>
      '${projectId.value}:${fileNodeId.value}';

  @override
  Future<String> readFile(EntityId projectId, EntityId fileNodeId) async {
    return _contents[_key(projectId, fileNodeId)] ?? '';
  }

  @override
  Future<void> writeFile(
      EntityId projectId, EntityId fileNodeId, String content) async {
    _contents[_key(projectId, fileNodeId)] = content;
  }

  @override
  Future<void> deleteContent(EntityId projectId, EntityId fileNodeId) async {
    _contents.remove(_key(projectId, fileNodeId));
  }

  @override
  Future<void> deleteAllContentForProject(EntityId projectId) async {
    _contents.removeWhere((k, _) => k.startsWith('${projectId.value}:'));
  }
}

void main() {
  group('S0.1.1 Web Project Creation', () {
    late InMemoryProjectRepository projectRepo;
    late InMemoryWorkspaceRepository workspaceRepo;
    late InMemoryFileContentRepository contentRepo;

    setUp(() {
      projectRepo = InMemoryProjectRepository();
      workspaceRepo = InMemoryWorkspaceRepository();
      contentRepo = InMemoryFileContentRepository();
    });

    testWidgets(
        'Creating Web Project creates index.html, style.css, and script.js with starter content',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProjectsView(
            repository: projectRepo,
            workspaceRepository: workspaceRepo,
            contentRepository: contentRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap FAB to create project
      await tester.tap(find.byKey(const Key('add_project_fab')));
      await tester.pumpAndSettle();

      // Enter name
      await tester.enterText(
          find.byKey(const Key('project_name_input')), 'My Portfolio');
      await tester.pumpAndSettle();

      // Tap Create (default type is Web)
      await tester.tap(find.byKey(const Key('save_project_button')));
      await tester.pumpAndSettle();

      // Verify Project saved
      final projects = await projectRepo.getAllProjects();
      expect(projects.length, 1);
      final project = projects.first;
      expect(project.name, 'My Portfolio');
      expect(project.type, ProjectType.web);

      // Verify 3 starter files created in workspace
      final nodes = await workspaceRepo.getNodesForProject(project.id);
      expect(nodes.length, 3);

      final htmlNode = nodes.firstWhere((n) => n.name == 'index.html');
      final cssNode = nodes.firstWhere((n) => n.name == 'style.css');
      final jsNode = nodes.firstWhere((n) => n.name == 'script.js');

      expect(htmlNode.isFile, isTrue);
      expect(cssNode.isFile, isTrue);
      expect(jsNode.isFile, isTrue);

      // Verify Starter content written
      final htmlContent = await contentRepo.readFile(project.id, htmlNode.id);
      final cssContent = await contentRepo.readFile(project.id, cssNode.id);
      final jsContent = await contentRepo.readFile(project.id, jsNode.id);

      expect(htmlContent, WebTemplate.indexHtml);
      expect(cssContent, WebTemplate.styleCss);
      expect(jsContent, WebTemplate.scriptJs);
      expect(htmlContent, contains('<title>Nomad Web Project</title>'));
      expect(cssContent, contains('body {'));
      expect(jsContent, contains('document.addEventListener'));
    });

    testWidgets('Deleting a project cleans up its files and content',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProjectsView(
            repository: projectRepo,
            workspaceRepository: workspaceRepo,
            contentRepository: contentRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Create
      await tester.tap(find.byKey(const Key('add_project_fab')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('project_name_input')), 'Temporary');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save_project_button')));
      await tester.pumpAndSettle();

      final projects = await projectRepo.getAllProjects();
      final project = projects.first;

      // Delete
      await tester.tap(find.byKey(Key('delete_project_${project.name}')));
      await tester.pumpAndSettle();

      expect(await projectRepo.getAllProjects(), isEmpty);
      expect(await workspaceRepo.getNodesForProject(project.id), isEmpty);
    });
  });
}
