import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/dump.dart';
import '../models/task_item.dart';
import '../models/project.dart';

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
      version: 11,
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
            tags TEXT,
            project_id TEXT,
            captured_at TEXT,
            created_at TEXT,
            sync_status TEXT,
            ai_summary TEXT
          )
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_dumps_user_id ON dumps(user_id)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_dumps_project_id ON dumps(project_id)',
        );
        await _createTasksTable(db);
        await _createProjectsTable(db);
        await _createInsightCardsTable(db);
        await _createReflectionCyclesTable(db);
        await _createDeletedTasksTable(db);
        await _createDumpTaskExtractionStatusTable(db);
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
        if (oldVersion < 7) {
          try {
            await db.execute('ALTER TABLE dumps ADD COLUMN tags TEXT');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE tasks ADD COLUMN tags TEXT');
          } catch (_) {}
        }
        if (oldVersion < 8) {
          try {
            await _createProjectsTable(db);
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE dumps ADD COLUMN project_id TEXT');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE tasks ADD COLUMN project_id TEXT');
          } catch (_) {}
          try {
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_dumps_project_id ON dumps(project_id)',
            );
          } catch (_) {}
          try {
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_tasks_project_id ON tasks(project_id)',
            );
          } catch (_) {}
        }
        if (oldVersion < 9) {
          try {
            await _createInsightCardsTable(db);
          } catch (_) {}
          try {
            await _createReflectionCyclesTable(db);
          } catch (_) {}
        }
        if (oldVersion < 10) {
          try {
            await _createDeletedTasksTable(db);
          } catch (_) {}
          try {
            await _createDumpTaskExtractionStatusTable(db);
          } catch (_) {}
        }
        if (oldVersion < 11) {
          try {
            await db.execute('ALTER TABLE insight_cards_local ADD COLUMN week_overview TEXT');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE insight_cards_local ADD COLUMN progress_and_wins TEXT');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE insight_cards_local ADD COLUMN motivation TEXT');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE insight_cards_local ADD COLUMN next_actions TEXT');
          } catch (_) {}
        }
      },
    );
  }

  Future<void> _createInsightCardsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS insight_cards_local(
        id TEXT PRIMARY KEY,
        session_id TEXT,
        user_id TEXT,
        title TEXT,
        main_insight TEXT,
        standout TEXT,
        suggestion TEXT,
        week_overview TEXT,
        progress_and_wins TEXT,
        motivation TEXT,
        next_actions TEXT,
        is_bookmarked INTEGER DEFAULT 0,
        created_at TEXT,
        sync_status TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_insight_cards_user_id ON insight_cards_local(user_id)',
    );
  }

  Future<void> _createReflectionCyclesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reflection_cycles_local(
        id TEXT PRIMARY KEY,
        user_id TEXT,
        period_start TEXT,
        period_end TEXT,
        status TEXT,
        summary TEXT,
        started_at TEXT,
        completed_at TEXT,
        created_at TEXT,
        sync_status TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reflection_cycles_user_id ON reflection_cycles_local(user_id)',
    );
  }

  Future<void> _createProjectsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS projects(
        id TEXT PRIMARY KEY,
        user_id TEXT,
        name TEXT NOT NULL,
        description TEXT,
        icon TEXT,
        color_value INTEGER,
        is_archived INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT,
        sync_status TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_projects_user_id ON projects(user_id)',
    );
  }

  Future<void> _createTasksTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tasks(
        id TEXT PRIMARY KEY,
        user_id TEXT,
        dump_id TEXT,
        insight_card_id TEXT,
        project_id TEXT,
        title TEXT,
        source_type TEXT,
        source_label TEXT,
        tags TEXT,
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
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tasks_project_id ON tasks(project_id)',
    );
  }

  Future<void> _createDeletedTasksTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS deleted_tasks(
        id TEXT PRIMARY KEY,
        user_id TEXT,
        dump_id TEXT,
        insight_card_id TEXT,
        title TEXT,
        deleted_at TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_deleted_tasks_user_id ON deleted_tasks(user_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_deleted_tasks_dump_id ON deleted_tasks(dump_id)',
    );
  }

  Future<void> _createDumpTaskExtractionStatusTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS dump_task_extraction_status(
        dump_id TEXT PRIMARY KEY,
        user_id TEXT,
        extracted_at TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_dump_task_extract_user_id ON dump_task_extraction_status(user_id)',
    );
  }

  Future<void> insertDump(Dump dump) async {
    final effectiveUserId = dump.userId.trim().isEmpty ? 'local_user' : dump.userId;
    final db = await database;
    final map = dump.toSqliteMap();
    map['user_id'] = effectiveUserId;
    await db.insert(
      'dumps',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Dump>> getPendingDumps({required String userId}) async {
    final effectiveUserId = userId.trim().isEmpty ? 'local_user' : userId;
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'dumps',
      where: 'sync_status = ? AND user_id = ?',
      whereArgs: [SyncStatus.pending.name, effectiveUserId],
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
    final effectiveUserId = userId.trim().isEmpty ? 'local_user' : userId;
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'dumps',
      where: 'user_id = ?',
      whereArgs: [effectiveUserId],
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

  Future<void> updateDumpAiSummary(
    String id,
    String summary, {
    String? title,
    List<String>? tags,
  }) async {
    final db = await database;
    final Map<String, dynamic> values = {'ai_summary': summary};
    if (title != null && title.isNotEmpty) {
      values['title'] = title;
      values['category'] = title;
    }
    if (tags != null) {
      values['tags'] = jsonEncode(Dump.parseTags(tags));
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
    List<String>? tags,
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
    if (tags != null) {
      values['tags'] = jsonEncode(Dump.parseTags(tags));
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

  Future<void> updateDumpTags(String id, List<String> tags) async {
    final db = await database;
    await db.update(
      'dumps',
      {'tags': jsonEncode(Dump.parseTags(tags))},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateDumpProject(String id, String? projectId) async {
    final db = await database;
    await db.update(
      'dumps',
      {'project_id': projectId},
      where: 'id = ?',
      whereArgs: [id],
    );
    await updateTasksProjectForDump(id, projectId);
  }

  Future<void> updateTasksProjectForDump(String dumpId, String? projectId) async {
    if (dumpId.isEmpty) return;
    final db = await database;
    await db.update(
      'tasks',
      {'project_id': projectId},
      where: 'dump_id = ?',
      whereArgs: [dumpId],
    );
  }

  Future<void> updateTaskProject(String taskId, String? projectId) async {
    final db = await database;
    await db.update(
      'tasks',
      {'project_id': projectId},
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  // ==========================================
  // Project CRUD Operations
  // ==========================================

  Future<void> insertProject(Project project) async {
    if (project.userId.trim().isEmpty) return;
    final db = await database;
    await db.insert(
      'projects',
      project.toSqliteMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Project>> getAllProjects({required String userId}) async {
    if (userId.trim().isEmpty) return [];
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'projects',
      where: 'user_id = ? AND is_archived = 0',
      whereArgs: [userId],
      orderBy: 'created_at ASC',
    );
    return List.generate(maps.length, (i) => Project.fromMap(maps[i]));
  }

  Future<Project?> getProjectById(String id, {String? userId}) async {
    final db = await database;
    final hasUser = userId != null && userId.trim().isNotEmpty;
    final List<Map<String, dynamic>> maps = await db.query(
      'projects',
      where: hasUser ? 'id = ? AND user_id = ?' : 'id = ?',
      whereArgs: hasUser ? [id, userId] : [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Project.fromMap(maps.first);
  }

  Future<void> updateProject(Project project) async {
    final db = await database;
    await db.update(
      'projects',
      project.toSqliteMap(),
      where: 'id = ?',
      whereArgs: [project.id],
    );
  }

  Future<void> deleteProject(String id, {String? userId}) async {
    final db = await database;
    final hasUser = userId != null && userId.trim().isNotEmpty;
    // 1. Unassign all dumps and tasks from this project instead of deleting user content
    await db.update(
      'dumps',
      {'project_id': null},
      where: hasUser ? 'project_id = ? AND user_id = ?' : 'project_id = ?',
      whereArgs: hasUser ? [id, userId] : [id],
    );
    await db.update(
      'tasks',
      {'project_id': null},
      where: hasUser ? 'project_id = ? AND user_id = ?' : 'project_id = ?',
      whereArgs: hasUser ? [id, userId] : [id],
    );
    // 2. Delete the project row
    await db.delete(
      'projects',
      where: hasUser ? 'id = ? AND user_id = ?' : 'id = ?',
      whereArgs: hasUser ? [id, userId] : [id],
    );
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
      'project_id': map['project_id']?.toString(),
      'tags': jsonEncode(Dump.parseTags(map['tags'])),
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

  Future<void> deleteDumpsBatch(List<String> ids, {String? userId}) async {
    if (ids.isEmpty) return;
    final db = await database;
    final hasUser = userId != null && userId.trim().isNotEmpty;
    final placeholders = List.filled(ids.length, '?').join(',');
    final where = hasUser
        ? 'id IN ($placeholders) AND user_id = ?'
        : 'id IN ($placeholders)';
    final whereArgs = hasUser ? [...ids, userId] : ids;

    // First delete associated tasks for all these dumps (which records them as deleted)
    for (final dumpId in ids) {
      await deleteTasksByDumpId(dumpId, userId: userId);
    }

    // Delete dumps
    await db.delete('dumps', where: where, whereArgs: whereArgs);
  }

  // ===========================================================================
  // Tasks CRUD & Offline-First Sync Methods
  // ===========================================================================

  Future<void> insertTask(TaskItem task) async {
    if (task.userId.trim().isEmpty || task.title.trim().isEmpty) return;
    final db = await database;
    await db.insert(
      'tasks',
      task.toSqliteMap(),
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
        task.toSqliteMap(),
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
    List<String>? tags,
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
    if (tags != null) {
      values['tags'] = jsonEncode(Dump.parseTags(tags));
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

  Future<void> recordDeletedTasks(List<TaskItem> tasks, {String? userId}) async {
    if (tasks.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    for (final task in tasks) {
      final uId = userId ?? task.userId;
      batch.insert(
        'deleted_tasks',
        {
          'id': task.id,
          'user_id': uId,
          'dump_id': task.dumpId,
          'insight_card_id': task.insightCardId,
          'title': task.title.toLowerCase().trim(),
          'deleted_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (task.dumpId != null && task.dumpId!.isNotEmpty) {
        batch.insert(
          'dump_task_extraction_status',
          {
            'dump_id': task.dumpId!,
            'user_id': uId,
            'extracted_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
    await batch.commit(noResult: true);
  }

  Future<Set<String>> getDeletedTaskIds({String? userId}) async {
    final db = await database;
    final hasUser = userId != null && userId.trim().isNotEmpty;
    final res = await db.query(
      'deleted_tasks',
      columns: ['id'],
      where: hasUser ? 'user_id = ?' : null,
      whereArgs: hasUser ? [userId] : null,
    );
    return res.map((r) => r['id'].toString()).toSet();
  }

  Future<Set<String>> getDeletedTaskTitles({String? userId, String? dumpId}) async {
    final db = await database;
    final hasUser = userId != null && userId.trim().isNotEmpty;
    final hasDump = dumpId != null && dumpId.trim().isNotEmpty;
    String? where;
    List<dynamic>? whereArgs;
    if (hasUser && hasDump) {
      where = 'user_id = ? AND dump_id = ?';
      whereArgs = [userId, dumpId];
    } else if (hasUser) {
      where = 'user_id = ?';
      whereArgs = [userId];
    } else if (hasDump) {
      where = 'dump_id = ?';
      whereArgs = [dumpId];
    }
    final res = await db.query(
      'deleted_tasks',
      columns: ['title'],
      where: where,
      whereArgs: whereArgs,
    );
    return res
        .map((r) => (r['title']?.toString() ?? '').toLowerCase().trim())
        .where((t) => t.isNotEmpty)
        .toSet();
  }

  Future<Set<String>> getDeletedInsightCardIds({String? userId}) async {
    final db = await database;
    final hasUser = userId != null && userId.trim().isNotEmpty;
    final res = await db.query(
      'deleted_tasks',
      columns: ['insight_card_id'],
      where: hasUser
          ? 'user_id = ? AND insight_card_id IS NOT NULL'
          : 'insight_card_id IS NOT NULL',
      whereArgs: hasUser ? [userId] : null,
    );
    return res
        .map((r) => r['insight_card_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<void> markDumpsTasksExtracted(List<String> dumpIds, {String? userId}) async {
    if (dumpIds.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    for (final dumpId in dumpIds) {
      if (dumpId.trim().isEmpty) continue;
      batch.insert(
        'dump_task_extraction_status',
        {
          'dump_id': dumpId.trim(),
          'user_id': userId,
          'extracted_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<Set<String>> getExtractedDumpIds({String? userId}) async {
    final db = await database;
    final hasUser = userId != null && userId.trim().isNotEmpty;
    final extractedRes = await db.query(
      'dump_task_extraction_status',
      columns: ['dump_id'],
      where: hasUser ? 'user_id = ?' : null,
      whereArgs: hasUser ? [userId] : null,
    );
    final results = extractedRes.map((r) => r['dump_id'].toString()).toSet();

    // Also include any dump_id present in existing tasks or deleted_tasks
    final tasksDumpRes = await db.query(
      'tasks',
      columns: ['dump_id'],
      where: hasUser ? 'user_id = ? AND dump_id IS NOT NULL' : 'dump_id IS NOT NULL',
      whereArgs: hasUser ? [userId] : null,
    );
    for (final r in tasksDumpRes) {
      final id = r['dump_id']?.toString();
      if (id != null && id.isNotEmpty) results.add(id);
    }

    final deletedDumpRes = await db.query(
      'deleted_tasks',
      columns: ['dump_id'],
      where: hasUser ? 'user_id = ? AND dump_id IS NOT NULL' : 'dump_id IS NOT NULL',
      whereArgs: hasUser ? [userId] : null,
    );
    for (final r in deletedDumpRes) {
      final id = r['dump_id']?.toString();
      if (id != null && id.isNotEmpty) results.add(id);
    }

    return results;
  }

  Future<void> deleteTask(String id, {String? userId}) async {
    final db = await database;
    final hasUser = userId != null && userId.trim().isNotEmpty;
    final existing = await db.query(
      'tasks',
      where: hasUser ? 'id = ? AND user_id = ?' : 'id = ?',
      whereArgs: hasUser ? [id, userId] : [id],
    );
    if (existing.isNotEmpty) {
      final item = TaskItem.fromMap(existing.first);
      await recordDeletedTasks([item], userId: userId);
    }
    await db.delete(
      'tasks',
      where: hasUser ? 'id = ? AND user_id = ?' : 'id = ?',
      whereArgs: hasUser ? [id, userId] : [id],
    );
  }

  Future<void> deleteTasksBatch(List<String> ids, {String? userId}) async {
    if (ids.isEmpty) return;
    final db = await database;
    final hasUser = userId != null && userId.trim().isNotEmpty;

    final placeholders = List.filled(ids.length, '?').join(',');
    final where = hasUser
        ? 'id IN ($placeholders) AND user_id = ?'
        : 'id IN ($placeholders)';
    final whereArgs = hasUser ? [...ids, userId] : ids;

    final existing = await db.query('tasks', where: where, whereArgs: whereArgs);
    if (existing.isNotEmpty) {
      final items = existing.map(TaskItem.fromMap).toList();
      await recordDeletedTasks(items, userId: userId);
    }

    await db.delete('tasks', where: where, whereArgs: whereArgs);
  }

  Future<void> deleteTasksByDumpId(String dumpId, {String? userId}) async {
    final db = await database;
    final hasUser = userId != null && userId.trim().isNotEmpty;
    final existing = await db.query(
      'tasks',
      where: hasUser ? 'dump_id = ? AND user_id = ?' : 'dump_id = ?',
      whereArgs: hasUser ? [dumpId, userId] : [dumpId],
    );
    if (existing.isNotEmpty) {
      final items = existing.map(TaskItem.fromMap).toList();
      await recordDeletedTasks(items, userId: userId);
    }
    await db.delete(
      'tasks',
      where: hasUser ? 'dump_id = ? AND user_id = ?' : 'dump_id = ?',
      whereArgs: hasUser ? [dumpId, userId] : [dumpId],
    );
  }

  // ===========================================================================
  // Local Insight Cards & Reflection Cycles (100% Offline Free Tier Support)
  // ===========================================================================

  Future<void> insertLocalInsightCard(Map<String, dynamic> card) async {
    final db = await database;
    final cardId = card['id']?.toString() ?? 'card_${DateTime.now().millisecondsSinceEpoch}';
    final effectiveUserId = (card['user_id']?.toString().trim().isNotEmpty == true)
        ? card['user_id'].toString().trim()
        : 'local_user';

    final row = <String, dynamic>{
      'id': cardId,
      'session_id': card['session_id']?.toString() ?? '',
      'user_id': effectiveUserId,
      'title': card['title']?.toString() ?? 'Daily Reflection',
      'main_insight': card['main_insight']?.toString() ?? '',
      'standout': card['standout']?.toString() ?? '',
      'suggestion': card['suggestion']?.toString() ?? '',
      'is_bookmarked': (card['is_bookmarked'] == true || card['is_bookmarked'] == 1) ? 1 : 0,
      'created_at': card['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      'sync_status': card['sync_status']?.toString() ?? SyncStatus.pending.name,
    };

    await db.insert('insight_cards_local', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getLocalInsightCards({String? userId}) async {
    final db = await database;
    final effectiveUserId = (userId != null && userId.trim().isNotEmpty) ? userId.trim() : 'local_user';
    final List<Map<String, dynamic>> maps = await db.query(
      'insight_cards_local',
      where: 'user_id = ?',
      whereArgs: [effectiveUserId],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => {
      ...m,
      'is_bookmarked': m['is_bookmarked'] == 1,
    }).toList();
  }

  Future<void> toggleBookmarkLocalInsightCard(String cardId, bool isBookmarked) async {
    final db = await database;
    await db.update(
      'insight_cards_local',
      {'is_bookmarked': isBookmarked ? 1 : 0},
      where: 'id = ?',
      whereArgs: [cardId],
    );
  }

  Future<void> insertLocalReflectionCycle(Map<String, dynamic> cycle) async {
    final db = await database;
    final cycleId = cycle['id']?.toString() ?? 'cycle_${DateTime.now().millisecondsSinceEpoch}';
    final effectiveUserId = (cycle['user_id']?.toString().trim().isNotEmpty == true)
        ? cycle['user_id'].toString().trim()
        : 'local_user';

    final row = <String, dynamic>{
      'id': cycleId,
      'user_id': effectiveUserId,
      'period_start': cycle['period_start']?.toString() ?? DateTime.now().toIso8601String(),
      'period_end': cycle['period_end']?.toString() ?? DateTime.now().toIso8601String(),
      'status': cycle['status']?.toString() ?? 'completed',
      'summary': cycle['summary']?.toString(),
      'started_at': cycle['started_at']?.toString(),
      'completed_at': cycle['completed_at']?.toString() ?? DateTime.now().toIso8601String(),
      'created_at': cycle['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      'sync_status': cycle['sync_status']?.toString() ?? SyncStatus.pending.name,
    };

    await db.insert('reflection_cycles_local', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getLocalReflectionCycles({String? userId}) async {
    final db = await database;
    final effectiveUserId = (userId != null && userId.trim().isNotEmpty) ? userId.trim() : 'local_user';
    return await db.query(
      'reflection_cycles_local',
      where: 'user_id = ?',
      whereArgs: [effectiveUserId],
      orderBy: 'created_at DESC',
    );
  }

  /// Migrates all guest 'local_user' data (dumps, tasks, projects, cards)
  /// to an authenticated user when they sign in to activate Cloud Sync.
  Future<void> migrateLocalDataToUser(String targetUserId) async {
    if (targetUserId.trim().isEmpty || targetUserId == 'local_user') return;
    final db = await database;
    await db.update(
      'dumps',
      {'user_id': targetUserId, 'sync_status': SyncStatus.pending.name},
      where: "user_id = 'local_user' OR user_id IS NULL OR TRIM(user_id) = ''",
    );
    await db.update(
      'tasks',
      {'user_id': targetUserId, 'sync_status': SyncStatus.pending.name},
      where: "user_id = 'local_user' OR user_id IS NULL OR TRIM(user_id) = ''",
    );
    await db.update(
      'projects',
      {'user_id': targetUserId, 'sync_status': SyncStatus.pending.name},
      where: "user_id = 'local_user' OR user_id IS NULL OR TRIM(user_id) = ''",
    );
    await db.update(
      'insight_cards_local',
      {'user_id': targetUserId, 'sync_status': SyncStatus.pending.name},
      where: "user_id = 'local_user' OR user_id IS NULL OR TRIM(user_id) = ''",
    );
    await db.update(
      'reflection_cycles_local',
      {'user_id': targetUserId, 'sync_status': SyncStatus.pending.name},
      where: "user_id = 'local_user' OR user_id IS NULL OR TRIM(user_id) = ''",
    );
  }
}
