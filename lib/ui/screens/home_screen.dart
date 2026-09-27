import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../providers/app_state.dart';
import '../../models/reflection_cycle.dart';
import '../../services/capture_service.dart';
import 'history_screen.dart';
import 'tasks_screen.dart';
import 'dump_detail_screen.dart';
import 'ai_cycle_summary_screen.dart';
import 'cycle_timeline_screen.dart';
import 'settings_screen.dart';
import '../widgets/offline_banner.dart';
import '../widgets/dusk_ui_components.dart';
import '../widgets/capture_speed_dial.dart';

class _NotchedSlotFabLocation extends StandardFabLocation
    with FabDockedOffsetY {
  final double centerRatio;

  const _NotchedSlotFabLocation({this.centerRatio = 0.5});

  @override
  double getOffsetX(
    ScaffoldPrelayoutGeometry scaffoldGeometry,
    double adjustment,
  ) {
    final double cx = scaffoldGeometry.scaffoldSize.width * centerRatio;
    return cx - scaffoldGeometry.floatingActionButtonSize.width / 2.0;
  }
}

enum TimePeriodPreset {
  allTime,
  today,
  yesterday,
  last7Days,
  last30Days,
  thisYear,
  customRange,
}

class DumpFilterOptions {
  TimePeriodPreset timePreset;
  DateTimeRange? customDateRange;
  String dumpType; // 'All', 'text', 'voice', 'photo'
  bool onlyWithMedia;
  String sortBy; // 'newest', 'oldest'

  DumpFilterOptions({
    this.timePreset = TimePeriodPreset.allTime,
    this.customDateRange,
    this.dumpType = 'All',
    this.onlyWithMedia = false,
    this.sortBy = 'newest',
  });

  DumpFilterOptions clone() {
    return DumpFilterOptions(
      timePreset: timePreset,
      customDateRange: customDateRange,
      dumpType: dumpType,
      onlyWithMedia: onlyWithMedia,
      sortBy: sortBy,
    );
  }

  bool get isDefault =>
      timePreset == TimePeriodPreset.allTime &&
      customDateRange == null &&
      dumpType == 'All' &&
      !onlyWithMedia &&
      sortBy == 'newest';

  int get activeFilterCount {
    int count = 0;
    if (timePreset != TimePeriodPreset.allTime) count++;
    if (dumpType != 'All') count++;
    if (onlyWithMedia) count++;
    if (sortBy != 'newest') count++;
    return count;
  }

  void reset() {
    timePreset = TimePeriodPreset.allTime;
    customDateRange = null;
    dumpType = 'All';
    onlyWithMedia = false;
    sortBy = 'newest';
  }

  String getTimeLabel() {
    switch (timePreset) {
      case TimePeriodPreset.allTime:
        return 'All Time';
      case TimePeriodPreset.today:
        return 'Today';
      case TimePeriodPreset.yesterday:
        return 'Yesterday';
      case TimePeriodPreset.last7Days:
        return 'Last 7 Days';
      case TimePeriodPreset.last30Days:
        return 'Last 30 Days';
      case TimePeriodPreset.thisYear:
        return 'This Year';
      case TimePeriodPreset.customRange:
        if (customDateRange != null) {
          final start = DateFormat('MMM d').format(customDateRange!.start);
          final end = DateFormat('MMM d, yyyy').format(customDateRange!.end);
          return '$start - $end';
        }
        return 'Custom Range';
    }
  }

  String getTypeLabel() {
    switch (dumpType.toLowerCase()) {
      case 'text':
        return 'Thoughts';
      case 'voice':
        return 'Voice Memos';
      case 'photo':
        return 'Moments';
      case 'all':
      default:
        return 'All Types';
    }
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pendingTasksCount = context.select<AppState, int>(
      (s) => s.pendingTasksCount,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F2),
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          CapturesFeedScreen(
            onOpenTasksTab: () => setState(() => _currentIndex = 1),
          ),
          const TasksScreen(),
          const HistoryScreen(),
          const SettingsScreen(),
        ],
      ),
      floatingActionButton: const Padding(
        padding: EdgeInsets.only(top: 12),
        child: CaptureSpeedDial(),
      ),
      floatingActionButtonLocation: const _NotchedSlotFabLocation(
        centerRatio: 0.5,
      ),
      bottomNavigationBar: DuskNotchedBottomBar(
        currentIndex: _currentIndex,
        pendingTasksCount: pendingTasksCount,
        notchCenterRatio: 0.5,
        onTabSelected: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}

// Backward compatibility alias for any existing references
typedef TodayScreen = CapturesFeedScreen;

class CapturesFeedScreen extends StatefulWidget {
  final VoidCallback? onOpenTasksTab;

  const CapturesFeedScreen({super.key, this.onOpenTasksTab});

  @override
  State<CapturesFeedScreen> createState() => _CapturesFeedScreenState();
}

class _CapturesFeedScreenState extends State<CapturesFeedScreen> {
  String _searchQuery = '';
  bool _isSearchVisible = false;
  int _chartMode = 0; // 0: 7-Day Activity, 1: Hourly Rhythm
  final TextEditingController _searchController = TextEditingController();
  final DumpFilterOptions _filterOptions = DumpFilterOptions();

