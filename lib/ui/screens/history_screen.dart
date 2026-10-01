import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../services/local_db_service.dart';
import '../../services/supabase_service.dart';
import 'past_reflection_screen.dart';
import 'paywall_screen.dart';
import 'share_insight_screen.dart';
import 'dusk_chat_screen.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/dusk_ui_components.dart';
export '../widgets/dusk_ui_components.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final SupabaseService _supabase = SupabaseService();
  List<Map<String, dynamic>> _allInsights = [];
  List<Map<String, dynamic>> _filteredInsights = [];
  bool _isLoading = true;
  String _searchQuery = '';
  int _selectedFilterIndex = 0; // 0: All, 1: Past Month, 2: Bookmarked
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _filters = ['All', 'Past Month', 'Bookmarked'];

  @override
  void initState() {
    super.initState();
    _fetchInsights();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int _archivedPastLimitCount = 0;

  Future<void> _fetchInsights() async {
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final currentUserId = _supabase.currentUser?.id ?? 'local_user';

      // 1. Instantly load local insight cards from SQLite (works 100% offline for Free tier)
      final localCards = await LocalDbService().getLocalInsightCards(userId: currentUserId);

      // 2. If Pro and user has an account, sync remote cards from Supabase
      List<Map<String, dynamic>> combined = List.from(localCards);
      if (appState.isPro && _supabase.currentUser != null) {
        try {
          final remoteCards = await _supabase.getInsightCards();
          final localIds = localCards.map((c) => c['id'].toString()).toSet();
          for (final remote in remoteCards) {
            if (!localIds.contains(remote['id'].toString())) {
              combined.add(remote);
              await LocalDbService().insertLocalInsightCard(remote);
            }
          }
        } catch (e) {
          debugPrint('Error syncing remote insight cards: $e');
        }
      }

      if (mounted) {
        setState(() {
          _allInsights = combined;
          _isLoading = false;
          _applyFilters();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    final appState = Provider.of<AppState>(context, listen: false);
    final isPro = appState.isPro;
    final now = DateTime.now();
    final cutoff14Days = now.subtract(const Duration(days: 14));

    List<Map<String, dynamic>> temp = List.from(_allInsights);

    if (_searchQuery.isNotEmpty) {
      temp = temp.where((insight) {
        final title = (insight['title'] as String?)?.toLowerCase() ?? '';
        final mainInsight = (insight['main_insight'] as String?)?.toLowerCase() ?? '';
        return title.contains(_searchQuery.toLowerCase()) || mainInsight.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    if (_selectedFilterIndex == 1) {
      final oneMonthAgo = now.subtract(const Duration(days: 30));
      temp = temp.where((insight) {
        final createdAtStr = insight['created_at'] as String?;
        if (createdAtStr == null) return false;
        try {
          final createdAt = DateTime.parse(createdAtStr);
          return createdAt.isAfter(oneMonthAgo);
        } catch (_) {
          return false;
        }
      }).toList();
    } else if (_selectedFilterIndex == 2) {
      temp = temp.where((insight) => (insight['is_bookmarked'] as bool?) == true).toList();
    }

    // Free Tier: rolling 14-day history window
    if (!isPro) {
      final within14 = <Map<String, dynamic>>[];
      int olderCount = 0;
      for (final item in temp) {
        final createdAtStr = item['created_at']?.toString();
        if (createdAtStr != null) {
          try {
            final dt = DateTime.parse(createdAtStr);
            if (dt.isAfter(cutoff14Days)) {
              within14.add(item);
            } else {
              olderCount++;
            }
          } catch (_) {
            within14.add(item);
          }
        } else {
          within14.add(item);
        }
      }
      _filteredInsights = within14;
      _archivedPastLimitCount = olderCount;
    } else {
      _filteredInsights = temp;
      _archivedPastLimitCount = 0;
    }

    setState(() {});
  }

  void _toggleBookmark(Map<String, dynamic> insight) {
    final id = insight['id']?.toString();
    if (id == null || id.isEmpty) return;

    final previousValue = (insight['is_bookmarked'] as bool?) == true;
    final newValue = !previousValue;

    // 1. Optimistic UI update (0ms)
    setState(() {
      insight['is_bookmarked'] = newValue;
      final index = _allInsights.indexWhere((i) => i['id']?.toString() == id);
      if (index != -1) {
        _allInsights[index]['is_bookmarked'] = newValue;
      }
      _applyFilters();
    });

    // 2. Background persistence with rollback on failure
    _supabase.toggleInsightBookmark(id, newValue).catchError((_) {
      if (!mounted) return;
      setState(() {
        insight['is_bookmarked'] = previousValue;
        final index = _allInsights.indexWhere((i) => i['id']?.toString() == id);
        if (index != -1) {
          _allInsights[index]['is_bookmarked'] = previousValue;
        }
        _applyFilters();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      body: DuskAmbientBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Column(
            children: [
              // Top Bar with Circular Action
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Reflection Archive',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1B1A19),
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    DuskCircleButton(
                      icon: _isSearchOpen ? Icons.close_rounded : Icons.search_rounded,
                      tooltip: 'Search reflections',
                      onTap: () {
                        setState(() {
                          _isSearchOpen = !_isSearchOpen;
                          if (!_isSearchOpen) {
                            _searchQuery = '';
                            _searchController.clear();
                            _applyFilters();
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),

              // Search Bar (if toggled)
              if (_isSearchOpen)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF1B1A19)),
                    decoration: InputDecoration(
                      hintText: 'Search past reflections and insights...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFFA59F95)),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: palette.outlineVariant),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: palette.outlineVariant),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: palette.primary, width: 1.5),
                      ),
                    ),
                    onChanged: (val) {
                      _searchQuery = val;
                      _applyFilters();
                    },
                  ),
                ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.1),

              // Pro Entitlement Banner
              if (context.watch<AppState>().isPro)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF81C784).withValues(alpha: 0.5)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.all_inclusive_rounded, size: 18, color: Color(0xFF2E7D32)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Dusk Vault Active • Unlimited lifetime reflection archive',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1B5E20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 300.ms)
              else
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      DuskPageRoute.modalSheet(
                        builder: (_) => const PaywallScreen(),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: palette.primaryContainer.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: palette.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock_clock_rounded, size: 18, color: palette.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _archivedPastLimitCount > 0
                                ? 'Showing rolling 14 days ($_archivedPastLimitCount archived in Vault). Tap to unlock.'
                                : 'Free tier displays rolling 14 days. Upgrade to Pro for lifetime archive.',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1B1A19),
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, size: 20, color: palette.primary),
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 300.ms),

              const SizedBox(height: 10),

              // Filter Tabs (Screen 2 Segmented Pill Tab Style)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: DuskPillTabBar(
                  tabs: _filters,
                  selectedIndex: _selectedFilterIndex,
                  onTabSelected: (index) {
                    setState(() {
                      _selectedFilterIndex = index;
                      _applyFilters();
                    });
                  },
                ),
              ).animate().fadeIn(delay: 150.ms),

              const SizedBox(height: 14),

              // Archive List
              Expanded(
                child: RefreshIndicator(
                  color: palette.primary,
                  backgroundColor: Colors.white,
                  displacement: 24,
                  onRefresh: _fetchInsights,
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(palette.primary),
                          ),
                        )
                      : _allInsights.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                              children: [
                                SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32.0),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.history_edu_rounded, size: 48, color: Color(0xFFA59F95)),
                                        SizedBox(height: 12),
                                        Text(
                                          'No history exists yet.',
                                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1B1A19)),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Completed evening reflections will appear here as AI insight cards.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontSize: 13, color: Color(0xFF88827A)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ).animate().fadeIn(),
                              ],
                            )
                          : _filteredInsights.isEmpty
                              ? ListView(
                                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                                  children: [
                                    SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                                    const Center(
                                      child: Text(
                                        'No matching reflections found.',
                                        style: TextStyle(color: Color(0xFF88827A), fontSize: 14),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                                  itemCount: _filteredInsights.length + (!context.watch<AppState>().isPro ? 1 : 0),
                                  itemBuilder: (context, index) {
                                    if (index == _filteredInsights.length) {
                                      return Container(
                                        margin: const EdgeInsets.only(top: 8, bottom: 20),
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFBF9F5),
                                          borderRadius: BorderRadius.circular(22),
                                          border: Border.all(
                                            color: const Color(0xFFFFB27A).withValues(alpha: 0.6),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFFDE8D7),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: const Icon(
                                                    Icons.lock_rounded,
                                                    color: Color(0xFFFF7A1A),
                                                    size: 20,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      const Text(
                                                        'Dusk Vault (14-Day Limit)',
                                                        style: TextStyle(
                                                          fontSize: 15,
                                                          fontWeight: FontWeight.w800,
                                                          color: Color(0xFF1B1A19),
                                                        ),
                                                      ),
                                                      Text(
                                                        _archivedPastLimitCount > 0
                                                            ? '$_archivedPastLimitCount older reflection(s) preserved in Vault'
                                                            : 'Older reflections are archived here',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color: Color(0xFF88827A),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            const Text(
                                              'Free tier displays your most recent 14 days of reflections. Upgrade to Dusk Pro to unlock lifetime archive access, full-history search, and cross-device cloud sync.',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF6E6862),
                                                height: 1.4,
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            DuskPrimaryButton(
                                              label: 'Unlock Full Archive with Pro',
                                              icon: Icons.auto_awesome_rounded,
                                              onPressed: () {
                                                Navigator.of(context).push(
                                                  DuskPageRoute.modalSheet(builder: (_) => const PaywallScreen()),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ).animate().fadeIn(duration: 400.ms);
                                    }

                                    final insight = _filteredInsights[index];
                                    final isBookmarked = (insight['is_bookmarked'] as bool?) == true;

                                    String dateRange = 'Recent';
                                    if (insight['created_at'] != null) {
                                      try {
                                        final dt = DateTime.parse(insight['created_at']);
                                        dateRange = DateFormat('MMM d, yyyy').format(dt);
                                      } catch (_) {}
                                    }

                                    return GestureDetector(
                                      onTap: () {
                                        Navigator.of(context).push(
                                          DuskPageRoute.perspectiveSlide(
                                            builder: (_) => PastReflectionScreen(insight: insight),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.only(bottom: 14),
                                        padding: const EdgeInsets.all(18),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(22),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.03),
                                              blurRadius: 14,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                          border: Border.all(color: palette.outlineVariant),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Flexible(
                                                  child: DuskPillBadge(
                                                    text: dateRange,
                                                    variant: DuskBadgeVariant.blue,
                                                    icon: Icons.calendar_today_rounded,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    GestureDetector(
                                                      behavior: HitTestBehavior.opaque,
                                                      onTap: () {
                                                        Navigator.of(context).push(
                                                          DuskPageRoute.modalSheet(
                                                            builder: (_) => ShareInsightScreen(insight: insight),
                                                          ),
                                                        );
                                                      },
                                                      child: const Padding(
                                                        padding: EdgeInsets.all(4.0),
                                                        child: Icon(
                                                          Icons.ios_share_rounded,
                                                          size: 18,
                                                          color: Color(0xFF9C958B),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    GestureDetector(
                                                      behavior: HitTestBehavior.opaque,
                                                      onTap: () => _toggleBookmark(insight),
                                                      child: Padding(
                                                        padding: const EdgeInsets.all(2.0),
                                                        child: Icon(
                                                          isBookmarked ? Icons.star_rounded : Icons.star_outline_rounded,
                                                          size: 22,
                                                          color: isBookmarked
                                                              ? palette.primary
                                                              : const Color(0xFFBEB7AC),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              insight['title'] as String? ?? 'Evening Reflection',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF1B1A19),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              insight['main_insight'] as String? ?? '',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 13.5,
                                                color: Color(0xFF6E6862),
                                                height: 1.45,
                                              ),
                                            ),
                                            const SizedBox(height: 14),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    'View synthesized report',
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 12.5,
                                                      fontWeight: FontWeight.w600,
                                                      color: palette.primary,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                DuskSegmentedDashes(
                                                  totalSegments: 3,
                                                  completedSegments: 3,
                                                  activeColor: palette.tertiary,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ).animate().fadeIn(delay: (index * 40).ms).slideY(begin: 0.04);
                                  },
                                ),
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 72,
            right: 16,
            child: DuskAiRotatingGradientButton(
              palette: palette,
              onTap: () {
                Navigator.of(context).push(
                  DuskPageRoute.modalSheet(
                    builder: (context) => const DuskChatScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  ),
);
  }
}
