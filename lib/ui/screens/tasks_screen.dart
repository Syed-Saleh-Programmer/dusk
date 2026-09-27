import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/task_item.dart';
import '../../providers/app_state.dart';
import '../../services/task_service.dart';
import '../widgets/dusk_ui_components.dart';
import 'dump_detail_screen.dart';

enum TaskDueFilter {
  all,
  dueToday,
  upcoming,
  overdue,
  hasDeadline,
}

class TasksScreen extends StatefulWidget {
  final bool showBackButton;

  const TasksScreen({
    super.key,
    this.showBackButton = false,
  });

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  int _statusTabIndex = 0; // 0: To Do, 1: Done, 2: Archived
  String _sourceFilter = 'all'; // 'all', 'dump', 'insight', 'manual'
  TaskDueFilter _dueFilter = TaskDueFilter.all;
  bool _isSearchOpen = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppState>().syncTasks();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasActiveFilters =>
      _sourceFilter != 'all' || _dueFilter != TaskDueFilter.all;

  int get _activeFilterCount {
    int count = 0;
    if (_sourceFilter != 'all') count++;
    if (_dueFilter != TaskDueFilter.all) count++;
    return count;
  }

  String _getDueFilterLabel(TaskDueFilter filter) {
    switch (filter) {
      case TaskDueFilter.all:
        return 'Any Time';
      case TaskDueFilter.dueToday:
        return 'Due Today';
      case TaskDueFilter.upcoming:
        return 'Upcoming';
      case TaskDueFilter.overdue:
        return 'Overdue';
      case TaskDueFilter.hasDeadline:
        return 'With Deadline';
    }
  }

  String _getSourceFilterLabel(String source) {
    switch (source) {
      case 'dump':
        return 'From Captures';
      case 'insight':
        return 'Reflections';
      case 'manual':
        return 'Quick Tasks';
      default:
        return 'All Sources';
    }
  }

  bool _matchesDueFilter(TaskItem task, TaskDueFilter filter) {
    if (filter == TaskDueFilter.all) return true;
    if (task.dueDate == null) return false;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final localDue = task.dueDate!.toLocal();
    final dueDay = DateTime(localDue.year, localDue.month, localDue.day);

    switch (filter) {
      case TaskDueFilter.dueToday:
        return dueDay.isAtSameMomentAs(todayStart);
      case TaskDueFilter.upcoming:
        return !dueDay.isBefore(todayStart);
      case TaskDueFilter.overdue:
        return dueDay.isBefore(todayStart) && !task.isDone;
      case TaskDueFilter.hasDeadline:
        return true;
      case TaskDueFilter.all:
        return true;
    }
  }

