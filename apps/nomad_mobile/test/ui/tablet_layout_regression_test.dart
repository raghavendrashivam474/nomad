import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_mobile/app/app_shell.dart';
import 'package:nomad_mobile/data/database/app_database.dart';
import 'package:nomad_mobile/data/repositories/local_file_content_repository.dart';
import 'package:nomad_mobile/data/repositories/local_project_repository.dart';
import 'package:nomad_mobile/data/repositories/local_workspace_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Regression tests for NT-1.S-T1R:
/// Verifies that the tablet layout exposes the terminal-enabled Lab interface
/// with correct navigation icons, branding, and terminal view.
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
    tempFilesDir = await Directory.systemTemp.createTemp('nomad_t1r_');
    projectRepo = LocalProjectRepository(dbProvider: () async => db);
    workspaceRepo = LocalWorkspaceRepository(dbProvider: () async => db);
    contentRepo =
        LocalFileContentRepository(baseDirProvider: () async => tempFilesDir);
  });

  tearDown(() async {
    await db.close();
    if (await tempFilesDir.exists()) {
      await tempFilesDir.delete(recursive: true);
    }
  });

  Widget buildTabletShell() {
    return MaterialApp(
      home: AppShell(
        repository: projectRepo,
        workspaceRepository: workspaceRepo,
        contentRepository: contentRepo,
      ),
    );
  }

  group('Tablet layout regression (S-T1R)', () {
    testWidgets(
      'NavigationRail uses terminal icons, not home icons',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildTabletShell());
        await tester.pumpAndSettle();

        // Lab tab is selected by default, so selectedIcon (Icons.terminal)
        // is rendered. The unselected Projects tab shows folder_outlined.
        expect(find.byIcon(Icons.terminal), findsWidgets);
        expect(find.byIcon(Icons.folder_outlined), findsWidgets);

        // Home icons must NOT appear anywhere
        expect(find.byIcon(Icons.home_outlined), findsNothing);
        expect(find.byIcon(Icons.home), findsNothing);
      },
    );

    testWidgets(
      'Lab tab shows TerminalView on tablet',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildTabletShell());
        await tester.pumpAndSettle();

        expect(find.text('type a command...'), findsOneWidget);
        expect(find.text('Nomad Terminal'), findsOneWidget);
      },
    );

    testWidgets(
      'Get Started button navigates to Projects on tablet',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildTabletShell());
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('get_started_button')), findsOneWidget);

        // Tap to navigate to Projects
        await tester.tap(find.byKey(const Key('get_started_button')));
        // Use bounded pump instead of pumpAndSettle to avoid
        // timeout from TerminalView continuous rebuilds
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));

        // After navigation, Projects tab is selected (Icons.folder)
        expect(find.byIcon(Icons.folder), findsWidgets);
      },
    );

    testWidgets(
      'Placeholder text is not shown on tablet Lab tab',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildTabletShell());
        await tester.pumpAndSettle();

        expect(
          find.text('Responsive Tablet Foundation Active'),
          findsNothing,
        );
      },
    );
  });
}