import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/dusk_logo.dart';
import '../widgets/dusk_ui_components.dart';
import '../navigation/dusk_navigation.dart';
import 'auth_screen.dart';
import 'home_screen.dart';

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
      tag: 'STEP 1 • RAW CAPTURE',
      tagVariant: DuskBadgeVariant.peach,
      tagIcon: Icons.bolt_rounded,
      title: 'Dump thoughts as they happen.',
      subtitle:
          'Drop fleeting thoughts, voice memos, and visual moments in seconds—zero folders, zero tags, zero pressure.',
      accentColor: Color(0xFFFF7A1A),
      glowColor: Color(0xFFFDE5CE),
      highlights: ['Quick Thoughts', 'Voice Memos', 'Photo Moments'],
    ),
    _OnboardingSlideData(
      tag: 'STEP 2 • CALM RHYTHM',
      tagVariant: DuskBadgeVariant.blue,
      tagIcon: Icons.wb_twilight_rounded,
      title: 'Reflect on your own rhythm.',
      subtitle:
          'No guilt-driven streak pressure. Dusk gently chimes when it is time to pause—daily, every 3 days, or weekly.',
      accentColor: Color(0xFF4A84D8),
      glowColor: Color(0xFFDCEBFA),
      highlights: ['Custom Cadence', 'Gentle Alarm Chimes', 'Zero Guilt'],
    ),
    _OnboardingSlideData(
      tag: 'STEP 3 • AI SYNTHESIS & DUSK BUDDY',
      tagVariant: DuskBadgeVariant.orange,
      tagIcon: Icons.auto_awesome_rounded,
      title: 'Turn dumps into clarity & chat with Buddy.',
      subtitle:
          'When your cycle completes, Dusk AI synthesizes themes and Insight Cards. Chat directly with Dusk Buddy to question your dumps and reflections.',
      accentColor: Color(0xFFE06D14),
      glowColor: Color(0xFFFCE6D2),
      highlights: ['Dusk Buddy Chat', 'Cycle Summary', 'Insight Cards'],
    ),
    _OnboardingSlideData(
      tag: 'STEP 4 • TASK EXTRACTION & VAULT',
      tagVariant: DuskBadgeVariant.green,
      tagIcon: Icons.task_alt_rounded,
      title: 'Actionable tasks, private forever.',
      subtitle:
          'Action items are automatically extracted from your voice and notes. Protected offline with strict encryption.',
      accentColor: Color(0xFF2DC48D),
      glowColor: Color(0xFFDDF4EC),
      highlights: ['Auto Task Extraction', 'Offline-First Vault', 'Zero Ads'],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _continueAsFreeUser() async {
    HapticFeedback.lightImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    await prefs.setBool('hasChosenGuestMode', true);

    if (!mounted) return;
    if (widget.isPreview) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        DuskPageRoute.flowProgression(builder: (_) => const HomeScreen()),
      );
    }
  }

  Future<void> _goToAuth() async {
    HapticFeedback.lightImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);

    if (!mounted) return;
    if (widget.isPreview) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        DuskPageRoute.flowProgression(builder: (_) => const AuthScreen()),
      );
    }
  }

  Future<void> _finishOnboarding() async {
    if (widget.isPreview) {
      Navigator.of(context).pop();
      return;
    }

    // Show clean bottom sheet allowing user to choose between Free Guest Mode or Pro Account
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDD8CF),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'How would you like to start?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B1A19),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose how you want to experience Dusk. You can always sign in or upgrade later.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF756F68),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              // Option 1: Continue without account (Free Users)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _continueAsFreeUser();
                  },
                  icon: const Icon(Icons.flash_on_rounded, color: Color(0xFFFF7A1A), size: 20),
                  label: const Text(
                    'Continue as Free User (Local Vault)',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B1A19),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFEBE5DC), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Option 2: Sign In / Create Account (Pro Users)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _goToAuth();
                  },
                  icon: const Icon(Icons.cloud_sync_rounded, color: Colors.white, size: 20),
                  label: const Text(
                    'Create Account / Log In (Cloud Sync)',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7A1A),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
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

  Widget _buildMockupContent(int index) {
    switch (index) {
      case 0:
        return const _CaptureMockupScreen();
      case 1:
        return const _RitualMockupScreen();
      case 2:
        return const _InsightMockupScreen();
      case 3:
      default:
        return const _TasksMockupScreen();
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
              // Top Header Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                child: Row(
                  children: [
                    const DuskLogo(size: 36, showBadgeContainer: true),
                    const SizedBox(width: 10),
                    const Text(
                      'Dusk',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B1A19),
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
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
                          backgroundColor: Colors.white.withValues(alpha: 0.8),
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

              // Main PageView with Mobile Mockup Device Frame
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
                    return AnimatedBuilder(
                      animation: _pageController,
                      builder: (context, child) {
                        double page = _currentPage.toDouble();
                        if (_pageController.hasClients &&
                            _pageController.position.haveDimensions) {
                          page = _pageController.page ?? _currentPage.toDouble();
                        }
                        final delta = (index - page).clamp(-1.0, 1.0);
                        final absDelta = delta.abs();
                        final scale = 1.0 - (0.07 * absDelta);
                        final angleY = delta * -0.16;

                        final matrix = Matrix4.identity()
                          ..setEntry(3, 2, 0.0012)
                          ..scaleByDouble(scale, scale, 1.0, 1.0)
                          ..rotateY(angleY);

                        return Transform(
                          alignment: delta >= 0
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                          transform: matrix,
                          child: child,
                        );
                      },
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20.0,
                              vertical: 6.0,
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: math.max(
                                  0.0,
                                  constraints.maxHeight - 12.0,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Mobile Mockup Frame Showcase
                                  Center(
                                    child: _MobileMockupDevice(
                                      accentColor: slide.accentColor,
                                      child: _buildMockupContent(index),
                                    ),
                                  )
                                      .animate(key: ValueKey('mockup_$index'))
                                      .fadeIn(duration: 400.ms)
                                      .slideY(begin: 0.04),

                                  const SizedBox(height: 18),

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
                                          fontSize: 24,
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
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: slide.highlights.map((chip) {
                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 11,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: const Color(0xFFEBE5DC),
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(
                                                    alpha: 0.02,
                                                  ),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.check_circle_rounded,
                                                  size: 14,
                                                  color: slide.accentColor,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  chip,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF1B1A19),
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
                                      .fadeIn(delay: 80.ms, duration: 380.ms)
                                      .slideY(begin: 0.04),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),

              // Bottom Navigation Bar with Perfectly Aligned, Uncut Buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                child: Row(
                  children: [
                    // Smooth Page Indicator Dots
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

                    const Spacer(),

                    // Back Circle Button
                    if (_currentPage > 0) ...[
                      DuskCircleButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        size: 46,
                        iconSize: 18,
                        onTap: _previousPage,
                      ),
                      const SizedBox(width: 12),
                    ],

                    // Primary Forward Button (Never cut off or truncated)
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF7A1A),
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shadowColor:
                              const Color(0xFFFF7A1A).withValues(alpha: 0.35),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isLastPage
                                  ? (widget.isPreview
                                      ? 'Done'
                                      : 'Get Started')
                                  : 'Continue',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              isLastPage
                                  ? Icons.auto_awesome_rounded
                                  : Icons.arrow_forward_rounded,
                              size: 18,
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

/// A realistic, elegant Mobile Device Mockup frame inspired by modern web landing pages
class _MobileMockupDevice extends StatelessWidget {
  final Widget child;
  final Color accentColor;

  const _MobileMockupDevice({
    required this.child,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 275,
      height: 270,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1D1C),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFF3B3835), width: 3.5),
        boxShadow: [
          // Soft ambient colored glow behind device
          BoxShadow(
            color: accentColor.withValues(alpha: 0.16),
            blurRadius: 28,
            offset: const Offset(0, 12),
            spreadRadius: 2,
          ),
          // Deep realistic ground drop shadow
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(27),
        child: Container(
          color: const Color(0xFFF9F7F2),
          child: Column(
            children: [
              // Top Mobile Status Bar + Dynamic Island
              Container(
                height: 24,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                color: Colors.white.withValues(alpha: 0.7),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '9:41',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF756F68),
                      ),
                    ),
                    // Dynamic Island Pill
                    Container(
                      width: 52,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFF141312),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            width: 3.5,
                            height: 3.5,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: const BoxDecoration(
                              color: Color(0xFF2C3240),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wifi, size: 10, color: Color(0xFF756F68)),
                        SizedBox(width: 4),
                        Icon(
                          Icons.battery_full_rounded,
                          size: 11,
                          color: Color(0xFF756F68),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Mockup Inner Screen Contents
              Expanded(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                  child: child,
                ),
              ),

              // Bottom Home Indicator Bar
              Container(
                height: 12,
                alignment: Alignment.center,
                child: Container(
                  width: 50,
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC7BFB4),
                    borderRadius: BorderRadius.circular(2),
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

/// MOCKUP SCREEN 1: RAW CAPTURE / DUMP FLOW
class _CaptureMockupScreen extends StatelessWidget {
  const _CaptureMockupScreen();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Mini App Bar inside mockup
        Row(
          children: [
            const DuskLogo(size: 18, showBadgeContainer: true),
            const SizedBox(width: 6),
            const Text(
              'Quick Dump',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1B1A19),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0E4),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Live',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFF7A1A),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 7),

        // 1. Text Thought Capture
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: const Color(0xFFEDE6DA)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDE8D7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Thought',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFD66B1E),
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    '2:15 PM',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF99938B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              const Text(
                '"Focus evening rituals on calmness rather than output."',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1B1A19),
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        // 2. Voice Memo Capture with Waveform
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: const Color(0xFFDCE8F8), width: 1.1),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF639BF0), Color(0xFF3B7ED4)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mic_rounded, color: Colors.white, size: 13),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Walk voice memo',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1B1A19),
                          ),
                        ),
                        Text(
                          '0:42',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF3B7ED4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    SizedBox(
                      height: 10,
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

        const SizedBox(height: 6),

        // 3. Photo Moment Capture
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: const Color(0xFFEDE6DA)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CustomPaint(
                    painter: _MiniSunsetLandscapePainter(),
                  ),
                ),
              ),
              const SizedBox(width: 7),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Photo Moment',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2E9473),
                      ),
                    ),
                    Text(
                      'Golden hour quiet on desk',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1B1A19),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const Spacer(),

        // Bottom Capture Dock
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
          decoration: BoxDecoration(
            color: const Color(0xFFF1EBE1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildDockButton(Icons.edit_note_rounded, 'Thought', const Color(0xFFFF7A1A)),
              _buildDockButton(Icons.mic_none_rounded, 'Voice', const Color(0xFF3B7ED4)),
              _buildDockButton(Icons.camera_alt_outlined, 'Moment', const Color(0xFF2E9473)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDockButton(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// MOCKUP SCREEN 2: CADENCE & EVENING REFLECTION
class _RitualMockupScreen extends StatelessWidget {
  const _RitualMockupScreen();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Mini App Bar
        Row(
          children: [
            const DuskLogo(size: 18, showBadgeContainer: true),
            const SizedBox(width: 6),
            const Text(
              'Evening Rhythm',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1B1A19),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F0FC),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Cadence',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF3B7ED4),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 6),

        // Sunset Horizon Arc Dial
        Center(
          child: SizedBox(
            height: 68,
            width: 140,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                CustomPaint(
                  size: const Size(140, 68),
                  painter: _DuskHorizonDialPainter(),
                ),
                const Positioned(
                  bottom: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '9:00 PM',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1B1A19),
                          letterSpacing: -0.4,
                        ),
                      ),
                      Text(
                        'Evening Reflection',
                        style: TextStyle(
                          fontSize: 8.5,
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
        ),

        const SizedBox(height: 8),

        // Cadence Selector Pills
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCadencePill('Daily', false),
            const SizedBox(width: 5),
            _buildCadencePill('Every 3 Days', true),
            const SizedBox(width: 5),
            _buildCadencePill('Weekly', false),
          ],
        ),

        const Spacer(),

        // Notification Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFEDE6DA)),
          ),
          child: const Row(
            children: [
              Icon(Icons.notifications_active_outlined, size: 12, color: Color(0xFFFF7A1A)),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  '14 captures ready to synthesize',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4A453F),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 5),

        // Action Button
        Container(
          height: 26,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF852A), Color(0xFFFF6600)],
            ),
            borderRadius: BorderRadius.circular(13),
          ),
          alignment: Alignment.center,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Begin Reflection',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward_rounded, size: 10, color: Colors.white),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCadencePill(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFFFF1E4) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? const Color(0xFFFF7A1A) : const Color(0xFFE2DCD2),
          width: active ? 1.2 : 0.8,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: active ? FontWeight.w800 : FontWeight.w600,
          color: active ? const Color(0xFFC75505) : const Color(0xFF756F68),
        ),
      ),
    );
  }
}

