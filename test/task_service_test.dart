import 'package:flutter_test/flutter_test.dart';
import 'package:dusk/models/dump.dart';
import 'package:dusk/models/task_item.dart';
import 'package:dusk/services/task_service.dart';

void main() {
  group('TaskItem Model & Serialization', () {
    test('serializes and deserializes TaskItem accurately for SQLite and Supabase', () {
      final now = DateTime(2026, 9, 27, 14, 0);
      final deadline = DateTime(2026, 9, 30, 23, 59);
      final task = TaskItem(
        id: 'task-123',
        userId: 'user-456',
        dumpId: 'dump-789',
        title: 'Send design mockups to Sarah',
        sourceType: TaskSourceType.dump,
        sourceLabel: 'Sprint Planning',
        status: TaskStatus.pending,
        dueDate: deadline,
        createdAt: now,
        updatedAt: now,
        syncStatus: SyncStatus.pending,
      );

      final localMap = task.toMap();
      final restored = TaskItem.fromMap(localMap);

      expect(restored.id, 'task-123');
      expect(restored.userId, 'user-456');
      expect(restored.dumpId, 'dump-789');
      expect(restored.title, 'Send design mockups to Sarah');
      expect(restored.sourceType, TaskSourceType.dump);
      expect(restored.sourceLabel, 'Sprint Planning');
      expect(restored.isPending, isTrue);
      expect(restored.hasDueDate, isTrue);
      expect(restored.dueDate?.year, 2026);
      expect(restored.dueDate?.month, 9);
      expect(restored.dueDate?.day, 30);
      expect(restored.syncStatus, SyncStatus.pending);

      final cleared = restored.copyWith(clearDueDate: true);
      expect(cleared.dueDate, isNull);

      final supaMap = task.toSupabaseMap();
      expect(supaMap['sync_status'], 'synced');
      expect(supaMap['source_type'], 'dump');
      expect(supaMap['dump_id'], 'dump-789');
      expect(supaMap['due_date'], isNotNull);
    });
  });

  group('TaskService Client-Side Extraction & Markdown Export', () {
    test('extracts tasks from bullet lists, checklists, and action sentences', () {
      const sampleText = '''
Had a productive afternoon thinking through the release.
Need to send the design mockups to Sarah and schedule the sprint review tomorrow.
- [ ] Update the Supabase schema migration
- Review onboarding copy with Alex
''';

      final extracted = TaskService.extractTasksFromText(sampleText);
      expect(extracted, isNotEmpty);
      expect(
        extracted.any((t) => t.toLowerCase().contains('send the design mockups')),
        isTrue,
      );
      expect(
        extracted.any((t) => t.toLowerCase().contains('schedule the sprint review')),
        isTrue,
      );
      expect(
        extracted.any((t) => t.toLowerCase().contains('update the supabase schema')),
        isTrue,
      );
      expect(
        extracted.any((t) => t.toLowerCase().contains('review onboarding copy')),
        isTrue,
      );
    });

    test('returns empty list for purely reflective non-actionable thoughts', () {
      const reflectiveText =
          'Watching the sunset over the hills today felt really peaceful and grounding.';
      final extracted = TaskService.extractTasksFromText(reflectiveText);
      expect(extracted, isEmpty);
    });

    test('formats tasks as clean Markdown grouped by source', () {
      final now = DateTime(2026, 9, 27, 10, 0);
      final tasks = [
        TaskItem(
          id: '1',
          userId: 'u1',
          insightCardId: 'ic1',
          title: 'Block 30 minutes of quiet focus before checking messages',
          sourceType: TaskSourceType.insight,
          sourceLabel: 'Protecting Morning Clarity',
          status: TaskStatus.pending,
          createdAt: now,
        ),
        TaskItem(
          id: '2',
          userId: 'u1',
          dumpId: 'd1',
          title: 'Send sprint notes to team',
          sourceType: TaskSourceType.dump,
          sourceLabel: 'Team Sync',
          status: TaskStatus.done,
          createdAt: now,
        ),
      ];

      final md = TaskService.formatTasksAsMarkdown(
        tasks,
        periodLabel: 'Today',
      );

      expect(md, contains('# Dusk — Gentle Next Steps & Tasks'));
      expect(md, contains('## Gentle Next Steps (From Reflections)'));
      expect(
        md,
        contains('- [ ] Block 30 minutes of quiet focus before checking messages'),
      );
      expect(md, contains('## Tasks from Captures'));
      expect(md, contains('- [x] Send sprint notes to team'));
    });
  });
}
