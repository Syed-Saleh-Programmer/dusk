import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/insight_card.dart';

/// Available minimalist editorial themes for the Insight Card Studio.
enum EditorialThemeId {
  obsidianDark(
    id: 'obsidian_dark',
    label: 'Obsidian Dark',
    subtitle: 'Monolith & Gold',
    swatchPrimary: Color(0xFF111115),
    swatchSecondary: Color(0xFFD9A760),
    isDark: true,
  ),
  warmPaper(
    id: 'warm_paper',
    label: 'Warm Paper',
    subtitle: 'Broadsheet & Serif',
    swatchPrimary: Color(0xFFF6F0E4),
    swatchSecondary: Color(0xFFC85A28),
    isDark: false,
  ),
  twilightGradient(
    id: 'twilight_gradient',
    label: 'Twilight',
    subtitle: 'Dusk Horizon',
    swatchPrimary: Color(0xFF281E38),
    swatchSecondary: Color(0xFFFFB085),
    isDark: true,
  ),
  swissAlabaster(
    id: 'swiss_alabaster',
    label: 'Alabaster',
    subtitle: 'Swiss Gallery',
    swatchPrimary: Color(0xFFFFFFFF),
    swatchSecondary: Color(0xFF2B5B46),
    isDark: false,
  );

  final String id;
  final String label;
  final String subtitle;
  final Color swatchPrimary;
  final Color swatchSecondary;
  final bool isDark;

  const EditorialThemeId({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.swatchPrimary,
    required this.swatchSecondary,
    required this.isDark,
  });

  static EditorialThemeId fromId(String? id) {
    return EditorialThemeId.values.firstWhere(
      (e) => e.id == id,
      orElse: () => EditorialThemeId.warmPaper,
    );
  }
}

/// Export aspect ratio & canvas format options.
enum EditorialCardFormat {
  editorialCard(
    id: 'card_4_5',
    label: 'Editorial Card',
    shortLabel: '4:5 Card',
    aspectRatio: 4 / 5,
    icon: Icons.crop_portrait_rounded,
  ),
  wallpaper9x16(
    id: 'wallpaper_9_16',
    label: 'Lockscreen Wallpaper',
    shortLabel: '9:16 Wallpaper',
    aspectRatio: 9 / 16,
    icon: Icons.stay_current_portrait_rounded,
  ),
  square1x1(
    id: 'square_1_1',
    label: 'Gallery Square',
    shortLabel: '1:1 Print',
    aspectRatio: 1.0,
    icon: Icons.crop_square_rounded,
  );

  final String id;
  final String label;
  final String shortLabel;
  final double aspectRatio;
  final IconData icon;

  const EditorialCardFormat({
    required this.id,
    required this.label,
    required this.shortLabel,
    required this.aspectRatio,
    required this.icon,
  });

  static EditorialCardFormat fromId(String? id) {
    return EditorialCardFormat.values.firstWhere(
      (e) => e.id == id,
      orElse: () => EditorialCardFormat.editorialCard,
    );
  }
}

/// Content density / focus modes so sharing feels personal rather than templated.
enum EditorialComposition {
  fullSynthesis(
    id: 'full_synthesis',
    label: 'Full Synthesis',
    subtitle: 'Pattern, standout & next step',
  ),
  distilledQuote(
    id: 'distilled_quote',
    label: 'Essence Quote',
    subtitle: 'Core insight in display type',
  ),
  gentleIntention(
    id: 'gentle_intention',
    label: 'Intention',
    subtitle: 'Insight & gentle next step',
  );

  final String id;
  final String label;
  final String subtitle;

  const EditorialComposition({
    required this.id,
    required this.label,
    required this.subtitle,
  });

  static EditorialComposition fromId(String? id) {
    return EditorialComposition.values.firstWhere(
      (e) => e.id == id,
      orElse: () => EditorialComposition.fullSynthesis,
    );
  }
}

/// Controls footer attribution so cards never feel like an advertisement.
enum EditorialColophonStyle {
  none(
    id: 'none',
    label: 'Unmarked',
  ),
  personal(
    id: 'personal',
    label: 'Personal Note',
  ),
  minimalDusk(
    id: 'minimal_dusk',
    label: 'Colophon',
  );

  final String id;
  final String label;

  const EditorialColophonStyle({
    required this.id,
    required this.label,
  });

  static EditorialColophonStyle fromId(String? id) {
    return EditorialColophonStyle.values.firstWhere(
      (e) => e.id == id,
      orElse: () => EditorialColophonStyle.personal,
    );
  }
}

/// Normalized data representation of an Insight Card (supports both [InsightCard] and Map).
class EditorialInsightData {
  final String id;
  final String title;
  final String mainInsight;
  final String standout;
  final String suggestion;
  final DateTime createdAt;

  const EditorialInsightData({
    required this.id,
    required this.title,
    required this.mainInsight,
    required this.standout,
    required this.suggestion,
    required this.createdAt,
  });

  factory EditorialInsightData.fromInsightCard(InsightCard card) {
    return EditorialInsightData(
      id: card.id,
      title: card.title.trim().isNotEmpty ? card.title.trim() : 'Evening Reflection',
      mainInsight: card.mainInsight.trim().isNotEmpty
          ? card.mainInsight.trim()
          : 'A mindful pause brings clarity to the rhythm of your days.',
      standout: card.standout.trim().isNotEmpty
          ? card.standout.trim()
          : 'Taking a quiet moment to observe your thoughts without judgment.',
      suggestion: card.suggestion.trim().isNotEmpty
          ? card.suggestion.trim()
          : 'Carry today’s stillness into tomorrow morning.',
      createdAt: card.createdAt,
    );
  }