  List<TaskItem> _filterTasks(List<TaskItem> allTasks) {
    return allTasks.where((t) {
      if (_sourceFilter != 'all' && t.sourceType.name != _sourceFilter) {
        return false;
      }

      if (!_matchesDueFilter(t, _dueFilter)) {
        return false;
      }

      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final matchTitle = t.title.toLowerCase().contains(q);
        final matchSource = (t.sourceLabel ?? '').toLowerCase().contains(q);
        if (!matchTitle && !matchSource) return false;
      }

      return true;
    }).toList();
  }

  /// Sort active tasks so items with deadlines come first (earliest due date first),
  /// followed by tasks without deadlines (newest created first).
  List<TaskItem> _sortActiveTasks(List<TaskItem> list) {
    final sorted = List<TaskItem>.from(list);
    sorted.sort((a, b) {
      if (a.dueDate != null && b.dueDate != null) {
        final cmp = a.dueDate!.compareTo(b.dueDate!);
        if (cmp != 0) return cmp;
      } else if (a.dueDate != null && b.dueDate == null) {
        return -1;
      } else if (a.dueDate == null && b.dueDate != null) {
        return 1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return sorted;
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final maxSheetHeight = MediaQuery.of(ctx).size.height * 0.85;
            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxSheetHeight),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2DDD5),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Filter Tasks',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1B1A19),
                              ),
                            ),
                          ),
                          if (_hasActiveFilters)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _sourceFilter = 'all';
                                  _dueFilter = TaskDueFilter.all;
                                });
                                Navigator.pop(ctx);
                              },
                              child: const Padding(
                                padding: EdgeInsets.only(left: 12),
                                child: Text(
                                  'Reset',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFFF7A1A),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Flexible(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'DEADLINE',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.9,
                                  color: Color(0xFF88827A),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: TaskDueFilter.values.map((f) {
                                  final isSelected = _dueFilter == f;
                                  return _buildFilterOptionChip(
                                    label: _getDueFilterLabel(f),
                                    isSelected: isSelected,
                                    onTap: () {
                                      setModalState(() => _dueFilter = f);
                                      setState(() => _dueFilter = f);
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'SOURCE',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.9,
                                  color: Color(0xFF88827A),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final entry in const [
                                    ('all', 'All Sources'),
                                    ('manual', 'Quick Tasks'),
                                    ('dump', 'From Captures'),
                                    ('insight', 'Reflections'),
                                  ])
                                    _buildFilterOptionChip(
                                      label: entry.$2,
                                      isSelected: _sourceFilter == entry.$1,
                                      onTap: () {
                                        setModalState(
                                          () => _sourceFilter = entry.$1,
                                        );
                                        setState(
                                          () => _sourceFilter = entry.$1,
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      DuskPrimaryButton(
                        label: 'Done',
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterOptionChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1B1A19)
              : const Color(0xFFF6F3EC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1B1A19)
                : const Color(0xFFE8E2D8),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF5E5850),
          ),
        ),
      ),
    );
  }

  String _buildSubtitle(List<TaskItem> activeTasks) {
    if (activeTasks.isEmpty) return 'All caught up';
    final dueTodayOrOverdue =
        activeTasks.where((t) => t.isDueToday || t.isOverdue).length;
    if (dueTodayOrOverdue > 0) {
      return '${activeTasks.length} pending • $dueTodayOrOverdue due today';
    }
    return '${activeTasks.length} ${activeTasks.length == 1 ? 'task' : 'tasks'} pending';
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final filtered = _filterTasks(appState.tasks);

    final activeTasks = _sortActiveTasks(
      filtered.where((t) => t.status == TaskStatus.pending).toList(),
    );
    final doneTasks =
        filtered.where((t) => t.status == TaskStatus.done).toList();
    final archivedTasks =
        filtered.where((t) => t.status == TaskStatus.archived).toList();

    final displayedTasks = _statusTabIndex == 0
        ? activeTasks
        : _statusTabIndex == 1
            ? doneTasks
            : archivedTasks;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F2),
      body: DuskAmbientBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Minimal Header Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                child: Row(
                  children: [
                    if (widget.showBackButton) ...[
                      DuskCircleButton(
                        icon: Icons.arrow_back_rounded,
                        size: 40,
                        iconSize: 19,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Tasks',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1B1A19),
                              letterSpacing: -0.4,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _buildSubtitle(activeTasks),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF88827A),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DuskCircleButton(
                      icon: _isSearchOpen
                          ? Icons.close_rounded
                          : Icons.search_rounded,
                      size: 40,
                      iconSize: 19,
                      iconColor: _isSearchOpen || _searchQuery.isNotEmpty
                          ? const Color(0xFFFF7A1A)
                          : const Color(0xFF1B1A19),
                      tooltip: 'Search tasks',
                      onTap: () {
                        setState(() {
                          _isSearchOpen = !_isSearchOpen;
                          if (!_isSearchOpen) {
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
                          icon: Icons.tune_rounded,
                          size: 40,
                          iconSize: 19,
                          iconColor: _hasActiveFilters
                              ? const Color(0xFFFF7A1A)
                              : const Color(0xFF1B1A19),
                          tooltip: 'Filter tasks',
                          onTap: _openFilterSheet,
                        ),
                        if (_activeFilterCount > 0)
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
                                  '$_activeFilterCount',
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
                    const SizedBox(width: 8),
                    DuskCircleButton(
                      icon: Icons.ios_share_rounded,
                      size: 40,
                      iconSize: 18,
                      tooltip: 'Export tasks',
                      onTap: () => showTaskExportModal(
                        context,
                        tasks: displayedTasks.isNotEmpty
                            ? displayedTasks
                            : filtered,
                        periodLabel: _getDueFilterLabel(_dueFilter),
                      ),
                    ),
                  ],
                ),
              ),

              // Collapsible Search Input
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: _isSearchOpen
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF1B1A19),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search tasks...',
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
                          onChanged: (val) =>
                              setState(() => _searchQuery = val),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              const SizedBox(height: 4),

              // 2. Clean Status Segmented Tab Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: DuskPillTabBar(
                  tabs: [
                    'To Do (${activeTasks.length})',
                    'Done (${doneTasks.length})',
                    'Archived (${archivedTasks.length})',
                  ],
                  selectedIndex: _statusTabIndex,
                  onTabSelected: (idx) => setState(() => _statusTabIndex = idx),
                ),
              ),

              // Subtle active filter summary bar (only shown when filters are applied)
              if (_hasActiveFilters)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.filter_alt_outlined,
                        size: 14,
                        color: Color(0xFF88827A),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          [
                            if (_dueFilter != TaskDueFilter.all)
                              _getDueFilterLabel(_dueFilter),
                            if (_sourceFilter != 'all')
                              _getSourceFilterLabel(_sourceFilter),
                          ].join(' • '),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6E6862),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _sourceFilter = 'all';
                            _dueFilter = TaskDueFilter.all;
                          });
                        },
                        child: const Text(
                          'Clear',
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

              // 3. Minimal Tasks List
              Expanded(
                child: RefreshIndicator(
                  color: const Color(0xFFFF7A1A),
                  backgroundColor: Colors.white,
                  onRefresh: () => context.read<AppState>().syncTasks(),
                  child: displayedTasks.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(20, 2, 20, 115),
                          itemCount: displayedTasks.length,
                          itemBuilder: (context, index) {
                            final task = displayedTasks[index];
                            return _buildTaskCard(task, appState, index);
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String title;
    String subtitle;
    IconData icon;

    if (_statusTabIndex == 1) {
      title = 'No completed tasks yet';
      subtitle = 'Tasks you check off will rest here.';
      icon = Icons.check_circle_outline_rounded;
    } else if (_statusTabIndex == 2) {
      title = 'No archived tasks';
      subtitle = 'Swipe left on any task to archive it.';
      icon = Icons.inventory_2_outlined;
    } else {
      title = 'All clear';
      subtitle =
          'Tap the + button below to create a quick task, or capture a thought.';
      icon = Icons.task_alt_rounded;
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFF0EBE1)),
                ),
                child: Icon(icon, size: 24, color: const Color(0xFFA59F95)),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1B1A19),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF88827A),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTaskCard(TaskItem task, AppState appState, int index) {
    final isInsight = task.sourceType == TaskSourceType.insight;
    final isDump = task.sourceType == TaskSourceType.dump;

    final sourceIcon = isInsight
        ? Icons.auto_awesome_rounded
        : isDump
            ? Icons.notes_rounded
            : Icons.bolt_rounded;

    final sourceText =
        (task.sourceLabel != null && task.sourceLabel!.trim().isNotEmpty)
            ? task.sourceLabel!.trim()
            : isInsight
                ? 'Reflection'
                : isDump
                    ? 'From Capture'
                    : 'Quick Task';

    return Dismissible(
      key: ValueKey('task_${task.id}_${task.status.name}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: task.isArchived
              ? const Color(0xFFE84F6E).withValues(alpha: 0.14)
              : const Color(0xFFF0EBE3),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(
          task.isArchived
              ? Icons.delete_outline_rounded
              : Icons.archive_outlined,
          size: 20,
          color: task.isArchived
              ? const Color(0xFFE84F6E)
              : const Color(0xFF6E6862),
        ),
      ),
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        if (task.isArchived) {
          appState.deleteTask(task.id);
        } else {
          appState.archiveTask(task.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Task archived'),
              duration: const Duration(seconds: 2),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () => appState.unarchiveTask(task.id),
              ),
            ),
          );
        }
      },
      child: GestureDetector(
        onTap: () => showQuickTaskSheet(context, existingTask: task),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: task.isOverdue
                  ? const Color(0xFFE84F6E).withValues(alpha: 0.32)
                  : task.isDone
                      ? const Color(0xFF389F7F).withValues(alpha: 0.22)
                      : const Color(0xFFF0EBE1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Clean circular checkbox
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.lightImpact();
                  appState.toggleTaskDone(task.id);
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 13, top: 2, bottom: 2),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: task.isDone
                          ? const Color(0xFF389F7F)
                          : Colors.transparent,
                      border: Border.all(
                        color: task.isDone
                            ? const Color(0xFF389F7F)
                            : task.isOverdue
                                ? const Color(0xFFE84F6E)
                                : const Color(0xFFD5CEC4),
                        width: 1.8,
                      ),
                    ),
                    child: task.isDone
                        ? const Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
              ),

              // 2. Title & quiet source subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: task.isDone
                            ? const Color(0xFFA59F95)
                            : const Color(0xFF1B1A19),
                        decoration: task.isDone
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: task.dumpId != null
                          ? () {
                              final dump = appState.allDumps
                                  .cast<Map<String, dynamic>?>()
                                  .firstWhere(
                                    (d) => d?['id']?.toString() == task.dumpId,
                                    orElse: () => null,
                                  );
                              if (dump != null) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        DumpDetailScreen(dump: dump),
                                  ),
                                );
                              }
                            }
                          : null,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            sourceIcon,
                            size: 12,
                            color: const Color(0xFFA59F95),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              sourceText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF9E978E),
                                decoration: task.dumpId != null
                                    ? TextDecoration.underline
                                    : TextDecoration.none,
                                decorationColor: const Color(0xFFD5CEC4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // 3. Due Date Badge or 1-Tap Set Deadline Icon
              _buildDueBadgeOrTrigger(task),
            ],
          ),
        ),
      ).animate().fadeIn(delay: (index * 20).ms).slideY(begin: 0.02),
    );
  }

  Widget _buildDueBadgeOrTrigger(TaskItem task) {
    if (task.dueDate == null) {
      if (task.isDone || task.isArchived) return const SizedBox.shrink();
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showQuickTaskSheet(context, existingTask: task),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            Icons.event_outlined,
            size: 17,
            color: const Color(0xFFC5BEB4),
          ),
        ),
      );
    }

    final localDue = task.dueDate!.toLocal();
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    final dueDay = DateTime(localDue.year, localDue.month, localDue.day);

    String label;
    Color bgColor;
    Color textColor;
    IconData icon = Icons.event_rounded;

    if (task.isDone) {
      label = DateFormat('MMM d').format(localDue);
      bgColor = const Color(0xFFF4F1EB);
      textColor = const Color(0xFF9E978E);
    } else if (dueDay.isBefore(todayStart)) {
      final diffDays = todayStart.difference(dueDay).inDays;
      label = diffDays == 1
          ? 'Yesterday'
          : DateFormat('MMM d').format(localDue);
      bgColor = const Color(0xFFFDE8EC);
      textColor = const Color(0xFFD9385A);
      icon = Icons.error_outline_rounded;
    } else if (dueDay.isAtSameMomentAs(todayStart)) {
      label = 'Today';
      bgColor = const Color(0xFFFFEFE3);
      textColor = const Color(0xFFD95F08);
      icon = Icons.today_rounded;
    } else if (dueDay.isAtSameMomentAs(tomorrowStart)) {
      label = 'Tomorrow';
      bgColor = const Color(0xFFEAF2FC);
      textColor = const Color(0xFF3B7ED4);
    } else {
      label = DateFormat('MMM d').format(localDue);
      bgColor = const Color(0xFFF3EFE9);
      textColor = const Color(0xFF6E6862);
    }

    return GestureDetector(
      onTap: () => showQuickTaskSheet(context, existingTask: task),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens a minimal Quick Task creation or Task/Deadline editor bottom sheet.
/// Used from the main Plus button (`CaptureSpeedDial`) as well as when tapping
/// a task in `TasksScreen`.
Future<void> showQuickTaskSheet(
  BuildContext context, {
  TaskItem? existingTask,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _QuickTaskSheet(
      existingTask: existingTask,
      parentContext: context,
    ),
  );
}

class _QuickTaskSheet extends StatefulWidget {
  final TaskItem? existingTask;
  final BuildContext parentContext;

  const _QuickTaskSheet({
    required this.existingTask,
    required this.parentContext,
  });

  @override
  State<_QuickTaskSheet> createState() => _QuickTaskSheetState();
}

class _QuickTaskSheetState extends State<_QuickTaskSheet> {
  late final TextEditingController _titleController;
  DateTime? _selectedDueDate;

  bool get _isEditing => widget.existingTask != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existingTask?.title ?? '',
    );
    _selectedDueDate = widget.existingTask?.dueDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  DateTime _normalizeDate(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59);

  bool _isSameDay(DateTime? a, DateTime b) {
    if (a == null) return false;
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }

  Future<void> _pickCustomDate() async {
    final now = DateTime.now();
    final initial = _selectedDueDate?.toLocal() ?? now;
    final firstDate = initial.isBefore(now) ? initial : DateTime(now.year, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: const Color(0xFFFF7A1A),
                  onPrimary: Colors.white,
                  surface: const Color(0xFFF9F7F2),
                  onSurface: const Color(0xFF1B1A19),
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDueDate = _normalizeDate(picked);
      });
    }
  }

  Future<void> _save() async {
    final text = _titleController.text.trim();
    if (text.isEmpty) return;

    final appState = context.read<AppState>();
    Navigator.of(context).pop();

    if (_isEditing) {
      final prev = widget.existingTask!;
      await appState.updateTask(
        prev.id,
        title: text,
        dueDate: _selectedDueDate,
        clearDueDate: _selectedDueDate == null && prev.dueDate != null,
      );
    } else {
      await appState.addManualTask(
        text,
        sourceType: TaskSourceType.manual,
        sourceLabel: 'Quick Task',
        dueDate: _selectedDueDate,
      );
      if (widget.parentContext.mounted) {
        final dueSuffix = _selectedDueDate != null
            ? ' (Due ${DateFormat('MMM d').format(_selectedDueDate!)})'
            : '';
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          SnackBar(
            content: Text('Task added$dueSuffix'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final maxSheetHeight = mediaQuery.size.height * 0.88;
    final now = DateTime.now();
    final today = _normalizeDate(now);
    final tomorrow = _normalizeDate(now.add(const Duration(days: 1)));
    final nextWeek = _normalizeDate(now.add(const Duration(days: 7)));

    final isTodaySelected = _isSameDay(_selectedDueDate, today);
    final isTomorrowSelected = _isSameDay(_selectedDueDate, tomorrow);
    final isNextWeekSelected = _isSameDay(_selectedDueDate, nextWeek);
    final isCustomSelected = _selectedDueDate != null &&
        !isTodaySelected &&
        !isTomorrowSelected &&
        !isNextWeekSelected;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      child: Container(
        padding: EdgeInsets.fromLTRB(22, 14, 22, 22 + bottomInset),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2DDD5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isEditing ? 'Edit Task' : 'New Quick Task',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1B1A19),
                        ),
                      ),
                    ),
                    if (_isEditing)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: widget.existingTask!.isArchived
                                ? 'Restore task'
                                : 'Archive task',
                            icon: Icon(
                              widget.existingTask!.isArchived
                                  ? Icons.unarchive_outlined
                                  : Icons.archive_outlined,
                              size: 20,
                              color: const Color(0xFF88827A),
                            ),
                            onPressed: () {
                              final appState = context.read<AppState>();
                              final t = widget.existingTask!;
                              Navigator.of(context).pop();
                              if (t.isArchived) {
                                appState.unarchiveTask(t.id);
                              } else {
                                appState.archiveTask(t.id);
                              }
                            },
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Delete task',
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 20,
                              color: Color(0xFFE84F6E),
                            ),
                            onPressed: () {
                              final appState = context.read<AppState>();
                              final id = widget.existingTask!.id;
                              Navigator.of(context).pop();
                              appState.deleteTask(id);
                            },
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _titleController,
                  autofocus: !_isEditing,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                  minLines: 1,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1B1A19),
                  ),
                  decoration: InputDecoration(
                    hintText: 'What needs to get done?',
                    hintStyle: const TextStyle(color: Color(0xFFA59F95)),
                    filled: true,
                    fillColor: const Color(0xFFF9F7F2),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: Color(0xFFECE7DE)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: Color(0xFFECE7DE)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(
                        color: Color(0xFFFF7A1A),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Due Date / Deadline selector
                Row(
                  children: [
                    const Icon(
                      Icons.event_rounded,
                      size: 15,
                      color: Color(0xFF88827A),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _selectedDueDate == null
                            ? 'Due Date (Optional)'
                            : 'Due ${DateFormat('EEE, MMM d').format(_selectedDueDate!)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: _selectedDueDate == null
                              ? const Color(0xFF88827A)
                              : const Color(0xFF1B1A19),
                        ),
                      ),
                    ),
                    if (_selectedDueDate != null)
                      GestureDetector(
                        onTap: () => setState(() => _selectedDueDate = null),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Text(
                            'Clear',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFFF7A1A),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildDueDateQuickChip(
                        label: 'Today',
                        icon: Icons.today_rounded,
                        isSelected: isTodaySelected,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedDueDate = isTodaySelected ? null : today;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildDueDateQuickChip(
                        label: 'Tomorrow',
                        icon: Icons.wb_sunny_outlined,
                        isSelected: isTomorrowSelected,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedDueDate =
                                isTomorrowSelected ? null : tomorrow;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildDueDateQuickChip(
                        label: 'Next Week',
                        icon: Icons.next_week_outlined,
                        isSelected: isNextWeekSelected,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedDueDate =
                                isNextWeekSelected ? null : nextWeek;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildDueDateQuickChip(
                        label: isCustomSelected
                            ? DateFormat('MMM d').format(_selectedDueDate!)
                            : 'Pick Date',
                        icon: Icons.calendar_month_rounded,
                        isSelected: isCustomSelected,
                        onTap: _pickCustomDate,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                DuskPrimaryButton(
                  label: _isEditing ? 'Save Changes' : 'Create Task',
                  icon:
                      _isEditing ? Icons.check_rounded : Icons.add_task_rounded,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDueDateQuickChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFFEFE3)
              : const Color(0xFFF6F3EC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFF7A1A)
                : const Color(0xFFE8E2D8),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? const Color(0xFFD95F08)
                  : const Color(0xFF767068),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected
                    ? const Color(0xFFD95F08)
                    : const Color(0xFF5E5850),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reusable 1-Tap Export Bottom Sheet for Clean Markdown copy & native OS Share Sheet
void showTaskExportModal(
  BuildContext context, {
  required List<TaskItem> tasks,
  String periodLabel = 'All Time',
}) {
  final markdown = TaskService.formatTasksAsMarkdown(
    tasks,
    periodLabel: periodLabel,
  );

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final maxSheetHeight = MediaQuery.of(ctx).size.height * 0.85;
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Export Tasks',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1B1A19),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DuskPillBadge(
                        text:
                            '${tasks.length} ${tasks.length == 1 ? 'Task' : 'Tasks'}',
                        variant: DuskBadgeVariant.green,
                        icon: Icons.task_alt_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Copy as clean Markdown or share directly to Apple Reminders, Google Tasks, Notion, or Notes.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6E6862),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 190),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F7F2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFECE7DE)),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        markdown,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: Color(0xFF1B1A19),
                          height: 1.45,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1B1A19),
                            side: const BorderSide(color: Color(0xFFE2DDD5)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text(
                            'Copy Markdown',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: markdown),
                            );
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Markdown copied to clipboard',
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF7A1A),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          icon: const Icon(Icons.ios_share_rounded, size: 18),
                          label: const Text(
                            'Share',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await SharePlus.instance.share(
                              ShareParams(
                                text: markdown,
                                subject: 'Dusk — Tasks',
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
