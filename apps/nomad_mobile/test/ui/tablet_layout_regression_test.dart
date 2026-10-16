import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_mobile/app/app_shell.dart';
import 'package:nomad_mobile/data/database/app_database.dart';
import 'package:nomad_mobile/data/repositories/local_file_content_repository.dart';
import 'package:nomad_mobile/data/repositories/local_project_repository.dart';
import 'package:nomad_mobile/data/repositories/local_workspace_repository.dart';
import 'package:nomad_core/nomad_core.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database db;
  late Directory tempFilesDir;
  late LocalProjectRepository projectRepo;
  late LocalWorkspaceRepository workspaceRepo;
  late LocalFileContentRepository contentRepo;

  setUp(() async {
    final dbFactory = databaseFactoryFfi;
    db = await dbFactory.openDatabase(inMemoryDatabasePath);
    await AppDatabase.createSchema(db);
    tempFilesDir = await Directory.systemTemp.createTemp('nomad_t2_');
    projectRepo = LocalProjectRepository(dbProvider: () async => db);
    workspaceRepo = LocalWorkspaceRepository(dbProvider: () async => db);
    contentRepo =
        LocalFileContentRepository(baseDirProvider: () async => tempFilesDir);
  });

  tearDown(() async {
    await db.close();
    if (tempFilesDir.existsSync()) {
      await tempFilesDir.delete(recursive: true);
    }
  });

  Widget buildShell() {
    return MaterialApp(
      home: AppShell(
        repository: projectRepo,
        workspaceRepository: workspaceRepo,
        contentRepository: contentRepo,
      ),
    );
  }

  Future<void> seedProject(WidgetTester tester, String name) async {
    await tester.runAsync(() async {
      final now = DateTime.now();
      await projectRepo.saveProject(Project(
        id: EntityId('proj-$name'),
        name: name,
        type: ProjectType.web,
        createdAt: now,
        updatedAt: now,
      ));
    });
  }

  Future<void> drainSqflite(WidgetTester tester) async {
    await tester.runAsync(() async {
      await Future.delayed(const Duration(seconds: 1));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> pumpFrames(WidgetTester tester, [int n = 3]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  // ── S-T1R legacy tests ────────────────────────────────────────

  group('Tablet no-project (S-T1R)', () {
    testWidgets('NavigationRail icons', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildShell());
      await pumpFrames(tester);

      expect(find.byIcon(Icons.terminal), findsWidgets);
      expect(find.byIcon(Icons.folder_outlined), findsWidgets);
      expect(find.byIcon(Icons.home_outlined), findsNothing);
      expect(find.byIcon(Icons.home), findsNothing);
    });

    testWidgets('Lab shows TerminalView', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildShell());
      await pumpFrames(tester);

      expect(find.text('type a command...'), findsOneWidget);
      expect(find.text('Nomad Terminal'), findsOneWidget);
    });

    testWidgets('Get Started navigates to Projects', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildShell());
      await pumpFrames(tester);

      await tester.tap(find.byKey(const Key('get_started_button')));
      await pumpFrames(tester);

      expect(find.byIcon(Icons.folder), findsWidgets);
    });

    testWidgets('No placeholder text', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildShell());
      await pumpFrames(tester);

      expect(find.text('Responsive Tablet Foundation Active'), findsNothing);
    });
  });

  // ── S-T2 project-selected tests ───────────────────────────────

  group('Tablet project-selected (S-T2)', () {
    testWidgets('T1: Terminal hidden on project entry', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await seedProject(tester, 'TestProject');

      await tester.pumpWidget(buildShell());
      await pumpFrames(tester);

      await tester.tap(find.byIcon(Icons.folder_outlined));
      await tester.pump();
      await drainSqflite(tester);

      expect(find.text('TestProject'), findsOneWidget);

      await tester.tap(find.text('TestProject'));
      await pumpFrames(tester);

      expect(find.text('type a command...'), findsNothing);
      expect(find.text('Nomad Terminal'), findsNothing);
      expect(
        find.text('Select a file from the workspace to edit'),
        findsOneWidget,
      );
    });

    testWidgets('T2: Terminal opens via Lab tab', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await seedProject(tester, 'TestProject');

      await tester.pumpWidget(buildShell());
      await pumpFrames(tester);

      await tester.tap(find.byIcon(Icons.folder_outlined));
      await tester.pump();
      await drainSqflite(tester);

      await tester.tap(find.text('TestProject'));
      await pumpFrames(tester);

      await tester.tap(find.byIcon(Icons.terminal_outlined));
      await pumpFrames(tester);

      expect(find.text('type a command...'), findsOneWidget);
      expect(find.text('Nomad Terminal'), findsOneWidget);
    });

    testWidgets('T3: Terminal closes via Projects tab', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await seedProject(tester, 'TestProject');

      await tester.pumpWidget(buildShell());
      await pumpFrames(tester);

      await tester.tap(find.byIcon(Icons.folder_outlined));
      await tester.pump();
      await drainSqflite(tester);

      await tester.tap(find.text('TestProject'));
      await pumpFrames(tester);

      // Open terminal
      await tester.tap(find.byIcon(Icons.terminal_outlined));
      await pumpFrames(tester);
      expect(find.text('type a command...'), findsOneWidget);

      // Close terminal — switch back to Projects
      await tester.tap(find.byIcon(Icons.folder_outlined));
      await tester.pump();
      // Drain the WorkspaceView._loadNodes sqflite query so the
      // timer completes before tearDown closes the DB.
      await drainSqflite(tester);

      expect(find.text('type a command...'), findsNothing);
      expect(find.text('Nomad Terminal'), findsNothing);
      expect(
        find.text('Select a file from the workspace to edit'),
        findsOneWidget,
      );
    });

    testWidgets('T4: NavigationRail persists after selection', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await seedProject(tester, 'TestProject');

      await tester.pumpWidget(buildShell());
      await pumpFrames(tester);

      await tester.tap(find.byIcon(Icons.folder_outlined));
      await tester.pump();
      await drainSqflite(tester);

      await tester.tap(find.text('TestProject'));
      await pumpFrames(tester);

      expect(find.byType(NavigationRail), findsOneWidget);
    });

    testWidgets('T7: Landscape no overflow', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await seedProject(tester, 'TestProject');

      await tester.pumpWidget(buildShell());
      await pumpFrames(tester);

      await tester.tap(find.byIcon(Icons.folder_outlined));
      await tester.pump();
      await drainSqflite(tester);

      await tester.tap(find.text('TestProject'));
      await pumpFrames(tester);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byIcon(Icons.terminal_outlined));
      await pumpFrames(tester);
      expect(tester.takeException(), isNull);
    });
  });

  // ── Phone regression ──────────────────────────────────────────

  group('Phone regression (S-T2)', () {
    testWidgets('T6: Phone Lab shows terminal', (tester) async {
      // Use DPR 1.0 so physical size = logical size.
      // 390x844 is a standard iPhone 14 logical resolution.
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildShell());
      await pumpFrames(tester);

      expect(find.text('type a command...'), findsOneWidget);
      expect(find.text('Nomad Terminal'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    });
  });
}