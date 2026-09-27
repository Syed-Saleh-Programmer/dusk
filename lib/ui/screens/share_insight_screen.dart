import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
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
  EditorialCardFormat _selectedFormat = EditorialCardFormat.editorialCard;
  EditorialComposition _selectedComposition = EditorialComposition.fullSynthesis;
  EditorialColophonStyle _selectedColophon = EditorialColophonStyle.personal;
  bool _showDateStamp = true;
  bool _showTextureAndRules = true;
  bool _showLockscreenClockPreview = true;

  int _activeStudioTab = 0; // 0: Theme, 1: Format & Layout, 2: Clean Details
  bool _isSharing = false;
  bool _isSaving = false;

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
    if (widget.initialFormat != null) {
      _selectedFormat = widget.initialFormat!;
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
      if (widget.initialFormat == null) {
        _selectedFormat = prefs['format'] as EditorialCardFormat;
      }
      _selectedComposition = prefs['composition'] as EditorialComposition;
      _selectedColophon = prefs['colophon'] as EditorialColophonStyle;
      _showDateStamp = prefs['showDate'] as bool;
      _showTextureAndRules = prefs['showTexture'] as bool;
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
    if (_isSharing || _isSaving) return;
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

  Future<void> _handleSaveOrWallpaper() async {
    if (_isSaving || _isSharing) return;
    HapticFeedback.mediumImpact();

    // If on Android and in 9:16 Wallpaper format, offer quick choice or save directly
    if (Platform.isAndroid &&
        _selectedFormat == EditorialCardFormat.wallpaper9x16) {
      _showWallpaperExportSheet();
      return;
    }

    await _savePngToDevice();
  }

  Future<void> _savePngToDevice() async {
    setState(() => _isSaving = true);
    try {
      final result = await InsightCardExportService.saveToDevice(
        boundaryKey: _boundaryKey,
        theme: _selectedTheme,
        format: _selectedFormat,
      );
      if (!mounted) return;
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1B1A19),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF2DC48D),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedFormat == EditorialCardFormat.wallpaper9x16
                          ? 'Wallpaper exported'
                          : 'Editorial card saved',
                      style: const TextStyle(
                        color: Color(0xFFFAF8F5),
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    Text(
                      result.displayLocation,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFB5AFA6),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'SHARE',
            textColor: const Color(0xFFFF7A1A),
            onPressed: () {
              SharePlus.instance.share(
                ShareParams(
                  files: [result.xFile],
                  subject: _insightData.title,
                ),
              );
            },
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (mounted) {
        _showToast(
          'Could not export image: $e',
          icon: Icons.error_outline_rounded,
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showWallpaperExportSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF9F7F2),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD6CFC4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  'Wallpaper & Export Options',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B1A19),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'High-resolution 9:16 canvas with lockscreen clock safe-zone.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF7A736A),
                  ),
                ),
                const SizedBox(height: 18),
                _buildExportOptionTile(
                  icon: Icons.download_rounded,
                  title: 'Save High-Res PNG to Gallery',
                  subtitle: 'Saves to Pictures/Dusk for clean archival or manual crop',
                  accentColor: const Color(0xFFFF7A1A),
                  onTap: () {
                    Navigator.pop(ctx);
                    _savePngToDevice();
                  },
                ),
                const SizedBox(height: 10),
                _buildExportOptionTile(
                  icon: Icons.lock_outline_rounded,
                  title: 'Apply as Lockscreen Wallpaper',
                  subtitle: 'Directly set this editorial insight on your lockscreen',
                  accentColor: const Color(0xFF4A84D8),
                  onTap: () async {
                    Navigator.pop(ctx);
                    setState(() => _isSaving = true);
                    final applied =
                        await InsightCardExportService.applyWallpaper(
                      boundaryKey: _boundaryKey,
                      target: 'lock',
                    );
                    if (!mounted) return;
                    setState(() => _isSaving = false);
                    if (applied) {
                      _showToast(
                        'Lockscreen wallpaper updated',
                        icon: Icons.check_circle_rounded,
                      );
                    } else {
                      await _savePngToDevice();
                    }
                  },
                ),
                const SizedBox(height: 10),
                _buildExportOptionTile(
                  icon: Icons.wallpaper_rounded,
                  title: 'Apply to Both Lock & Home Screen',
                  subtitle: 'Set across your entire device backdrop',
                  accentColor: const Color(0xFF389F7F),
                  onTap: () async {
                    Navigator.pop(ctx);
                    setState(() => _isSaving = true);
                    final applied =
                        await InsightCardExportService.applyWallpaper(
                      boundaryKey: _boundaryKey,
                      target: 'both',
                    );
                    if (!mounted) return;
                    setState(() => _isSaving = false);
                    if (applied) {
                      _showToast(
                        'Device wallpaper updated',
                        icon: Icons.check_circle_rounded,
                      );
                    } else {
                      await _savePngToDevice();
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExportOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEDE6DA)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B1A19),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7D766D),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFB5AFA6),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleCopyText() async {
    HapticFeedback.selectionClick();
    final formatted = InsightCardExportService.formatEditorialText(
      _insightData,
      composition: _selectedComposition,
      colophon: _selectedColophon,
    );
    await Clipboard.setData(ClipboardData(text: formatted));
    if (!mounted) return;
    _showToast(
      'Editorial note copied to clipboard',
      icon: Icons.check_circle_rounded,
    );
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
    final isWallpaper = _selectedFormat == EditorialCardFormat.wallpaper9x16;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F2),
      body: DuskAmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // 1. Studio Top Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                child: Row(
                  children: [
                    DuskCircleButton(
                      icon: Icons.close_rounded,
                      size: 40,
                      iconSize: 19,
                      tooltip: 'Close Studio',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: const [
                          Text(
                            'Editorial Studio',
                            style: TextStyle(
                              fontSize: 17.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1B1A19),
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            'Personal print & wallpaper export',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF857E74),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    DuskCircleButton(
                      icon: Icons.content_copy_rounded,
                      size: 40,
                      iconSize: 18,
                      tooltip: 'Copy formatted text',
                      onTap: _handleCopyText,
                    ),
                  ],
                ),
              ),

              // 2. Interactive Canvas Preview Stage
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 6,
                  ),
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Shadowed frame around the RepaintBoundary
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 32,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: RepaintBoundary(
                              key: _boundaryKey,
                              child: EditorialInsightCardCanvas(
                                insight: _insightData,
                                theme: _selectedTheme,
                                format: _selectedFormat,
                                composition: _selectedComposition,
                                colophon: _selectedColophon,
                                showDateStamp: _showDateStamp,
                                showTextureAndRules: _showTextureAndRules,
                              ),
                            ),
                          ),
                        ),

                        // Non-exported Lockscreen Clock Safe-Zone Overlay Preview
                        if (isWallpaper && _showLockscreenClockPreview)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: _LockscreenClockPreviewOverlay(
                                isDarkTheme: _selectedTheme.isDark,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 280.ms).scale(
                      begin: const Offset(0.97, 0.97),
                      curve: Curves.easeOutCubic,
                    ),
              ),

              // 3. Studio Control Dock
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
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Studio Control Section Switcher
                    Row(
                      children: [
                        _buildControlTabPill(
                          index: 0,
                          icon: Icons.palette_outlined,
                          label: 'Theme',
                        ),
                        const SizedBox(width: 8),
                        _buildControlTabPill(
                          index: 1,
                          icon: Icons.aspect_ratio_rounded,
                          label: 'Canvas & Layout',
                        ),
                        const SizedBox(width: 8),
                        _buildControlTabPill(
                          index: 2,
                          icon: Icons.tune_rounded,
                          label: 'Clean Details',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Active Control Content
                    SizedBox(
                      height: 68,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _buildActiveStudioControls(),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Primary Export & Share Action Row
                    Row(
                      children: [
                        // Save Wallpaper / Export PNG Button
                        Expanded(
                          flex: 5,
                          child: SizedBox(
                            height: 52,
                            child: OutlinedButton.icon(
                              onPressed: (_isSaving || _isSharing)
                                  ? null
                                  : _handleSaveOrWallpaper,
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF1B1A19),
                                      ),
                                    )
                                  : Icon(
                                      isWallpaper
                                          ? Icons.wallpaper_rounded
                                          : Icons.download_rounded,
                                      size: 19,
                                    ),
                              label: Text(
                                _isSaving
                                    ? 'Saving...'
                                    : (isWallpaper
                                        ? 'Wallpaper'
                                        : 'Save PNG'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF1B1A19),
                                backgroundColor: const Color(0xFFF9F7F2),
                                side: const BorderSide(
                                  color: Color(0xFFE2DBD0),
                                  width: 1.2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(26),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Share Image Primary CTA
                        Expanded(
                          flex: 7,
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: (_isSharing || _isSaving)
                                  ? null
                                  : _handleShareImage,
                              icon: _isSharing
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.ios_share_rounded,
                                      size: 19,
                                    ),
                              label: Text(
                                _isSharing ? 'Rendering...' : 'Share Image',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF7A1A),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(26),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlTabPill({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _activeStudioTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _activeStudioTab = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFFDE8D7)
                : const Color(0xFFF6F3ED),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFFF7A1A).withValues(alpha: 0.35)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected
                    ? const Color(0xFFD65A00)
                    : const Color(0xFF7D766D),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected
                        ? const Color(0xFF1B1A19)
                        : const Color(0xFF7D766D),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveStudioControls() {
    switch (_activeStudioTab) {
      case 0:
        return Align(
          key: const ValueKey('tab_theme'),
          alignment: Alignment.centerLeft,
          child: EditorialThemeSelectorBar(
            selectedTheme: _selectedTheme,
            onThemeSelected: (theme) {
              setState(() => _selectedTheme = theme);
              _persistPreferences();
            },
          ),
        );

      case 1:
        return SingleChildScrollView(
          key: const ValueKey('tab_format'),
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              // Aspect Ratio / Format Chips
              ...EditorialCardFormat.values.map((format) {
                final isSelected = _selectedFormat == format;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildStudioChoiceChip(
                    icon: format.icon,
                    label: format.shortLabel,
                    subtitle: format == EditorialCardFormat.wallpaper9x16
                        ? 'Lockscreen'
                        : (format == EditorialCardFormat.editorialCard
                            ? 'Portrait'
                            : 'Square'),
                    isSelected: isSelected,
                    onTap: () {
                      setState(() => _selectedFormat = format);
                      _persistPreferences();
                    },
                  ),
                );
              }),
              Container(
                width: 1,
                height: 34,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: const Color(0xFFE6DFD3),
              ),
              // Composition Mode Chips
              ...EditorialComposition.values.map((comp) {
                final isSelected = _selectedComposition == comp;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildStudioChoiceChip(
                    icon: comp == EditorialComposition.distilledQuote
                        ? Icons.format_quote_rounded
                        : (comp == EditorialComposition.gentleIntention
                            ? Icons.explore_outlined
                            : Icons.subject_rounded),
                    label: comp.label,
                    subtitle: comp == EditorialComposition.distilledQuote
                        ? 'Minimal quote'
                        : (comp == EditorialComposition.gentleIntention
                            ? 'With next step'
                            : 'All 3 sections'),
                    isSelected: isSelected,
                    onTap: () {
                      setState(() => _selectedComposition = comp);
                      _persistPreferences();
                    },
                  ),
                );
              }),
            ],
          ),
        );

      case 2:
      default:
        return SingleChildScrollView(
          key: const ValueKey('tab_details'),
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              // Colophon / Branding Style (Anti-Ad options)
              ...EditorialColophonStyle.values.map((colophon) {
                final isSelected = _selectedColophon == colophon;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildStudioChoiceChip(
                    icon: colophon == EditorialColophonStyle.none
                        ? Icons.visibility_off_outlined
                        : (colophon == EditorialColophonStyle.personal
                            ? Icons.person_outline_rounded
                            : Icons.auto_stories_outlined),
                    label: colophon.label,
                    subtitle: colophon == EditorialColophonStyle.none
                        ? 'Zero branding'
                        : (colophon == EditorialColophonStyle.personal
                            ? 'Personal archive'
                            : 'Subtle colophon'),
                    isSelected: isSelected,
                    onTap: () {
                      setState(() => _selectedColophon = colophon);
                      _persistPreferences();
                    },
                  ),
                );
              }),
              Container(
                width: 1,
                height: 34,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: const Color(0xFFE6DFD3),
              ),
              _buildStudioChoiceChip(
                icon: Icons.calendar_today_rounded,
                label: 'Dateline',
                subtitle: _showDateStamp ? 'Visible' : 'Hidden',
                isSelected: _showDateStamp,
                onTap: () {
                  setState(() => _showDateStamp = !_showDateStamp);
                  _persistPreferences();
                },
              ),
              const SizedBox(width: 8),
              _buildStudioChoiceChip(
                icon: Icons.grain_rounded,
                label: 'Texture & Rules',
                subtitle: _showTextureAndRules ? 'Visible' : 'Clean',
                isSelected: _showTextureAndRules,
                onTap: () {
                  setState(() => _showTextureAndRules = !_showTextureAndRules);
                  _persistPreferences();
                },
              ),
              if (_selectedFormat == EditorialCardFormat.wallpaper9x16) ...[
                const SizedBox(width: 8),
                _buildStudioChoiceChip(
                  icon: Icons.access_time_rounded,
                  label: 'Clock Guide',
                  subtitle: _showLockscreenClockPreview ? 'Preview On' : 'Off',
                  isSelected: _showLockscreenClockPreview,
                  onTap: () {
                    setState(
                      () => _showLockscreenClockPreview =
                          !_showLockscreenClockPreview,
                    );
                  },
                ),
              ],
            ],
          ),
        );
    }
  }

  Widget _buildStudioChoiceChip({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1B1A19) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1B1A19)
                : const Color(0xFFE5DFD4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? const Color(0xFFFF9646)
                  : const Color(0xFF6E6862),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? const Color(0xFFFAF8F5)
                        : const Color(0xFF1B1A19),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? const Color(0xFFC2BDB5)
                        : const Color(0xFF8C857B),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Non-exported preview overlay showing where the phone's lockscreen clock sits
/// when designing a 9:16 wallpaper.
class _LockscreenClockPreviewOverlay extends StatelessWidget {
  final bool isDarkTheme;

  const _LockscreenClockPreviewOverlay({required this.isDarkTheme});

  @override
  Widget build(BuildContext context) {
    final color = isDarkTheme
        ? Colors.white.withValues(alpha: 0.32)
        : const Color(0xFF1B1A19).withValues(alpha: 0.25);

    return Column(
      children: [
        const SizedBox(height: 36),
        Text(
          '09:41',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: -1.0,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Text(
            'LOCKSCREEN SAFE ZONE PREVIEW',
            style: GoogleFonts.ibmPlexMono(
              fontSize: 7.5,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 1.0,
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }
}
