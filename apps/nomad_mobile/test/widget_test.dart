import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_mobile/app/nomad_app.dart';
import 'package:nomad_mobile/data/database/app_database.dart';
import 'package:nomad_mobile/data/repositories/local_file_content_repository.dart';
import 'package:nomad_mobile/data/repositories/local_project_repository.dart';
import 'package:nomad_mobile/data/repositories/local_workspace_repository.dart';
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

    tempFilesDir = await Directory.systemTemp.createTemp('nomad_e2e_files_');

    projectRepo = LocalProjectRepository(dbProvider: () async => db);
    workspaceRepo = LocalWorkspaceRepository(dbProvider: () async => db);
    contentRepo = LocalFileContentRepository(baseDirProvider: () async => tempFilesDir);
  });

  tearDown(() async {
    await db.close();
    if (await tempFilesDir.exists()) {
      await tempFilesDir.delete(recursive: true);
    }
  });

  Future<void> settleDb(WidgetTester tester) async {
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('App renders Phone layout on narrow screens', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(NomadApp(
      repository: projectRepo,
      workspaceRepository: workspaceRepo,
      contentRepository: contentRepo,
    ));
    await settleDb(tester);

    expect(find.text('Nomad'), findsWidgets);
    expect(find.text('Development. Everywhere You Go.'), findsOneWidget);
    expect(find.text('Phone View'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });

  testWidgets('App renders Tablet layout on wide screens', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(NomadApp(
      repository: projectRepo,
      workspaceRepository: workspaceRepo,
      contentRepository: contentRepo,
    ));
    await settleDb(tester);

    expect(find.text('Tablet View'), findsOneWidget);
    expect(find.text('Nomad — Mobile-First Development Lab'), findsOneWidget);
    expect(find.text('Lab'), findsOneWidget);
    expect(find.text('Projects'), findsOneWidget);
  });

  testWidgets('End-to-End S0.0.3: Create project -> Restart app -> Project persists', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(NomadApp(
      repository: projectRepo,
      workspaceRepository: workspaceRepo,
      contentRepository: contentRepo,
    ));
    await settleDb(tester);

    await tester.tap(find.byKey(const Key('get_started_button')));
    await settleDb(tester);
    expect(find.text('No projects yet'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add_project_fab')));
    await settleDb(tester);

    await tester.enterText(find.byKey(const Key('project_name_input')), 'My Website');
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byKey(const Key('save_project_button')));
    await settleDb(tester);

    expect(find.text('My Website'), findsOneWidget);
    expect(find.text('Type: Web'), findsOneWidget);

    // Restart app
    await tester.pumpWidget(NomadApp(
      key: UniqueKey(),
      repository: projectRepo,
      workspaceRepository: workspaceRepo,
      contentRepository: contentRepo,
    ));
    await settleDb(tester);

    await tester.tap(find.byKey(const Key('get_started_button')));
    await settleDb(tester);

    expect(find.text('My Website'), findsOneWidget);
    expect(find.text('Type: Web'), findsOneWidget);
  });

  testWidgets('End-to-End S0.0.4: Open Project -> Workspace File & Folder lifecycle -> Persist across restart', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(NomadApp(
      repository: projectRepo,
      workspaceRepository: workspaceRepo,
      contentRepository: contentRepo,
    ));
    await settleDb(tester);
    await tester.tap(find.byKey(const Key('get_started_button')));
    await settleDb(tester);

    // Create "Portfolio" project
    await tester.tap(find.byKey(const Key('add_project_fab')));
    await settleDb(tester);
    await tester.enterText(find.byKey(const Key('project_name_input')), 'Portfolio');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('save_project_button')));
    await settleDb(tester);

    // Open "Portfolio"
    await tester.tap(find.text('Portfolio'));
    await settleDb(tester);

    // Create folder & file
    await tester.tap(find.byKey(const Key('add_folder_button')));
    await settleDb(tester);
    await tester.enterText(find.byKey(const Key('node_name_input')), 'assets');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('save_node_button')));
    await settleDb(tester);

    await tester.tap(find.byKey(const Key('add_file_button')));
    await settleDb(tester);
    await tester.enterText(find.byKey(const Key('node_name_input')), 'index.html');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('save_node_button')));
    await settleDb(tester);

    expect(find.text('assets'), findsOneWidget);
    expect(find.text('index.html'), findsOneWidget);

    // Back to projects
    await tester.tap(find.byKey(const Key('workspace_back_button')));
    await settleDb(tester);

    // RESTART APP
    await tester.pumpWidget(NomadApp(
      key: UniqueKey(),
      repository: projectRepo,
      workspaceRepository: workspaceRepo,
      contentRepository: contentRepo,
    ));
    await settleDb(tester);
    await tester.tap(find.byKey(const Key('get_started_button')));
    await settleDb(tester);

    await tester.tap(find.text('Portfolio'));
    await settleDb(tester);

    expect(find.text('assets'), findsOneWidget);
    expect(find.text('index.html'), findsOneWidget);
  });

  testWidgets('End-to-End S0.0.5: Open File -> Edit Code -> Save -> Restart App -> Code Persists', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // 1. Launch & navigate to Projects
    await tester.pumpWidget(NomadApp(
      repository: projectRepo,
      workspaceRepository: workspaceRepo,
      contentRepository: contentRepo,
    ));
    await settleDb(tester);
    await tester.tap(find.byKey(const Key('get_started_button')));
    await settleDb(tester);

    // 2. Create "Web Lab Project"
    await tester.tap(find.byKey(const Key('add_project_fab')));
    await settleDb(tester);
    await tester.enterText(find.byKey(const Key('project_name_input')), 'Web Lab Project');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('save_project_button')));
    await settleDb(tester);

    // 3. Open project workspace
    await tester.tap(find.text('Web Lab Project'));
    await settleDb(tester);

    // 4. Create "index.html" file
    await tester.tap(find.byKey(const Key('add_file_button')));
    await settleDb(tester);
    await tester.enterText(find.byKey(const Key('node_name_input')), 'index.html');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('save_node_button')));
    await settleDb(tester);

    // 5. Open index.html in Editor
    await tester.tap(find.text('index.html'));
    await settleDb(tester);

    expect(find.text('index.html'), findsOneWidget);
    expect(find.byKey(const Key('editor_text_field')), findsOneWidget);

    // 6. Type HTML source code
    const htmlSnippet = '<html>\n  <body>\n    Hello Nomad\n  </body>\n</html>';
    await tester.enterText(find.byKey(const Key('editor_text_field')), htmlSnippet);
    await tester.pump(const Duration(milliseconds: 50));

    // Notice dirty title "index.html *"
    expect(find.text('index.html *'), findsOneWidget);

    // 7. Save content
    await tester.tap(find.byKey(const Key('editor_save_button')));
    await settleDb(tester);

    // 8. Close editor and go back to projects
    await tester.tap(find.byKey(const Key('editor_close_button')));
    await settleDb(tester);
    await tester.tap(find.byKey(const Key('workspace_back_button')));
    await settleDb(tester);

    // 9. COLD RESTART NOMAD
    await tester.pumpWidget(NomadApp(
      key: UniqueKey(),
      repository: projectRepo,
      workspaceRepository: workspaceRepo,
      contentRepository: contentRepo,
    ));
    await settleDb(tester);

    // 10. Reopen Web Lab Project -> Reopen index.html
    await tester.tap(find.byKey(const Key('get_started_button')));
    await settleDb(tester);

    await tester.tap(find.text('Web Lab Project'));
    await settleDb(tester);

    await tester.tap(find.text('index.html'));
    await settleDb(tester);

    // 11. PROOF: File content survived app restart!
    expect(find.text(htmlSnippet), findsOneWidget);
  });
}
