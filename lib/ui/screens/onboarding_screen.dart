import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/dusk_logo.dart';
import '../widgets/dusk_ui_components.dart';
import 'auth_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final bool isPreview;

  const OnboardingScreen({super.key, this.isPreview = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<_OnboardingSlideData> _slides = [
    _OnboardingSlideData(
      tag: 'CAPTURE FREELY',
      tagVariant: DuskBadgeVariant.peach,
      tagIcon: Icons.bolt_rounded,
      title: 'Unclutter your mind, effortlessly.',
      subtitle:
          'Drop fleeting thoughts, voice memos, and visual moments in seconds—without folders, tags, or pressure.',
      accentColor: Color(0xFFFF7A1A),
      glowColor: Color(0xFFFDE5CE),
      highlights: ['Text Thoughts', 'Voice Memos', 'Photo Moments'],
    ),
    _OnboardingSlideData(
      tag: 'INTENTIONAL RHYTHM',
      tagVariant: DuskBadgeVariant.blue,
      tagIcon: Icons.wb_twilight_rounded,
      title: 'A calm ritual on your schedule.',
      subtitle:
          'No streaks or guilt-driven alerts. Choose a cadence that fits your life—daily, every 3 days, or weekly.',
      accentColor: Color(0xFF4A84D8),
      glowColor: Color(0xFFDCEBFA),
      highlights: ['Custom Cadence', 'Gentle Chimes', 'Zero Guilt'],
    ),
    _OnboardingSlideData(
      tag: 'AI SYNTHESIS',
      tagVariant: DuskBadgeVariant.orange,
      tagIcon: Icons.auto_awesome_rounded,
      title: 'Turn scattered dumps into clarity.',
      subtitle:
          'When your cycle completes, Dusk reviews your captures, asks thoughtful questions, and distills an Insight Card.',
      accentColor: Color(0xFFE06D14),
      glowColor: Color(0xFFFCE6D2),
      highlights: ['Cycle Summary', 'Guided Prompts', 'Insight Cards'],
    ),
    _OnboardingSlideData(
      tag: 'PRIVATE SANCTUARY',
      tagVariant: DuskBadgeVariant.green,
      tagIcon: Icons.shield_outlined,
      title: 'Private by design. Yours alone.',
      subtitle:
          'Capture offline anytime and sync seamlessly. Your reflections are protected by strict row-level security.',
      accentColor: Color(0xFF2DC48D),
      glowColor: Color(0xFFDDF4EC),
      highlights: ['Offline-First', 'Row-Level Vault', 'Ad-Free'],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    HapticFeedback.lightImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);

    if (!mounted) return;
    if (widget.isPreview) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
    }
  }

  void _nextPage() {
    HapticFeedback.selectionClick();
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: 400.ms,
        curve: Curves.easeOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _previousPage() {
    HapticFeedback.selectionClick();
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: 360.ms,
        curve: Curves.easeOutCubic,
      );
    }
  }

  Widget _buildIllustration(int index) {
    switch (index) {
      case 0:
        return const _CaptureSlideIllustration();
      case 1:
        return const _RitualSlideIllustration();
      case 2:
        return const _InsightSlideIllustration();
      case 3:
      default:
        return const _PrivacySlideIllustration();
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeSlide = _slides[_currentPage];
    final isLastPage = _currentPage == _slides.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F2),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              activeSlide.glowColor,
              const Color(0xFFFAF6F0),
              const Color(0xFFF9F7F2),
            ],
            stops: const [0.0, 0.36, 0.75],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Header Bar (Overflow-safe)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                child: Row(
                  children: [
                    const DuskLogo(size: 36, showBadgeContainer: true),
                    const SizedBox(width: 10),
                    const Flexible(
                      child: Text(
                        'Dusk',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1B1A19),
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFEBE5DC)),
                      ),
                      child: Text(
                        '${_currentPage + 1}/${_slides.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF88827A),
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (!isLastPage)
                      TextButton(
                        onPressed: _finishOnboarding,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF6E6862),
                          backgroundColor: Colors.white.withValues(alpha: 0.75),
                          minimumSize: const Size(0, 34),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: const BorderSide(color: Color(0xFFEBE5DC)),
                          ),
                        ),
                        child: Text(
                          widget.isPreview ? 'Close' : 'Skip',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else if (widget.isPreview)
                      DuskCircleButton(
                        icon: Icons.close_rounded,
                        size: 34,
                        iconSize: 17,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                  ],
                ),
              ),

              // Main PageView (Scroll-safe on any height or font scale)
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemCount: _slides.length,
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20.0,
                            vertical: 8.0,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: math.max(
                                0.0,
                                constraints.maxHeight - 16.0,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Self-contained, non-overlapping visual stage
                                _buildIllustration(index)
                                    .animate(key: ValueKey('illust_$index'))
                                    .fadeIn(duration: 380.ms)
                                    .slideY(begin: 0.03),

                                const SizedBox(height: 16),

                                // Editorial Copy Block
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    DuskPillBadge(
                                      text: slide.tag,
                                      variant: slide.tagVariant,
                                      icon: slide.tagIcon,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      slide.title,
                                      style: const TextStyle(
                                        fontSize: 25,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF1B1A19),
                                        letterSpacing: -0.6,
                                        height: 1.18,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      slide.subtitle,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                        color: Color(0xFF6E6862),
                                        height: 1.45,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: slide.highlights.map((chip) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: Border.all(
                                              color: const Color(0xFFEBE5DC),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.check_circle_rounded,
                                                size: 13,
                                                color: slide.accentColor,
                                              ),
                                              const SizedBox(width: 5),
                                              Flexible(
                                                child: Text(
                                                  chip,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF1B1A19),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                )
                                    .animate(key: ValueKey('copy_$index'))
                                    .fadeIn(delay: 60.ms, duration: 380.ms)
                                    .slideY(begin: 0.04),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // Bottom Controls Bar (Overflow-safe on 312px width & 1.15x+ text scale)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
                child: Row(
                  children: [
                    // Animated Page Indicators
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(_slides.length, (index) {
                        final isSelected = _currentPage == index;
                        return GestureDetector(
                          onTap: () {
                            _pageController.animateToPage(
                              index,
                              duration: 350.ms,
                              curve: Curves.easeOutCubic,
                            );
                          },
                          child: AnimatedContainer(
                            duration: 280.ms,
                            margin: const EdgeInsets.only(right: 6),
                            height: 8,
                            width: isSelected ? 24 : 8,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? activeSlide.accentColor
                                  : const Color(0xFFDDD6CA),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(width: 8),
                    const Spacer(),
                    if (_currentPage > 0) ...[
                      DuskCircleButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        size: 44,
                        iconSize: 17,
                        onTap: _previousPage,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF7A1A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                isLastPage
                                    ? (widget.isPreview
                                        ? 'Done'
                                        : 'Get Started')
                                    : 'Continue',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              isLastPage
                                  ? Icons.auto_awesome_rounded
                                  : Icons.arrow_forward_rounded,
                              size: 17,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingSlideData {
  final String tag;
  final DuskBadgeVariant tagVariant;
  final IconData tagIcon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final Color glowColor;
  final List<String> highlights;

  const _OnboardingSlideData({
    required this.tag,
    required this.tagVariant,
    required this.tagIcon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.glowColor,
    required this.highlights,
  });
}

/// SLIDE 1 ILLUSTRATION: Non-overlapping Column of 3 Capture Cards (Thought, Voice, Photo)
class _CaptureSlideIllustration extends StatelessWidget {
  const _CaptureSlideIllustration();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFEDE6DA)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Quick Thought Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFEDE6DA)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Flexible(
                      child: DuskPillBadge(
                        text: 'Thought',
                        variant: DuskBadgeVariant.peach,
                        icon: Icons.notes_rounded,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '7:42 PM',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF88827A).withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  '"Simplify the opening step so the evening feels calm."',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1B1A19),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 2. Voice Memo Card with Custom Waveform
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFDCE8F8), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4A84D8).withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF639BF0), Color(0xFF4A84D8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mic_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Evening walk voice memo',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1B1A19),
                              ),
                            ),
                          ),
                          SizedBox(width: 6),
                          Text(
                            '0:42',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4A84D8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 16,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: _WaveformBarsPainter(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 3. Visual Moment Card
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFEDE6DA)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: CustomPaint(
                      painter: _MiniSunsetLandscapePainter(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DuskPillBadge(
                        text: 'Moment',
                        variant: DuskBadgeVariant.green,
                        icon: Icons.camera_alt_rounded,
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Golden hour quiet by the window',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B1A19),
                        ),
                      ),
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
}

/// SLIDE 2 ILLUSTRATION: Intentional Evening Ritual & Horizon Dial (Wrap-safe)
class _RitualSlideIllustration extends StatelessWidget {
  const _RitualSlideIllustration();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFEDE6DA)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B1A19).withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Custom Sunset Horizon Dial
          SizedBox(
            height: 96,
            width: 190,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                CustomPaint(
                  size: const Size(190, 96),
                  painter: _DuskHorizonDialPainter(),
                ),
                const Positioned(
                  bottom: 2,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '9:00 PM',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1B1A19),
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Evening Reflection',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF88827A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Wrap instead of Row so cadence pills never overflow horizontally
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildCadencePill('Daily', false),
              _buildCadencePill('Every 3 Days', true),
              _buildCadencePill('Weekly', false),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF6F0),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEFE8DE)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.notifications_none_rounded,
                  size: 17,
                  color: Color(0xFFFF7A1A),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '6 captures ready for your 3-day synthesis',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF5E5850),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCadencePill(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFFFF3E8) : const Color(0xFFF6F3ED),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: active ? const Color(0xFFFF7A1A) : const Color(0xFFE8E2D8),
          width: active ? 1.4 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (active) ...[
            const Icon(Icons.star_rounded, size: 12, color: Color(0xFFFF7A1A)),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: active ? const Color(0xFFD65A00) : const Color(0xFF88827A),
            ),
          ),
        ],
      ),
    );
  }
}