  factory EditorialInsightData.fromMap(Map<String, dynamic> map) {
    DateTime parsedDate = DateTime.now();
    final rawDate = map['created_at'];
    if (rawDate is DateTime) {
      parsedDate = rawDate;
    } else if (rawDate is String && rawDate.isNotEmpty) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    }

    final title = (map['title'] as String?)?.trim() ?? '';
    final mainInsight = (map['main_insight'] as String?)?.trim() ?? '';
    final standout = (map['standout'] as String?)?.trim() ?? '';
    final suggestion = (map['suggestion'] as String?)?.trim() ?? '';

    return EditorialInsightData(
      id: map['id']?.toString() ?? 'insight',
      title: title.isNotEmpty ? title : 'Evening Reflection',
      mainInsight: mainInsight.isNotEmpty
          ? mainInsight
          : (standout.isNotEmpty
              ? standout
              : 'A mindful pause brings clarity to the rhythm of your days.'),
      standout: standout.isNotEmpty
          ? standout
          : (mainInsight.isNotEmpty
              ? mainInsight
              : 'Observing the quiet patterns beneath the surface of the day.'),
      suggestion: suggestion.isNotEmpty
          ? suggestion
          : 'Rest well and step into tomorrow with gentle intention.',
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'main_insight': mainInsight,
      'standout': standout,
      'suggestion': suggestion,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get formattedDateUpper =>
      DateFormat('MMM d, yyyy').format(createdAt).toUpperCase();

  String get formattedFullDate =>
      DateFormat('EEEE, MMMM d').format(createdAt);

  String get issueNumber {
    final dayOfYear = int.tryParse(DateFormat('D').format(createdAt)) ?? createdAt.day;
    return 'NO. ${dayOfYear.toString().padLeft(3, '0')}';
  }
}

/// Persists the user's preferred Editorial Studio settings in SharedPreferences.
class EditorialStudioPreferences {
  static const _keyTheme = 'editorial_studio_theme_v1';
  static const _keyFormat = 'editorial_studio_format_v1';
  static const _keyComposition = 'editorial_studio_composition_v1';
  static const _keyColophon = 'editorial_studio_colophon_v1';
  static const _keyShowDate = 'editorial_studio_show_date_v1';
  static const _keyShowTexture = 'editorial_studio_show_texture_v1';

  static Future<EditorialThemeId> loadPreferredTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return EditorialThemeId.fromId(prefs.getString(_keyTheme));
  }

  static Future<void> savePreferredTheme(EditorialThemeId theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTheme, theme.id);
  }

  static Future<Map<String, dynamic>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'theme': EditorialThemeId.fromId(prefs.getString(_keyTheme)),
      'format': EditorialCardFormat.fromId(prefs.getString(_keyFormat)),
      'composition': EditorialComposition.fromId(prefs.getString(_keyComposition)),
      'colophon': EditorialColophonStyle.fromId(prefs.getString(_keyColophon)),
      'showDate': prefs.getBool(_keyShowDate) ?? true,
      'showTexture': prefs.getBool(_keyShowTexture) ?? true,
    };
  }

  static Future<void> saveAll({
    required EditorialThemeId theme,
    required EditorialCardFormat format,
    required EditorialComposition composition,
    required EditorialColophonStyle colophon,
    required bool showDate,
    required bool showTexture,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTheme, theme.id);
    await prefs.setString(_keyFormat, format.id);
    await prefs.setString(_keyComposition, composition.id);
    await prefs.setString(_keyColophon, colophon.id);
    await prefs.setBool(_keyShowDate, showDate);
    await prefs.setBool(_keyShowTexture, showTexture);
  }
}

/// Result of exporting an insight card or wallpaper to disk/gallery.
class InsightExportResult {
  final String filePath;
  final String displayLocation;
  final XFile xFile;
  final Uint8List bytes;

  const InsightExportResult({
    required this.filePath,
    required this.displayLocation,
    required this.xFile,
    required this.bytes,
  });
}

/// Service that renders the [EditorialInsightCardCanvas] RepaintBoundary to high-DPI PNG
/// and handles native sharing, saving to gallery/disk, and setting wallpapers.
class InsightCardExportService {
  static const MethodChannel _mediaChannel =
      MethodChannel('com.example.dusk/media_export');

  /// Renders the widget attached to [boundaryKey] into a high-resolution PNG [Uint8List].
  static Future<Uint8List> capturePngBytes(
    GlobalKey boundaryKey, {
    double pixelRatio = 3.5,
  }) async {
    // Wait for end of frame so any pending UI state changes have painted
    await WidgetsBinding.instance.endOfFrame;

    final context = boundaryKey.currentContext;
    if (context == null || !context.mounted) {
      throw Exception('Card preview is not ready to render yet.');
    }

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      throw Exception('Could not locate card render boundary.');
    }

