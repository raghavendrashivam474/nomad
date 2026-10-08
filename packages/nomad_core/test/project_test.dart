import 'package:test/test.dart';
import 'package:nomad_core/nomad_core.dart';

void main() {
  group('Project Domain Model', () {
    final now = DateTime.now();
    const testId = EntityId('project-1');

    test('can be created with valid values', () {
      final project = Project(
        id: testId,
        name: 'My Website',
        type: ProjectType.web,
        createdAt: now,
        updatedAt: now,
      );

      expect(project.id, equals(testId));
      expect(project.name, equals('My Website'));
      expect(project.type, equals(ProjectType.web));
      expect(project.createdAt, equals(now));
      expect(project.updatedAt, equals(now));
    });

    test('throws ContractViolationException on empty or whitespace name', () {
      expect(
        () => Project(
          id: testId,
          name: '',
          type: ProjectType.web,
          createdAt: now,
          updatedAt: now,
        ),
        throwsA(isA<ContractViolationException>()),
      );

      expect(
        () => Project(
          id: testId,
          name: '   ',
          type: ProjectType.web,
          createdAt: now,
          updatedAt: now,
        ),
        throwsA(isA<ContractViolationException>()),
      );
    });

    test('supports copyWith mutation properly', () {
      final project = Project(
        id: testId,
        name: 'Initial Name',
        type: ProjectType.web,
        createdAt: now,
        updatedAt: now,
      );

      final nextTime = now.add(const Duration(minutes: 5));
      final updatedProject = project.copyWith(
        name: 'Updated Name',
        type: ProjectType.android,
        updatedAt: nextTime,
      );

      // Verify changed values
      expect(updatedProject.name, equals('Updated Name'));
      expect(updatedProject.type, equals(ProjectType.android));
      expect(updatedProject.updatedAt, equals(nextTime));

      // Verify unchanged values (ID and createdAt must remain identical)
      expect(updatedProject.id, equals(testId));
      expect(updatedProject.createdAt, equals(now));
    });
  });
}
