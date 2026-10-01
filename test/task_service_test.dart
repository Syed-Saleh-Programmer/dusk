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

    test('serializes and deserializes tags on Dump and TaskItem', () {
      expect(
        Dump.parseTags(['#Work', '  personal ', 'work', 'Deep Focus']),
        equals(['Work', 'Personal', 'Deep Focus']),
      );
      expect(
        Dump.parseTags('["Health", "#Goals", "health"]'),
        equals(['Health', 'Goals']),
      );

      final now = DateTime(2026, 9, 28, 12, 0);
      final task = TaskItem(
        id: 'task-tags-1',
        userId: 'user-1',
        title: 'Prepare quarterly tax documents',
        tags: const ['Finance', 'Work'],
        createdAt: now,
      );

      final sqliteMap = task.toSqliteMap();
      expect(sqliteMap['tags'], isA<String>());
      final fromSqlite = TaskItem.fromMap(sqliteMap);
      expect(fromSqlite.tags, equals(['Finance', 'Work']));

      final supaMap = task.toSupabaseMap();
      expect(supaMap['tags'], equals(['Finance', 'Work']));
      final fromSupa = TaskItem.fromMap(supaMap);
      expect(fromSupa.tags, equals(['Finance', 'Work']));

      final updated = fromSupa.copyWith(tags: ['Finance', 'Tax Prep']);
      expect(updated.tags, equals(['Finance', 'Tax Prep']));
    });
  });

  group('TaskService Client-Side Extraction, Tagging & Markdown Export', () {
    test('parses structured AI tasks with tags as well as plain string lists', () {
      const structuredJson = '''
[
  {"title": "Send design mockups to Sarah", "tags": ["Work", "#Design"]},
  {"title": "Book dentist appointment", "tags": ["Health", "Errands"]}
]
''';
      final parsed = TaskService.parseAiTasks(structuredJson);
      expect(parsed, hasLength(2));
      expect(parsed[0].title, 'Send design mockups to Sarah');
      expect(parsed[0].tags, equals(['Work', 'Design']));
      expect(parsed[1].title, 'Book dentist appointment');
      expect(parsed[1].tags, equals(['Health', 'Errands']));
    });

    test('infers relevant tags from task text, hashtags, and available tags', () {
      final inferred = TaskService.inferTagsForText(
        'Review monthly budget and pay invoice #SideProject',
        availableTags: [...Dump.defaultTags, 'Side Project'],
        seedTags: const ['Personal'],
      );
      expect(inferred, contains('Personal'));
      expect(inferred, contains('Finance'));
    });

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

    test('filters out introductory list sentences and deduplicates variants', () {
      const userDump = '''
i have to complete the following.
- complete app
- prepare demo
''';
      final extracted = TaskService.extractTasksFromText(userDump);
      expect(extracted, hasLength(2));
      expect(extracted, contains('Complete app'));
      expect(extracted, contains('Prepare demo'));
      expect(extracted.any((t) => t.toLowerCase().contains('following')), isFalse);

      expect(TaskService.isNonActionableIntro('i have to complete the following.'), isTrue);
      expect(TaskService.isNonActionableIntro('Complete the following'), isTrue);
      expect(TaskService.isNonActionableIntro('Things to do:'), isTrue);
      expect(TaskService.isNonActionableIntro('Complete app'), isFalse);

      expect(
        TaskService.areTaskTitlesEquivalent('Complete app', 'Complete the app'),
        isTrue,
      );
      expect(
        TaskService.areTaskTitlesEquivalent('Prepare demo', 'Prepare the demo'),
        isTrue,
      );
      expect(
        TaskService.areTaskTitlesEquivalent('Prepare demo', 'prepare demo.'),
        isTrue,
      );
      expect(
        TaskService.areTaskTitlesEquivalent('Complete app', 'Prepare demo'),
        isFalse,
      );
    });

    test('returns empty list for purely reflective non-actionable thoughts', () {
      const reflectiveText =
          'Watching the sunset over the hills today felt really peaceful and grounding.';
      final extracted = TaskService.extractTasksFromText(reflectiveText);
      expect(extracted, isEmpty);
    });

    test('formats tasks as clean Markdown grouped by source including tags', () {
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
          tags: const ['Health', 'Goals'],
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
          tags: const ['Work'],
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
      expect(md, contains('#Health #Goals'));
      expect(md, contains('## Tasks from Captures'));
      expect(md, contains('- [x] Send sprint notes to team'));
      expect(md, contains('#Work'));
    });
  });
}
