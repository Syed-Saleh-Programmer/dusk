import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/dusk_ui_components.dart';
import 'privacy_screen.dart';
import 'paywall_screen.dart';

class DataStorageSettingsScreen extends StatefulWidget {
  const DataStorageSettingsScreen({super.key});

  @override
  State<DataStorageSettingsScreen> createState() => _DataStorageSettingsScreenState();
}

class _DataStorageSettingsScreenState extends State<DataStorageSettingsScreen> {
  String _audioCacheSize = 'Calculating...';
  int _audioFileCount = 0;
  bool _isClearing = false;

  @override
  void initState() {
    super.initState();
    _calculateStorageUsage();
  }

  Future<void> _calculateStorageUsage() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${directory.path}/audio_dumps');
      if (await cacheDir.exists()) {
        int totalBytes = 0;
        int count = 0;
        await for (final file in cacheDir.list(recursive: true, followLinks: false)) {
          if (file is File) {
            totalBytes += await file.length();
            count++;
          }
        }
        if (mounted) {
          setState(() {
            _audioFileCount = count;
            if (totalBytes < 1024) {
              _audioCacheSize = '$totalBytes B';
            } else if (totalBytes < 1024 * 1024) {
              _audioCacheSize = '${(totalBytes / 1024).toStringAsFixed(1)} KB';
            } else {
              _audioCacheSize = '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _audioCacheSize = '0 KB';
            _audioFileCount = 0;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _audioCacheSize = 'Unknown';
        });
      }
    }
  }

  Future<void> _confirmClearCache() async {
    final p = AppTheme.palette;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Clear Audio Cache?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: p.onSurface,
          ),
        ),
        content: Text(
          'This will remove cached local audio recordings ($_audioCacheSize). Any recordings already synced to the cloud remain safely preserved.',
          style: TextStyle(
            fontSize: 13.5,
            color: p.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: p.onSurfaceVariant, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD9383A),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Clear', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _executeClearCache();
    }
  }

  Future<void> _executeClearCache() async {
    setState(() => _isClearing = true);
    HapticFeedback.mediumImpact();
    try {
      final directory = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${directory.path}/audio_dumps');
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create();
      }
      await _calculateStorageUsage();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Text('Audio cache cleared successfully'),
              ],
            ),
            backgroundColor: const Color(0xFF1B1A19),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear cache: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final p = AppTheme.of(context);
    final totalCaptures = appState.allDumps.length;
    final totalTasks = appState.tasks.length;

    return Scaffold(
      backgroundColor: p.background,
      body: DuskAmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Top Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    DuskCircleButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      size: 38,
                      iconSize: 17,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Data & Storage',
                        style: TextStyle(
                          fontSize: 17.5,
                          fontWeight: FontWeight.w800,
                          color: p.onSurface,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  children: [
                    // 1. STORAGE USAGE HERO CARD
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            p.primarySoftBg,
                            p.surface,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: p.outline),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.035),
                            blurRadius: 16,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: p.primaryContainer,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(Icons.storage_rounded, color: p.primary, size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Audio Cache',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: p.onSurfaceVariant,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _audioCacheSize,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        color: p.onSurface,
                                        letterSpacing: -0.6,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              DuskPillBadge(
                                text: '$_audioFileCount Files',
                                variant: DuskBadgeVariant.neutral,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: p.background.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: p.outline),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Offline Database',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: p.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$totalCaptures captures · $totalTasks tasks indexed',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: p.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.check_circle_rounded, size: 18, color: p.tertiary),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.04),

                    const SizedBox(height: 16),

                    // CLOUD SYNC & STORAGE ARCHITECTURE CARD
                    Container(
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: appState.isPro ? p.outline : const Color(0xFFFFD8B3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.025),
                            blurRadius: 14,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: appState.isPro ? p.tertiaryContainer : const Color(0xFFFFEADA),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  appState.isPro ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                                  color: appState.isPro ? p.tertiary : const Color(0xFFFF7A1A),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      appState.isPro ? 'Cloud Sync: Active (Pro)' : '100% Offline Local SQLite',
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                        color: p.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      appState.isPro
                                          ? 'Real-time encrypted sync to Supabase vault'
                                          : 'Free tier operates 100% locally. Zero cloud data storage.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: p.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              DuskPillBadge(
                                text: appState.isPro ? 'Pro' : 'Free',
                                variant: appState.isPro ? DuskBadgeVariant.green : DuskBadgeVariant.neutral,
                              ),
                            ],
                          ),
                          if (!appState.isPro) ...[
                            const SizedBox(height: 14),
                            Text(
                              'Upgrade to Dusk Pro to enable automatic cloud backup, cross-device sync, and unlimited archive retention.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: p.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  DuskPageRoute.modalSheet(builder: (_) => const PaywallScreen()),
                                );
                              },
                              icon: const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFF7A1A)),
                              label: const Text(
                                'Enable Cloud Sync with Pro',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFFF7A1A),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFFF7A1A)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ).animate().fadeIn(delay: 50.ms, duration: 280.ms),

                    const SizedBox(height: 24),

                    // Section: Storage Management
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 10),
                      child: Text(
                        'CACHE MANAGEMENT',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: p.onSurfaceVariant,
                        ),
                      ),
                    ),

                    // 2. CLEAR CACHE TILE
                    Container(
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: p.outline),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.025),
                            blurRadius: 14,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Column(
                          children: [
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _isClearing ? null : _confirmClearCache,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: p.tertiaryContainer,
                                          borderRadius: BorderRadius.circular(13),
                                        ),
                                        child: Icon(Icons.cleaning_services_rounded, color: p.tertiary, size: 20),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Clear Local Audio Cache',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: p.onSurface,
                                                letterSpacing: -0.1,
                                              ),
                                            ),
                                            const SizedBox(height: 2.5),
                                            Text(
                                              'Free temporary voice recordings while preserving metadata',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                color: p.onSurfaceVariant,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _isClearing
                                          ? SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(p.primary),
                                              ),
                                            )
                                          : Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: p.surfaceVariant,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                'Clear',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: p.onSurface,
                                                ),
                                              ),
                                            ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: 70.ms, duration: 280.ms),

                    const SizedBox(height: 24),

                    // Section: Privacy & Architecture
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 10),
                      child: Text(
                        'ARCHITECTURE & INTEGRITY',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: p.onSurfaceVariant,
                        ),
                      ),
                    ),

                    Container(
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: p.outline),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                DuskPageRoute.perspectiveSlide(
                                  builder: (_) => const PrivacyScreen(),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: p.secondaryContainer,
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                    child: Icon(Icons.shield_outlined, color: p.secondary, size: 20),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Privacy & Data Architecture',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: p.onSurface,
                                            letterSpacing: -0.1,
                                          ),
                                        ),
                                        const SizedBox(height: 2.5),
                                        Text(
                                          'Row-level security, end-to-end encryption & export policies',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: p.onSurfaceVariant,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: p.surfaceVariant,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.chevron_right_rounded,
                                      size: 18,
                                      color: p.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ).animate().fadeIn(delay: 120.ms, duration: 280.ms),
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