  final List<String> _quickFilterTabs = ['All', 'Thoughts', 'Voice', 'Moments'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getGreeting(AppState appState) {
    final hour = DateTime.now().hour;
    final rawName = appState.preferredName;
    final displayName = rawName.isNotEmpty ? rawName : 'Friend';

    if (hour < 12) {
      return 'Morning, $displayName';
    } else if (hour < 17) {
      return 'Afternoon, $displayName';
    } else {
      return 'Evening, $displayName';
    }
  }

  DateTime? _parseDumpDate(dynamic rawDate) {
    if (rawDate == null) return null;
    if (rawDate is DateTime) return rawDate;
    try {
      return DateTime.parse(rawDate.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  bool _matchesTimeFilter(
    DateTime? date,
    TimePeriodPreset preset,
    DateTimeRange? customRange,
  ) {
    if (preset == TimePeriodPreset.allTime) return true;
    if (date == null) return false;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    switch (preset) {
      case TimePeriodPreset.today:
        return date.isAfter(todayStart.subtract(const Duration(milliseconds: 1))) &&
            date.isBefore(todayEnd.add(const Duration(milliseconds: 1)));

      case TimePeriodPreset.yesterday:
        final yesterdayStart = todayStart.subtract(const Duration(days: 1));
        final yesterdayEnd = todayEnd.subtract(const Duration(days: 1));
        return date.isAfter(yesterdayStart.subtract(const Duration(milliseconds: 1))) &&
            date.isBefore(yesterdayEnd.add(const Duration(milliseconds: 1)));

      case TimePeriodPreset.last7Days:
        final sevenDaysAgo = todayStart.subtract(const Duration(days: 7));
        return date.isAfter(sevenDaysAgo.subtract(const Duration(milliseconds: 1)));

      case TimePeriodPreset.last30Days:
        final thirtyDaysAgo = todayStart.subtract(const Duration(days: 30));
        return date.isAfter(thirtyDaysAgo.subtract(const Duration(milliseconds: 1)));

      case TimePeriodPreset.thisYear:
        final yearStart = DateTime(now.year, 1, 1);
        return date.isAfter(yearStart.subtract(const Duration(milliseconds: 1)));

      case TimePeriodPreset.customRange:
        if (customRange == null) return true;
        final start = DateTime(
          customRange.start.year,
          customRange.start.month,
          customRange.start.day,
        );
        final end = DateTime(
          customRange.end.year,
          customRange.end.month,
          customRange.end.day,
          23,
          59,
          59,
          999,
        );
        return date.isAfter(start.subtract(const Duration(milliseconds: 1))) &&
            date.isBefore(end.add(const Duration(milliseconds: 1)));

      case TimePeriodPreset.allTime:
        return true;
    }
  }

  String _formatCompactTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final isToday =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day;

    final timeStr = DateFormat('h:mm a').format(dt);
    if (isToday) return timeStr;
    if (isYesterday) return 'Yesterday • $timeStr';
    return '${DateFormat('MMM d').format(dt)} • $timeStr';
  }

  List<DuskBarData> _buildWeeklyBars(List<Map<String, dynamic>> dumps) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final List<DuskBarData> result = [];

    for (int i = 6; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      int count = 0;
      for (final d in dumps) {
        final dt = _parseDumpDate(d['captured_at'] ?? d['created_at']);
        if (dt != null &&
            dt.year == day.year &&
            dt.month == day.month &&
            dt.day == day.day) {
          count++;
        }
      }
      final dayLabel = DateFormat('E').format(day).substring(0, 2);
      result.add(
        DuskBarData(
          label: dayLabel,
          count: count,
          isHighlighted: i == 0,
        ),
      );
    }
    return result;
  }

  Map<String, int> _getTimeOfDayBuckets(List<Map<String, dynamic>> dumps) {
    int morning = 0, afternoon = 0, evening = 0, night = 0;
    for (final d in dumps) {
      final dt = _parseDumpDate(d['captured_at'] ?? d['created_at']);
      if (dt == null) continue;
      final h = dt.hour;
      if (h >= 5 && h < 12) {
        morning++;
      } else if (h >= 12 && h < 17) {
        afternoon++;
      } else if (h >= 17 && h < 22) {
        evening++;
      } else {
        night++;
      }
    }
    return {
      'Morning': morning,
      'Afternoon': afternoon,
      'Evening': evening,
      'Night': night,
    };
  }

  String _getPeakPeriodLabel(List<Map<String, dynamic>> dumps) {
    if (dumps.isEmpty) return 'No captures yet';
    final buckets = _getTimeOfDayBuckets(dumps);
    String bestKey = 'Evening';
    int bestVal = -1;
    buckets.forEach((k, v) {
      if (v > bestVal) {
        bestVal = v;
        bestKey = k;
      }
    });
    if (bestVal <= 0) return 'No captures yet';
    return 'Peak in the $bestKey';
  }

  String _getDominantTypeLabel(int thoughts, int voice, int photos) {
    if (thoughts == 0 && voice == 0 && photos == 0) return 'No captures';
    if (thoughts >= voice && thoughts >= photos) return 'Mostly Thoughts';
    if (voice >= thoughts && voice >= photos) return 'Mostly Voice';
    return 'Mostly Moments';
  }

  void _openAdvancedFilterDialog(
    BuildContext context,
    List<Map<String, dynamic>> allDumps,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AdvancedFilterSheet(
        initialOptions: _filterOptions,
        allDumps: allDumps,
        onApply: (newOptions) {
          setState(() {
            _filterOptions.timePreset = newOptions.timePreset;
            _filterOptions.customDateRange = newOptions.customDateRange;
            _filterOptions.dumpType = newOptions.dumpType;
            _filterOptions.onlyWithMedia = newOptions.onlyWithMedia;
            _filterOptions.sortBy = newOptions.sortBy;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DuskAmbientBackground(
      child: SafeArea(
        bottom: false,
        child: Consumer<AppState>(
          builder: (context, appState, child) {
            final hasActiveFilters = !_filterOptions.isDefault;
            final activeCount = _filterOptions.activeFilterCount;

            return Column(
              children: [
                const OfflineSyncBanner(),

                // Minimalist Top Bar: Brand + Compact Actions (Search, Filter, Settings)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                          border: Border.all(
                            color: const Color(0xFFEDE6DA),
                            width: 1,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.wb_twilight_rounded,
                            size: 20,
                            color: Color(0xFFFF7A1A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Dusk',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1B1A19),
                                letterSpacing: -0.4,
                                height: 1.1,
                              ),
                            ),
                            Text(
                              _getGreeting(appState),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF88827A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      DuskCircleButton(
                        icon: _isSearchVisible
                            ? Icons.close_rounded
                            : Icons.search_rounded,
                        size: 40,
                        iconSize: 19,
                        iconColor: _isSearchVisible || _searchQuery.isNotEmpty
                            ? const Color(0xFFFF7A1A)
                            : const Color(0xFF1B1A19),
                        tooltip: 'Search',
                        onTap: () {
                          setState(() {
                            _isSearchVisible = !_isSearchVisible;
                            if (!_isSearchVisible && _searchQuery.isNotEmpty) {
                              _searchQuery = '';
                              _searchController.clear();
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          DuskCircleButton(
                            icon: Icons.filter_list_rounded,
                            size: 40,
                            iconSize: 19,
                            iconColor: hasActiveFilters
                                ? const Color(0xFFFF7A1A)
                                : const Color(0xFF1B1A19),
                            tooltip: 'Filter',
                            onTap: () => _openAdvancedFilterDialog(
                              context,
                              appState.allDumps,
                            ),
                          ),
                          if (activeCount > 0)
                            Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFF7A1A),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '$activeCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Collapsible Search Input
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: _isSearchVisible
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            onChanged: (value) =>
                                setState(() => _searchQuery = value),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF1B1A19),
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search captures...',
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                size: 19,
                                color: Color(0xFFA59F95),
                              ),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.clear_rounded,
                                        size: 17,
                                        color: Color(0xFFA59F95),
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Color(0xFFECE7DE),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Color(0xFFECE7DE),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Color(0xFFFF7A1A),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),

                // Main Content Body
                Expanded(
                  child: Builder(
                    builder: (context) {
                      if (appState.isLoading) {
                        return const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFFFF7A1A),
                            ),
                          ),
                        );
                      }

                      final cycle = appState.currentCycle;
                      final bool isCompleted =
                          cycle?.status == CycleStatus.completed;

                      // Filter dumps
                      final filteredDumps = appState.allDumps.where((dump) {
                        final type =
                            dump['type']?.toString().toLowerCase() ?? '';
                        final content =
                            dump['content']?.toString().toLowerCase() ?? '';
                        final transcript =
                            dump['transcript']?.toString().toLowerCase() ?? '';
                        final title =
                            dump['title']?.toString().toLowerCase() ?? '';
                        final mediaUrl = dump['media_url']?.toString() ?? '';
                        final dumpDate = _parseDumpDate(
                          dump['captured_at'] ?? dump['created_at'],
                        );

                        if (_filterOptions.dumpType != 'All' &&
                            type != _filterOptions.dumpType.toLowerCase()) {
                          return false;
                        }

                        if (!_matchesTimeFilter(
                          dumpDate,
                          _filterOptions.timePreset,
                          _filterOptions.customDateRange,
                        )) {
                          return false;
                        }

                        if (_filterOptions.onlyWithMedia) {
                          final hasMedia =
                              (type == 'voice' || type == 'photo') ||
                              mediaUrl.isNotEmpty;
                          if (!hasMedia) return false;
                        }

                        if (_searchQuery.isNotEmpty) {
                          final q = _searchQuery.toLowerCase();
                          if (!content.contains(q) &&
                              !transcript.contains(q) &&
                              !title.contains(q)) {
                            return false;
                          }
                        }

                        return true;
                      }).toList();

                      // Sort
                      filteredDumps.sort((a, b) {
                        final dateA =
                            _parseDumpDate(a['captured_at'] ?? a['created_at']) ??
                            DateTime.fromMillisecondsSinceEpoch(0);
                        final dateB =
                            _parseDumpDate(b['captured_at'] ?? b['created_at']) ??
                            DateTime.fromMillisecondsSinceEpoch(0);
                        if (_filterOptions.sortBy == 'oldest') {
                          return dateA.compareTo(dateB);
                        }
                        return dateB.compareTo(dateA);
                      });

                      // Calculate Analytics
                      final thoughtCount = appState.allDumps
                          .where((d) => d['type'] == 'text')
                          .length;
                      final voiceCount = appState.allDumps
                          .where((d) => d['type'] == 'voice')
                          .length;
                      final photoCount = appState.allDumps
                          .where((d) => d['type'] == 'photo')
                          .length;
                      final totalCaptures = appState.allDumps.length;

                      final now = DateTime.now();
                      final todayCaptures = appState.allDumps.where((d) {
                        final dt =
                            _parseDumpDate(d['captured_at'] ?? d['created_at']);
                        return dt != null &&
                            dt.year == now.year &&
                            dt.month == now.month &&
                            dt.day == now.day;
                      }).length;

                      final weeklyBars = _buildWeeklyBars(appState.allDumps);
                      final int weeklyTotal = weeklyBars.fold(
                        0,
                        (sum, item) => sum + item.count,
                      );
                      final int activeDays = weeklyBars
                          .where((b) => b.count > 0)
                          .length;

                      final double progressPercentage = isCompleted
                          ? 1.0
                          : (totalCaptures / 4.0).clamp(0.0, 1.0);
                      final int progressPercentInt =
                          (progressPercentage * 100).round();

                      final chartSegments = [
                        DuskChartSegment(
                          label: 'Thoughts',
                          count: thoughtCount,
                          color: const Color(0xFFFF7A1A),
                          icon: Icons.notes_rounded,
                          filterKey: 'text',
                        ),
                        DuskChartSegment(
                          label: 'Voice',
                          count: voiceCount,
                          color: const Color(0xFF4A84D8),
                          icon: Icons.graphic_eq_rounded,
                          filterKey: 'voice',
                        ),
                        DuskChartSegment(
                          label: 'Moments',
                          count: photoCount,
                          color: const Color(0xFF2DC48D),
                          icon: Icons.image_rounded,
                          filterKey: 'photo',
                        ),
                      ];

                      int currentTabIndex = 0;
                      if (_filterOptions.dumpType.toLowerCase() == 'text') {
                        currentTabIndex = 1;
                      } else if (_filterOptions.dumpType.toLowerCase() ==
                          'voice') {
                        currentTabIndex = 2;
                      } else if (_filterOptions.dumpType.toLowerCase() ==
                          'photo') {
                        currentTabIndex = 3;
                      }

                      return RefreshIndicator(
                        color: const Color(0xFFFF7A1A),
                        backgroundColor: Colors.white,
                        displacement: 20,
                        onRefresh: () async {
                          await CaptureService().syncPendingDumps();
                          await appState.fetchAllDumps();
                        },
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(20, 6, 20, 110),
                          children: [
                            // CLEAN TABBED ANALYTICS CARD
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: const Color(0xFFEDE6DA),
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Simple 3-Tab Switcher Header
                                  Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF5F1EA),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: _buildChartModeChip(
                                            'Activity',
                                            0,
                                          ),
                                        ),
                                        Expanded(
                                          child: _buildChartModeChip(
                                            'Breakdown',
                                            1,
                                          ),
                                        ),
                                        Expanded(
                                          child: _buildChartModeChip(
                                            'Rhythm',
                                            2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  // Active Tab Content (One clean, full-width chart at a time)
                                  if (_chartMode == 0) ...[
                                    // TAB 0: 7-DAY ACTIVITY
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.baseline,
                                          textBaseline: TextBaseline.alphabetic,
                                          children: [
                                            Text(
                                              '$weeklyTotal',
                                              style: const TextStyle(
                                                fontSize: 26,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF1B1A19),
                                                letterSpacing: -0.6,
                                                height: 1.0,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            const Text(
                                              'past 7 days',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF88827A),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            DuskPillBadge(
                                              text: '$todayCaptures Today',
                                              variant: DuskBadgeVariant.peach,
                                            ),
                                            const SizedBox(width: 6),
                                            DuskPillBadge(
                                              text: '$activeDays/7 Days',
                                              variant: DuskBadgeVariant.neutral,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    DuskActivityBarChart(
                                      bars: weeklyBars,
                                      height: 124,
                                    ),
                                  ] else if (_chartMode == 1) ...[
                                    // TAB 1: CAPTURE TYPE BREAKDOWN
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.baseline,
                                          textBaseline: TextBaseline.alphabetic,
                                          children: [
                                            Text(
                                              '$totalCaptures',
                                              style: const TextStyle(
                                                fontSize: 26,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF1B1A19),
                                                letterSpacing: -0.6,
                                                height: 1.0,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            const Text(
                                              'total captures',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF88827A),
                                              ),
                                            ),
                                          ],
                                        ),
                                        DuskPillBadge(
                                          text: _getDominantTypeLabel(
                                            thoughtCount,
                                            voiceCount,
                                            photoCount,
                                          ),
                                          variant: DuskBadgeVariant.peach,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    DuskTypeBreakdownChart(
                                      segments: chartSegments,
                                      totalCount: totalCaptures,
                                      selectedType: _filterOptions.dumpType,
                                      onSelectType: (key) {
                                        setState(() {
                                          if (_filterOptions.dumpType
                                                  .toLowerCase() ==
                                              key.toLowerCase()) {
                                            _filterOptions.dumpType = 'All';
                                          } else {
                                            _filterOptions.dumpType = key;
                                          }
                                        });
                                      },
                                    ),
                                  ] else ...[
                                    // TAB 2: TIME-OF-DAY RHYTHM
                                    _buildRhythmTabContent(
                                      appState.allDumps,
                                      progressPercentInt,
                                    ),
                                  ],

                                  // Compact Evening Ritual Strip
                                  if (cycle != null) ...[
                                    const SizedBox(height: 14),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 9,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFDF6EE),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: const Color(0xFFF6E4D2),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.nights_stay_rounded,
                                            size: 15,
                                            color: Color(0xFFFF7A1A),
                                          ),
                                          const SizedBox(width: 7),
                                          Expanded(
                                            child: Text(
                                              isCompleted
                                                  ? 'Reflection complete'
                                                  : '9:00 PM Ritual • $progressPercentInt% ready',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF1B1A19),
                                              ),
                                            ),
                                          ),
                                          InkWell(
                                            onTap: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      CycleTimelineScreen(
                                                        cycleId: cycle.id,
                                                      ),
                                                ),
                                              );
                                            },
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.timeline_rounded,
                                                    size: 14,
                                                    color: Color(0xFF6E6862),
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'Timeline',
                                                    style: TextStyle(
                                                      fontSize: 11.5,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Color(0xFF6E6862),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          if (!isCompleted) ...[
                                            const SizedBox(width: 6),
                                            GestureDetector(
                                              onTap: () {
                                                Navigator.of(context)
                                                    .push(
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            AiCycleSummaryScreen(
                                                              cycleId: cycle.id,
                                                            ),
                                                      ),
                                                    )
                                                    .then((_) {
                                                      if (!context.mounted) {
                                                        return;
                                                      }
                                                      context
                                                          .read<AppState>()
                                                          .fetchAllDumps();
                                                    });
                                              },
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 11,
                                                      vertical: 5,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFFF7A1A,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: const Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .auto_awesome_rounded,
                                                      size: 12,
                                                      color: Colors.white,
                                                    ),
                                                    SizedBox(width: 4),
                                                    Text(
                                                      'Reflect',
                                                      style: TextStyle(
                                                        fontSize: 11.5,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.03),

                            const SizedBox(height: 16),

                            // Quick Type Filter Pill Tabs
                            DuskPillTabBar(
                              tabs: _quickFilterTabs,
                              selectedIndex: currentTabIndex,
                              onTabSelected: (index) {
                                setState(() {
                                  if (index == 0) {
                                    _filterOptions.dumpType = 'All';
                                  }
                                  if (index == 1) {
                                    _filterOptions.dumpType = 'text';
                                  }
                                  if (index == 2) {
                                    _filterOptions.dumpType = 'voice';
                                  }
                                  if (index == 3) {
                                    _filterOptions.dumpType = 'photo';
                                  }
                                });
                              },
                            ),

                            if (!_filterOptions.isDefault)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Showing ${filteredDumps.length} filtered',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF88827A),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => setState(
                                        () => _filterOptions.reset(),
                                      ),
                                      child: const Text(
                                        'Clear filters',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFFFF7A1A),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            const SizedBox(height: 12),

                            // Captures Feed List
                            if (filteredDumps.isEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 32,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: const Color(0xFFF0EBE1),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFDE8D7),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.add_rounded,
                                        color: Color(0xFFFF7A1A),
                                        size: 26,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _searchQuery.isEmpty &&
                                              _filterOptions.isDefault
                                          ? 'No captures yet'
                                          : 'No matches found',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1B1A19),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _searchQuery.isEmpty &&
                                              _filterOptions.isDefault
                                          ? 'Tap + to capture a thought, voice note, or moment.'
                                          : 'Try adjusting your filters or search.',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: Color(0xFF88827A),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ...filteredDumps.asMap().entries.map((entry) {
                                final int index = entry.key;
                                final dump = entry.value;
                                return _buildStreamlinedCaptureCard(
                                  context,
                                  dump,
                                  index,
                                );
                              }),
                          ],
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
    );
  }

  Widget _buildRhythmTabContent(
    List<Map<String, dynamic>> dumps,
    int readinessPercent,
  ) {
    final buckets = _getTimeOfDayBuckets(dumps);
    final total = dumps.length;

    final items = [
      (
        label: 'Morning',
        sub: '5a–12p',
        count: buckets['Morning'] ?? 0,
        icon: Icons.wb_sunny_outlined,
        color: const Color(0xFFF59E0B),
      ),
      (
        label: 'Afternoon',
        sub: '12p–5p',
        count: buckets['Afternoon'] ?? 0,
        icon: Icons.light_mode_rounded,
        color: const Color(0xFFFF7A1A),
      ),
      (
        label: 'Evening',
        sub: '5p–10p',
        count: buckets['Evening'] ?? 0,
        icon: Icons.wb_twilight_rounded,
        color: const Color(0xFF4A84D8),
      ),
      (
        label: 'Night',
        sub: '10p–5a',
        count: buckets['Night'] ?? 0,
        icon: Icons.nights_stay_outlined,
        color: const Color(0xFF2DC48D),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _getPeakPeriodLabel(dumps),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1B1A19),
              ),
            ),
            DuskPillBadge(
              text: 'Time of Day',
              variant: DuskBadgeVariant.blue,
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...items.map((item) {
          final double ratio = total > 0
              ? (item.count / total).clamp(0.0, 1.0)
              : 0.0;
          final int pct = (ratio * 100).round();

          return Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(
              children: [
                Icon(item.icon, size: 16, color: item.color),
                const SizedBox(width: 8),
                SizedBox(
                  width: 74,
                  child: Text(
                    item.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B1A19),
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 8,
                      child: Stack(
                        children: [
                          Container(color: const Color(0xFFF2ECE2)),
                          FractionallySizedBox(
                            widthFactor: ratio == 0 ? 0.02 : ratio,
                            child: Container(
                              decoration: BoxDecoration(
                                color: item.count > 0
                                    ? item.color
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 52,
                  child: Text(
                    '${item.count} ($pct%)',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6E6862),
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

  Widget _buildChartModeChip(String label, int mode) {
    final isSelected = _chartMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _chartMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 7),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected
                ? const Color(0xFF1B1A19)
                : const Color(0xFF88827A),
          ),
        ),
      ),
    );
  }

  Widget _buildStreamlinedCaptureCard(
    BuildContext context,
    Map<String, dynamic> dump,
    int index,
  ) {
    final type = dump['type']?.toString().toLowerCase() ?? 'text';
    final dumpDate = _parseDumpDate(dump['captured_at'] ?? dump['created_at']);

    Color accentColor;
    Color badgeBg;
    String defaultLabel;
    IconData typeIcon;

    if (type == 'voice') {
      accentColor = const Color(0xFF4A84D8);
      badgeBg = const Color(0xFFEAF2FC);
      defaultLabel = 'Voice Memo';
      typeIcon = Icons.graphic_eq_rounded;
    } else if (type == 'photo') {
      accentColor = const Color(0xFF2DC48D);
      badgeBg = const Color(0xFFE6F6F0);
      defaultLabel = 'Moment';
      typeIcon = Icons.image_rounded;
    } else {
      accentColor = const Color(0xFFFF7A1A);
      badgeBg = const Color(0xFFFDE8D7);
      defaultLabel = 'Thought';
      typeIcon = Icons.notes_rounded;
    }

    final rawTitle = dump['title'] ?? dump['category'];
    final String fallbackText = (type == 'voice' || type == 'photo'
            ? (dump['transcript'] ?? dump['content'] ?? '')
            : (dump['content'] ?? dump['transcript'] ?? ''))
        .toString()
        .trim();

    final String title = (rawTitle != null &&
            rawTitle.toString().trim().isNotEmpty &&
            rawTitle.toString().toLowerCase() != 'null')
        ? rawTitle.toString().trim()
        : (fallbackText.isNotEmpty ? fallbackText : defaultLabel);

    final String dumpId = dump['id']?.toString() ?? 'dump_$index';
    final bool isProcessing =
        dump['is_processing'] == true || CaptureService().isProcessing(dumpId);

    final String timeLabel = _formatCompactTime(dumpDate);
    final String? mediaUrl = dump['media_url']?.toString();
    final bool hasPhoto =
        type == 'photo' && mediaUrl != null && mediaUrl.isNotEmpty;

    return GestureDetector(
      key: ValueKey(dumpId),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DumpDetailScreen(dump: dump)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: const BoxConstraints(minHeight: 80),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFEEE8DE), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.025),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Leading Type Icon Squircle
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(typeIcon, size: 21, color: accentColor),
            ),
            const SizedBox(width: 14),

            // Full Title & Timestamp (re-renders immediately when background AI processing finishes)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    layoutBuilder: (currentChild, previousChildren) {
                      return Stack(
                        alignment: Alignment.centerLeft,
                        children: <Widget>[
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      );
                    },
                    child: Text(
                      title,
                      key: ValueKey('${dumpId}_$title'),
                      softWrap: true,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B1A19),
                        letterSpacing: -0.15,
                        height: 1.32,
                      ),
                    ),
                  ),
                  if (timeLabel.isNotEmpty || isProcessing) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        if (timeLabel.isNotEmpty)
                          Text(
                            timeLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF9A938A),
                            ),
                          ),
                        if (isProcessing) ...[
                          if (timeLabel.isNotEmpty)
                            const Text(
                              ' • ',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFFBEB7AC),
                              ),
                            ),
                          SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.6,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                accentColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Refining...',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Small Preview of Image for Image Dumps
            if (hasPhoto) ...[
              const SizedBox(width: 10),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEDE6DA), width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: (mediaUrl.startsWith('/') || mediaUrl.contains(r':\'))
                      ? Image.file(
                          File(mediaUrl),
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(
                            color: const Color(0xFFF4EFEA),
                            child: const Icon(
                              Icons.broken_image_rounded,
                              size: 18,
                              color: Color(0xFFA59F95),
                            ),
                          ),
                        )
                      : Image.network(
                          mediaUrl,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(
                            color: const Color(0xFFF4EFEA),
                            child: const Icon(
                              Icons.broken_image_rounded,
                              size: 18,
                              color: Color(0xFFA59F95),
                            ),
                          ),
                        ),
                ),
              ),
            ],

            const SizedBox(width: 4),

            // More Actions Menu
            SizedBox(
              width: 36,
              height: 36,
              child: PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.more_vert_rounded,
                  size: 24,
                  color: Color(0xFF88827A),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                onSelected: (value) {
                  if (value == 'copy') {
                    Clipboard.setData(
                      ClipboardData(
                        text: fallbackText.isNotEmpty ? fallbackText : title,
                      ),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copied to clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  } else if (value == 'delete') {
                    // Instant optimistic UI deletion (background local DB + cloud delete)
                    context.read<AppState>().deleteDump(dumpId);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'copy',
                    child: Row(
                      children: [
                        Icon(
                          Icons.copy_rounded,
                          size: 17,
                          color: Color(0xFF1B1A19),
                        ),
                        SizedBox(width: 10),
                        Text('Copy'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 17,
                          color: Colors.red,
                        ),
                        SizedBox(width: 10),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Advanced Filter Modal Bottom Sheet
class _AdvancedFilterSheet extends StatefulWidget {
  final DumpFilterOptions initialOptions;
  final List<Map<String, dynamic>> allDumps;
  final ValueChanged<DumpFilterOptions> onApply;

  const _AdvancedFilterSheet({
    required this.initialOptions,
    required this.allDumps,
    required this.onApply,
  });

  @override
  State<_AdvancedFilterSheet> createState() => _AdvancedFilterSheetState();
}

class _AdvancedFilterSheetState extends State<_AdvancedFilterSheet> {
  late DumpFilterOptions _tempOptions;

  @override
  void initState() {
    super.initState();
    _tempOptions = widget.initialOptions.clone();
  }

  int _calculateMatchingCount() {
    return widget.allDumps.where((dump) {
      final type = dump['type']?.toString().toLowerCase() ?? '';
      final mediaUrl = dump['media_url']?.toString() ?? '';
      final rawDate = dump['captured_at'] ?? dump['created_at'];
      DateTime? dumpDate;
      if (rawDate != null) {
        try {
          dumpDate = DateTime.parse(rawDate.toString()).toLocal();
        } catch (_) {}
      }

      if (_tempOptions.dumpType != 'All' && type != _tempOptions.dumpType.toLowerCase()) {
        return false;
      }

      if (!_matchesTimeFilter(dumpDate, _tempOptions.timePreset, _tempOptions.customDateRange)) {
        return false;
      }

      if (_tempOptions.onlyWithMedia) {
        final hasMedia = (type == 'voice' || type == 'photo') || mediaUrl.isNotEmpty;
        if (!hasMedia) return false;
      }

      return true;
    }).length;
  }

  bool _matchesTimeFilter(DateTime? date, TimePeriodPreset preset, DateTimeRange? customRange) {
    if (preset == TimePeriodPreset.allTime) return true;
    if (date == null) return false;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    switch (preset) {
      case TimePeriodPreset.today:
        return date.isAfter(todayStart.subtract(const Duration(milliseconds: 1))) &&
               date.isBefore(todayEnd.add(const Duration(milliseconds: 1)));

      case TimePeriodPreset.yesterday:
        final yesterdayStart = todayStart.subtract(const Duration(days: 1));
        final yesterdayEnd = todayEnd.subtract(const Duration(days: 1));
        return date.isAfter(yesterdayStart.subtract(const Duration(milliseconds: 1))) &&
               date.isBefore(yesterdayEnd.add(const Duration(milliseconds: 1)));

      case TimePeriodPreset.last7Days:
        final sevenDaysAgo = todayStart.subtract(const Duration(days: 7));
        return date.isAfter(sevenDaysAgo.subtract(const Duration(milliseconds: 1)));

      case TimePeriodPreset.last30Days:
        final thirtyDaysAgo = todayStart.subtract(const Duration(days: 30));
        return date.isAfter(thirtyDaysAgo.subtract(const Duration(milliseconds: 1)));

      case TimePeriodPreset.thisYear:
        final yearStart = DateTime(now.year, 1, 1);
        return date.isAfter(yearStart.subtract(const Duration(milliseconds: 1)));

      case TimePeriodPreset.customRange:
        if (customRange == null) return true;
        final start = DateTime(customRange.start.year, customRange.start.month, customRange.start.day);
        final end = DateTime(customRange.end.year, customRange.end.month, customRange.end.day, 23, 59, 59, 999);
        return date.isAfter(start.subtract(const Duration(milliseconds: 1))) &&
               date.isBefore(end.add(const Duration(milliseconds: 1)));

      case TimePeriodPreset.allTime:
        return true;
    }
  }

  Future<void> _selectCustomDateRange() async {
    final now = DateTime.now();
    final initialRange = _tempOptions.customDateRange ??
        DateTimeRange(
          start: now.subtract(const Duration(days: 14)),
          end: now,
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: initialRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFF7A1A),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1B1A19),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _tempOptions.timePreset = TimePeriodPreset.customRange;
        _tempOptions.customDateRange = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final matchingCount = _calculateMatchingCount();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2DDD5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Dialog Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Advanced Filters',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B1A19),
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Refine captures by period and type',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF8E8880),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() => _tempOptions.reset());
                },
                child: const Text(
                  'Reset',
                  style: TextStyle(
                    color: Color(0xFFFF7A1A),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.55,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // SECTION 1: TIME PERIOD
                  Row(
                    children: const [
                      Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFFFF7A1A)),
                      SizedBox(width: 8),
                      Text(
                        'Time Period',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B1A19),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildPresetChip('All Time', TimePeriodPreset.allTime),
                      _buildPresetChip('Today', TimePeriodPreset.today),
                      _buildPresetChip('Yesterday', TimePeriodPreset.yesterday),
                      _buildPresetChip('Last 7 Days', TimePeriodPreset.last7Days),
                      _buildPresetChip('Last 30 Days', TimePeriodPreset.last30Days),
                      _buildPresetChip('This Year', TimePeriodPreset.thisYear),
                      _buildPresetChip('Custom Range', TimePeriodPreset.customRange, onTap: _selectCustomDateRange),
                    ],
                  ),

                  // Custom Range Display Box
                  if (_tempOptions.timePreset == TimePeriodPreset.customRange && _tempOptions.customDateRange != null) ...[
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: _selectCustomDateRange,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDE8D7),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFF7A1A).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.date_range_rounded, size: 16, color: Color(0xFFFF7A1A)),
                                const SizedBox(width: 8),
                                Text(
                                  _tempOptions.getTimeLabel(),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1B1A19),
                                  ),
                                ),
                              ],
                            ),
                            const Text(
                              'Change',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFFF7A1A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // SECTION 2: CAPTURE TYPE
                  Row(
                    children: const [
                      Icon(Icons.category_rounded, size: 18, color: Color(0xFF4A84D8)),
                      SizedBox(width: 8),
                      Text(
                        'Capture Type',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B1A19),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildTypeChip('All Types', 'All', Icons.apps_rounded),
                      _buildTypeChip('Thoughts', 'text', Icons.notes_rounded),
                      _buildTypeChip('Voice Memos', 'voice', Icons.graphic_eq_rounded),
                      _buildTypeChip('Moments', 'photo', Icons.image_rounded),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // SECTION 3: SORT ORDER
                  Row(
                    children: const [
                      Icon(Icons.sort_rounded, size: 18, color: Color(0xFF2DC48D)),
                      SizedBox(width: 8),
                      Text(
                        'Sort Order',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B1A19),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSortButton('Newest First', 'newest', Icons.arrow_downward_rounded),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildSortButton('Oldest First', 'oldest', Icons.arrow_upward_rounded),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // SECTION 4: EXTRA OPTIONS
                  Row(
                    children: const [
                      Icon(Icons.tune_rounded, size: 18, color: Color(0xFF8E8880)),
                      SizedBox(width: 8),
                      Text(
                        'Content Options',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B1A19),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Only captures with media attachments',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1B1A19)),
                    ),
                    subtitle: const Text(
                      'Shows only voice recordings and photos',
                      style: TextStyle(fontSize: 12, color: Color(0xFF8E8880)),
                    ),
                    value: _tempOptions.onlyWithMedia,
                    activeThumbColor: const Color(0xFFFF7A1A),
                    onChanged: (val) {
                      setState(() => _tempOptions.onlyWithMedia = val);
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Bottom Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    side: const BorderSide(color: Color(0xFFECE7DE)),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Color(0xFF767068),
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(_tempOptions);
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7A1A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text(
                    matchingCount == 1 ? 'Show 1 Capture' : 'Show $matchingCount Captures',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, TimePeriodPreset preset, {VoidCallback? onTap}) {
    final isSelected = _tempOptions.timePreset == preset;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (onTap != null && (!isSelected || preset == TimePeriodPreset.customRange)) {
          onTap();
        } else if (selected) {
          setState(() {
            _tempOptions.timePreset = preset;
            if (preset != TimePeriodPreset.customRange) {
              _tempOptions.customDateRange = null;
            }
          });
        }
      },
      selectedColor: const Color(0xFFFDE8D7),
      backgroundColor: const Color(0xFFF7F4EE),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? const Color(0xFFC75505) : const Color(0xFF6E6862),
      ),
      side: BorderSide(
        color: isSelected ? const Color(0xFFFF7A1A) : const Color(0xFFECE7DE),
        width: 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      showCheckmark: false,
    );
  }

  Widget _buildTypeChip(String label, String value, IconData icon) {
    final isSelected = _tempOptions.dumpType.toLowerCase() == value.toLowerCase();
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? const Color(0xFFC75505) : const Color(0xFF8E8880),
      ),
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _tempOptions.dumpType = value);
        }
      },
      selectedColor: const Color(0xFFFDE8D7),
      backgroundColor: const Color(0xFFF7F4EE),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? const Color(0xFFC75505) : const Color(0xFF6E6862),
      ),
      side: BorderSide(
        color: isSelected ? const Color(0xFFFF7A1A) : const Color(0xFFECE7DE),
        width: 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      showCheckmark: false,
    );
  }

  Widget _buildSortButton(String label, String value, IconData icon) {
    final isSelected = _tempOptions.sortBy == value;
    return InkWell(
      onTap: () => setState(() => _tempOptions.sortBy = value),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFDE8D7) : const Color(0xFFF7F4EE),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF7A1A) : const Color(0xFFECE7DE),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? const Color(0xFFC75505) : const Color(0xFF6E6862),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFFC75505) : const Color(0xFF6E6862),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
