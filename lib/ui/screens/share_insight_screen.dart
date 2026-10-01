import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/insight_card.dart';
import '../widgets/dusk_ui_components.dart';
import '../widgets/editorial_insight_card.dart';

class ShareInsightScreen extends StatefulWidget {
  final Map<String, dynamic>? insight;
  final InsightCard? insightCard;
  final EditorialThemeId? initialTheme;
  final EditorialCardFormat? initialFormat;

  const ShareInsightScreen({
    super.key,
    this.insight,
    this.insightCard,
    this.initialTheme,
    this.initialFormat,
  });

  factory ShareInsightScreen.fromCard(
    InsightCard card, {
    Key? key,
    EditorialThemeId? initialTheme,
    EditorialCardFormat? initialFormat,
  }) {
    return ShareInsightScreen(
      key: key,
      insightCard: card,
      initialTheme: initialTheme,
      initialFormat: initialFormat,
    );
  }

  @override
  State<ShareInsightScreen> createState() => _ShareInsightScreenState();
}

class _ShareInsightScreenState extends State<ShareInsightScreen> {
  final GlobalKey _boundaryKey = GlobalKey();

  late final EditorialInsightData _insightData;
  EditorialThemeId _selectedTheme = EditorialThemeId.warmPaper;
  static const EditorialCardFormat _selectedFormat = EditorialCardFormat.wallpaper9x16;
  EditorialComposition _selectedComposition = EditorialComposition.fullSynthesis;
  EditorialColophonStyle _selectedColophon = EditorialColophonStyle.personal;
  static const bool _showDateStamp = true;
  static const bool _showTextureAndRules = true;

  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    if (widget.insightCard != null) {
      _insightData = EditorialInsightData.fromInsightCard(widget.insightCard!);
    } else if (widget.insight != null) {
      _insightData = EditorialInsightData.fromMap(widget.insight!);
    } else {
      _insightData = EditorialInsightData(
        id: 'preview',
        title: 'Evening Reflection',
        mainInsight: 'A mindful pause brings clarity to the rhythm of your days.',
        standout: 'Taking a quiet moment to observe thoughts without judgment.',
        suggestion: 'Carry today’s stillness into tomorrow morning.',
        createdAt: DateTime.now(),
      );
    }

    if (widget.initialTheme != null) {
      _selectedTheme = widget.initialTheme!;
    }

    _loadSavedPreferences();
  }

  Future<void> _loadSavedPreferences() async {
    final prefs = await EditorialStudioPreferences.loadAll();
    if (!mounted) return;
    setState(() {
      if (widget.initialTheme == null) {
        _selectedTheme = prefs['theme'] as EditorialThemeId;
      }
      _selectedComposition = prefs['composition'] as EditorialComposition;
      _selectedColophon = prefs['colophon'] as EditorialColophonStyle;
    });
  }

  void _persistPreferences() {
    EditorialStudioPreferences.saveAll(
      theme: _selectedTheme,
      format: _selectedFormat,
      composition: _selectedComposition,
      colophon: _selectedColophon,
      showDate: _showDateStamp,
      showTexture: _showTextureAndRules,
    );
  }

  Rect? _getShareOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _handleShareImage() async {
    if (_isSharing) return;
    HapticFeedback.mediumImpact();
    setState(() => _isSharing = true);

    try {
      await InsightCardExportService.shareAsImage(
        boundaryKey: _boundaryKey,
        insight: _insightData,
        theme: _selectedTheme,
        format: _selectedFormat,
        sharePositionOrigin: _getShareOrigin(),
      );
    } catch (e) {
      if (mounted) {
        _showToast(
          'Could not share image: $e',
          icon: Icons.error_outline_rounded,
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  void _showToast(
    String message, {
    required IconData icon,
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1B1A19),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isError
                  ? const Color(0xFFFF6B6B)
                  : const Color(0xFFFF7A1A),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Color(0xFFFAF8F5),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F2),
      body: DuskAmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // 1. Share Top Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                child: Row(
                  children: [
                    DuskCircleButton(
                      icon: Icons.close_rounded,
                      size: 40,
                      iconSize: 19,
                      tooltip: 'Close',
                      onTap: () => Navigator.of(context).pop(_selectedTheme),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Share Reflection',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1B1A19),
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),

              // 2. Interactive 9:16 Canvas Preview Stage (Live updating)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.14),
                              blurRadius: 36,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: RepaintBoundary(
                            key: _boundaryKey,
                            child: SizedBox(
                              width: 420,
                              height: 746.67, // Fixed 9:16 mobile aspect ratio
                              child: EditorialInsightCardCanvas(
                                insight: _insightData,
                                theme: _selectedTheme,
                                format: EditorialCardFormat.wallpaper9x16,
                                composition: _selectedComposition,
                                colophon: _selectedColophon,
                                showDateStamp: _showDateStamp,
                                showTextureAndRules: _showTextureAndRules,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ).animate().fadeIn(duration: 280.ms).scale(
                      begin: const Offset(0.97, 0.97),
                      curve: Curves.easeOutCubic,
                    ),
              ),

              // 3. Simplified, Clean Control Dock
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  border: const Border(
                    top: BorderSide(color: Color(0xFFEDE6DA), width: 1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Themes Selector Bar (Live Preview)
                      EditorialThemeSelectorBar(
                        selectedTheme: _selectedTheme,
                        compact: true,
                        onThemeSelected: (theme) {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedTheme = theme);
                          _persistPreferences();
                        },
                      ),

                      const SizedBox(height: 16),

                      // Primary Share Action CTA
                      SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _isSharing ? null : _handleShareImage,
                          icon: _isSharing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.ios_share_rounded,
                                  size: 20,
                                ),
                          label: Text(
                            _isSharing ? 'Preparing...' : 'Share',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15.5,
                              letterSpacing: 0.2,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B1A19),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                          ),
                        ),
                      ),
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
}
