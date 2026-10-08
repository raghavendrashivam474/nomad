import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_mobile/app/nomad_app.dart';
import 'package:nomad_mobile/data/database/app_database.dart';
import 'package:nomad_mobile/data/repositories/local_project_repository.dart';
import 'package:nomad_mobile/data/repositories/local_workspace_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database db;
  late LocalProjectRepository projectRepo;
  late LocalWorkspaceRepository workspaceRepo;

  setUp(() async {
    final dbFactory = databaseFactoryFfi;
    db = await dbFactory.openDatabase(inMemoryDatabasePath);
    await AppDatabase.createSchema(db);
    projectRepo = LocalProjectRepository(dbProvider: () async => db);
    workspaceRepo = LocalWorkspaceRepository(dbProvider: () async => db);
  });

  tearDown(() async {
    await db.close();
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

    await tester.pumpWidget(NomadApp(repository: projectRepo, workspaceRepository: workspaceRepo));
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

    await tester.pumpWidget(NomadApp(repository: projectRepo, workspaceRepository: workspaceRepo));
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

    await tester.pumpWidget(NomadApp(repository: projectRepo, workspaceRepository: workspaceRepo));
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
    await tester.pumpWidget(NomadApp(key: UniqueKey(), repository: projectRepo, workspaceRepository: workspaceRepo));
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

    // 1. Launch & navigate to Projects
    await tester.pumpWidget(NomadApp(repository: projectRepo, workspaceRepository: workspaceRepo));
    await settleDb(tester);
    await tester.tap(find.byKey(const Key('get_started_button')));
    await settleDb(tester);

    // 2. Create "Portfolio" project
    await tester.tap(find.byKey(const Key('add_project_fab')));
    await settleDb(tester);
    await tester.enterText(find.byKey(const Key('project_name_input')), 'Portfolio');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('save_project_button')));
    await settleDb(tester);

    // 3. Open the "Portfolio" project workspace
    await tester.tap(find.text('Portfolio'));
    await settleDb(tester);

    expect(find.text('Portfolio'), findsOneWidget);
    expect(find.text('Workspace Root'), findsOneWidget);
    expect(find.text('Workspace is empty'), findsOneWidget);

    // 4. Create "assets" folder
    await tester.tap(find.byKey(const Key('add_folder_button')));
    await settleDb(tester);
    await tester.enterText(find.byKey(const Key('node_name_input')), 'assets');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('save_node_button')));
    await settleDb(tester);

    // 5. Create "index.html" file
    await tester.tap(find.byKey(const Key('add_file_button')));
    await settleDb(tester);
    await tester.enterText(find.byKey(const Key('node_name_input')), 'index.html');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('save_node_button')));
    await settleDb(tester);

    expect(find.text('assets'), findsOneWidget);
    expect(find.text('index.html'), findsOneWidget);

    // 6. Drill down into "assets" folder
    await tester.tap(find.text('assets'));
    await settleDb(tester);

    expect(find.text('/ assets'), findsOneWidget);
    expect(find.text('.. (Go up)'), findsOneWidget);

    // 7. Create "logo.svg" inside "assets"
    await tester.tap(find.byKey(const Key('add_file_button')));
    await settleDb(tester);
    await tester.enterText(find.byKey(const Key('node_name_input')), 'logo.svg');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('save_node_button')));
    await settleDb(tester);
    expect(find.text('logo.svg'), findsOneWidget);

    // 8. Navigate back up to root
    await tester.tap(find.byKey(const Key('navigate_up_tile')));
    await settleDb(tester);
    expect(find.text('Workspace Root'), findsOneWidget);

    // 9. Go back to projects list
    await tester.tap(find.byKey(const Key('workspace_back_button')));
    await settleDb(tester);
    expect(find.text('Portfolio'), findsOneWidget);

    // 10. RESTART APP & VERIFY PERSISTENCE
    await tester.pumpWidget(NomadApp(key: UniqueKey(), repository: projectRepo, workspaceRepository: workspaceRepo));
    await settleDb(tester);
    await tester.tap(find.byKey(const Key('get_started_button')));
    await settleDb(tester);

    await tester.tap(find.text('Portfolio'));
    await settleDb(tester);

    // Root nodes persisted
    expect(find.text('assets'), findsOneWidget);
    expect(find.text('index.html'), findsOneWidget);

    // Child nodes persisted
    await tester.tap(find.text('assets'));
    await settleDb(tester);
    expect(find.text('logo.svg'), findsOneWidget);
  });
}