    final ui.Image image = await renderObject.toImage(pixelRatio: pixelRatio);
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      throw Exception('Failed to encode insight image as PNG.');
    }

    return byteData.buffer.asUint8List();
  }

  /// Writes PNG bytes to a clean file in the temporary directory and opens the OS share sheet.
  static Future<void> shareAsImage({
    required GlobalKey boundaryKey,
    required EditorialInsightData insight,
    required EditorialThemeId theme,
    required EditorialCardFormat format,
    Rect? sharePositionOrigin,
  }) async {
    final bytes = await capturePngBytes(
      boundaryKey,
      pixelRatio: format == EditorialCardFormat.wallpaper9x16 ? 3.8 : 3.5,
    );

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'dusk_${theme.id}_${format.id}_$timestamp.png';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);

    final xFile = XFile(
      file.path,
      mimeType: 'image/png',
      name: fileName,
    );

    await SharePlus.instance.share(
      ShareParams(
        files: [xFile],
        subject: insight.title,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  /// Exports high-resolution PNG to device Gallery (`Pictures/Dusk`) or Downloads/Documents.
  static Future<InsightExportResult> saveToDevice({
    required GlobalKey boundaryKey,
    required EditorialThemeId theme,
    required EditorialCardFormat format,
  }) async {
    final bytes = await capturePngBytes(
      boundaryKey,
      pixelRatio: format == EditorialCardFormat.wallpaper9x16 ? 4.0 : 3.5,
    );

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final isWallpaper = format == EditorialCardFormat.wallpaper9x16;
    final prefix = isWallpaper ? 'dusk_wallpaper' : 'dusk_insight';
    final fileName = '${prefix}_${theme.id}_$timestamp.png';

    // Always write a local copy for XFile quick-open/share fallback
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/$fileName');
    await tempFile.writeAsBytes(bytes, flush: true);
    final xFile = XFile(tempFile.path, mimeType: 'image/png', name: fileName);

    // 1. On Android, attempt saving directly to MediaStore (Pictures/Dusk)
    if (Platform.isAndroid) {
      try {
        final savedLocation = await _mediaChannel.invokeMethod<String>(
          'saveImageToGallery',
          {
            'bytes': bytes,
            'fileName': fileName,
          },
        );
        if (savedLocation != null && savedLocation.isNotEmpty) {
          return InsightExportResult(
            filePath: tempFile.path,
            displayLocation: savedLocation,
            xFile: xFile,
            bytes: bytes,
          );
        }
      } catch (_) {
        // Fallback if native channel isn't registered in current hot-reload session
      }

      // Fallback on Android: try public Download or Pictures directory
      for (final candidateDir in [
        '/storage/emulated/0/Pictures/Dusk',
        '/storage/emulated/0/Download',
      ]) {
        try {
          final dir = Directory(candidateDir);
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
          final outFile = File('${dir.path}/$fileName');
          await outFile.writeAsBytes(bytes, flush: true);
          final label = candidateDir.contains('Pictures')
              ? 'Pictures/Dusk/$fileName'
              : 'Downloads/$fileName';
          return InsightExportResult(
            filePath: outFile.path,
            displayLocation: label,
            xFile: XFile(outFile.path, mimeType: 'image/png', name: fileName),
            bytes: bytes,
          );
        } catch (_) {}
      }
    }

    // 2. Desktop / iOS / Fallback: Save to Downloads or ApplicationDocumentsDirectory
    try {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        final outFile = File('${downloadsDir.path}/$fileName');
        await outFile.writeAsBytes(bytes, flush: true);
        return InsightExportResult(
          filePath: outFile.path,
          displayLocation: 'Downloads/$fileName',
          xFile: XFile(outFile.path, mimeType: 'image/png', name: fileName),
          bytes: bytes,
        );
      }
    } catch (_) {}

    final docsDir = await getApplicationDocumentsDirectory();
    final outFile = File('${docsDir.path}/$fileName');
    await outFile.writeAsBytes(bytes, flush: true);
    return InsightExportResult(
      filePath: outFile.path,
      displayLocation: 'Saved to Dusk Archive ($fileName)',
      xFile: XFile(outFile.path, mimeType: 'image/png', name: fileName),
      bytes: bytes,
    );
  }

  /// Sets the rendered image directly as the Android lockscreen or home wallpaper if supported.
  static Future<bool> applyWallpaper({
    required GlobalKey boundaryKey,
    String target = 'lock', // 'lock', 'system', 'both'
  }) async {
    if (!Platform.isAndroid) return false;
    final bytes = await capturePngBytes(boundaryKey, pixelRatio: 3.8);
    try {
      final result = await _mediaChannel.invokeMethod<bool>(
        'setWallpaper',
        {
          'bytes': bytes,
          'target': target,
        },
      );
      return result == true;
    } catch (_) {
      return false;
    }
  }

  /// Formats the insight into a clean, non-promotional editorial plain text snippet.
  static String formatEditorialText(
    EditorialInsightData insight, {
    EditorialComposition composition = EditorialComposition.fullSynthesis,
    EditorialColophonStyle colophon = EditorialColophonStyle.personal,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(insight.title);
    buffer.writeln(insight.formattedDateUpper);
    buffer.writeln('—');
    buffer.writeln();

    if (composition == EditorialComposition.distilledQuote) {
      buffer.writeln('“${insight.mainInsight}”');
    } else if (composition == EditorialComposition.gentleIntention) {
      buffer.writeln(insight.mainInsight);
      buffer.writeln();
      buffer.writeln('Next Step: ${insight.suggestion}');
    } else {
      buffer.writeln('What Stood Out:');
      buffer.writeln(insight.standout);
      buffer.writeln();
      buffer.writeln('The Underlying Pattern:');
      buffer.writeln(insight.mainInsight);
      buffer.writeln();
      buffer.writeln('A Gentle Next Step:');
      buffer.writeln(insight.suggestion);
    }

    if (colophon == EditorialColophonStyle.personal) {
      buffer.writeln();
      buffer.write('— Personal Reflection Archive');
    } else if (colophon == EditorialColophonStyle.minimalDusk) {
      buffer.writeln();
      buffer.write('— Dusk');
    }

    return buffer.toString();
  }
}

/// Interactive horizontal selector for choosing one of the 4 Editorial Themes.
class EditorialThemeSelectorBar extends StatelessWidget {
  final EditorialThemeId selectedTheme;
  final ValueChanged<EditorialThemeId> onThemeSelected;
  final bool compact;

  const EditorialThemeSelectorBar({
    super.key,
    required this.selectedTheme,
    required this.onThemeSelected,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: EditorialThemeId.values.map((theme) {
          final isSelected = theme == selectedTheme;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onThemeSelected(theme);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 12 : 14,
                  vertical: compact ? 8 : 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF1B1A19)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF1B1A19)
                        : const Color(0xFFE6DFD3),
                    width: 1.2,
                  ),
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(
                        color: const Color(0xFF1B1A19).withValues(alpha: 0.14),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    else
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dual-tone theme swatch circle
                    Container(
                      width: compact ? 18 : 22,
                      height: compact ? 18 : 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.swatchPrimary,
                        border: Border.all(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.45)
                              : const Color(0xFFD5CEC2),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: compact ? 6 : 7,
                          height: compact ? 6 : 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.swatchSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          theme.label,
                          style: TextStyle(
                            fontSize: compact ? 12.5 : 13,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? const Color(0xFFFAF8F5)
                                : const Color(0xFF1B1A19),
                            letterSpacing: -0.1,
                          ),
                        ),
                        if (!compact)
                          Text(
                            theme.subtitle,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? const Color(0xFFC7C1B8)
                                  : const Color(0xFF8C857B),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Renders the themed Insight Card on either an inline card or an aspect-ratio export canvas.
class EditorialInsightCardCanvas extends StatelessWidget {
  final EditorialInsightData insight;
  final EditorialThemeId theme;
  final EditorialCardFormat format;
  final EditorialComposition composition;
  final EditorialColophonStyle colophon;
  final bool showDateStamp;
  final bool showTextureAndRules;
  final bool isInlineCard;

  const EditorialInsightCardCanvas({
    super.key,
    required this.insight,
    required this.theme,
    this.format = EditorialCardFormat.editorialCard,
    this.composition = EditorialComposition.fullSynthesis,
    this.colophon = EditorialColophonStyle.personal,
    this.showDateStamp = true,
    this.showTextureAndRules = true,
    this.isInlineCard = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isInlineCard) {
      return _buildThemedCardSurface(
        isWallpaper: false,
        isSquare: false,
        isInline: true,
      );
    }

    final isWallpaper = format == EditorialCardFormat.wallpaper9x16;
    final isSquare = format == EditorialCardFormat.square1x1;

    return AspectRatio(
      aspectRatio: format.aspectRatio,
      child: Container(
        decoration: _buildOuterCanvasDecoration(isWallpaper: isWallpaper),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background ambient texture / grain / celestial atmosphere
            if (showTextureAndRules)
              Positioned.fill(
                child: CustomPaint(
                  painter: _EditorialAtmospherePainter(
                    theme: theme,
                    isWallpaper: isWallpaper,
                  ),
                ),
              ),

            // Content layout
            Padding(
              padding: isWallpaper
                  ? const EdgeInsets.fromLTRB(22, 26, 22, 24)
                  : isSquare
                      ? const EdgeInsets.all(18)
                      : const EdgeInsets.all(20),
              child: isWallpaper
                  ? _buildWallpaperLayout()
                  : Center(
                      child: _buildThemedCardSurface(
                        isWallpaper: false,
                        isSquare: isSquare,
                        isInline: false,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Full-bleed 9:16 lockscreen wallpaper layout with top clock-safe breathing space.
  Widget _buildWallpaperLayout() {
    final spec = _ThemeVisualSpec.forTheme(theme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top minimal issue/date header above or below lockscreen clock zone
        if (showDateStamp)
          Opacity(
            opacity: 0.72,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  insight.issueNumber,
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: spec.mutedTextColor,
                    letterSpacing: 1.4,
                  ),
                ),
                Text(
                  insight.formattedDateUpper,
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                    color: spec.mutedTextColor,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),

        // Lockscreen clock breathing room (top ~24% of 9:16 screen)
        const Spacer(flex: 3),

        // Framed or floating editorial centerpiece
        Flexible(
          flex: 9,
          child: Center(
            child: _buildThemedCardSurface(
              isWallpaper: true,
              isSquare: false,
              isInline: false,
            ),
          ),
        ),

        const Spacer(flex: 2),

        // Bottom subtle colophon in wallpaper mode
        if (colophon != EditorialColophonStyle.none)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _buildColophonFooter(spec, centered: true),
          ),
      ],
    );
  }

  BoxDecoration _buildOuterCanvasDecoration({required bool isWallpaper}) {
    switch (theme) {
      case EditorialThemeId.obsidianDark:
        return const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF08080A),
              Color(0xFF101015),
              Color(0xFF0A0A0D),
            ],
          ),
        );
      case EditorialThemeId.warmPaper:
        return const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFEDE6D8),
              Color(0xFFE5DECF),
              Color(0xFFE8E0D2),
            ],
          ),
        );
      case EditorialThemeId.twilightGradient:
        return const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF120F21), // Deep midnight indigo
              Color(0xFF281D39), // Twilight plum
              Color(0xFF5A3446), // Bruised dusk rose
              Color(0xFF9C5742), // Warm horizon ember
            ],
            stops: [0.0, 0.36, 0.72, 1.0],
          ),
        );
      case EditorialThemeId.swissAlabaster:
        return const BoxDecoration(
          color: Color(0xFFE8E4DC),
        );
    }
  }

  Widget _buildThemedCardSurface({
    required bool isWallpaper,
    required bool isSquare,
    required bool isInline,
  }) {
    final spec = _ThemeVisualSpec.forTheme(theme);
    final double pad = isInline
        ? 24.0
        : isSquare
            ? 20.0
            : isWallpaper
                ? 22.0
                : 22.0;

    final cardContent = Container(
      width: double.infinity,
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: spec.cardBackgroundColor,
        gradient: spec.cardGradient,
        borderRadius: BorderRadius.circular(spec.borderRadius),
        border: Border.all(
          color: spec.borderColor,
          width: spec.borderWidth,
        ),
        boxShadow: [
          if (!isWallpaper || theme != EditorialThemeId.twilightGradient)
            BoxShadow(
              color: Colors.black.withValues(alpha: theme.isDark ? 0.35 : 0.06),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: Stack(
        children: [
          if (showTextureAndRules && isInline)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _EditorialAtmospherePainter(
                    theme: theme,
                    isWallpaper: false,
                  ),
                ),
              ),
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Editorial Masthead / Header
              if (!isWallpaper || !showDateStamp)
                _buildMasthead(spec, showDate: showDateStamp)
              else
                _buildMasthead(spec, showDate: false),

              if (showTextureAndRules) ...[
                const SizedBox(height: 12),
                _buildEditorialDivider(spec, isHeader: true),
              ],

              SizedBox(height: isSquare ? 12 : 16),

              // 2. Main Editorial Body based on Composition
              if (composition == EditorialComposition.distilledQuote)
                _buildDistilledQuoteBody(spec, isSquare: isSquare)
              else if (composition == EditorialComposition.gentleIntention)
                _buildGentleIntentionBody(spec, isSquare: isSquare)
              else
                _buildFullSynthesisBody(
                  spec,
                  isSquare: isSquare,
                  isInline: isInline,
                ),

              // 3. Footer Colophon (shown inside card unless in wallpaper mode where it's at bottom)
              if (!isWallpaper && colophon != EditorialColophonStyle.none) ...[
                SizedBox(height: isSquare ? 14 : 18),
                if (showTextureAndRules) ...[
                  _buildEditorialDivider(spec, isHeader: false),
                  const SizedBox(height: 10),
                ],
                _buildColophonFooter(spec, centered: false),
              ],
            ],
          ),
        ],
      ),
    );

    if (isInline) {
      return cardContent;
    }

    // Ensure non-inline export canvases never overflow regardless of user text length
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth,
            ),
            child: cardContent,
          ),
        );
      },
    );
  }

  Widget _buildMasthead(_ThemeVisualSpec spec, {required bool showDate}) {
    switch (theme) {
      case EditorialThemeId.warmPaper:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: spec.primaryAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  'THE EVENING DISPATCH',
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.3,
                    color: spec.primaryAccent,
                  ),
                ),
              ],
            ),
            if (showDate)
              Text(
                insight.formattedDateUpper,
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.0,
                  color: spec.mutedTextColor,
                ),
              ),
          ],
        );

      case EditorialThemeId.obsidianDark:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 12,
                  color: spec.primaryAccent,
                ),
                const SizedBox(width: 6),
                Text(
                  'NOCTURNE SYNTHESIS',
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.6,
                    color: spec.primaryAccent,
                  ),
                ),
              ],
            ),
            if (showDate)
              Text(
                insight.formattedDateUpper,
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 1.2,
                  color: spec.mutedTextColor,
                ),
              ),
          ],
        );

      case EditorialThemeId.twilightGradient:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.wb_twilight_rounded,
                    size: 12,
                    color: spec.primaryAccent,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'TWILIGHT NOTE',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: spec.headlineColor,
                    ),
                  ),
                ],
              ),
            ),
            if (showDate)
              Text(
                insight.formattedDateUpper,
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.1,
                  color: spec.mutedTextColor,
                ),
              ),
          ],
        );

      case EditorialThemeId.swissAlabaster:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  color: spec.primaryAccent,
                ),
                const SizedBox(width: 7),
                Text(
                  'INDEX / ${insight.issueNumber}',
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: spec.headlineColor,
                  ),
                ),
              ],
            ),
            if (showDate)
              Text(
                insight.formattedDateUpper,
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: spec.mutedTextColor,
                ),
              ),
          ],
        );
    }
  }

  Widget _buildEditorialDivider(_ThemeVisualSpec spec, {required bool isHeader}) {
    if (theme == EditorialThemeId.warmPaper && isHeader) {
      // Classic newspaper double-rule divider
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 1.4, color: spec.dividerColor),
          const SizedBox(height: 2.5),
          Container(height: 0.7, color: spec.dividerColor),
        ],
      );
    }
    return Container(
      height: 1,
      color: spec.dividerColor,
    );
  }

  /// Composition 1: Distilled Essence Quote (large display typography, ideal for wallpapers).
  Widget _buildDistilledQuoteBody(_ThemeVisualSpec spec, {required bool isSquare}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '“',
          style: GoogleFonts.playfairDisplay(
            fontSize: isSquare ? 38 : 46,
            height: 0.75,
            fontWeight: FontWeight.w700,
            color: spec.primaryAccent.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          insight.mainInsight,
          maxLines: isSquare ? 5 : 7,
          overflow: TextOverflow.ellipsis,
          style: spec.quoteDisplayStyle(fontSize: isSquare ? 18.5 : 21),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Container(
              width: 24,
              height: 1.5,
              color: spec.primaryAccent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                insight.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: spec.subheadStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Composition 2: Gentle Intention (Core Pattern + Next Step).
  Widget _buildGentleIntentionBody(_ThemeVisualSpec spec, {required bool isSquare}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          insight.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: spec.headlineStyle(fontSize: isSquare ? 18 : 20),
        ),
        const SizedBox(height: 14),
        Text(
          insight.mainInsight,
          maxLines: isSquare ? 4 : 5,
          overflow: TextOverflow.ellipsis,
          style: spec.bodyStyle(fontSize: isSquare ? 13.5 : 14.5),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: spec.calloutBackgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: spec.dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: spec.tertiaryAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    theme == EditorialThemeId.swissAlabaster
                        ? '01 / GENTLE NEXT STEP'
                        : 'A GENTLE NEXT STEP',
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: spec.tertiaryAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                insight.suggestion,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: spec.bodyStyle(fontSize: 13).copyWith(
                      color: spec.headlineColor,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Composition 3: Full Synthesis (Title + What Stood Out + Underlying Pattern + Gentle Next Step).
  Widget _buildFullSynthesisBody(
    _ThemeVisualSpec spec, {
    required bool isSquare,
    required bool isInline,
  }) {
    final int maxLinesPerSection = isInline ? 10 : (isSquare ? 2 : 3);
    final double sectionGap = isSquare ? 11.0 : 15.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          insight.title,
          maxLines: isInline ? 4 : 2,
          overflow: TextOverflow.ellipsis,
          style: spec.headlineStyle(
            fontSize: isInline ? 21 : (isSquare ? 16.5 : 18.5),
          ),
        ),
        SizedBox(height: isSquare ? 12 : 16),
        _buildSynthesisSection(
          spec: spec,
          indexPrefix: theme == EditorialThemeId.swissAlabaster
              ? '01 / '
              : theme == EditorialThemeId.obsidianDark
                  ? 'I · '
                  : '',
          label: 'WHAT STOOD OUT',
          content: insight.standout,
          accentColor: spec.primaryAccent,
          maxLines: maxLinesPerSection,
          isCompact: isSquare,
        ),
        SizedBox(height: sectionGap),
        _buildSynthesisSection(
          spec: spec,
          indexPrefix: theme == EditorialThemeId.swissAlabaster
              ? '02 / '
              : theme == EditorialThemeId.obsidianDark
                  ? 'II · '
                  : '',
          label: 'THE UNDERLYING PATTERN',
          content: insight.mainInsight,
          accentColor: spec.secondaryAccent,
          maxLines: maxLinesPerSection,
          isCompact: isSquare,
        ),
        SizedBox(height: sectionGap),
        _buildSynthesisSection(
          spec: spec,
          indexPrefix: theme == EditorialThemeId.swissAlabaster
              ? '03 / '
              : theme == EditorialThemeId.obsidianDark
                  ? 'III · '
                  : '',
          label: 'A GENTLE NEXT STEP',
          content: insight.suggestion,
          accentColor: spec.tertiaryAccent,
          maxLines: maxLinesPerSection,
          isCompact: isSquare,
        ),
      ],
    );
  }

  Widget _buildSynthesisSection({
    required _ThemeVisualSpec spec,
    required String indexPrefix,
    required String label,
    required String content,
    required Color accentColor,
    required int maxLines,
    required bool isCompact,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 5.5,
              height: 5.5,
              decoration: BoxDecoration(
                color: accentColor,
                shape: theme == EditorialThemeId.swissAlabaster
                    ? BoxShape.rectangle
                    : BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                '$indexPrefix$label',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.ibmPlexMono(
                  color: accentColor,
                  fontSize: isCompact ? 9.5 : 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: isCompact ? 4 : 5),
        Text(
          content,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: spec.bodyStyle(fontSize: isCompact ? 12.5 : 13.8),
        ),
      ],
    );
  }

  Widget _buildColophonFooter(_ThemeVisualSpec spec, {required bool centered}) {
    String leftText = '';
    String rightText = '';

    if (colophon == EditorialColophonStyle.personal) {
      leftText = 'PERSONAL ARCHIVE';
      rightText = 'QUIET REFLECTION';
    } else if (colophon == EditorialColophonStyle.minimalDusk) {
      leftText = 'DUSK · STUDIO EDITION';
      rightText = insight.issueNumber;
    }

    if (centered) {
      return Center(
        child: Text(
          '$leftText  ·  $rightText',
          style: GoogleFonts.ibmPlexMono(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.4,
            color: spec.mutedTextColor.withValues(alpha: 0.75),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          leftText,
          style: GoogleFonts.ibmPlexMono(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.3,
            color: spec.mutedTextColor,
          ),
        ),
        Text(
          rightText,
          style: GoogleFonts.ibmPlexMono(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.1,
            color: spec.mutedTextColor.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

/// Internal visual specification for each of the 4 editorial themes.
class _ThemeVisualSpec {
  final EditorialThemeId theme;
  final Color cardBackgroundColor;
  final Gradient? cardGradient;
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;
  final Color headlineColor;
  final Color bodyTextColor;
  final Color mutedTextColor;
  final Color dividerColor;
  final Color calloutBackgroundColor;
  final Color primaryAccent;
  final Color secondaryAccent;
  final Color tertiaryAccent;

  const _ThemeVisualSpec({
    required this.theme,
    required this.cardBackgroundColor,
    this.cardGradient,
    required this.borderColor,
    required this.borderWidth,
    required this.borderRadius,
    required this.headlineColor,
    required this.bodyTextColor,
    required this.mutedTextColor,
    required this.dividerColor,
    required this.calloutBackgroundColor,
    required this.primaryAccent,
    required this.secondaryAccent,
    required this.tertiaryAccent,
  });

  factory _ThemeVisualSpec.forTheme(EditorialThemeId theme) {
    switch (theme) {
      case EditorialThemeId.obsidianDark:
        return const _ThemeVisualSpec(
          theme: EditorialThemeId.obsidianDark,
          cardBackgroundColor: Color(0xFF131318),
          cardGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF191920),
              Color(0xFF111116),
              Color(0xFF0D0D11),
            ],
          ),
          borderColor: Color(0xFF2B2A33),
          borderWidth: 1.0,
          borderRadius: 22,
          headlineColor: Color(0xFFF5F2EB),
          bodyTextColor: Color(0xFFC2BDB4),
          mutedTextColor: Color(0xFF7D7870),
          dividerColor: Color(0xFF26252E),
          calloutBackgroundColor: Color(0xFF1A1A22),
          primaryAccent: Color(0xFFDFA964), // Warm Champagne Gold
          secondaryAccent: Color(0xFF88A8D8), // Muted Celestial Blue
          tertiaryAccent: Color(0xFF6BB89B), // Nocturne Sage
        );

      case EditorialThemeId.warmPaper:
        return const _ThemeVisualSpec(
          theme: EditorialThemeId.warmPaper,
          cardBackgroundColor: Color(0xFFFAF6EE),
          borderColor: Color(0xFFDCD3C2),
          borderWidth: 1.0,
          borderRadius: 16,
          headlineColor: Color(0xFF1B1916),
          bodyTextColor: Color(0xFF4B463F),
          mutedTextColor: Color(0xFF857D72),
          dividerColor: Color(0xFFD8CFC0),
          calloutBackgroundColor: Color(0xFFF2ECE0),
          primaryAccent: Color(0xFFC85A28), // Broadsheet Terracotta Ink
          secondaryAccent: Color(0xFF3E6B89), // Archival Prussian Blue
          tertiaryAccent: Color(0xFF3A7359), // Botanical Press Green
        );

      case EditorialThemeId.twilightGradient:
        return _ThemeVisualSpec(
          theme: EditorialThemeId.twilightGradient,
          cardBackgroundColor: const Color(0xFF1D162B).withValues(alpha: 0.72),
          cardGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF231A35).withValues(alpha: 0.88),
              const Color(0xFF3E263D).withValues(alpha: 0.85),
              const Color(0xFF6C3D42).withValues(alpha: 0.82),
            ],
          ),
          borderColor: Colors.white.withValues(alpha: 0.18),
          borderWidth: 1.0,
          borderRadius: 24,
          headlineColor: const Color(0xFFFCF9F5),
          bodyTextColor: const Color(0xFFEADFD8),
          mutedTextColor: const Color(0xFFC7B4AC),
          dividerColor: Colors.white.withValues(alpha: 0.14),
          calloutBackgroundColor: Colors.black.withValues(alpha: 0.18),
          primaryAccent: const Color(0xFFFFB38A), // Sunset Peach
          secondaryAccent: const Color(0xFFC5B4F0), // Lavender Dusk
          tertiaryAccent: const Color(0xFF8CE0C2), // Horizon Mint
        );

      case EditorialThemeId.swissAlabaster:
        return const _ThemeVisualSpec(
          theme: EditorialThemeId.swissAlabaster,
          cardBackgroundColor: Color(0xFFFFFFFF),
          borderColor: Color(0xFF1B1A19),
          borderWidth: 1.4,
          borderRadius: 8, // Crisp gallery print corners
          headlineColor: Color(0xFF111111),
          bodyTextColor: Color(0xFF3D3B38),
          mutedTextColor: Color(0xFF78746E),
          dividerColor: Color(0xFFE5E0D8),
          calloutBackgroundColor: Color(0xFFF7F5F0),
          primaryAccent: Color(0xFFE04F26), // International Orange
          secondaryAccent: Color(0xFF1F4E78), // Bauhaus Cobalt
          tertiaryAccent: Color(0xFF2B5B46), // Swiss Pine
        );
    }
  }

  TextStyle headlineStyle({required double fontSize}) {
    switch (theme) {
      case EditorialThemeId.warmPaper:
        return GoogleFonts.playfairDisplay(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: headlineColor,
          height: 1.25,
          letterSpacing: -0.2,
        );
      case EditorialThemeId.obsidianDark:
        return GoogleFonts.playfairDisplay(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: headlineColor,
          height: 1.28,
          letterSpacing: -0.1,
        );
      case EditorialThemeId.twilightGradient:
        return GoogleFonts.lora(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: headlineColor,
          height: 1.3,
        );
      case EditorialThemeId.swissAlabaster:
        return GoogleFonts.plusJakartaSans(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: headlineColor,
          height: 1.22,
          letterSpacing: -0.5,
        );
    }
  }

  TextStyle quoteDisplayStyle({required double fontSize}) {
    switch (theme) {
      case EditorialThemeId.warmPaper:
      case EditorialThemeId.obsidianDark:
        return GoogleFonts.playfairDisplay(
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.italic,
          color: headlineColor,
          height: 1.38,
        );
      case EditorialThemeId.twilightGradient:
        return GoogleFonts.lora(
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.italic,
          color: headlineColor,
          height: 1.42,
        );
      case EditorialThemeId.swissAlabaster:
        return GoogleFonts.plusJakartaSans(
          fontSize: fontSize - 1,
          fontWeight: FontWeight.w700,
          color: headlineColor,
          height: 1.35,
          letterSpacing: -0.4,
        );
    }
  }

  TextStyle subheadStyle({required double fontSize}) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      color: mutedTextColor,
      letterSpacing: 0.1,
    );
  }

  TextStyle bodyStyle({required double fontSize}) {
    if (theme == EditorialThemeId.warmPaper) {
      return GoogleFonts.lora(
        fontSize: fontSize,
        fontWeight: FontWeight.w400,
        color: bodyTextColor,
        height: 1.48,
      );
    }
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      color: bodyTextColor,
      height: 1.46,
    );
  }
}

