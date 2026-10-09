import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_core/nomad_core.dart';
import 'package:nomad_mobile/ui/projects_view.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'Create Project dialog renders and scrolls without overflowing in short height layout',
      (WidgetTester tester) async {
    // Set a constrained view height (simulating landscape tablet/phone with soft keyboard)
    tester.view.physicalSize = const Size(800, 320);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final projectRepo = InMemoryProjectRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: ProjectsView(
          repository: projectRepo,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap FAB to open Create Project dialog
    await tester.tap(find.byKey(const Key('add_project_fab')));
    await tester.pumpAndSettle();

    // Verify dialog title is rendered
    expect(find.text('Create Project'), findsOneWidget);

    // Verify dialog content is wrapped in a SingleChildScrollView
    expect(find.byType(SingleChildScrollView), findsWidgets);

    // Verify no layout overflow exception was thrown during layout
    expect(tester.takeException(), isNull);
  });
}
