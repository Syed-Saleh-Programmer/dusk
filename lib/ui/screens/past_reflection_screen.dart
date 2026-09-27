import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/task_item.dart';
import '../../providers/app_state.dart';
import '../widgets/dusk_ui_components.dart';
import '../widgets/editorial_insight_card.dart';
import 'share_insight_screen.dart';
import 'tasks_screen.dart';

class PastReflectionScreen extends StatefulWidget {
  final Map<String, dynamic> insight;

  const PastReflectionScreen({super.key, required this.insight});

  @override
  State<PastReflectionScreen> createState() => _PastReflectionScreenState();
}

class _PastReflectionScreenState extends State<PastReflectionScreen> {
  final GlobalKey _inlineCardKey = GlobalKey();
  EditorialThemeId _selectedTheme = EditorialThemeId.warmPaper;
  bool _isQuickSharing = false;
  bool _isSummaryExpanded = false;
  bool _isQAExpanded = false;

  late final EditorialInsightData _insightData;

  // Mock data for sections not directly available in standard insight map
  final List<Map<String, String>> mockQA = [
    {
      "question": "What challenged you most recently?",
      "answer": "I found it difficult to balance my deep work with unexpected meetings."
    },
    {
      "question": "How did you feel when you accomplished your main goal?",
      "answer": "Relieved, but also realizing that I need better boundaries."
    }
  ];

  final List<Map<String, String>> mockCaptures = [
    {
      "type": "text",
      "content": "Feeling a bit overwhelmed by the project scope today.",
      "time": "10:30 AM"
    },
    {
      "type": "voice",
      "content": "Audio note (0:45)",
      "time": "2:15 PM"
    }
  ];

  @override
  void initState() {
    super.initState();
    _insightData = EditorialInsightData.fromMap(widget.insight);
    _loadPreferredTheme();
  }

  Future<void> _loadPreferredTheme() async {
    final saved = await EditorialStudioPreferences.loadPreferredTheme();
    if (!mounted) return;
    setState(() => _selectedTheme = saved);
  }