/// Subtle custom painter that renders paper fiber speckles, twilight stars/glow,
/// or Swiss architectural registration marks.
class _EditorialAtmospherePainter extends CustomPainter {
  final EditorialThemeId theme;
  final bool isWallpaper;

  _EditorialAtmospherePainter({
    required this.theme,
    required this.isWallpaper,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(42);

    switch (theme) {
      case EditorialThemeId.warmPaper:
        // Subtle tactile newsprint paper grain dots
        final speckPaint = Paint()
          ..color = const Color(0xFF8C7A64).withValues(alpha: 0.055)
          ..style = PaintingStyle.fill;
        final count = isWallpaper ? 160 : 90;
        for (int i = 0; i < count; i++) {
          final dx = rand.nextDouble() * size.width;
          final dy = rand.nextDouble() * size.height;
          final r = 0.5 + rand.nextDouble() * 0.9;
          canvas.drawCircle(Offset(dx, dy), r, speckPaint);
        }
        break;

      case EditorialThemeId.obsidianDark:
        // Subtle warm champagne-gold radial ambient glow in top-right corner
        final glowCenter = Offset(size.width * 0.85, size.height * 0.12);
        final glowRadius = size.width * 0.65;
        final glowPaint = Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFDFA964).withValues(alpha: 0.10),
              const Color(0xFFDFA964).withValues(alpha: 0.0),
            ],
          ).createShader(
            Rect.fromCircle(center: glowCenter, radius: glowRadius),
          );
        canvas.drawCircle(glowCenter, glowRadius, glowPaint);
        break;

