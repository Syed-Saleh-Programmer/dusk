import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/insight_card.dart';
import '../../models/task_item.dart';
import '../../providers/app_state.dart';
import '../theme/app_theme.dart';
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
      final appState = context.read<AppState>();
      
      // Auto-register primary suggestion task
      if (insight.suggestion.isNotEmpty) {
        appState.addManualTask(
          insight.suggestion,
          sourceType: TaskSourceType.insight,
          insightCardId: insight.id,
          sourceLabel: insight.title,
        );
      }
      
      // Auto-register next actions tasks
      if (insight.nextActions != null && insight.nextActions!.isNotEmpty) {
        for (final action in insight.nextActions!) {
          if (action.trim().isNotEmpty && action.trim() != insight.suggestion.trim()) {
            appState.addManualTask(
              action.trim(),
              sourceType: TaskSourceType.insight,
              insightCardId: insight.id,
              sourceLabel: insight.title,
            );
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final appState = context.watch<AppState>();

    return Scaffold(
      backgroundColor: p.background,
      body: DuskAmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    DuskCircleButton(
                      icon: Icons.close_rounded,
                      size: 40,
                      iconSize: 19,
                      onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Weekly Summary & Insights',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: p.onSurface,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DuskCircleButton(
                      icon: Icons.task_alt_rounded,
                      size: 40,
                      iconSize: 19,
                      tooltip: 'Open Tasks Action Tray',
                      onTap: () {
                        Navigator.of(context).push(
                          DuskPageRoute.perspectiveSlide(
                            builder: (_) => const TasksScreen(showBackButton: true),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: p.outline,
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
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: const [
                                DuskPillBadge(
                                  text: 'Weekly Reflection Summary',
                                  variant: DuskBadgeVariant.peach,
                                  icon: Icons.auto_awesome_rounded,
                                ),
                                DuskPillBadge(
                                  text: '7-Day Synthesis',
                                  variant: DuskBadgeVariant.blue,
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Text(
                              insight.title,
                              style: TextStyle(
                                fontSize: 22,
                                color: p.onSurface,
                                fontWeight: FontWeight.w800,
                                height: 1.3,
                                letterSpacing: -0.3,
                              ),
                            ),

                            // What the week was about
                            if (insight.weekOverview != null && insight.weekOverview!.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              _buildSection(
                                'What the past week was about',
                                insight.weekOverview!,
                                p.primary,
                                icon: Icons.calendar_today_rounded,
                              ),
                            ],

                            // Progress and Wins
                            if (insight.progressAndWins != null && insight.progressAndWins!.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              _buildSection(
                                'Progress & Wins',
                                insight.progressAndWins!,
                                p.tertiary,
                                icon: Icons.emoji_events_rounded,
                              ),
                            ],

                            // Standout & Main Insight
                            const SizedBox(height: 20),
                            _buildSection(
                              'What stood out',
                              insight.standout,
                              p.primaryLight,
                              icon: Icons.lightbulb_rounded,
                            ),
                            const SizedBox(height: 20),
                            _buildSection(
                              'Core Pattern & Realization',
                              insight.mainInsight,
                              p.secondary,
                              icon: Icons.psychology_rounded,
                            ),

                            // Motivation & Mindset
                            if (insight.motivation != null && insight.motivation!.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: p.primaryContainer.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: p.primaryContainer),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.volunteer_activism_rounded, size: 16, color: p.primary),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'MOTIVATION & MINDSET',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: p.primary,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      insight.motivation!,
                                      style: TextStyle(
                                        color: p.onSurface,
                                        fontSize: 14.5,
                                        height: 1.5,
                                        fontWeight: FontWeight.w600,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Next Actions / Todos
                            const SizedBox(height: 22),
                            _buildNextActionsSection(context, appState),

                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      DuskPageRoute.perspectiveSlide(
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
                                    final stepItems = appState.tasks
                                        .where((t) => t.insightCardId == insight.id)
                                        .toList();
                                    final itemsToExport = stepItems.isNotEmpty
                                        ? stepItems
                                        : [
                                            TaskItem(
                                              id: insight.id,
                                              userId: insight.userId,
                                              insightCardId: insight.id,
                                              title: insight.suggestion,
                                              sourceType: TaskSourceType.insight,
                                              sourceLabel: insight.title,
                                              createdAt: insight.createdAt,
                                            )
                                          ];
                                    showTaskExportModal(
                                      context,
                                      tasks: itemsToExport,
                                      periodLabel: 'Weekly Reflection Summary',
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
                        label: 'Save & Finish Reflection',
                        icon: Icons.check_circle_outline_rounded,
                        onPressed: () {
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        },
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

  Widget _buildSection(String title, String content, Color accentColor, {IconData? icon}) {
    final p = AppTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: accentColor),
              const SizedBox(width: 6),
            ] else ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                title.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          content,
          style: TextStyle(
            color: p.onSurfaceVariant,
            fontSize: 14.5,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildNextActionsSection(BuildContext context, AppState appState) {
    final p = AppTheme.of(context);
    final actionsList = (insight.nextActions != null && insight.nextActions!.isNotEmpty)
        ? insight.nextActions!
        : [insight.suggestion];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.checklist_rounded, size: 16, color: p.tertiary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'RECOMMENDED NEXT ACTIONS & TODOS',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: p.tertiary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...actionsList.map((actionStr) {
          final matchingTask = appState.tasks.firstWhere(
            (t) => t.title.toLowerCase().trim() == actionStr.toLowerCase().trim(),
            orElse: () => TaskItem(
              id: '',
              userId: insight.userId,
              title: actionStr,
              sourceType: TaskSourceType.insight,
              createdAt: DateTime.now(),
            ),
          );

          final isDone = matchingTask.id.isNotEmpty && matchingTask.isDone;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDone ? p.tertiaryContainer.withValues(alpha: 0.3) : p.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDone ? p.tertiaryContainer : p.outline,
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (matchingTask.id.isNotEmpty) {
                      appState.toggleTaskDone(matchingTask.id);
                    } else {
                      appState.addManualTask(
                        actionStr,
                        sourceType: TaskSourceType.insight,
                        insightCardId: insight.id,
                        sourceLabel: insight.title,
                      );
                    }
                  },
                  child: Icon(
                    isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    color: isDone ? p.tertiary : p.onSurfaceVariant,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    actionStr,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDone ? p.onSurfaceVariant : p.onSurface,
                      fontWeight: FontWeight.w600,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
