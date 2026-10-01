import 'package:intl/intl.dart';
import '../models/dump.dart';
import '../models/task_item.dart';
import 'local_db_service.dart';
import 'supabase_service.dart';

class BuddyContextMetadata {
  final int dumpCount;
  final int taskCount;
  final int reflectionCount;
  final String systemPrompt;

  const BuddyContextMetadata({
    required this.dumpCount,
    required this.taskCount,
    required this.reflectionCount,
    required this.systemPrompt,
  });

  String get summaryLabel =>
      '$dumpCount ${dumpCount == 1 ? 'dump' : 'dumps'} · $taskCount ${taskCount == 1 ? 'task' : 'tasks'} · $reflectionCount ${reflectionCount == 1 ? 'reflection' : 'reflections'}';
}

class BuddyContextService {
  static final BuddyContextService _instance = BuddyContextService._internal();
  factory BuddyContextService() => _instance;
  BuddyContextService._internal();

  final LocalDbService _localDb = LocalDbService();
  final SupabaseService _supabase = SupabaseService();

  static const String outOfContextFallback =
      'Sorry, nothing like that in your second brain.';

  /// Compresses a raw text or transcript to a compact single-line snippet.
  String _compressText(String? raw, {int maxLen = 140}) {
    if (raw == null) return '';
    final cleaned = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length <= maxLen) return cleaned;
    return '${cleaned.substring(0, maxLen).trim()}...';
  }

  /// Builds context snapshot for dumps, tasks, and reflections.
  Future<BuddyContextMetadata> buildSecondBrainContext({String? userId}) async {
    final effectiveUserId = userId ?? _supabase.currentUser?.id ?? 'local_user';
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final dateFormat = DateFormat('yyyy-MM-dd');

    // 1. Fetch Dumps (Past 1 Month)
    List<Dump> allDumps = [];
    try {
      allDumps = await _localDb.getAllDumps(userId: effectiveUserId);
    } catch (_) {}

    final monthlyDumps = allDumps.where((d) {
      return d.capturedAt.isAfter(thirtyDaysAgo);
    }).toList();

    final dumpsBuffer = StringBuffer();
    if (monthlyDumps.isEmpty) {
      dumpsBuffer.writeln('No dumps recorded in the past 30 days.');
    } else {
      // Sort newest first
      monthlyDumps.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
      // Cap at 45 most relevant compressed items to maintain prompt compactness
      final cappedDumps = monthlyDumps.take(45);
      for (final d in cappedDumps) {
        final dateStr = dateFormat.format(d.capturedAt);
        final tagStr = d.tags.isNotEmpty ? d.tags.join('/') : (d.category ?? d.type.name);
        final summaryBody = (d.aiSummary != null && d.aiSummary!.trim().isNotEmpty)
            ? _compressText(d.aiSummary, maxLen: 160)
            : _compressText(d.content ?? d.transcript, maxLen: 140);
        final titlePrefix = (d.title != null && d.title!.trim().isNotEmpty)
            ? '${d.title!.trim()}: '
            : '';
        dumpsBuffer.writeln('- [$dateStr] ($tagStr): $titlePrefix$summaryBody');
      }
    }

    // 2. Fetch Tasks (Past 1 Month)
    List<TaskItem> allTasks = [];
    try {
      allTasks = await _localDb.getAllTasks(userId: effectiveUserId);
    } catch (_) {}

    final monthlyTasks = allTasks.where((t) {
      return t.createdAt.isAfter(thirtyDaysAgo) || t.updatedAt.isAfter(thirtyDaysAgo);
    }).toList();

    final tasksBuffer = StringBuffer();
    if (monthlyTasks.isEmpty) {
      tasksBuffer.writeln('No tasks recorded in the past 30 days.');
    } else {
      monthlyTasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final cappedTasks = monthlyTasks.take(40);
      for (final t in cappedTasks) {
        final statusTag = t.isDone ? 'DONE' : (t.isArchived ? 'ARCHIVED' : 'PENDING');
        final dueStr = t.dueDate != null ? ' (Due: ${dateFormat.format(t.dueDate!)})' : '';
        final tagsStr = t.tags.isNotEmpty ? ' [${t.tags.join(', ')}]' : '';
        tasksBuffer.writeln('- [$statusTag] ${t.title}$dueStr$tagsStr');
      }
    }

    // 3. Fetch Reflections (Past 1 Week)
    List<Map<String, dynamic>> localInsightCards = [];
    try {
      localInsightCards = await _localDb.getLocalInsightCards(userId: effectiveUserId);
    } catch (_) {}

    final weeklyInsights = localInsightCards.where((card) {
      final createdStr = card['created_at']?.toString();
      if (createdStr == null) return false;
      final dt = DateTime.tryParse(createdStr);
      return dt != null && dt.isAfter(sevenDaysAgo);
    }).toList();

    final reflectionsBuffer = StringBuffer();
    if (weeklyInsights.isEmpty) {
      reflectionsBuffer.writeln('No reflections recorded in the past 7 days.');
    } else {
      for (final card in weeklyInsights) {
        final dateStr = card['created_at'] != null
            ? card['created_at'].toString().substring(0, 10)
            : 'Recent';
        final title = card['title']?.toString() ?? 'Weekly Reflection';
        final mainInsight = _compressText(card['main_insight']?.toString(), maxLen: 160);
        final standout = _compressText(card['standout']?.toString(), maxLen: 120);
        final wins = _compressText(card['progress_and_wins']?.toString(), maxLen: 120);

        final parts = <String>[];
        if (mainInsight.isNotEmpty) parts.add(mainInsight);
        if (standout.isNotEmpty) parts.add('Breakthrough: $standout');
        if (wins.isNotEmpty) parts.add('Wins: $wins');

        reflectionsBuffer.writeln('- [$dateStr] "$title": ${parts.join(' | ')}');
      }
    }

    // 4. Construct System Prompt with Strict Directives
    final systemPrompt = '''
You are Dusk Buddy, a personalized AI companion for the Dusk second-brain app.
Your purpose is to answer the user's questions using their second brain context provided below, while answering as Dusk Buddy.

=== USER'S SECOND BRAIN CONTEXT ===

[PAST 1 MONTH DUMPS (COMPRESSED)]:
${dumpsBuffer.toString().trim()}

[PAST 1 MONTH TASKS]:
${tasksBuffer.toString().trim()}

[PAST 1 WEEK REFLECTIONS]:
${reflectionsBuffer.toString().trim()}

=== STRICT RULES FOR YOUR RESPONSES ===
1. When asked about "who you are", who you are, or related questions, you must respond: "I am Dusk Buddy, your companion in your journey." and other related questions should be answered as being Dusk Buddy.
2. Answer what is asked directly and immediately. Keep answers short and to the point with NO extra explanations or filler.
3. Except for questions about being Dusk Buddy, if the user asks anything that is OUT OF CONTEXT (meaning it is not found in, mentioned by, or directly about their dumps, tasks, or reflections above), you MUST respond with EXACTLY:
$outOfContextFallback
4. Never invent, assume, or hallucinate facts not in the context.
5. Format your output cleanly in Markdown (using concise bullet points or bold keywords when listing items).
6. Output must remain concise (maximum 2 to 4 sentences or a brief bullet list).
''';

    return BuddyContextMetadata(
      dumpCount: monthlyDumps.length,
      taskCount: monthlyTasks.length,
      reflectionCount: weeklyInsights.length,
      systemPrompt: systemPrompt.trim(),
    );
  }
}
