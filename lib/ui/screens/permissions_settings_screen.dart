import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_theme.dart';
import '../widgets/dusk_ui_components.dart';

class PermissionsSettingsScreen extends StatefulWidget {
  const PermissionsSettingsScreen({super.key});

  @override
  State<PermissionsSettingsScreen> createState() => _PermissionsSettingsScreenState();
}

class _PermissionsSettingsScreenState extends State<PermissionsSettingsScreen> with WidgetsBindingObserver {
  Map<Permission, PermissionStatus> _statuses = {};
  bool _isLoading = true;

  List<_PermissionMeta> get _items {
    final p = AppTheme.palette;
    return [
      _PermissionMeta(
        permission: Permission.microphone,
        title: 'Microphone',
        subtitle: 'Capture voice thoughts, nightly brain dumps, and spoken reflections',
        icon: Icons.mic_rounded,
        color: p.primary,
        bgColor: p.primaryContainer,
      ),
      _PermissionMeta(
        permission: Permission.camera,
        title: 'Camera',
        subtitle: 'Capture real-time visual moments and photos as reflection anchors',
        icon: Icons.camera_alt_rounded,
        color: p.secondary,
        bgColor: p.secondaryContainer,
      ),
      _PermissionMeta(
        permission: Permission.notification,
        title: 'Notifications',
        subtitle: 'Alert you when dusk arrives and it is time for your reflection',
        icon: Icons.notifications_active_rounded,
        color: p.tertiary,
        bgColor: p.tertiaryContainer,
      ),
      _PermissionMeta(
        permission: Permission.scheduleExactAlarm,
        title: 'Exact Alarms',
        subtitle: 'Trigger your peaceful chime and reminder precisely at your scheduled time',
        icon: Icons.alarm_rounded,
        color: p.primaryDark,
        bgColor: p.primaryContainer,
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStatuses();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadStatuses();
    }
  }

  Future<void> _loadStatuses() async {
    final statuses = <Permission, PermissionStatus>{};
    for (final item in _items) {
      statuses[item.permission] = await item.permission.status;
    }
    if (mounted) {
      setState(() {
        _statuses = statuses;
        _isLoading = false;
      });
    }
  }

  Future<void> _requestPermission(_PermissionMeta item) async {
    final currentStatus = _statuses[item.permission];

    if (currentStatus == PermissionStatus.permanentlyDenied ||
        currentStatus == PermissionStatus.restricted) {
      final opened = await openAppSettings();
      if (opened) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) _loadStatuses();
        });
      }
      return;
    }

    HapticFeedback.lightImpact();
    final newStatus = await item.permission.request();
    if (mounted) {
      setState(() {
        _statuses[item.permission] = newStatus;
      });
    }
  }

  Future<void> _requestAllPermissions() async {
    HapticFeedback.mediumImpact();
    for (final item in _items) {
      final status = _statuses[item.permission];
      if (status != PermissionStatus.granted) {
        if (status != PermissionStatus.permanentlyDenied) {
          final res = await item.permission.request();
          if (mounted) {
            setState(() {
              _statuses[item.permission] = res;
            });
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final grantedCount = _statuses.values.where((s) => s == PermissionStatus.granted).length;
    final allGranted = !_isLoading && grantedCount == _items.length;

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
                        'System Permissions',
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
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(p.primary),
                        ),
                      )
                    : ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                        children: [
                          // 1. STATUS HERO CARD
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  allGranted ? p.tertiaryContainer.withValues(alpha: 0.4) : p.primarySoftBg,
                                  p.surface,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: allGranted ? p.tertiary.withValues(alpha: 0.3) : p.outline,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.035),
                                  blurRadius: 16,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: allGranted ? p.tertiaryContainer : p.primaryContainer,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    allGranted ? Icons.verified_user_rounded : Icons.shield_outlined,
                                    color: allGranted ? p.tertiary : p.primary,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        allGranted
                                            ? 'Everything is Ready'
                                            : '${_items.length - grantedCount} Permissions Required',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: p.onSurface,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        allGranted
                                            ? 'Dusk has all necessary access for seamless captures and chimes.'
                                            : 'Enable remaining permissions for full voice, camera & chime features.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: p.onSurfaceVariant,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.04),

                          const SizedBox(height: 24),

                          // 2. PERMISSIONS LIST
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 10),
                            child: Text(
                              'REQUIRED PERMISSIONS',
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
                                  ..._items.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final item = entry.value;
                                    final status = _statuses[item.permission];
                                    final isGranted = status == PermissionStatus.granted;
                                    final isPermanentlyDenied = status == PermissionStatus.permanentlyDenied;

                                    return Column(
                                      children: [
                                        if (index > 0)
                                          Divider(height: 1, indent: 68, endIndent: 16, color: p.outline),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 42,
                                                height: 42,
                                                decoration: BoxDecoration(
                                                  color: item.bgColor,
                                                  borderRadius: BorderRadius.circular(13),
                                                ),
                                                child: Icon(item.icon, color: item.color, size: 20),
                                              ),
                                              const SizedBox(width: 14),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      item.title,
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.w700,
                                                        fontSize: 15,
                                                        color: p.onSurface,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      isPermanentlyDenied
                                                          ? 'Blocked in system settings · Tap to open settings'
                                                          : item.subtitle,
                                                      style: TextStyle(
                                                        color: isPermanentlyDenied ? p.primaryDark : p.onSurfaceVariant,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w500,
                                                        height: 1.3,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              if (isGranted)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                  decoration: BoxDecoration(
                                                    color: p.tertiaryContainer,
                                                    borderRadius: BorderRadius.circular(20),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.check_circle_rounded,
                                                        color: p.onTertiaryContainer,
                                                        size: 14,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Active',
                                                        style: TextStyle(
                                                          fontSize: 11.5,
                                                          fontWeight: FontWeight.w700,
                                                          color: p.onTertiaryContainer,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                )
                                              else
                                                InkWell(
                                                  onTap: () => _requestPermission(item),
                                                  borderRadius: BorderRadius.circular(20),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                                    decoration: BoxDecoration(
                                                      color: isPermanentlyDenied ? p.primaryContainer : p.primary,
                                                      borderRadius: BorderRadius.circular(20),
                                                    ),
                                                    child: Text(
                                                      isPermanentlyDenied ? 'Settings' : 'Allow',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w700,
                                                        color: isPermanentlyDenied ? p.primary : Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ).animate().fadeIn(delay: 80.ms, duration: 280.ms),

                          const SizedBox(height: 24),

                          // 3. ACTION BUTTONS
                          if (!allGranted)
                            ElevatedButton.icon(
                              onPressed: _requestAllPermissions,
                              icon: const Icon(Icons.verified_user_rounded, size: 18),
                              label: Text('Grant All Missing (${_items.length - grantedCount})'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: p.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ).animate().fadeIn(delay: 120.ms, duration: 280.ms),

                          const SizedBox(height: 12),

                          OutlinedButton.icon(
                            onPressed: openAppSettings,
                            icon: Icon(Icons.open_in_new_rounded, size: 16, color: p.onSurface),
                            label: Text(
                              'Open System App Settings',
                              style: TextStyle(
                                color: p.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: p.outline),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ).animate().fadeIn(delay: 150.ms, duration: 280.ms),
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

class _PermissionMeta {
  final Permission permission;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color bgColor;

  _PermissionMeta({
    required this.permission,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.bgColor,
  });
}
