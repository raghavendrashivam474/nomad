import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_mobile/app/nomad_app.dart';
import 'package:nomad_mobile/branding/nomad_brand.dart';
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
    contentRepo =
        LocalFileContentRepository(baseDirProvider: () async => tempFilesDir);
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

  testWidgets('App renders Phone layout on narrow screens (390x844)',
      (WidgetTester tester) async {
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

  testWidgets('App renders Tablet layout on wide screens (1024x768)',
      (WidgetTester tester) async {
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
    expect(find.text('${NomadBrand.productName} — ${NomadBrand.tagline}'),
        findsOneWidget);
    expect(find.text('Lab'), findsOneWidget);
    expect(find.text('Projects'), findsOneWidget);
  });

  testWidgets(
      'End-to-End S0.0.3: Create project -> Restart app -> Project persists',
      (WidgetTester tester) async {
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

    await tester.enterText(
        find.byKey(const Key('project_name_input')), 'My Website');
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byKey(const Key('save_project_button')));
    await tester.pumpAndSettle();
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

  testWidgets(
      'End-to-End S0.0.4: Open Project -> Workspace File & Folder lifecycle -> Persist across restart',
      (WidgetTester tester) async {
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
    await tester.enterText(
        find.byKey(const Key('project_name_input')), 'Portfolio');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('save_project_button')));
    await tester.pumpAndSettle();
    await settleDb(tester);

    // Open "Portfolio"
    await tester.tap(find.text('Portfolio'));
    await settleDb(tester);

    // Create custom folder & custom file
    await tester.tap(find.byKey(const Key('add_folder_button')));
    await settleDb(tester);
    await tester.enterText(find.byKey(const Key('node_name_input')), 'assets');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('save_node_button')));
    await settleDb(tester);

    await tester.tap(find.byKey(const Key('add_file_button')));
    await settleDb(tester);
    await tester.enterText(
        find.byKey(const Key('node_name_input')), 'about.html');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('save_node_button')));
    await settleDb(tester);

    expect(find.text('assets'), findsOneWidget);
    expect(find.text('about.html'), findsOneWidget);

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
    expect(find.text('about.html'), findsOneWidget);
  });

  testWidgets(
      'End-to-End S0.0.5: Phone flow - Open File -> Edit Code -> Save -> Restart App -> Code Persists',
      (WidgetTester tester) async {
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

    // 2. Create "Web Lab Project" (starter files index.html, style.css, script.js auto-created)
    await tester.tap(find.byKey(const Key('add_project_fab')));
    await settleDb(tester);
    await tester.enterText(
        find.byKey(const Key('project_name_input')), 'Web Lab Project');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('save_project_button')));
    await tester.pumpAndSettle();
    await settleDb(tester);

    // 3. Open project workspace
    await tester.tap(find.text('Web Lab Project'));
    await settleDb(tester);

    // 4. Open auto-generated index.html in Editor
    await tester.tap(find.text('index.html'));
    await settleDb(tester);

    expect(find.text('index.html'), findsOneWidget);
    expect(find.byKey(const Key('editor_text_field')), findsOneWidget);

    // 5. Type HTML source code
    const htmlSnippet = '<html>\n  <body>\n    Hello Nomad\n  </body>\n</html>';
    await tester.enterText(
        find.byKey(const Key('editor_text_field')), htmlSnippet);
    await tester.pump(const Duration(milliseconds: 50));

    // Notice dirty title "index.html *"
    expect(find.text('index.html *'), findsOneWidget);

    // 6. Save content
    await tester.tap(find.byKey(const Key('editor_save_button')));
    await settleDb(tester);

    // 7. Close editor and go back to projects
    await tester.tap(find.byKey(const Key('editor_close_button')));
    await settleDb(tester);
    await tester.tap(find.byKey(const Key('workspace_back_button')));
    await settleDb(tester);

    // 8. COLD RESTART NOMAD
    await tester.pumpWidget(NomadApp(
      key: UniqueKey(),
      repository: projectRepo,
      workspaceRepository: workspaceRepo,
      contentRepository: contentRepo,
    ));
    await settleDb(tester);

    // 9. Reopen Web Lab Project -> Reopen index.html
    await tester.tap(find.byKey(const Key('get_started_button')));
    await settleDb(tester);

    await tester.tap(find.text('Web Lab Project'));
    await settleDb(tester);

    await tester.tap(find.text('index.html'));
    await settleDb(tester);

    // 10. PROOF: File content survived app restart!
    expect(find.text(htmlSnippet), findsOneWidget);
  });

  testWidgets(
      'End-to-End S0.0.6: Tablet flow - Split-Pane Workspace with Multi-File Tabs & Editing',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // 1. Launch in Tablet View
    await tester.pumpWidget(NomadApp(
      repository: projectRepo,
      workspaceRepository: workspaceRepo,
      contentRepository: contentRepo,
    ));
    await settleDb(tester);

    // 2. Open Projects via Rail
    await tester.tap(find.text('Projects'));
    await settleDb(tester);

    // 3. Create Project "Tablet IDE" (starter files auto-created)
    await tester.tap(find.byKey(const Key('add_project_fab')));
    await settleDb(tester);
    await tester.enterText(
        find.byKey(const Key('project_name_input')), 'Tablet IDE');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('save_project_button')));
    await tester.pumpAndSettle();
    await settleDb(tester);

    // 4. Open "Tablet IDE" workspace
    await tester.tap(find.text('Tablet IDE'));
    await settleDb(tester);

    // Verify split layout: placeholder on the right side
    expect(
        find.text('Select a file from the workspace to edit'), findsOneWidget);

    // 5. Open "index.html" -> Tab appears & Editor opens
    await tester.tap(find.byKey(const Key('node_index.html')));
    await settleDb(tester);
    expect(find.byKey(const Key('tab_index.html')), findsOneWidget);

    // Edit index.html
    await tester.enterText(
        find.byKey(const Key('editor_text_field')), '<h1>Nomad V0.0</h1>');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('editor_save_button')));
    await settleDb(tester);

    // 6. Open "style.css" -> Second tab appears & active editor switches
    await tester.tap(find.byKey(const Key('node_style.css')));
    await settleDb(tester);
    expect(find.byKey(const Key('tab_index.html')), findsOneWidget);
    expect(find.byKey(const Key('tab_style.css')), findsOneWidget);

    // Edit style.css
    await tester.enterText(find.byKey(const Key('editor_text_field')),
        'body { background: #000; }');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('editor_save_button')));
    await settleDb(tester);

    // 7. Switch back to "index.html" tab -> verify content
    await tester.tap(find.byKey(const Key('tab_index.html')));
    await settleDb(tester);
    expect(find.text('<h1>Nomad V0.0</h1>'), findsOneWidget);

    // 8. Close "index.html" tab -> active editor switches to style.css
    await tester.tap(find.byKey(const Key('close_tab_index.html')));
    await settleDb(tester);
    expect(find.byKey(const Key('tab_index.html')), findsNothing);
    expect(find.text('body { background: #000; }'), findsOneWidget);
  });
}