/// MOCKUP SCREEN 3: AI CYCLE SUMMARY (SYNTHESIS)
class _InsightMockupScreen extends StatelessWidget {
  const _InsightMockupScreen();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Mini App Bar
        Row(
          children: [
            const DuskLogo(size: 18, showBadgeContainer: true),
            const SizedBox(width: 6),
            const Text(
              'AI Synthesis',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1B1A19),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0E4),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 8.5, color: Color(0xFFFF7A1A)),
                  SizedBox(width: 3),
                  Text(
                    'Cycle #14',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFF7A1A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 7),

        // Prompt Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1D1C),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 10, color: Color(0xFFFF9B50)),
              SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Q: What gave you the most calm this cycle?',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 7),

        // Insight Card Showcase
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEDE6DA)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF7A1A).withValues(alpha: 0.05),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDE8D7),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Text(
                      'INSIGHT CARD',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFD66B1E),
                      ),
                    ),
                  ),
                  const Text(
                    '3 Days Synthesis',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF99938B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Protecting Unstructured Focus',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B1A19),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Your clearest breakthroughs occurred during evening walks rather than at your desk.',
                style: TextStyle(
                  fontSize: 8.5,
                  color: Color(0xFF6E6862),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8F2),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: const Color(0xFFFF7A1A).withValues(alpha: 0.25),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.compass_calibration_rounded,
                      size: 10,
                      color: Color(0xFFFF7A1A),
                    ),
                    SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'Next: Block 20 min quiet walk before dinner',
                        style: TextStyle(
                          fontSize: 8,
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

        const Spacer(),

        // Bottom AI Stat Indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF3EC),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome_rounded, size: 10, color: Color(0xFFFF7A1A)),
              SizedBox(width: 4),
              Text(
                'Dusk Buddy AI Chat • 1 Insight Distilled',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF756F68),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// MOCKUP SCREEN 4: TASK EXTRACTION & SANCTUARY VAULT
class _TasksMockupScreen extends StatelessWidget {
  const _TasksMockupScreen();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Mini App Bar
        Row(
          children: [
            const DuskLogo(size: 18, showBadgeContainer: true),
            const SizedBox(width: 6),
            const Text(
              'Extracted Tasks',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1B1A19),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE4F5EE),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '3 Actionable',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2E9473),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 7),

        // Extracted Task 1
        _buildTaskItem(
          checked: true,
          title: 'Finalize design proposal draft',
          sourceTag: 'from voice memo',
          badgeColor: const Color(0xFF3B7ED4),
        ),

        const SizedBox(height: 5),

        // Extracted Task 2
        _buildTaskItem(
          checked: false,
          title: 'Send sync email to team',
          sourceTag: 'from thought #2',
          badgeColor: const Color(0xFFFF7A1A),
        ),

        const SizedBox(height: 5),

        // Extracted Task 3
        _buildTaskItem(
          checked: false,
          title: 'Block 20 min quiet walk before dinner',
          sourceTag: 'from insight card',
          badgeColor: const Color(0xFF2E9473),
        ),

        const Spacer(),

        // Sanctuary Security & Vault Seal
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFD6EFE5)),
          ),
          child: const Row(
            children: [
              Icon(Icons.shield_outlined, size: 12, color: Color(0xFF2DC48D)),
              SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Offline-First Sanctuary • Row-Level Vault',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF267D5C),
                  ),
                ),
              ),
              Icon(Icons.lock_rounded, size: 10, color: Color(0xFF2DC48D)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTaskItem({
    required bool checked,
    required String title,
    required String sourceTag,
    required Color badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFEDE6DA)),
      ),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: checked ? const Color(0xFF2DC48D) : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: checked ? const Color(0xFF2DC48D) : const Color(0xFFB5ADA0),
                width: 1.2,
              ),
            ),
            child: checked
                ? const Icon(Icons.check_rounded, size: 10, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    decoration:
                        checked ? TextDecoration.lineThrough : null,
                    color: checked
                        ? const Color(0xFF88827A)
                        : const Color(0xFF1B1A19),
                  ),
                ),
                Text(
                  sourceTag,
                  style: TextStyle(
                    fontSize: 7.5,
                    fontWeight: FontWeight.w600,
                    color: badgeColor,
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

/// Custom Painter for the Voice Memo Waveform
class _WaveformBarsPainter extends CustomPainter {
  static const List<double> _heights = [
    0.35, 0.65, 0.9, 0.5, 0.8, 1.0, 0.7, 0.4, 0.85,
    0.95, 0.6, 0.45, 0.75, 0.55, 0.3, 0.5, 0.7, 0.4,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = _heights.length;
    final spacing = size.width / barCount;
    final barWidth = math.max(1.8, spacing * 0.42);

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

/// Custom Painter for the Sunset Landscape Thumbnail
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
      5,
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

/// Custom Painter for the Dusk Horizon Dial
class _DuskHorizonDialPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 4);
    final radius = size.width / 2 - 10;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background track arc
    final trackPaint = Paint()
      ..color = const Color(0xFFF2ECE2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
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
      ..strokeWidth = 8
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
      7,
      Paint()..color = const Color(0xFFFF7A1A).withValues(alpha: 0.25),
    );
    canvas.drawCircle(
      sunOffset,
      4.5,
      Paint()..color = const Color(0xFFFF7A1A),
    );
    canvas.drawCircle(
      sunOffset,
      1.8,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
