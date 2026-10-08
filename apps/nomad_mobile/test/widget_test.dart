import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_mobile/app/nomad_app.dart';
import 'package:nomad_mobile/data/database/app_database.dart';
import 'package:nomad_mobile/data/repositories/local_project_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database db;
  late LocalProjectRepository repository;

  setUp(() async {
    final dbFactory = databaseFactoryFfi;
    db = await dbFactory.openDatabase(inMemoryDatabasePath);
    await AppDatabase.createSchema(db);
    repository = LocalProjectRepository(dbProvider: () async => db);
  });

  tearDown(() async {
    await db.close();
  });

  /// Yields across multiple isolate and frame turns to ensure chained async DB calls settle.
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

    await tester.pumpWidget(NomadApp(repository: repository));
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

    await tester.pumpWidget(NomadApp(repository: repository));
    await settleDb(tester);

    expect(find.text('Tablet View'), findsOneWidget);
    expect(find.text('Nomad — Mobile-First Development Lab'), findsOneWidget);
    expect(find.text('Lab'), findsOneWidget);
    expect(find.text('Projects'), findsOneWidget);
  });

  testWidgets('End-to-End: Create project -> Restart app -> Project persists', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // 1. Launch Nomad
    await tester.pumpWidget(NomadApp(repository: repository));
    await settleDb(tester);

    // 2. Tap "Get Started" to navigate to Projects view
    await tester.tap(find.byKey(const Key('get_started_button')));
    await settleDb(tester);
    expect(find.text('No projects yet'), findsOneWidget);

    // 3. Tap "+ New Project" FAB
    await tester.tap(find.byKey(const Key('add_project_fab')));
    await settleDb(tester);

    // 4. Enter Project Name
    await tester.enterText(find.byKey(const Key('project_name_input')), 'My Website');
    await tester.pump(const Duration(milliseconds: 50));

    // 5. Submit creation
    await tester.tap(find.byKey(const Key('save_project_button')));
    await settleDb(tester);

    // 6. Verify project appears in list
    expect(find.text('My Website'), findsOneWidget);
    expect(find.text('Type: Web'), findsOneWidget);

    // 7. SIMULATE COLD APP RESTART: fresh NomadApp with unique key on same persistent database
    await tester.pumpWidget(NomadApp(key: UniqueKey(), repository: repository));
    await settleDb(tester);

    // 8. Open Projects tab after fresh launch
    await tester.tap(find.byKey(const Key('get_started_button')));
    await settleDb(tester);

    // 9. PROOF: Previously created project survived the restart!
    expect(find.text('My Website'), findsOneWidget);
    expect(find.text('Type: Web'), findsOneWidget);
  });
}
