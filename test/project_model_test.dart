import 'package:flutter_test/flutter_test.dart';
import 'package:dusk/models/project.dart';
import 'package:dusk/models/dump.dart';
import 'package:dusk/models/task_item.dart';

void main() {
  group('Project Model & Serialization', () {
    test('serializes and deserializes Project accurately for SQLite and Supabase', () {
      final now = DateTime.now();
      final project = Project(
        id: 'proj_123',
        userId: 'user_abc',
        name: 'Work & Startup',
        description: 'Projects and tasks related to dusk',
        icon: '🚀',
        colorValue: 0xFF4A84D8,
        createdAt: now,
        updatedAt: now,
      );

      final sqliteMap = project.toSqliteMap();
      expect(sqliteMap['id'], 'proj_123');
      expect(sqliteMap['user_id'], 'user_abc');
      expect(sqliteMap['name'], 'Work & Startup');
      expect(sqliteMap['icon'], '🚀');
      expect(sqliteMap['color_value'], 0xFF4A84D8);

      final fromSqlite = Project.fromMap(sqliteMap);
      expect(fromSqlite.id, project.id);
      expect(fromSqlite.name, project.name);
      expect(fromSqlite.icon, project.icon);
      expect(fromSqlite.colorValue, project.colorValue);

      final supabaseMap = project.toSupabaseMap();
      expect(supabaseMap['id'], 'proj_123');
      expect(supabaseMap['user_id'], 'user_abc');
      expect(supabaseMap['name'], 'Work & Startup');
    });

    test('Project copyWith works as expected', () {
      final project = Project(
        id: 'proj_1',
        userId: 'user_abc',
        name: 'Personal',
      );

      final updated = project.copyWith(
        name: 'Personal Growth',
        icon: '🌱',
        colorValue: 0xFF2DC48D,
      );

      expect(updated.id, 'proj_1');
      expect(updated.name, 'Personal Growth');
      expect(updated.icon, '🌱');
      expect(updated.colorValue, 0xFF2DC48D);
    });

    test('Dump model supports projectId', () {
      final now = DateTime.now();
      final dump = Dump(
        id: 'dump_1',
        userId: 'user_abc',
        content: 'Building the new Spaces feature',
        type: DumpType.text,
        capturedAt: now,
        createdAt: now,
        projectId: 'proj_dusk',
      );

      expect(dump.projectId, 'proj_dusk');

      final map = dump.toSqliteMap();
      expect(map['project_id'], 'proj_dusk');

      final fromMap = Dump.fromMap(map);
      expect(fromMap.projectId, 'proj_dusk');
    });

    test('TaskItem model supports projectId', () {
      final now = DateTime.now();
      final task = TaskItem(
        id: 'task_1',
        userId: 'user_abc',
        title: 'Review pull request',
        createdAt: now,
        projectId: 'proj_dusk',
      );

      expect(task.projectId, 'proj_dusk');

      final sqliteMap = task.toSqliteMap();
      expect(sqliteMap['project_id'], 'proj_dusk');

      final fromSqlite = TaskItem.fromMap(sqliteMap);
      expect(fromSqlite.projectId, 'proj_dusk');

      final supabaseMap = task.toSupabaseMap();
      expect(supabaseMap['project_id'], 'proj_dusk');
    });
  });
}
