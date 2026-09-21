import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/dump.dart';

class LocalDbService {
  static final LocalDbService _instance = LocalDbService._internal();
  factory LocalDbService() => _instance;
  LocalDbService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'dusk_local.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE dumps(
            id TEXT PRIMARY KEY,
            user_id TEXT,
            type TEXT,
            content TEXT,
            transcript TEXT,
            media_url TEXT,
            category TEXT,
            captured_at TEXT,
            created_at TEXT,
            sync_status TEXT
          )
        ''');
      },
    );
  }

  Future<void> insertDump(Dump dump) async {
    final db = await database;
    await db.insert(
      'dumps',
      dump.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Dump>> getPendingDumps() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'dumps',
      where: 'sync_status = ?',
      whereArgs: [SyncStatus.pending.name],
    );
    return List.generate(maps.length, (i) => Dump.fromMap(maps[i]));
  }

  Future<void> updateDumpSyncStatus(String id, SyncStatus status) async {
    final db = await database;
    await db.update(
      'dumps',
      {'sync_status': status.name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