  void _openStudio({EditorialCardFormat? initialFormat}) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShareInsightScreen(
          insight: widget.insight,
          initialTheme: _selectedTheme,
          initialFormat: initialFormat,
        ),
      ),
    );
  }

  Future<void> _quickShareImage() async {
    if (_isQuickSharing) return;
    HapticFeedback.mediumImpact();
    setState(() => _isQuickSharing = true);
    try {
      final box = context.findRenderObject() as RenderBox?;
      final origin =
          (box != null && box.hasSize) ? (box.localToGlobal(Offset.zero) & box.size) : null;

      await InsightCardExportService.shareAsImage(
        boundaryKey: _inlineCardKey,
        insight: _insightData,
        theme: _selectedTheme,
        format: EditorialCardFormat.editorialCard,
        sharePositionOrigin: origin,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share insight image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isQuickSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final appState = context.watch<AppState>();
    final cardId = widget.insight['id']?.toString() ?? '';
    final suggestionText =
        widget.insight['suggestion'] as String? ?? 'Keep observing your thoughts gently.';
    final matchingTask = appState.tasks.cast<TaskItem?>().firstWhere(
          (t) =>
              (cardId.isNotEmpty && t?.insightCardId == cardId) ||
              (t?.sourceType == TaskSourceType.insight &&
                  t?.title.toLowerCase().trim() ==
                      suggestionText.toLowerCase().trim()),
          orElse: () => null,
        );

    String dateTitle = 'Reflection';
    if (widget.insight['created_at'] != null) {
      try {
        final dt = DateTime.parse(widget.insight['created_at']);
        dateTitle = DateFormat('MMMM d, yyyy').format(dt);
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F2),
      body: DuskAmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    DuskCircleButton(
                      icon: Icons.arrow_back_rounded,
                      size: 40,
                      iconSize: 19,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    Text(
                      dateTitle,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B1A19),
                        letterSpacing: -0.2,
                      ),
                    ),
                    DuskCircleButton(
                      icon: Icons.ios_share_rounded,
                      size: 40,
                      iconSize: 18,
                      iconColor: const Color(0xFFFF7A1A),
                      tooltip: 'Editorial Studio & Share',
                      onTap: _openStudio,
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Editorial Theme Bar for the Insight Card
                      EditorialThemeSelectorBar(
                        selectedTheme: _selectedTheme,
                        compact: true,
                        onThemeSelected: (theme) {
                          setState(() => _selectedTheme = theme);
                          EditorialStudioPreferences.savePreferredTheme(theme);
                        },
                      ),
                      const SizedBox(height: 14),

                      // Section 1: The Historical Insight Card rendered in the selected Editorial Theme
                      RepaintBoundary(
                        key: _inlineCardKey,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: EditorialInsightCardCanvas(
                            key: ValueKey(_selectedTheme),
                            insight: _insightData,
                            theme: _selectedTheme,
                            composition: EditorialComposition.fullSynthesis,
                            colophon: EditorialColophonStyle.personal,
                            showDateStamp: true,
                            showTextureAndRules: true,
                            isInlineCard: true,
                          ),
                        ),
                      ).animate().fadeIn().slideY(begin: 0.04),

                      const SizedBox(height: 14),

                      // Studio & Wallpaper Export Action Strip
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _openStudio,
                              icon: const Icon(
                                Icons.auto_fix_high_rounded,
                                size: 17,
                                color: Color(0xFF1B1A19),
                              ),
                              label: const Text(
                                'Editorial Studio',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1B1A19),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                side: const BorderSide(color: Color(0xFFE5DFD4)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(22),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _openStudio(
                                initialFormat: EditorialCardFormat.wallpaper9x16,
                              ),
                              icon: const Icon(
                                Icons.stay_current_portrait_rounded,
                                size: 17,
                                color: Color(0xFFFF7A1A),
                              ),
                              label: const Text(
                                'Wallpaper 9:16',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1B1A19),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                side: const BorderSide(color: Color(0xFFE5DFD4)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(22),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          DuskCircleButton(
                            icon: Icons.ios_share_rounded,
                            size: 44,
                            iconSize: 18,
                            tooltip: 'Quick Share Image',
                            onTap: _isQuickSharing ? null : _quickShareImage,
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Gentle Next Step Action Tray Strip
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFF0EBE1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(
                                  Icons.task_alt_rounded,
                                  size: 17,
                                  color: Color(0xFF389F7F),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'GENTLE NEXT STEP • ACTION TRAY',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.9,
                                    color: Color(0xFF389F7F),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                GestureDetector(
                                  onTap: () async {
                                    if (matchingTask != null) {
                                      await appState
                                          .toggleTaskDone(matchingTask.id);
                                    } else {
                                      final added =
                                          await appState.addManualTask(
                                        suggestionText,
                                        sourceType: TaskSourceType.insight,
                                        insightCardId:
                                            cardId.isNotEmpty ? cardId : null,
                                        sourceLabel: widget.insight['title']
                                                ?.toString() ??
                                            'Evening Insight',
                                      );
                                      if (added != null) {
                                        await appState.toggleTaskDone(added.id);
                                      }
                                    }
                                  },
                                  child: DuskPillBadge(
                                    text: matchingTask?.isDone == true
                                        ? 'Completed in Tasks'
                                        : 'Mark Step Done',
                                    variant: DuskBadgeVariant.green,
                                    icon: matchingTask?.isDone == true
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const TasksScreen(
                                          showBackButton: true,
                                        ),
                                      ),
                                    );
                                  },
                                  child: const DuskPillBadge(
                                    text: 'Open Action Tray',
                                    variant: DuskBadgeVariant.peach,
                                    icon: Icons.open_in_new_rounded,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    final stepItem = matchingTask ??
                                        TaskItem(
                                          id: cardId.isNotEmpty
                                              ? cardId
                                              : 'insight_step',
                                          userId: widget.insight['user_id']
                                                  ?.toString() ??
                                              '',
                                          insightCardId:
                                              cardId.isNotEmpty ? cardId : null,
                                          title: suggestionText,
                                          sourceType: TaskSourceType.insight,
                                          sourceLabel: widget.insight['title']
                                                  ?.toString() ??
                                              'Evening Insight',
                                          createdAt: DateTime.tryParse(
                                                widget.insight['created_at']
                                                        ?.toString() ??
                                                    '',
                                              ) ??
                                              DateTime.now(),
                                        );
                                    showTaskExportModal(
                                      context,
                                      tasks: [stepItem],
                                      periodLabel: dateTitle,
                                    );
                                  },
                                  child: const DuskPillBadge(
                                    text: '1-Tap Export',
                                    variant: DuskBadgeVariant.neutral,
                                    icon: Icons.ios_share_rounded,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Section 2: AI Cycle Summary Accordion
                      _buildAccordion(
                        context,
                        title: 'AI Cycle Summary',
                        icon: Icons.psychology_outlined,
                        isExpanded: _isSummaryExpanded,
                        onTap: () =>
                            setState(() => _isSummaryExpanded = !_isSummaryExpanded),
                        child: Text(
                          'This reflection captured a transition period. You focused heavily on boundary setting and emotional regulation. The AI noted a recurring theme of seeking quiet moments.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                      ).animate().fadeIn(delay: 100.ms),

                      const SizedBox(height: 14),

                      // Section 3: Guided Reflection Q&A Archive
                      _buildAccordion(
                        context,
                        title: 'Guided Q&A Archive',
                        icon: Icons.question_answer_outlined,
                        isExpanded: _isQAExpanded,
                        onTap: () =>
                            setState(() => _isQAExpanded = !_isQAExpanded),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: mockQA.map((qa) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    qa["question"]!,
                                    style: textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: colors.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    qa["answer"]!,
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: colors.onSurfaceVariant,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ).animate().fadeIn(delay: 200.ms),

                      const SizedBox(height: 28),

                      // Section 4: Original Captures List
                      Text(
                        'Original Captures',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ).animate().fadeIn(delay: 300.ms),
                      const SizedBox(height: 12),
                      ...mockCaptures.map((capture) {
                        final isVoice = capture["type"] == "voice";
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFF0EBE1)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                isVoice ? Icons.mic_none : Icons.notes,
                                size: 20,
                                color: colors.primary.withValues(alpha: 0.8),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      capture["content"]!,
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: colors.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      capture["time"]!,
                                      style: textTheme.labelSmall?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 400.ms);
                      }),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccordion(
    BuildContext context, {
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onTap,
    required Widget child,
  }) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0EBE1)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Icon(icon, size: 22, color: colors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: child,
            ),
        ],
      ),
    );
  }
}
