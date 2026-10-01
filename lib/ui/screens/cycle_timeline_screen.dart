import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/app_state.dart';
import 'reflection_ready_screen.dart';
import 'dump_detail_screen.dart';
import '../widgets/dusk_ui_components.dart';
import '../widgets/capture_speed_dial.dart';
import '../navigation/dusk_navigation.dart';

class CycleTimelineScreen extends StatefulWidget {
  final String? cycleId;

  const CycleTimelineScreen({super.key, this.cycleId});

  @override
  State<CycleTimelineScreen> createState() => _CycleTimelineScreenState();
}

class _CycleTimelineScreenState extends State<CycleTimelineScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F2),
      body: DuskAmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Top Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    DuskCircleButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      size: 38,
                      iconSize: 17,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'Cycle Timeline',
                        style: TextStyle(
                          fontSize: 17.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1B1A19),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Consumer<AppState>(
                  builder: (context, appState, child) {
                    if (appState.isLoading) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF7A1A)),
                        ),
                      );
                    }

                    final dumps = appState.todayDumps;
                    final cycle = appState.currentCycle;

                    int daysLeft = 0;
                    if (cycle != null) {
                      daysLeft = cycle.periodEnd.difference(DateTime.now()).inDays;
                      if (daysLeft < 0) daysLeft = 0;
                    }

                    // Group dumps by date string
                    final groupedDumps = <String, List<Map<String, dynamic>>>{};
                    for (var dump in dumps) {
                      final rawDate = dump['captured_at'] ?? dump['created_at'] ?? DateTime.now().toIso8601String();
                      final date = DateTime.parse(rawDate.toString()).toLocal();
                      final dateString = DateFormat('yyyy-MM-dd').format(date);
                      if (!groupedDumps.containsKey(dateString)) {
                        groupedDumps[dateString] = [];
                      }
                      groupedDumps[dateString]!.add(dump);
                    }

                    final sortedDates = groupedDumps.keys.toList()..sort((a, b) => b.compareTo(a));

                    int totalItems = 0;
                    for (var date in sortedDates) {
                      totalItems += 1; // Header
                      totalItems += groupedDumps[date]!.length; // Items
                    }

                    return Stack(
                      children: [
                        CustomScrollView(
                          slivers: [
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                                child: _buildSummaryCard(context, daysLeft, dumps.length),
                              ).animate().fadeIn().slideY(begin: 0.05),
                            ),
                            if (dumps.isEmpty)
                              const SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(
                                  child: Text(
                                    'No captures yet.\nStart logging your thoughts.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFF88827A),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              )
                            else
                              SliverPadding(
                                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 100),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      int currentIndex = 0;
                                      for (var date in sortedDates) {
                                        if (currentIndex == index) {
                                          return _buildDateSeparator(context, date, date == sortedDates.first);
                                        }
                                        currentIndex++;

                                        final dayDumps = groupedDumps[date]!;
                                        for (int i = 0; i < dayDumps.length; i++) {
                                          if (currentIndex == index) {
                                            final isLastOfAll = (date == sortedDates.last && i == dayDumps.length - 1);
                                            return _buildTimelineItem(context, dayDumps[i], isLastOfAll);
                                          }
                                          currentIndex++;
                                        }
                                      }
                                      return const SizedBox.shrink();
                                    },
                                    childCount: totalItems,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (dumps.isNotEmpty)
                          Positioned(
                            left: 20,
                            right: 20,
                            bottom: 16,
                            child: DuskPrimaryButton(
                              label: 'Reflect Now',
                              icon: Icons.auto_awesome_rounded,
                              onPressed: () {
                                final activeCycleId = widget.cycleId ?? cycle?.id ?? '';
                                Navigator.push(
                                  context,
                                  DuskPageRoute.ritual(
                                    builder: (_) => ReflectionReadyScreen(cycleId: activeCycleId),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 70.0),
        child: const CaptureSpeedDial(
          anglesDeg: [-96, -64, -32, 0],
        ).animate().scale(delay: 200.ms, curve: Curves.easeOutBack),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, int daysLeft, int dumpCount) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFF0EBE1)),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem(context, 'Days Left', '$daysLeft', Icons.calendar_today_outlined),
          Container(width: 1, height: 40, color: const Color(0xFFECE7DE)),
          _buildSummaryItem(context, 'Captures', '$dumpCount', Icons.layers_outlined),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(BuildContext context, String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFFFF7A1A), size: 22),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1B1A19),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF88827A),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDateSeparator(BuildContext context, String dateString, bool isFirst) {
    DateTime date = DateTime.parse(dateString);
    String formattedDate = DateFormat('EEEE, MMMM d').format(date);
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      formattedDate = 'Today';
    }

    return Padding(
      padding: EdgeInsets.only(top: isFirst ? 0 : 24, bottom: 12),
      child: Row(
        children: [
          Text(
            formattedDate,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1B1A19),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Divider(color: Color(0xFFECE7DE), thickness: 1)),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(BuildContext context, Map<String, dynamic> dump, bool isLast) {
    final dumpId = dump['id']?.toString() ?? '';
    final type = dump['type'] as String? ?? 'text';
    final rawDate = dump['captured_at'] ?? dump['created_at'] ?? DateTime.now().toIso8601String();
    final time = DateFormat('h:mm a').format(DateTime.parse(rawDate.toString()).toLocal());
    final isProcessing = dump['is_processing'] == true;

    final rawTitle = (dump['title'] as String?)?.trim() ?? '';
    final rawContent = (dump['content'] as String?)?.trim() ?? '';
    final rawTranscript = (dump['transcript'] as String?)?.trim() ?? '';
    final rawSummary = (dump['ai_summary'] as String?)?.trim() ?? '';

    String displayBody = rawContent;
    if (type == 'voice') {
      displayBody = rawTranscript.isNotEmpty
          ? rawTranscript
          : (rawSummary.isNotEmpty ? rawSummary : (isProcessing ? 'Transcribing audio...' : 'Voice Memo'));
    } else if (type == 'photo') {
      displayBody = rawTranscript.isNotEmpty
          ? rawTranscript
          : (rawSummary.isNotEmpty ? rawSummary : (isProcessing ? 'Analyzing photo...' : 'Photo Capture'));
    } else if (displayBody.isEmpty) {
      displayBody = rawSummary.isNotEmpty ? rawSummary : 'Thought capture';
    }

    IconData typeIcon;
    Color iconColor;
    Color iconBg;

    switch (type) {
      case 'voice':
        typeIcon = Icons.mic_rounded;
        iconColor = const Color(0xFF4A84D8);
        iconBg = const Color(0xFFE8F1FC);
        break;
      case 'photo':
        typeIcon = Icons.image_rounded;
        iconColor = const Color(0xFF389F7F);
        iconBg = const Color(0xFFE5F5F0);
        break;
      case 'text':
      default:
        typeIcon = Icons.edit_note_rounded;
        iconColor = const Color(0xFFFF7A1A);
        iconBg = const Color(0xFFFDE8D7);
        break;
    }

    return KeyedSubtree(
      key: ValueKey(dumpId.isNotEmpty ? dumpId : rawDate),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Timeline indicator line
            SizedBox(
              width: 36,
              child: Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: iconBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(typeIcon, size: 14, color: iconColor),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: const Color(0xFFECE7DE),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    DuskPageRoute.perspectiveSlide(
                      builder: (_) => DumpDetailScreen(dump: dump),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFF0EBE1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    type.toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: iconColor,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                                if (isProcessing) ...[
                                  const SizedBox(width: 8),
                                  const SizedBox(
                                    width: 10,
                                    height: 10,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF7A1A)),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Flexible(
                                    child: Text(
                                      'Refining...',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFFF7A1A),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            time,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF88827A),
                            ),
                          ),
                          if (dumpId.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _confirmInstantDelete(context, dumpId),
                              child: const Padding(
                                padding: EdgeInsets.all(2.0),
                                child: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 16,
                                  color: Color(0xFFBEB7AC),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (rawTitle.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: Text(
                            rawTitle,
                            key: ValueKey(rawTitle),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1B1A19),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: Text(
                          displayBody,
                          key: ValueKey(displayBody),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: rawTitle.isNotEmpty ? const Color(0xFF6E6862) : const Color(0xFF1B1A19),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmInstantDelete(BuildContext context, String dumpId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFFF9F7F2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          'Delete Capture?',
          style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1B1A19)),
        ),
        content: const Text(
          'Are you sure you want to delete this capture? This action cannot be undone.',
          style: TextStyle(color: Color(0xFF6E6862), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF88827A), fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<AppState>().deleteDump(dumpId);
            },
            child: const Text('Delete', style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
