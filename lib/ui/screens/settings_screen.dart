import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/alarm_sound.dart';
import '../../providers/app_state.dart';
import '../../services/supabase_service.dart';
import '../../services/notification_service.dart';
import '../navigation/dusk_navigation.dart';
import '../theme/app_theme.dart';
import '../widgets/dusk_ui_components.dart';
import 'alarm_sound_screen.dart';
import 'auth_screen.dart';
import 'customization_settings_screen.dart';
import 'data_storage_settings_screen.dart';
import 'edit_reflection_schedule_screen.dart';
import 'evening_ritual_settings_screen.dart';
import 'home_widgets_screen.dart';
import 'onboarding_screen.dart';
import 'paywall_screen.dart';
import 'permissions_settings_screen.dart';
import 'privacy_screen.dart';
import 'profile_setup_screen.dart';
import 'user_profile_screen.dart';
import 'dusk_chat_screen.dart';

class SettingsScreen extends StatefulWidget {
  final bool showBackButton;

  const SettingsScreen({
    super.key,
    this.showBackButton = false,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  TimeOfDay _scheduleTime = const TimeOfDay(hour: 21, minute: 0);
  int _scheduleFrequency = 3;
  AlarmSound _selectedAlarmSound = AlarmSound.calmHorizon;
  String _cacheSizeStr = 'Calculating...';

  // Permission states
  Map<Permission, PermissionStatus> _permissionStatuses = {};
  bool _permissionsLoaded = false;

  static final List<_PermissionItem> _permissionItems = [
    _PermissionItem(
      permission: Permission.microphone,
      label: 'Microphone',
      subtitle: 'Required for voice memos',
      icon: Icons.mic_rounded,
      color: const Color(0xFFFF7A1A),
    ),
    _PermissionItem(
      permission: Permission.camera,
      label: 'Camera',
      subtitle: 'Required for photo capture',
      icon: Icons.camera_alt_rounded,
      color: const Color(0xFF4A84D8),
    ),
    _PermissionItem(
      permission: Permission.notification,
      label: 'Notifications',
      subtitle: 'Required for reflection reminders',
      icon: Icons.notifications_active_rounded,
      color: const Color(0xFF6BBF59),
    ),
    _PermissionItem(
      permission: Permission.scheduleExactAlarm,
      label: 'Exact Alarms',
      subtitle: 'Required for precise reminder timing',
      icon: Icons.alarm_rounded,
      color: const Color(0xFFE84F6E),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _calculateCacheSize();
    _loadScheduleSettings();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final statuses = <Permission, PermissionStatus>{};
    for (final item in _permissionItems) {
      statuses[item.permission] = await item.permission.status;
    }
    if (mounted) {
      setState(() {
        _permissionStatuses = statuses;
        _permissionsLoaded = true;
      });
    }
  }

  Future<void> _loadScheduleSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = SupabaseService().currentUser?.id;
      final suffix = (uid != null && uid.isNotEmpty) ? '_$uid' : '';
      final freq = prefs.getInt('reflection_cadence_days$suffix') ?? 3;
      final hour = prefs.getInt('reflection_reminder_hour$suffix') ?? 21;
      final minute = prefs.getInt('reflection_reminder_minute$suffix') ?? 0;
      final alarmSound = await AlarmSound.loadSelected();
      if (mounted) {
        setState(() {
          _scheduleFrequency = freq;
          _scheduleTime = TimeOfDay(hour: hour, minute: minute);
          _selectedAlarmSound = alarmSound;
        });
      }
    } catch (_) {}
  }

  String _getFrequencyText(int days) {
    switch (days) {
      case 1:
        return 'Daily';
      case 2:
        return 'Every 2 days';
      case 3:
        return 'Every 3 days';
      case 7:
        return 'Every 7 days';
      default:
        return 'Every $days days';
    }
  }

  Future<void> _calculateCacheSize() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${directory.path}/audio_dumps');
      if (await cacheDir.exists()) {
        int totalBytes = 0;
        await for (var file in cacheDir.list(recursive: true, followLinks: false)) {
          if (file is File) {
            totalBytes += await file.length();
          }
        }
        final double mb = totalBytes / (1024 * 1024);
        if (mounted) {
          setState(() {
            if (mb < 0.1) {
              _cacheSizeStr = '< 0.1 MB';
            } else {
              _cacheSizeStr = '${mb.toStringAsFixed(1)} MB';
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _cacheSizeStr = '0 MB';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cacheSizeStr = 'Unknown';
        });
      }
    }
  }

  Widget _buildSectionHeader(String title) {
    final p = AppTheme.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 20, 6, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          color: p.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildCardContainer({required List<Widget> children}) {
    final p = AppTheme.palette;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: p.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Material(
          color: Colors.transparent,
          child: Column(
            children: children,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final p = AppTheme.of(context);
    final user = SupabaseService().currentUser;
    final fullName = appState.preferredName.isNotEmpty
        ? appState.preferredName
        : ((user?.userMetadata?['full_name'] as String?) ?? 'User');
    final profession = appState.profession;
    final dob = appState.dob;
    final email = user?.email ?? 'Free User (Local Vault • No Account)';
    final firstLetter = fullName.isNotEmpty ? fullName[0].toUpperCase() : 'D';

    ImageProvider? avatarProvider;
    if (appState.avatarLocalPath != null &&
        appState.avatarLocalPath!.isNotEmpty &&
        File(appState.avatarLocalPath!).existsSync()) {
      avatarProvider = FileImage(File(appState.avatarLocalPath!));
    } else if (appState.avatarUrl != null && appState.avatarUrl!.isNotEmpty) {
      avatarProvider = NetworkImage(appState.avatarUrl!);
    }

    final grantedCount = _permissionStatuses.values
        .where((s) => s == PermissionStatus.granted)
        .length;
    final totalPerms = _permissionItems.length;

    return Scaffold(
      backgroundColor: p.background,
      body: DuskAmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  children: [
                    if (widget.showBackButton) ...[
                      DuskCircleButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        size: 42,
                        iconSize: 18,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Settings',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: p.onSurface,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Customization, ritual, permissions & account',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: p.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                  children: [
                    // Interactive Profile Card (Taps into UserProfileScreen)
                    Material(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(24),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () {
                          Navigator.of(context).push(
                            DuskPageRoute.perspectiveSlide(
                              builder: (_) => const UserProfileScreen(),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: p.outline),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 14,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      gradient: avatarProvider == null
                                          ? LinearGradient(
                                              colors: [
                                                p.primary,
                                                p.primaryDark,
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            )
                                          : null,
                                      shape: BoxShape.circle,
                                      image: avatarProvider != null
                                          ? DecorationImage(
                                              image: avatarProvider,
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: avatarProvider == null
                                        ? Center(
                                            child: Text(
                                              firstLetter,
                                              style: const TextStyle(
                                                fontSize: 26,
                                                color: Colors.white,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          )
                                        : null,
                                  ),
                                  Positioned(
                                    bottom: -2,
                                    right: -2,
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: p.onSurface,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: p.surface,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.edit_rounded,
                                        size: 11,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            fullName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w800,
                                              color: p.onSurface,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        DuskPillBadge(
                                          text: appState.isPro ? 'Pro Member' : 'Free Plan',
                                          variant: appState.isPro
                                              ? DuskBadgeVariant.green
                                              : DuskBadgeVariant.neutral,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      email,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: p.onSurfaceVariant,
                                      ),
                                    ),
                                    if (profession.isNotEmpty || dob != null) ...[
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          if (profession.isNotEmpty)
                                            DuskPillBadge(
                                              text: profession,
                                              variant: DuskBadgeVariant.blue,
                                              icon: Icons.work_outline_rounded,
                                            ),
                                          if (dob != null)
                                            DuskPillBadge(
                                              text: DateFormat('MMM d, yyyy').format(dob),
                                              variant: DuskBadgeVariant.green,
                                              icon: Icons.cake_outlined,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: p.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // SECTION 1: APP CUSTOMIZATION
                    _buildSectionHeader('App Customization & Look'),
                    _buildCardContainer(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: p.primarySoftBg,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(Icons.palette_outlined, color: p.primary, size: 20),
                          ),
                          title: Text(
                            'App Theme & Appearance',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                              color: p.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            appState.colorTheme.displayName,
                            style: TextStyle(color: p.onSurfaceVariant, fontSize: 13),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: appState.colorTheme.palette.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: p.outline, width: 1.5),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.chevron_right_rounded, color: p.onSurfaceVariant),
                            ],
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              DuskPageRoute.perspectiveSlide(
                                builder: (_) => const CustomizationSettingsScreen(),
                              ),
                            );
                          },
                        ),
                        Divider(height: 1, indent: 18, endIndent: 18, color: p.outline),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: p.secondaryContainer,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(Icons.widgets_outlined, color: p.secondary, size: 20),
                          ),
                          title: Text(
                            'Home Screen Widgets',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                              color: p.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            'Quick Capture & Analytics widget setups',
                            style: TextStyle(color: p.onSurfaceVariant, fontSize: 13),
                          ),
                          trailing: Icon(Icons.chevron_right_rounded, color: p.onSurfaceVariant),
                          onTap: () {
                            Navigator.of(context).push(
                              DuskPageRoute.perspectiveSlide(
                                builder: (_) => const HomeWidgetsScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    // SECTION 2: DUSK BUDDY & SECOND BRAIN AI
                    _buildSectionHeader('Dusk Buddy & Second Brain AI'),
                    _buildCardContainer(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: p.primarySoftBg,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(Icons.auto_awesome_rounded, color: p.primary, size: 20),
                          ),
                          title: Text(
                            'Dusk Buddy AI Chat',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                              color: p.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            'Chat with your dumps, tasks & reflections • Groq API',
                            style: TextStyle(color: p.onSurfaceVariant, fontSize: 13),
                          ),
                          trailing: Icon(Icons.chevron_right_rounded, color: p.onSurfaceVariant),
                          onTap: () {
                            Navigator.of(context).push(
                              DuskPageRoute.modalSheet(
                                builder: (_) => const DuskChatScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    // SECTION 3: EVENING RITUAL
                    _buildSectionHeader('Evening Ritual & Alarm'),
                    _buildCardContainer(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: p.primarySoftBg,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(Icons.nightlight_round_sharp, color: p.primary, size: 20),
                          ),
                          title: Text(
                            'Evening Reflection Ritual',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                              color: p.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            '${_getFrequencyText(_scheduleFrequency)} at ${_scheduleTime.format(context)} • ${_selectedAlarmSound.name}',
                            style: TextStyle(color: p.onSurfaceVariant, fontSize: 13),
                          ),
                          trailing: Icon(Icons.chevron_right_rounded, color: p.onSurfaceVariant),
                          onTap: () async {
                            await Navigator.of(context).push(
                              DuskPageRoute.perspectiveSlide(
                                builder: (_) => const EveningRitualSettingsScreen(),
                              ),
                            );
                            _loadScheduleSettings();
                          },
                        ),
                      ],
                    ),

                    // SECTION 3: SYSTEM PERMISSIONS
                    _buildSectionHeader('Permissions & Device Access'),
                    _buildCardContainer(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: p.tertiaryContainer,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(Icons.verified_user_outlined, color: p.tertiary, size: 20),
                          ),
                          title: Text(
                            'Permissions Manager',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                              color: p.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            _permissionsLoaded
                                ? '$grantedCount of $totalPerms permissions granted'
                                : 'Microphone, Camera, Notifications & Alarms',
                            style: TextStyle(color: p.onSurfaceVariant, fontSize: 13),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DuskPillBadge(
                                text: _permissionsLoaded && grantedCount == totalPerms
                                    ? 'All Active'
                                    : '$grantedCount/$totalPerms',
                                variant: _permissionsLoaded && grantedCount == totalPerms
                                    ? DuskBadgeVariant.green
                                    : DuskBadgeVariant.neutral,
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.chevron_right_rounded, color: p.onSurfaceVariant),
                            ],
                          ),
                          onTap: () async {
                            await Navigator.of(context).push(
                              DuskPageRoute.perspectiveSlide(
                                builder: (_) => const PermissionsSettingsScreen(),
                              ),
                            );
                            _loadPermissions();
                          },
                        ),
                      ],
                    ),

                    // SECTION 4: DATA & PRIVACY
                    _buildSectionHeader('Data & Storage Vault'),
                    _buildCardContainer(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: p.secondaryContainer,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(Icons.storage_rounded, color: p.secondary, size: 20),
                          ),
                          title: Text(
                            'Data & Storage Vault',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                              color: p.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            'Audio dumps cache: $_cacheSizeStr',
                            style: TextStyle(color: p.onSurfaceVariant, fontSize: 13),
                          ),
                          trailing: Icon(Icons.chevron_right_rounded, color: p.onSurfaceVariant),
                          onTap: () async {
                            await Navigator.of(context).push(
                              DuskPageRoute.perspectiveSlide(
                                builder: (_) => const DataStorageSettingsScreen(),
                              ),
                            );
                            _calculateCacheSize();
                          },
                        ),
                        Divider(height: 1, indent: 18, endIndent: 18, color: p.outline),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: p.secondaryContainer,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(Icons.security_rounded, color: p.secondary, size: 20),
                          ),
                          title: Text(
                            'Privacy & Security Architecture',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                              color: p.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            'Zero telemetry & local device encryption',
                            style: TextStyle(color: p.onSurfaceVariant, fontSize: 13),
                          ),
                          trailing: Icon(Icons.chevron_right_rounded, color: p.onSurfaceVariant),
                          onTap: () {
                            Navigator.of(context).push(
                              DuskPageRoute.perspectiveSlide(
                                builder: (_) => const PrivacyScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    // SECTION 5: MEMBERSHIP & PREVIEWS
                    _buildSectionHeader('Subscription & Previews'),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          DuskPageRoute.modalSheet(
                            builder: (_) => const PaywallScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: p.primarySoftBg,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: p.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: p.surface,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.star_rounded, color: p.primary, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Upgrade to Dusk Pro',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: p.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Unlock infinite history & AI synthesis',
                                    style: TextStyle(color: p.onSurfaceVariant, fontSize: 12.5),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios_rounded, color: p.primary, size: 16),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                    _buildCardContainer(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                          leading: Icon(Icons.auto_stories_outlined, color: p.secondary),
                          title: Text(
                            'Replay Welcome Onboarding',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14.5,
                              color: p.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            'Preview the 4-step Dusk introduction',
                            style: TextStyle(color: p.onSurfaceVariant, fontSize: 12.5),
                          ),
                          trailing: Icon(Icons.chevron_right_rounded, color: p.onSurfaceVariant),
                          onTap: () {
                            Navigator.of(context).push(
                              DuskPageRoute.flowProgression(
                                builder: (_) => const OnboardingScreen(isPreview: true),
                              ),
                            );
                          },
                        ),
                        Divider(height: 1, indent: 18, endIndent: 18, color: p.outline),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                          leading: Icon(Icons.badge_outlined, color: p.tertiary),
                          title: Text(
                            'First-Signup Profile Setup',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14.5,
                              color: p.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            '"What should I call you?" onboarding screen',
                            style: TextStyle(color: p.onSurfaceVariant, fontSize: 12.5),
                          ),
                          trailing: Icon(Icons.chevron_right_rounded, color: p.onSurfaceVariant),
                          onTap: () {
                            Navigator.of(context).push(
                              DuskPageRoute.flowProgression(
                                builder: (_) => const ProfileSetupScreen(isPreview: true),
                              ),
                            );
                          },
                        ),
                        Divider(height: 1, indent: 18, endIndent: 18, color: p.outline),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                          leading: Icon(Icons.info_outline_rounded, color: p.onSurfaceVariant),
                          title: Text(
                            'About Dusk',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14.5,
                              color: p.onSurface,
                            ),
                          ),
                          trailing: Text(
                            'v1.0.0',
                            style: TextStyle(color: p.onSurfaceVariant, fontSize: 13),
                          ),
                        ),
                        Divider(height: 1, indent: 18, endIndent: 18, color: p.outline),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                          leading: const Icon(Icons.logout_rounded, color: Colors.red),
                          title: const Text(
                            'Log Out',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                            ),
                          ),
                          onTap: () async {
                            final appStateRef = context.read<AppState>();
                            try {
                              await NotificationService().cancelAll();
                            } catch (_) {}
                            await SupabaseService().signOut();
                            await appStateRef.resetStateForSignOut();
                            if (context.mounted) {
                              Navigator.of(context).pushAndRemoveUntil(
                                DuskPageRoute.flowProgression(
                                  builder: (_) => const AuthScreen(),
                                ),
                                (route) => false,
                              );
                            }
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 48),
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

class _PermissionItem {
  final Permission permission;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;

  _PermissionItem({
    required this.permission,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}