      case EditorialThemeId.twilightGradient:
        // Soft horizon sun-glow + delicate celestial starlight specks
        final horizonCenter = Offset(size.width * 0.5, size.height * 0.88);
        final horizonRadius = size.width * 0.75;
        final horizonPaint = Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFA570).withValues(alpha: 0.22),
              const Color(0xFFFFA570).withValues(alpha: 0.0),
            ],
          ).createShader(
            Rect.fromCircle(center: horizonCenter, radius: horizonRadius),
          );
        canvas.drawCircle(horizonCenter, horizonRadius, horizonPaint);

        final starPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.18)
          ..style = PaintingStyle.fill;
        final starCount = isWallpaper ? 45 : 24;
        for (int i = 0; i < starCount; i++) {
          final dx = rand.nextDouble() * size.width;
          final dy = rand.nextDouble() * (size.height * 0.65);
          final r = 0.4 + rand.nextDouble() * 1.1;
          canvas.drawCircle(Offset(dx, dy), r, starPaint);
        }
        break;

      case EditorialThemeId.swissAlabaster:
        // Subtle architectural crop / registration ticks in the outer corners
        if (!isWallpaper) break;
        final tickPaint = Paint()
          ..color = const Color(0xFF1B1A19).withValues(alpha: 0.22)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;
        const double inset = 12;
        const double len = 8;
        // Top-left
        canvas.drawLine(
            const Offset(inset, inset), const Offset(inset + len, inset), tickPaint);
        canvas.drawLine(
            const Offset(inset, inset), const Offset(inset, inset + len), tickPaint);
        // Top-right
        canvas.drawLine(Offset(size.width - inset, inset),
            Offset(size.width - inset - len, inset), tickPaint);
        canvas.drawLine(Offset(size.width - inset, inset),
            Offset(size.width - inset, inset + len), tickPaint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _EditorialAtmospherePainter oldDelegate) {
    return oldDelegate.theme != theme || oldDelegate.isWallpaper != isWallpaper;
  }
}