/// SLIDE 3 ILLUSTRATION: Non-overlapping Column with Prompt Pill + Editorial Insight Card
class _InsightSlideIllustration extends StatelessWidget {
  const _InsightSlideIllustration();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Question Prompt Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1A19),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: Color(0xFFFF9B50),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Q: What gave you the most energy over these 3 days?',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Main Editorial Insight Card Preview
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFEDE6DA)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF7A1A).withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Flexible(
                    child: DuskPillBadge(
                      text: 'INSIGHT CARD',
                      variant: DuskBadgeVariant.peach,
                      icon: Icons.wb_sunny_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F4EE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Cycle #14',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF88827A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Protecting Unstructured Space',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B1A19),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Your clearest breakthroughs arrived during unscheduled evening walks rather than at your desk.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6E6862),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFF7A1A).withValues(alpha: 0.25),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.compass_calibration_rounded,
                      size: 15,
                      color: Color(0xFFFF7A1A),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Next step: Block 20 quiet minutes before dinner.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFC75505),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// SLIDE 4 ILLUSTRATION: Private & Offline-First Sanctuary Vault
class _PrivacySlideIllustration extends StatelessWidget {
  const _PrivacySlideIllustration();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEDE6DA)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sacred Vault Emblem Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2F2EC)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF38B889), Color(0xFF238C66)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(
                    Icons.verified_user_rounded,
                    size: 26,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Personal Sanctuary Vault',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1B1A19),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Protected by user-isolated encryption',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF2E9473),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _buildPrivacyRow(
            icon: Icons.cloud_done_rounded,
            color: const Color(0xFF2DC48D),
            title: 'Offline-First Local Queue',
            subtitle: 'Capture anywhere, syncs automatically',
          ),
          const SizedBox(height: 8),
          _buildPrivacyRow(
            icon: Icons.lock_rounded,
            color: const Color(0xFF4A84D8),
            title: 'Row-Level Vault Isolation',
            subtitle: 'Only your authenticated session can read',
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDE6DA)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B1A19),
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF88827A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom Painter for the Voice Memo Waveform on Slide 1
class _WaveformBarsPainter extends CustomPainter {
  static const List<double> _heights = [
    0.35, 0.65, 0.9, 0.5, 0.8, 1.0, 0.7, 0.4, 0.85,
    0.95, 0.6, 0.45, 0.75, 0.55, 0.3, 0.5, 0.7, 0.4,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = _heights.length;
    final spacing = size.width / barCount;
    final barWidth = math.max(2.0, spacing * 0.45);

    for (int i = 0; i < barCount; i++) {
      final isPlayed = i < 11;
      final paint = Paint()
        ..color = isPlayed
            ? const Color(0xFF4A84D8)
            : const Color(0xFFD6E4F7)
        ..strokeCap = StrokeCap.round
        ..strokeWidth = barWidth;

      final h = size.height * _heights[i];
      final x = i * spacing + barWidth / 2;
      final top = (size.height - h) / 2;
      canvas.drawLine(Offset(x, top), Offset(x, top + h), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom Painter for the Sunset Landscape Thumbnail on Slide 1
class _MiniSunsetLandscapePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFF9A4D),
          Color(0xFFFFCAA0),
          Color(0xFFE4F5EE),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, skyPaint);

    // Setting sun
    canvas.drawCircle(
      Offset(size.width * 0.62, size.height * 0.42),
      7,
      Paint()..color = const Color(0xFFFFF5EB),
    );

    // Silhouette hills
    final hill1 = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.68)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.48,
        size.width * 0.75,
        size.height * 0.76,
      )
      ..lineTo(size.width, size.height * 0.65)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(hill1, Paint()..color = const Color(0xFF2E9473));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom Painter for the Dusk Horizon Dial on Slide 2
class _DuskHorizonDialPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 6);
    final radius = size.width / 2 - 14;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background track arc
    final trackPaint = Paint()
      ..color = const Color(0xFFF2ECE2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, math.pi, math.pi, false, trackPaint);

    // Gradient progress arc
    final gradPaint = Paint()
      ..shader = const SweepGradient(
        startAngle: math.pi,
        endAngle: 2 * math.pi,
        colors: [
          Color(0xFF4A84D8),
          Color(0xFFFF9B50),
          Color(0xFFFF7A1A),
        ],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round;

    const sweep = math.pi * 0.78;
    canvas.drawArc(rect, math.pi, sweep, false, gradPaint);

    // Glowing Sun Orb on the arc tip
    final angle = math.pi + sweep;
    final sunOffset = Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );
    canvas.drawCircle(
      sunOffset,
      9,
      Paint()..color = const Color(0xFFFF7A1A).withValues(alpha: 0.25),
    );
    canvas.drawCircle(
      sunOffset,
      5.5,
      Paint()..color = const Color(0xFFFF7A1A),
    );
    canvas.drawCircle(
      sunOffset,
      2.2,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
