import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/insight_card.dart';
import '../../models/task_item.dart';
import '../../providers/app_state.dart';
import '../widgets/dusk_ui_components.dart';
import 'tasks_screen.dart';

class InsightCardScreen extends StatefulWidget {
  final InsightCard insight;

  const InsightCardScreen({super.key, required this.insight});

  @override
  State<InsightCardScreen> createState() => _InsightCardScreenState();
}

class _InsightCardScreenState extends State<InsightCardScreen> {
  InsightCard get insight => widget.insight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppState>().addManualTask(
            insight.suggestion,
            sourceType: TaskSourceType.insight,
            insightCardId: insight.id,
            sourceLabel: insight.title,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final matchingTask = appState.tasks.cast<TaskItem?>().firstWhere(
          (t) =>
              t?.insightCardId == insight.id ||
              (t?.sourceType == TaskSourceType.insight &&
                  t?.title.toLowerCase().trim() ==
                      insight.suggestion.toLowerCase().trim()),
          orElse: () => null,
        );

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F2),
      body: DuskAmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    DuskCircleButton(
                      icon: Icons.close_rounded,
                      size: 42,
                      iconSize: 20,
                      onTap: () => Navigator.of(context)
                          .popUntil((route) => route.isFirst),
                    ),
                    const Text(
                      'Your Daily Insight',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B1A19),
                        letterSpacing: -0.2,
                      ),
                    ),
                    DuskCircleButton(
                      icon: Icons.task_alt_rounded,
                      size: 42,
                      iconSize: 20,
                      tooltip: 'Open Tasks Action Tray',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const TasksScreen(showBackButton: true),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: const Color(0xFFF0EBE1),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: const [
                                DuskPillBadge(
                                  text: 'Synthesized Insight',
                                  variant: DuskBadgeVariant.peach,
                                  icon: Icons.auto_awesome_rounded,
                                ),
                                DuskPillBadge(
                                  text: 'Today',
                                  variant: DuskBadgeVariant.blue,
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Text(
                              insight.title,
                              style: const TextStyle(
                                fontSize: 20,
                                color: Color(0xFF1B1A19),
                                fontWeight: FontWeight.w800,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildSection(
                              'What stood out',
                              insight.standout,
                              const Color(0xFFFF7A1A),
                            ),
                            const SizedBox(height: 20),
                            _buildSection(
                              'The underlying pattern',
                              insight.mainInsight,
                              const Color(0xFF4A84D8),
                            ),
                            const SizedBox(height: 20),
                            _buildSection(
                              'A gentle next step',
                              insight.suggestion,
                              const Color(0xFF389F7F),
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (matchingTask != null)
                                  GestureDetector(
                                    onTap: () =>
                                        appState.toggleTaskDone(matchingTask.id),
                                    child: DuskPillBadge(
                                      text: matchingTask.isDone
                                          ? 'Completed in Tasks'
                                          : 'Mark Step Done',
                                      variant: DuskBadgeVariant.green,
                                      icon: matchingTask.isDone
                                          ? Icons.check_circle_rounded
                                          : Icons
                                              .radio_button_unchecked_rounded,
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
                                          id: insight.id,
                                          userId: insight.userId,
                                          insightCardId: insight.id,
                                          title: insight.suggestion,
                                          sourceType: TaskSourceType.insight,
                                          sourceLabel: insight.title,
                                          createdAt: insight.createdAt,
                                        );
                                    showTaskExportModal(
                                      context,
                                      tasks: [stepItem],
                                      periodLabel: 'Daily Insight',
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
                      DuskPrimaryButton(
                        label: 'Save & Finish Ritual',
                        icon: Icons.check_circle_outline_rounded,
                        onPressed: () {
                          Navigator.of(context)
                              .popUntil((route) => route.isFirst);
                        },
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            final stepItem = matchingTask ??
                                TaskItem(
                                  id: insight.id,
                                  userId: insight.userId,
                                  insightCardId: insight.id,
                                  title: insight.suggestion,
                                  sourceType: TaskSourceType.insight,
                                  sourceLabel: insight.title,
                                  createdAt: insight.createdAt,
                                );
                            showTaskExportModal(
                              context,
                              tasks: [stepItem],
                              periodLabel: 'Daily Insight',
                            );
                          },
                          icon: const Icon(
                            Icons.ios_share_rounded,
                            size: 18,
                            color: Color(0xFF767068),
                          ),
                          label: const Text(
                            'Export Gentle Next Step',
                            style: TextStyle(
                              color: Color(0xFF767068),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
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

  Widget _buildSection(String title, String content, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title.toUpperCase(),
              style: TextStyle(
                color: accentColor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          content,
          style: const TextStyle(
            color: Color(0xFF6E6862),
            fontSize: 14.5,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
