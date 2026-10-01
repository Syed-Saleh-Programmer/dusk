import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/reflection_cycle.dart';
import '../../providers/app_state.dart';
import '../../services/quick_capture_service.dart';
import '../theme/app_theme.dart';
import '../widgets/dusk_ui_components.dart';
import 'dusk_chat_screen.dart';

class HomeWidgetsScreen extends StatefulWidget {
  const HomeWidgetsScreen({super.key});

  @override
  State<HomeWidgetsScreen> createState() => _HomeWidgetsScreenState();
}

class _HomeWidgetsScreenState extends State<HomeWidgetsScreen> {
  int _wallpaperIndex = 0;

  final List<_WallpaperTheme> _wallpapers = [
    _WallpaperTheme(
      name: 'Modern Petals',
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF67D8EF), // Sky Cyan
          Color(0xFFF9D15C), // Warm Sun Yellow
          Color(0xFF57CF85), // Spring Green
          Color(0xFFFF8B43), // Vivid Tangerine
        ],
      ),
    ),
    _WallpaperTheme(
      name: 'Sunset Horizon',
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFF9458),
          Color(0xFFFF7A1A),
          Color(0xFF5274C7),
          Color(0xFF2C3E75),
        ],
      ),
    ),
    _WallpaperTheme(
      name: 'Warm Cream Canvas',
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFDEFD9),
          Color(0xFFF5EFE6),
          Color(0xFFEDE5DA),
        ],
      ),
    ),
  ];

  Future<void> _pinWidget(
    BuildContext context,
    String providerName,
    String displayName,
  ) async {
    final pinned = await QuickCaptureService().requestPinWidget(providerName);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1B1A19),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(
          pinned
              ? 'Pin request sent for "$displayName"!'
              : 'Long-press your Home Screen → Widgets → Dusk to add "$displayName".',
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final dumps = appState.allDumps;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final thoughtCount = dumps.where((d) => d['type'] == 'text').length;
    final voiceCount = dumps.where((d) => d['type'] == 'voice').length;
    final photoCount = dumps.where((d) => d['type'] == 'photo').length;
    final totalCount = dumps.length;

    int todayCount = 0;
    final List<DuskBarData> weeklyBars = [];
    for (int i = 6; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      int c = 0;
      for (final d in dumps) {
        final raw = d['captured_at'] ?? d['created_at'];
        final dt = raw is DateTime
            ? raw.toLocal()
            : DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
        if (dt != null &&
            dt.year == day.year &&
            dt.month == day.month &&
            dt.day == day.day) {
          c++;
        }
      }
      if (i == 0) todayCount = c;
      weeklyBars.add(
        DuskBarData(
          label: DateFormat('E').format(day).substring(0, 2),
          count: c,
          isHighlighted: i == 0,
        ),
      );
    }

    final int weeklyTotal = weeklyBars.fold(0, (s, b) => s + b.count);
    final int activeDays = weeklyBars.where((b) => b.count > 0).length;
    final bool isCompleted =
        appState.currentCycle?.status == CycleStatus.completed;
    final double ritualPct =
        isCompleted ? 1.0 : (totalCount / 4.0).clamp(0.0, 1.0);
    final int ritualPctInt = (ritualPct * 100).round();

    final denom = (thoughtCount + voiceCount + photoCount).clamp(1, 999999);
    final thoughtPct =
        totalCount > 0 ? ((thoughtCount * 100) / denom).round() : 0;
    final voicePct = totalCount > 0 ? ((voiceCount * 100) / denom).round() : 0;
    final photoPct = totalCount > 0 ? ((photoCount * 100) / denom).round() : 0;

    final activeWallpaper = _wallpapers[_wallpaperIndex];

    return Scaffold(
      body: Stack(
        children: [
          // Dynamic wallpaper simulator background behind the blurry glass widgets
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(gradient: activeWallpaper.gradient),
            ),
          ),

          // Soft organic light blobs to accentuate blur effects
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.amber.withValues(alpha: 0.35),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.tealAccent.withValues(alpha: 0.25),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top Bar with glass pill title
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                  child: Row(
                    children: [
                      _buildGlassCircleButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'Frosted Glass Widgets',
                          style: TextStyle(
                            fontSize: 17.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1B1A19),
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Wallpaper theme tester strip
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                    child: Row(
                      children: List.generate(_wallpapers.length, (idx) {
                        final isSel = idx == _wallpaperIndex;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _wallpaperIndex = idx),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? Colors.white.withValues(alpha: 0.90)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: isSel
                                    ? [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.06),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  _wallpapers[idx].name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSel
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: isSel
                                        ? const Color(0xFF1B1A19)
                                        : const Color(0xFF4A453E),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
                    children: [
                      // ==========================================
                      // WIDGET 1: DUSK ANALYTICS & RHYTHM (4x3)
                      // ==========================================
                      _buildWidgetHeader(
                        title: '1. Dusk Analytics & Rhythm',
                        badge: '4×3 Glass Chart',
                        subtitle:
                            'Translucent frosted glass with glowing 7-day activity bars, reflection readiness arc gauge, and modality breakdown.',
                        onPin: () => _pinWidget(
                          context,
                          'DuskAnalyticsWidgetProvider',
                          'Dusk Analytics & Rhythm',
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildGlassAnalyticsWidgetPreview(
                        todayCount: todayCount,
                        totalCount: totalCount,
                        weeklyTotal: weeklyTotal,
                        activeDays: activeDays,
                        weeklyBars: weeklyBars,
                        ritualPct: ritualPct,
                        ritualPctInt: ritualPctInt,
                        isCompleted: isCompleted,
                        thoughtCount: thoughtCount,
                        voiceCount: voiceCount,
                        photoCount: photoCount,
                        thoughtPct: thoughtPct,
                        voicePct: voicePct,
                        photoPct: photoPct,
                      ),

                      const SizedBox(height: 28),

                      // ==========================================
                      // WIDGET 2: DUSK QUICK CAPTURE BAR (4x1)
                      // ==========================================
                      _buildWidgetHeader(
                        title: '2. Dusk Quick Capture Bar',
                        badge: '4×1 Glass Bar',
                        subtitle:
                            'Semi-transparent frosted glass card with separated, color-tinted glass tiles for Thought, Voice, and Photo.',
                        onPin: () => _pinWidget(
                          context,
                          'DuskQuickCaptureWidgetProvider',
                          'Dusk Quick Capture',
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildGlassQuickCaptureWidgetPreview(
                        todayCount: todayCount,
                        totalCount: totalCount,
                      ),

                      const SizedBox(height: 28),

                      // ==========================================
                      // WIDGET 3: DUSK VOICE & THOUGHT SPLIT (4x1)
                      // ==========================================
                      _buildWidgetHeader(
                        title: '3. Dusk Voice & Thought Split',
                        badge: '4×1 Dual Glass',
                        subtitle:
                            'Two separated floating frosted glass cards tailored for instant Text Thoughts and Voice Memos.',
                        onPin: () => _pinWidget(
                          context,
                          'DuskVoiceTextWidgetProvider',
                          'Dusk Voice & Thought',
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildGlassSplitWidgetPreview(
                        thoughtCount: thoughtCount,
                        voiceCount: voiceCount,
                      ),

                      const SizedBox(height: 28),

                      // ==========================================
                      // WIDGET 4: DUSK BUDDY QUICK WIDGET (1x1)
                      // ==========================================
                      _buildWidgetHeader(
                        title: '4. Dusk Buddy Quick Widget',
                        badge: '1×1 Transparent',
                        subtitle:
                            'Transparent 1×1 home screen widget featuring the rotating gradient Dusk Buddy button with label below. Tap to instantly chat with Dusk Buddy.',
                        onPin: () => _pinWidget(
                          context,
                          'DuskBuddyWidgetProvider',
                          'Dusk Buddy',
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildGlassBuddyWidgetPreview(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCircleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(21),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.55),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.75),
              width: 1.2,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(21),
              child: Center(
                child: Icon(
                  icon,
                  size: 18,
                  color: const Color(0xFF1B1A19),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWidgetHeader({
    required String title,
    required String badge,
    required String subtitle,
    required VoidCallback onPin,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B1A19),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFD95F08),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12.5,
            color: Color(0xFF4A453E),
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            onTap: onPin,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF9648), Color(0xFFFF7A1A)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF7A1A).withValues(alpha: 0.30),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_to_home_screen_rounded,
                      size: 16, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Add to Home Screen',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Glass container wrapper providing real optical blur and specular rim highlight
  Widget _buildGlassContainer({
    required Widget child,
    double borderRadius = 26,
    EdgeInsets padding = const EdgeInsets.all(14),
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.82), // Refractive top light
                Colors.white.withValues(alpha: 0.58), // Translucent center
                Colors.white.withValues(alpha: 0.68), // Semi-transparent bottom
              ],
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.88), // Specular rim stroke
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildGlassAnalyticsWidgetPreview({
    required int todayCount,
    required int totalCount,
    required int weeklyTotal,
    required int activeDays,
    required List<DuskBarData> weeklyBars,
    required double ritualPct,
    required int ritualPctInt,
    required bool isCompleted,
    required int thoughtCount,
    required int voiceCount,
    required int photoCount,
    required int thoughtPct,
    required int voicePct,
    required int photoPct,
  }) {
    return _buildGlassContainer(
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.75),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.9)),
                ),
                child: const Icon(
                  Icons.wb_twilight_rounded,
                  size: 16,
                  color: Color(0xFFFF7A1A),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dusk Analytics',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B1A19),
                      ),
                    ),
                    Text(
                      '$totalCount total captures • Peak in Evening',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF6E6862),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              _buildGlassPillBadge(
                text: '$todayCount Today',
                color: const Color(0xFFD66B1E),
                bgColor: const Color(0x33FF7A1A),
                borderColor: const Color(0x66FF7A1A),
              ),
              const SizedBox(width: 5),
              _buildGlassPillBadge(
                text: '$activeDays/7 Days',
                color: const Color(0xFF1E8A63),
                bgColor: const Color(0x332DC48D),
                borderColor: const Color(0x662DC48D),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Inner Frosted Glass Chart Well
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.65),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '$weeklyTotal',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1B1A19),
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              'captures past 7d',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFF6E6862),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        DuskActivityBarChart(
                          bars: weeklyBars,
                          height: 92,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 110,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    color: Colors.black.withValues(alpha: 0.08),
                  ),
                  Expanded(
                    flex: 4,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: DuskArcGauge(
                        percentage: ritualPct,
                        centerTitle: '$ritualPctInt%',
                        centerSubtitle: 'Reflection Ready',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Proportional Glass Breakdown Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 7,
              child: Row(
                children: [
                  Expanded(
                    flex: thoughtCount > 0 ? thoughtCount : 1,
                    child: Container(color: const Color(0xFFFF7A1A)),
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    flex: voiceCount > 0 ? voiceCount : 1,
                    child: Container(color: const Color(0xFF4A84D8)),
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    flex: photoCount > 0 ? photoCount : 1,
                    child: Container(color: const Color(0xFF2DC48D)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 7),

          // 3 Modality Glass Tiles
          Row(
            children: [
              Expanded(
                child: _buildMiniGlassModalityTile(
                  icon: Icons.notes_rounded,
                  iconColor: const Color(0xFFFF7A1A),
                  bgColor: const Color(0x38FFA35C),
                  borderColor: const Color(0x73FFA35C),
                  title: '$thoughtCount · $thoughtPct%',
                  subtitle: 'Thoughts',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMiniGlassModalityTile(
                  icon: Icons.graphic_eq_rounded,
                  iconColor: const Color(0xFF4A84D8),
                  bgColor: const Color(0x38639AE6),
                  borderColor: const Color(0x73639AE6),
                  title: '$voiceCount · $voicePct%',
                  subtitle: 'Voice',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMiniGlassModalityTile(
                  icon: Icons.image_rounded,
                  iconColor: const Color(0xFF2DC48D),
                  bgColor: const Color(0x3842D39F),
                  borderColor: const Color(0x7342D39F),
                  title: '$photoCount · $photoPct%',
                  subtitle: 'Moments',
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),

          // Ritual Glass Strip
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.65),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.nights_stay_rounded,
                    size: 14,
                    color: Color(0xFFFF7A1A),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isCompleted
                          ? 'Evening Reflection complete'
                          : '9:00 PM Reflection • $ritualPctInt% ready',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B1A19),
                      ),
                    ),
                  ),
                  const Text(
                    'Open Dusk',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFF7A1A),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 14,
                    color: Color(0xFFFF7A1A),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassPillBadge({
    required String text,
    required Color color,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMiniGlassModalityTile({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B1A19),
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: Color(0xFF6E6862),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassQuickCaptureWidgetPreview({
    required int todayCount,
    required int totalCount,
  }) {
    return _buildGlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.75),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.9)),
                ),
                child: const Icon(
                  Icons.wb_twilight_rounded,
                  size: 13,
                  color: Color(0xFFFF7A1A),
                ),
              ),
              const SizedBox(width: 7),
              const Text(
                'Dusk',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B1A19),
                ),
              ),
              const SizedBox(width: 6),
              const Text('•', style: TextStyle(color: Color(0xFF88827A))),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  totalCount > 0
                      ? '$totalCount total • Peak in Evening'
                      : 'Mindful quick capture',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF5A554E),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              _buildGlassPillBadge(
                text: '$todayCount Today',
                color: const Color(0xFFD66B1E),
                bgColor: const Color(0x33FF7A1A),
                borderColor: const Color(0x66FF7A1A),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildActionTileGlassPreview(
                  label: 'Thought',
                  icon: Icons.edit_rounded,
                  circleColor: const Color(0xFFFF7A1A),
                  bgColor: const Color(0x38FFA35C),
                  borderColor: const Color(0x73FFA35C),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _buildActionTileGlassPreview(
                  label: 'Voice',
                  icon: Icons.mic_rounded,
                  circleColor: const Color(0xFF4A84D8),
                  bgColor: const Color(0x38639AE6),
                  borderColor: const Color(0x73639AE6),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _buildActionTileGlassPreview(
                  label: 'Photo',
                  icon: Icons.camera_alt_rounded,
                  circleColor: const Color(0xFF2DC48D),
                  bgColor: const Color(0x3842D39F),
                  borderColor: const Color(0x7342D39F),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionTileGlassPreview({
    required String label,
    required IconData icon,
    required Color circleColor,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: circleColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1B1A19),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassSplitWidgetPreview({
    required int thoughtCount,
    required int voiceCount,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildGlassContainer(
            borderRadius: 24,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF7A1A),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit_rounded,
                      size: 18, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Thought',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1B1A19),
                              ),
                            ),
                          ),
                          _buildGlassPillBadge(
                            text: '$thoughtCount',
                            color: const Color(0xFFD66B1E),
                            bgColor: const Color(0x33FF7A1A),
                            borderColor: const Color(0x66FF7A1A),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        thoughtCount > 0 ? '$thoughtCount saved' : 'Write note',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6E6862),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildGlassContainer(
            borderRadius: 24,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4A84D8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mic_rounded,
                      size: 18, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Voice',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1B1A19),
                              ),
                            ),
                          ),
                          _buildGlassPillBadge(
                            text: '$voiceCount',
                            color: const Color(0xFF265CA8),
                            bgColor: const Color(0x334A84D8),
                            borderColor: const Color(0x664A84D8),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        voiceCount > 0 ? '$voiceCount saved' : 'Audio memo',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6E6862),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlassBuddyWidgetPreview(BuildContext context) {
    final palette = AppTheme.palette;
    return Center(
      child: Container(
        width: 140,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.28),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DuskAiRotatingGradientButton(
              palette: palette,
              size: 58,
              animateRotation: true,
              onTap: () {
                Navigator.of(context).push(
                  DuskPageRoute.modalSheet(
                    builder: (_) => const DuskChatScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            const Text(
              'Dusk Buddy',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.2,
                shadows: [
                  Shadow(
                    color: Color(0x99000000),
                    offset: Offset(0, 1.2),
                    blurRadius: 3,
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

class _WallpaperTheme {
  final String name;
  final Gradient gradient;

  const _WallpaperTheme({required this.name, required this.gradient});
}
