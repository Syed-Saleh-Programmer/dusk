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
import 'alarm_sound_screen.dart';
import 'paywall_screen.dart';
import 'privacy_screen.dart';
import 'auth_screen.dart';
import 'edit_reflection_schedule_screen.dart';
import 'user_profile_screen.dart';
import 'onboarding_screen.dart';
import 'profile_setup_screen.dart';
import '../widgets/dusk_ui_components.dart';

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

  // The permissions this app uses
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

  Future<void> _requestPermission(_PermissionItem item) async {
    final currentStatus = _permissionStatuses[item.permission];

    if (currentStatus == PermissionStatus.permanentlyDenied ||
        currentStatus == PermissionStatus.restricted) {
      // Can't request again — must go to system settings
      final opened = await openAppSettings();
      if (opened) {
        // Reload permission statuses when user returns
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) _loadPermissions();
        });
      }
      return;
    }

    // For scheduleExactAlarm on Android 12+, must open special settings
    if (item.permission == Permission.scheduleExactAlarm &&
        currentStatus != PermissionStatus.granted) {
      final status = await item.permission.request();
      if (mounted) {
        setState(() {
          _permissionStatuses[item.permission] = status;
        });
      }
      return;
    }

    final status = await item.permission.request();
    if (mounted) {
      setState(() {
        _permissionStatuses[item.permission] = status;
      });

      // If notification was just granted, re-schedule any pending reminders
      if (item.permission == Permission.notification &&
          status == PermissionStatus.granted) {
        NotificationService().scheduleNextCadenceReminder();
      }
    }
  }

  Future<void> _requestAllPermissions() async {
    for (final item in _permissionItems) {
      final status = _permissionStatuses[item.permission];
      if (status != PermissionStatus.granted) {
        await _requestPermission(item);
        // Small delay between requests so dialogs don't stack
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
    await _loadPermissions();
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

  Future<void> _openAlarmSoundScreen() async {
    final chosen = await Navigator.of(context).push<AlarmSound>(
      MaterialPageRoute(
        builder: (_) => AlarmSoundScreen(
          initialSound: _selectedAlarmSound,
        ),
      ),
    );
    if (chosen != null && mounted) {
      setState(() {
        _selectedAlarmSound = chosen;
      });
    } else {
      _loadScheduleSettings();
    }
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
        setState(() {
          if (mb < 0.1) {
            _cacheSizeStr = '< 0.1 MB';
          } else {
            _cacheSizeStr = '${mb.toStringAsFixed(1)} MB';
          }
        });
      } else {
        setState(() {
          _cacheSizeStr = '0 MB';
        });
      }
    } catch (e) {
      setState(() {
        _cacheSizeStr = 'Unknown';
      });
    }
  }

  Future<void> _clearCache() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${directory.path}/audio_dumps');
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create();
      }
      _calculateCacheSize();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audio cache cleared')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error clearing cache: $e')),
        );
      }
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 20, 6, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          color: Color(0xFF88827A),
        ),
      ),
    );
  }

  Widget _buildCardContainer({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF0EBE1)),
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
    final user = SupabaseService().currentUser;
    final fullName = appState.preferredName.isNotEmpty
        ? appState.preferredName
        : ((user?.userMetadata?['full_name'] as String?) ?? 'User');
    final profession = appState.profession;
    final dob = appState.dob;
    final email = user?.email ?? 'mindful@dusk.app';
    final firstLetter = fullName.isNotEmpty ? fullName[0].toUpperCase() : 'D';

    ImageProvider? avatarProvider;
    if (appState.avatarLocalPath != null &&
        appState.avatarLocalPath!.isNotEmpty &&
        File(appState.avatarLocalPath!).existsSync()) {
      avatarProvider = FileImage(File(appState.avatarLocalPath!));
    } else if (appState.avatarUrl != null && appState.avatarUrl!.isNotEmpty) {
      avatarProvider = NetworkImage(appState.avatarUrl!);
    }

    final timeString = _scheduleTime.format(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F2),
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
                        children: const [
                          Text(
                            'Settings',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1B1A19),
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Profile, reflection ritual & preferences',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF88827A),
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const UserProfileScreen(),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFFF0EBE1)),
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
                                          ? const LinearGradient(
                                              colors: [
                                                Color(0xFFFF9548),
                                                Color(0xFFFF7A1A),
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
                                        color: const Color(0xFF1B1A19),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
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
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF1B1A19),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const DuskPillBadge(
                                          text: 'Free Plan',
                                          variant: DuskBadgeVariant.neutral,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      email,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: Color(0xFF88827A),
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
                                              text: DateFormat('MMM d, yyyy')
                                                  .format(dob),
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
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Color(0xFFA59F95),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    _buildSectionHeader('Reflection Ritual'),
                    _buildCardContainer(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                          leading: const Icon(Icons.schedule_rounded, color: Color(0xFFFF7A1A)),
                          title: const Text(
                            'Reflection Schedule',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                          ),
                          subtitle: Text(
                            '${_getFrequencyText(_scheduleFrequency)} at $timeString',
                            style: const TextStyle(color: Color(0xFF88827A), fontSize: 13),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFA59F95)),
                          onTap: () async {
                            final updated = await Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const EditReflectionScheduleScreen()),
                            );
                            if (updated == true) {
                              _loadScheduleSettings();
                            }
                          },
                        ),
                        const Divider(height: 1, indent: 18, endIndent: 18, color: Color(0xFFF0EBE1)),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                          leading: const Icon(Icons.music_note_rounded, color: Color(0xFFFF7A1A)),
                          title: const Text(
                            'Alarm Sound',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                          ),
                          subtitle: Text(
                            '${_selectedAlarmSound.name} · ${_selectedAlarmSound.tag}',
                            style: const TextStyle(color: Color(0xFF88827A), fontSize: 13),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFA59F95)),
                          onTap: _openAlarmSoundScreen,
                        ),
                      ],
                    ),

                    _buildSectionHeader('App Permissions'),
                    _buildCardContainer(
                      children: [
                        if (!_permissionsLoaded)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF7A1A)),
                                ),
                              ),
                            ),
                          )
                        else ...[
                          ..._permissionItems.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            final status = _permissionStatuses[item.permission];
                            final isGranted = status == PermissionStatus.granted;
                            final isPermanentlyDenied = status == PermissionStatus.permanentlyDenied;

                            return Column(
                              children: [
                                if (index > 0)
                                  const Divider(height: 1, indent: 18, endIndent: 18, color: Color(0xFFF0EBE1)),
                                ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                                  leading: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: item.color.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(item.icon, color: item.color, size: 20),
                                  ),
                                  title: Text(
                                    item.label,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                                  ),
                                  subtitle: Text(
                                    isGranted ? 'Granted' : (isPermanentlyDenied ? 'Denied — tap to open settings' : item.subtitle),
                                    style: TextStyle(
                                      color: isGranted ? const Color(0xFF6BBF59) : const Color(0xFF88827A),
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  trailing: isGranted
                                      ? const Icon(Icons.check_circle_rounded, color: Color(0xFF6BBF59), size: 22)
                                      : Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: isPermanentlyDenied
                                                ? const Color(0xFFFFF0E6)
                                                : const Color(0xFFF5F3EE),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: isPermanentlyDenied
                                                  ? const Color(0xFFFF7A1A).withValues(alpha: 0.3)
                                                  : const Color(0xFFE8E2D8),
                                            ),
                                          ),
                                          child: Text(
                                            isPermanentlyDenied ? 'Settings' : 'Grant',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: isPermanentlyDenied
                                                  ? const Color(0xFFFF7A1A)
                                                  : const Color(0xFF1B1A19),
                                            ),
                                          ),
                                        ),
                                  onTap: isGranted ? null : () => _requestPermission(item),
                                ),
                              ],
                            );
                          }),
                          // "Grant All" button if any permission is not granted
                          if (_permissionStatuses.values.any((s) => s != PermissionStatus.granted)) ...[
                            const Divider(height: 1, indent: 18, endIndent: 18, color: Color(0xFFF0EBE1)),
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                              leading: const Icon(Icons.security_rounded, color: Color(0xFFFF7A1A)),
                              title: const Text(
                                'Grant All Permissions',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5,
                                  color: Color(0xFFFF7A1A),
                                ),
                              ),
                              subtitle: Text(
                                '${_permissionStatuses.values.where((s) => s != PermissionStatus.granted).length} permission(s) needed',
                                style: const TextStyle(color: Color(0xFF88827A), fontSize: 12.5),
                              ),
                              trailing: const Icon(Icons.arrow_forward_rounded, color: Color(0xFFFF7A1A), size: 20),
                              onTap: _requestAllPermissions,
                            ),
                          ],
                        ],
                      ],
                    ),

                    _buildSectionHeader('Subscription & Upgrades'),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PaywallScreen()),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDE8D7).withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFFF7A1A).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.star_rounded, color: Color(0xFFFF7A1A), size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Upgrade to Dusk Pro',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: Color(0xFF1B1A19),
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Unlock infinite history & AI synthesis',
                                    style: TextStyle(color: Color(0xFF6E6862), fontSize: 12.5),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFFF7A1A), size: 16),
                          ],
                        ),
                      ),
                    ),

                    _buildSectionHeader('Privacy & Data'),
                    _buildCardContainer(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                          leading: const Icon(Icons.security_rounded, color: Color(0xFF4A84D8)),
                          title: const Text(
                            'Privacy & Data Architecture',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFA59F95)),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                            );
                          },
                        ),
                        const Divider(height: 1, indent: 18, endIndent: 18, color: Color(0xFFF0EBE1)),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                          leading: const Icon(Icons.cleaning_services_outlined, color: Color(0xFF4A84D8)),
                          title: const Text(
                            'Clear Local Audio Cache',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                          ),
                          subtitle: Text(
                            _cacheSizeStr,
                            style: const TextStyle(color: Color(0xFF88827A), fontSize: 13),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFA59F95)),
                          onTap: _clearCache,
                        ),
                      ],
                    ),

                    _buildSectionHeader('Account & Session'),
                    _buildCardContainer(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                          leading: const Icon(Icons.person_outline_rounded, color: Color(0xFFFF7A1A)),
                          title: const Text(
                            'Personal Profile',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                          ),
                          subtitle: const Text(
                            'Update preferred name, profession, DOB & photo',
                            style: TextStyle(color: Color(0xFF88827A), fontSize: 12.5),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFA59F95)),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const UserProfileScreen()),
                            );
                          },
                        ),
                        const Divider(height: 1, indent: 18, endIndent: 18, color: Color(0xFFF0EBE1)),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                          leading: const Icon(Icons.auto_stories_outlined, color: Color(0xFF4A84D8)),
                          title: const Text(
                            'Replay Welcome Onboarding',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                          ),
                          subtitle: const Text(
                            'Preview the 4-step Dusk introduction',
                            style: TextStyle(color: Color(0xFF88827A), fontSize: 12.5),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFA59F95)),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const OnboardingScreen(isPreview: true),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1, indent: 18, endIndent: 18, color: Color(0xFFF0EBE1)),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                          leading: const Icon(Icons.badge_outlined, color: Color(0xFF2DC48D)),
                          title: const Text(
                            'First-Signup Profile Setup',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                          ),
                          subtitle: const Text(
                            '"What should I call you?" onboarding screen',
                            style: TextStyle(color: Color(0xFF88827A), fontSize: 12.5),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFA59F95)),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ProfileSetupScreen(isPreview: true),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1, indent: 18, endIndent: 18, color: Color(0xFFF0EBE1)),
                        const ListTile(
                          contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                          leading: Icon(Icons.info_outline_rounded, color: Color(0xFF88827A)),
                          title: Text(
                            'About Dusk',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                          ),
                          trailing: Text(
                            'v1.0.0',
                            style: TextStyle(color: Color(0xFF88827A), fontSize: 13),
                          ),
                        ),
                        const Divider(height: 1, indent: 18, endIndent: 18, color: Color(0xFFF0EBE1)),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                          leading: const Icon(Icons.logout_rounded, color: Colors.red),
                          title: const Text(
                            'Log Out',
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700, fontSize: 14.5),
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
                                MaterialPageRoute(builder: (_) => const AuthScreen()),
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

/// Simple data holder for each permission row in the Settings screen.
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

