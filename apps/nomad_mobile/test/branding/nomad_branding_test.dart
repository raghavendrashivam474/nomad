import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_core/nomad_core.dart';
import 'package:nomad_mobile/app/nomad_app.dart';
import 'package:nomad_mobile/branding/nomad_brand.dart';
import 'package:nomad_mobile/branding/nomad_logo_widget.dart';

class _FakeProjectRepo implements ProjectRepository {
  @override
  Future<List<Project>> getAllProjects() async => [];
  @override
  Future<Project?> getProjectById(EntityId id) async => null;
  @override
  Future<void> saveProject(Project project) async {}
  @override
  Future<void> deleteProject(EntityId id) async {}
}

class _FakeWorkspaceRepo implements WorkspaceRepository {
  @override
  Future<void> moveNode(EntityId id, EntityId? newParentId) async {}
  @override
  Future<List<FileNode>> getNodesForProject(EntityId projectId) async => [];
  @override
  Future<FileNode?> getNodeById(EntityId id) async => null;
  @override
  Future<void> createNode(FileNode node) async {}
  @override
  Future<void> renameNode(EntityId id, String newName) async {}
  @override
  Future<void> deleteNode(EntityId id) async {}
  @override
  Future<void> deleteAllNodesForProject(EntityId projectId) async {}
}

class _FakeContentRepo implements FileContentRepository {
  @override
  Future<List<int>> readFileBytes(
      EntityId projectId, EntityId fileNodeId) async {
    final text = await readFile(projectId, fileNodeId);
    return utf8.encode(text);
  }

  @override
  Future<void> writeFileBytes(
      EntityId projectId, EntityId fileNodeId, List<int> bytes) async {
    await writeFile(projectId, fileNodeId, utf8.decode(bytes));
  }

  @override
  Future<String> readFile(EntityId projectId, EntityId fileNodeId) async => '';

  @override
  Future<void> writeFile(
      EntityId projectId, EntityId fileNodeId, String content) async {}

  @override
  Future<void> deleteContent(EntityId projectId, EntityId fileNodeId) async {}

  @override
  Future<void> deleteAllContentForProject(EntityId projectId) async {}
}

void main() {
  group('NomadBrand Tokens & Themes', () {
    test('brand constants are authoritative', () {
      expect(NomadBrand.productName, equals('Nomad'));
      expect(NomadBrand.logoAsset, equals('assets/branding/nomad_logo.jpeg'));
      expect(NomadBrand.primary, isNotNull);
      expect(NomadBrand.surfaceLight, isNotNull);
      expect(NomadBrand.surfaceDark, isNotNull);
    });

    test('lightTheme generates valid Material 3 theme', () {
      final light = NomadBrand.lightTheme();
      expect(light.useMaterial3, isTrue);
      expect(light.brightness, equals(Brightness.light));
      expect(light.scaffoldBackgroundColor, equals(NomadBrand.surfaceLight));
    });

    test('darkTheme generates valid Material 3 theme', () {
      final dark = NomadBrand.darkTheme();
      expect(dark.useMaterial3, isTrue);
      expect(dark.brightness, equals(Brightness.dark));
      expect(dark.scaffoldBackgroundColor, equals(NomadBrand.surfaceDark));
    });
  });

  group('NomadLogo Widget', () {
    testWidgets('renders NomadLogo widget with custom dimensions',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: NomadLogo(size: 64, showBorder: true),
            ),
          ),
        ),
      );

      expect(find.byType(NomadLogo), findsOneWidget);
      expect(find.byType(ClipRRect), findsOneWidget);
    });
  });

  group('NomadApp Branded Startup', () {
    testWidgets('renders Nomad branding on phone launch', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        NomadApp(
          repository: _FakeProjectRepo(),
          workspaceRepository: _FakeWorkspaceRepo(),
          contentRepository: _FakeContentRepo(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nomad'), findsWidgets);
      expect(find.text(NomadBrand.subTagline), findsOneWidget);
      expect(find.byKey(const Key('get_started_button')), findsOneWidget);
      expect(find.byType(NomadLogo), findsWidgets);
    });

    testWidgets('renders Nomad branding on tablet launch', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        NomadApp(
          repository: _FakeProjectRepo(),
          workspaceRepository: _FakeWorkspaceRepo(),
          contentRepository: _FakeContentRepo(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('${NomadBrand.productName} — ${NomadBrand.tagline}'),
          findsOneWidget);
      expect(find.byType(NomadLogo), findsWidgets);
      expect(find.text('Tablet View'), findsOneWidget);
    });
  });
}
