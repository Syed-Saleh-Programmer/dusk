import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/dump.dart';
import '../models/task_item.dart';

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
      version: 6,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE dumps(
            id TEXT PRIMARY KEY,
            user_id TEXT,
            type TEXT,
            title TEXT,
            content TEXT,
            transcript TEXT,
            media_url TEXT,
            category TEXT,
            captured_at TEXT,
            created_at TEXT,
            sync_status TEXT,
            ai_summary TEXT
          )
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_dumps_user_id ON dumps(user_id)',
        );
        await _createTasksTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE dumps ADD COLUMN ai_summary TEXT');
        }
        if (oldVersion < 3) {
          try {
            await db.execute('ALTER TABLE dumps ADD COLUMN title TEXT');
          } catch (_) {}
        }
        if (oldVersion < 4) {
          try {
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_dumps_user_id ON dumps(user_id)',
            );
            await db.execute(
              "DELETE FROM dumps WHERE user_id IS NULL OR TRIM(user_id) = ''",
            );
          } catch (_) {}
        }
        if (oldVersion < 5) {
          try {
            await _createTasksTable(db);
          } catch (_) {}
        }
        if (oldVersion < 6) {
          try {
            await db.execute('ALTER TABLE tasks ADD COLUMN due_date TEXT');
          } catch (_) {}
        }
      },
    );
  }

  Future<void> _createTasksTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tasks(
        id TEXT PRIMARY KEY,
        user_id TEXT,
        dump_id TEXT,
        insight_card_id TEXT,
        title TEXT,
        source_type TEXT,
        source_label TEXT,
        status TEXT,
        due_date TEXT,
        created_at TEXT,
        completed_at TEXT,
        updated_at TEXT,
        sync_status TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tasks_user_id ON tasks(user_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tasks_dump_id ON tasks(dump_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tasks_insight_card_id ON tasks(insight_card_id)',
    );
  }

  Future<void> insertDump(Dump dump) async {
    if (dump.userId.trim().isEmpty) return;
    final db = await database;
    await db.insert(
      'dumps',
      dump.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Dump>> getPendingDumps({required String userId}) async {
    if (userId.trim().isEmpty) return [];
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'dumps',
      where: 'sync_status = ? AND user_id = ?',
      whereArgs: [SyncStatus.pending.name, userId],
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

  Future<List<Dump>> getAllDumps({required String userId}) async {
    if (userId.trim().isEmpty) return [];
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'dumps',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'captured_at DESC',
    );
    return List.generate(maps.length, (i) => Dump.fromMap(maps[i]));
  }

  Future<Dump?> getDumpById(String id, {String? userId}) async {
    final db = await database;
    final hasUser = userId != null && userId.trim().isNotEmpty;
    final List<Map<String, dynamic>> maps = await db.query(
      'dumps',
      where: hasUser ? 'id = ? AND user_id = ?' : 'id = ?',
      whereArgs: hasUser ? [id, userId] : [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Dump.fromMap(maps.first);
  }

  Future<void> updateDumpAiSummary(String id, String summary, {String? title}) async {
    final db = await database;
    final Map<String, dynamic> values = {'ai_summary': summary};
    if (title != null && title.isNotEmpty) {
      values['title'] = title;
      values['category'] = title;
    }
    await db.update(
      'dumps',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateDumpDetails(
    String id, {
    String? transcript,
    String? title,
    String? aiSummary,
    SyncStatus? syncStatus,
  }) async {
    final db = await database;
    final Map<String, dynamic> values = {};
    if (transcript != null) values['transcript'] = transcript;
    if (title != null && title.isNotEmpty) {
      values['title'] = title;
      values['category'] = title;
    }
    if (aiSummary != null && aiSummary.isNotEmpty) {
      values['ai_summary'] = aiSummary;
    }
    if (syncStatus != null) {
      values['sync_status'] = syncStatus.name;
    }
    if (values.isNotEmpty) {
      await db.update(
        'dumps',
        values,
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> upsertMergedDump(Map<String, dynamic> map) async {
    final userId = map['user_id']?.toString().trim() ?? '';
    final id = map['id']?.toString();
    if (id == null || id.isEmpty || userId.isEmpty) return;

    final db = await database;
    final row = <String, dynamic>{
      'id': id,
      'user_id': userId,
      'type': map['type']?.toString() ?? 'text',
      'title': map['title'] ?? map['category'],
      'content': map['content'],
      'transcript': map['transcript'],
      'media_url': map['media_url'],
      'category': map['category'] ?? map['title'],
      'captured_at': map['captured_at']?.toString() ?? DateTime.now().toIso8601String(),
      'created_at': map['created_at']?.toString() ??
          map['captured_at']?.toString() ??
          DateTime.now().toIso8601String(),
      'sync_status': map['sync_status']?.toString() ?? SyncStatus.synced.name,
      'ai_summary': map['ai_summary'],
    };
    await db.insert(
      'dumps',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateDumpTitle(String id, String title) async {
    final db = await database;
    await db.update(
      'dumps',
      {'title': title, 'category': title},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteDump(String id, {String? userId}) async {
    final db = await database;
    final hasUser = userId != null && userId.trim().isNotEmpty;
    await db.delete(
      'dumps',
      where: hasUser ? 'id = ? AND user_id = ?' : 'id = ?',
      whereArgs: hasUser ? [id, userId] : [id],
    );
    await deleteTasksByDumpId(id, userId: userId);
  }

  // ===========================================================================
  // Tasks CRUD & Offline-First Sync Methods
  // ===========================================================================

  Future<void> insertTask(TaskItem task) async {
    if (task.userId.trim().isEmpty || task.title.trim().isEmpty) return;
    final db = await database;
    await db.insert(
      'tasks',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertTasksBatch(List<TaskItem> tasks) async {
    if (tasks.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final task in tasks) {
      if (task.userId.trim().isEmpty || task.title.trim().isEmpty) continue;
      batch.insert(
        'tasks',
        task.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<TaskItem>> getAllTasks({required String userId}) async {
    if (userId.trim().isEmpty) return [];
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tasks',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => TaskItem.fromMap(maps[i]));
  }

  Future<List<TaskItem>> getTasksForDump(String dumpId, {String? userId}) async {
    if (dumpId.trim().isEmpty) return [];
    final db = await database;
    final hasUser = userId != null && userId.trim().isNotEmpty;
    final List<Map<String, dynamic>> maps = await db.query(
      'tasks',
      where: hasUser ? 'dump_id = ? AND user_id = ?' : 'dump_id = ?',
      whereArgs: hasUser ? [dumpId, userId] : [dumpId],
      orderBy: 'created_at ASC',
    );
    return List.generate(maps.length, (i) => TaskItem.fromMap(maps[i]));
  }

  Future<List<TaskItem>> getPendingSyncTasks({required String userId}) async {
    if (userId.trim().isEmpty) return [];
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tasks',
      where: 'sync_status = ? AND user_id = ?',
      whereArgs: [SyncStatus.pending.name, userId],
    );
    return List.generate(maps.length, (i) => TaskItem.fromMap(maps[i]));
  }

  Future<void> updateTaskStatus(
    String id,
    TaskStatus status, {
    DateTime? completedAt,
    bool clearCompletedAt = false,
    SyncStatus syncStatus = SyncStatus.pending,
  }) async {
    final db = await database;
    final nowIso = DateTime.now().toIso8601String();
    final Map<String, dynamic> values = {
      'status': status.name,
      'updated_at': nowIso,
      'sync_status': syncStatus.name,
    };
    if (clearCompletedAt) {
      values['completed_at'] = null;
    } else if (completedAt != null) {
      values['completed_at'] = completedAt.toIso8601String();
    }
    await db.update(
      'tasks',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateTaskDetails(
    String id, {
    String? title,
    DateTime? dueDate,
    bool clearDueDate = false,
    SyncStatus syncStatus = SyncStatus.pending,
  }) async {
    final db = await database;
    final nowIso = DateTime.now().toIso8601String();
    final Map<String, dynamic> values = {
      'updated_at': nowIso,
      'sync_status': syncStatus.name,
    };
    if (title != null && title.trim().isNotEmpty) {
      values['title'] = title.trim();
    }
    if (clearDueDate) {
      values['due_date'] = null;
    } else if (dueDate != null) {
      values['due_date'] = dueDate.toIso8601String();
    }
    await db.update(
      'tasks',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateTaskSyncStatus(String id, SyncStatus status) async {
    final db = await database;
    await db.update(
      'tasks',
      {'sync_status': status.name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateTaskSourceLabelForDump(String dumpId, String sourceLabel) async {
    if (dumpId.isEmpty || sourceLabel.trim().isEmpty) return;
    final db = await database;
    await db.update(
      'tasks',
      {'source_label': sourceLabel.trim()},
      where: 'dump_id = ?',
      whereArgs: [dumpId],
    );
  }

  Future<void> deleteTask(String id, {String? userId}) async {
    final db = await database;
    final hasUser = userId != null && userId.trim().isNotEmpty;
    await db.delete(
      'tasks',
      where: hasUser ? 'id = ? AND user_id = ?' : 'id = ?',
      whereArgs: hasUser ? [id, userId] : [id],
    );
  }

  Future<void> deleteTasksByDumpId(String dumpId, {String? userId}) async {
    final db = await database;
    final hasUser = userId != null && userId.trim().isNotEmpty;
    await db.delete(
      'tasks',
      where: hasUser ? 'dump_id = ? AND user_id = ?' : 'dump_id = ?',
      whereArgs: hasUser ? [dumpId, userId] : [dumpId],
    );
  }
}
