import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static const String _databaseName = 'nomad.db';
  static const int _databaseVersion = 2;

  // Projects table
  static const String tableProjects = 'projects';
  static const String columnId = 'id';
  static const String columnName = 'name';
  static const String columnType = 'type';
  static const String columnCreatedAt = 'created_at';
  static const String columnUpdatedAt = 'updated_at';

  // File nodes table
  static const String tableFileNodes = 'file_nodes';
  static const String columnProjectId = 'project_id';
  static const String columnParentId = 'parent_id';

  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: (db, version) async {
        await createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createFileNodesTable(db);
        }
      },
    );
  }

  static Future<void> createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE $tableProjects (
        $columnId TEXT PRIMARY KEY,
        $columnName TEXT NOT NULL,
        $columnType TEXT NOT NULL,
        $columnCreatedAt TEXT NOT NULL,
        $columnUpdatedAt TEXT NOT NULL
      )
    ''');
    await _createFileNodesTable(db);
  }

  static Future<void> _createFileNodesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableFileNodes (
        $columnId TEXT PRIMARY KEY,
        $columnProjectId TEXT NOT NULL,
        $columnParentId TEXT,
        $columnName TEXT NOT NULL,
        $columnType TEXT NOT NULL,
        $columnCreatedAt TEXT NOT NULL,
        $columnUpdatedAt TEXT NOT NULL
      )
    ''');
  }
}
