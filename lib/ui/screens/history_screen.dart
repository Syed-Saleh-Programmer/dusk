import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/supabase_service.dart';
import 'past_reflection_screen.dart';
import 'paywall_screen.dart';
import 'share_insight_screen.dart';
import 'package:intl/intl.dart';
import '../widgets/dusk_ui_components.dart';

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

  Future<void> _fetchInsights() async {
    try {
      final list = await _supabase.getInsightCards();
      setState(() {
        _allInsights = list;
        _isLoading = false;
        _applyFilters();
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> temp = List.from(_allInsights);

    if (_searchQuery.isNotEmpty) {
      temp = temp.where((insight) {
        final title = (insight['title'] as String?)?.toLowerCase() ?? '';
        final mainInsight = (insight['main_insight'] as String?)?.toLowerCase() ?? '';
        return title.contains(_searchQuery.toLowerCase()) || mainInsight.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    if (_selectedFilterIndex == 1) {
      final oneMonthAgo = DateTime.now().subtract(const Duration(days: 30));
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

    setState(() {
      _filteredInsights = temp;
    });
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
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F2),
      body: DuskAmbientBackground(
        child: SafeArea(
          child: Column(
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
                        borderSide: const BorderSide(color: Color(0xFFECE7DE)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: Color(0xFFECE7DE)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: Color(0xFFFF7A1A), width: 1.5),
                      ),
                    ),
                    onChanged: (val) {
                      _searchQuery = val;
                      _applyFilters();
                    },
                  ),
                ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.1),

              // Pro Entitlement Banner
              GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallScreen()));
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDE8D7).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFFF7A1A).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.auto_awesome_rounded, size: 18, color: Color(0xFFFF7A1A)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Free tier includes past 7 days. Upgrade to Pro for complete archive.',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1B1A19),
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFFFF7A1A)),
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
                  color: const Color(0xFFFF7A1A),
                  backgroundColor: Colors.white,
                  displacement: 24,
                  onRefresh: _fetchInsights,
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF7A1A)),
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
                                  itemCount: _filteredInsights.length,
                                  itemBuilder: (context, index) {
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
                                          MaterialPageRoute(
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
                                          border: Border.all(color: const Color(0xFFF0EBE1)),
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
                                                          MaterialPageRoute(
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
                                                              ? const Color(0xFFFF7A1A)
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
                                              children: const [
                                                Expanded(
                                                  child: Text(
                                                    'View synthesized report',
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 12.5,
                                                      fontWeight: FontWeight.w600,
                                                      color: Color(0xFFFF7A1A),
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(width: 8),
                                                DuskSegmentedDashes(
                                                  totalSegments: 3,
                                                  completedSegments: 3,
                                                  activeColor: Color(0xFF389F7F),
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
        ),
      ),
    );
  }
}
