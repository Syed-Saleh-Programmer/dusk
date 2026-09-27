import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../main.dart';
import '../models/alarm_sound.dart';
import '../ui/screens/alarm_screen.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import 'supabase_service.dart';

/// Top-level background action handler for notification action buttons
/// (e.g. Snooze, Dismiss) tapped while the app is in background or terminated.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  debugPrint('🔔 [Background Action] actionId=${notificationResponse.actionId}');
  if (notificationResponse.actionId == 'snooze_action') {
    NotificationService().snoozeReminder(notificationResponse.payload ?? 'cycle');
  } else if (notificationResponse.actionId == 'dismiss_action') {
    NotificationService().cancelAll();
    NotificationService().scheduleNextCadenceReminder();
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  /// Whether this app launch was triggered by tapping a notification.
  bool _launchedFromNotification = false;
  String? _launchPayload;

  bool get launchedFromNotification => _launchedFromNotification;
  String? get launchPayload => _launchPayload;

  /// Call once the navigator is ready to consume the launch payload.
  void clearLaunchPayload() {
    _launchedFromNotification = false;
    _launchPayload = null;
  }

  Future<void> init() async {
    tz.initializeTimeZones();

    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      final currentTimeZone = timezoneInfo.identifier;
      tz.setLocalLocation(tz.getLocation(currentTimeZone));
      debugPrint('📍 NotificationService: Local timezone successfully set to $currentTimeZone');
    } catch (e) {
      debugPrint('⚠️ NotificationService: Could not determine local timezone: $e');
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/ic_stat_dusk');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('🔔 onDidReceiveNotificationResponse: actionId=${response.actionId}, payload=${response.payload}');
        if (response.actionId == 'snooze_action') {
          snoozeReminder(response.payload ?? 'cycle');
        } else if (response.actionId == 'dismiss_action') {
          cancelAll();
          scheduleNextCadenceReminder();
        } else {
          // Default tap or "Begin Reflection"
          if (response.payload != null) {
            _navigateToAlarm(response.payload!);
          }
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Create high-priority alarm notification channel on Android
    final androidImplementation = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      for (final sound in AlarmSound.values) {
        final channel = AndroidNotificationChannel(
          sound.channelId,
          'Reflection Alarms (${sound.name})',
          description: 'Exact alarms for your daily reflection (${sound.name})',
          importance: Importance.max,
          sound: RawResourceAndroidNotificationSound(sound.rawResourceName),
          playSound: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          enableVibration: true,
          enableLights: true,
        );
        await androidImplementation.createNotificationChannel(channel);
      }
      debugPrint('📢 NotificationService: Alarm channels registered for all sounds');

      // Request runtime permissions on Android 13+ (POST_NOTIFICATIONS and SCHEDULE_EXACT_ALARM)
      try {
        final notifGranted = await androidImplementation.requestNotificationsPermission();
        debugPrint('📢 NotificationService: Notification permission result: $notifGranted');
        final alarmGranted = await androidImplementation.requestExactAlarmsPermission();
        debugPrint('📢 NotificationService: Exact alarm permission result: $alarmGranted');
        final fsiGranted = await androidImplementation.requestFullScreenIntentPermission();
        debugPrint('📢 NotificationService: Full-screen intent permission result: $fsiGranted');
      } catch (e) {
        debugPrint('⚠️ NotificationService: Error requesting Android permissions: $e');
      }
    }

    // Check if the app was launched by tapping a notification (cold start)
    final launchDetails =
        await _flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
    if (launchDetails != null &&
        launchDetails.didNotificationLaunchApp &&
        launchDetails.notificationResponse?.payload != null) {
      _launchedFromNotification = true;
      _launchPayload = launchDetails.notificationResponse!.payload;
      debugPrint('🚀 NotificationService: Launched from notification cold-start, payload: $_launchPayload');
    }
  }

  /// Navigate to the alarm screen when a notification is tapped or full-screen intent triggers.
  void _navigateToAlarm(String payload) {
    // Cancel the system notification so the insistent looping OS audio stops
    _flutterLocalNotificationsPlugin.cancel(id: 0);

    if (navigatorKey.currentState != null && navigatorKey.currentContext != null) {
      // Get the real current cycle id
      final appState = Provider.of<AppState>(navigatorKey.currentContext!, listen: false);
      final realCycleId = appState.currentCycle?.id ?? payload;

      debugPrint('🚀 Navigating to AlarmScreen with cycleId: $realCycleId');
      // Push alarm screen on top of whatever is currently showing
      navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (_) => AlarmScreen(cycleId: realCycleId),
        ),
      );
    }
  }

  /// Call from main.dart after the first frame renders, to handle
  /// cold-start from a notification tap.
  void handleLaunchNotification() {
    if (_launchedFromNotification && _launchPayload != null) {
      // Slight delay to let the home screen finish building
      Future.delayed(const Duration(milliseconds: 800), () {
        _navigateToAlarm(_launchPayload!);
        clearLaunchPayload();
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Scheduling
  // ---------------------------------------------------------------------------

  /// Schedules a one-shot alarm for the next reflection time based on cadence.
  Future<void> scheduleReflectionReminder(DateTime scheduledTime, String cycleId) async {
    // Cancel any previous alarm so we don't stack duplicates
    await _flutterLocalNotificationsPlugin.cancelAll();

    final now = tz.TZDateTime.now(tz.local);

    // Build the TZDateTime explicitly using the date & time parts in local timezone
    var scheduledTZ = tz.TZDateTime(
      tz.local,
      scheduledTime.year,
      scheduledTime.month,
      scheduledTime.day,
      scheduledTime.hour,
      scheduledTime.minute,
      scheduledTime.second,
    );

    // If the scheduled time is in the past, push it to tomorrow
    if (scheduledTZ.isBefore(now)) {
      debugPrint('⚠️ Scheduled time $scheduledTZ is before now $now. Adding 1 day...');
      scheduledTZ = scheduledTZ.add(const Duration(days: 1));
    }

    final selectedSound = await AlarmSound.loadSelected();

    // FLAG_INSISTENT = 4: repeats the alarm audio in a continuous loop until handled
    final Int32List additionalFlags = Int32List.fromList(<int>[4]);

    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        selectedSound.channelId,
        'Reflection Alarms (${selectedSound.name})',
        channelDescription: 'Exact alarms for your daily reflection (${selectedSound.name})',
        icon: '@drawable/ic_stat_dusk',
        color: const Color(0xFFFF7A1A),
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: true,
        sound: RawResourceAndroidNotificationSound(selectedSound.rawResourceName),
        playSound: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        ongoing: true, // sticky until user acts
        autoCancel: false,
        enableLights: true,
        enableVibration: true,
        additionalFlags: additionalFlags,
        actions: const <AndroidNotificationAction>[
          AndroidNotificationAction(
            'begin_action',
            'Begin Reflection',
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            'snooze_action',
            'Snooze 1h',
            showsUserInterface: false,
          ),
          AndroidNotificationAction(
            'dismiss_action',
            'Dismiss',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
      ),
      iOS: const DarwinNotificationDetails(
        presentSound: true,
        presentAlert: true,
        presentBadge: true,
        sound: 'reflection_bell.aiff',
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );

    try {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id: 0,
        title: 'Time to Reflect',
        body: 'Your evening ritual is ready. Tap to start.',
        scheduledDate: scheduledTZ,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        payload: cycleId,
      );
      debugPrint('🔔 [alarmClock] Reflection alarm scheduled successfully for $scheduledTZ');
    } catch (e) {
      debugPrint('⚠️ [alarmClock] failed ($e), attempting exactAllowWhileIdle fallback...');
      try {
        await _flutterLocalNotificationsPlugin.zonedSchedule(
          id: 0,
          title: 'Time to Reflect',
          body: 'Your evening ritual is ready. Tap to start.',
          scheduledDate: scheduledTZ,
          notificationDetails: notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: cycleId,
        );
        debugPrint('🔔 [exactAllowWhileIdle] Reflection alarm scheduled successfully for $scheduledTZ');
      } catch (e2) {
        debugPrint('⚠️ [exactAllowWhileIdle] failed ($e2), attempting inexact fallback...');
        await _flutterLocalNotificationsPlugin.zonedSchedule(
          id: 0,
          title: 'Time to Reflect',
          body: 'Your evening ritual is ready. Tap to start.',
          scheduledDate: scheduledTZ,
          notificationDetails: notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: cycleId,
        );
        debugPrint('🔔 [inexactAllowWhileIdle] Reflection alarm scheduled successfully for $scheduledTZ');
      }
    }
  }

  /// Schedules a snooze alarm 1 hour from now.
  Future<void> snoozeReminder(String cycleId) async {
    final snoozeTime = tz.TZDateTime.now(tz.local).add(const Duration(hours: 1));
    await scheduleReflectionReminder(snoozeTime, cycleId);
    debugPrint('⏰ Snoozed — alarm rescheduled for $snoozeTime');
  }

  /// Reads the user's cadence preferences and schedules the NEXT alarm.
  Future<void> scheduleNextCadenceReminder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String suffix = '';
      try {
        final uid = SupabaseService().currentUser?.id;
        if (uid != null && uid.isNotEmpty) {
          suffix = '_$uid';
        }
      } catch (_) {}

      final cadenceDays = prefs.getInt('reflection_cadence_days$suffix') ?? 3;
      final hour = prefs.getInt('reflection_reminder_hour$suffix') ?? 21;
      final minute = prefs.getInt('reflection_reminder_minute$suffix') ?? 0;

      final now = tz.TZDateTime.now(tz.local);
      var nextDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

      // The next alarm is cadenceDays from today.
      nextDate = nextDate.add(Duration(days: cadenceDays));
      if (nextDate.isBefore(now)) {
        nextDate = nextDate.add(Duration(days: cadenceDays));
      }

      await scheduleReflectionReminder(nextDate, 'cadence-auto');
      debugPrint('📅 Next cadence reminder scheduled for $nextDate (every $cadenceDays days)');
    } catch (e) {
      debugPrint('Error scheduling next cadence reminder: $e');
    }
  }

  Future<void> cancelAll() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }
}
