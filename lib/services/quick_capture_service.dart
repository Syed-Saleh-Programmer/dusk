import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../main.dart';
import '../providers/app_state.dart';
import '../ui/screens/ai_cycle_summary_screen.dart';
import '../ui/screens/text_capture_screen.dart';
import '../ui/screens/voice_capture_screen.dart';
import '../ui/screens/photo_capture_screen.dart';
import '../ui/screens/paywall_screen.dart';
import '../ui/screens/dusk_chat_screen.dart';
import '../ui/widgets/quick_share_modal.dart';
import '../ui/navigation/dusk_navigation.dart';

class QuickCaptureService {
  static final QuickCaptureService _instance = QuickCaptureService._internal();
  factory QuickCaptureService() => _instance;
  QuickCaptureService._internal();

  static const MethodChannel _shareChannel =
      MethodChannel('com.example.dusk/share_intent');

  StreamSubscription<List<SharedMediaFile>>? _intentDataStreamSubscription;
  final QuickActions _quickActions = const QuickActions();
  bool _isInitialized = false;

  List<SharedMediaFile>? _queuedSharedFiles;
  String? _queuedExtraText;
  String? _queuedExtraSubject;
  List<Map<String, dynamic>>? _queuedNativeFiles;
  Uri? _queuedWidgetUri;

  static const List<String> _widgetProviders = [
    'DuskQuickCaptureWidgetProvider',
    'DuskVoiceTextWidgetProvider',
    'DuskAnalyticsWidgetProvider',
    'DuskBuddyWidgetProvider',
  ];

  /// Initializes Share Sheet receiving, Quick Actions (Launcher Shortcuts), and Home Screen Widgets.
  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    _setupQuickActions();
    _setupShareReceiver();
    _setupHomeWidget();
  }

  void dispose() {
    _intentDataStreamSubscription?.cancel();
  }

  // ==========================================
  // 1. App Launcher Shortcuts (Quick Actions)
  // ==========================================
  void _setupQuickActions() {
    try {
      _quickActions
          .initialize((shortcutType) {
            _handleCaptureRoute(shortcutType);
          })
          .catchError((e) {
            debugPrint('Failed to initialize quick_actions: $e');
          });

      _quickActions
          .setShortcutItems([
            const ShortcutItem(
              type: 'action_thought',
              localizedTitle: 'New Thought',
              icon: 'ic_launcher',
            ),
            const ShortcutItem(
              type: 'action_voice',
              localizedTitle: 'Voice Note',
              icon: 'ic_launcher',
            ),
            const ShortcutItem(
              type: 'action_photo',
              localizedTitle: 'Photo Dump',
              icon: 'ic_launcher',
            ),
          ])
          .catchError((e) {
            debugPrint('Failed to set shortcut items: $e');
          });
    } catch (e) {
      debugPrint('Failed to initialize quick_actions: $e');
    }
  }

  // ==========================================
  // 2. System Share Sheet Receiver
  // ==========================================
  void _setupShareReceiver() {
    // A. For listening to shares while app is in memory (running / backgrounded)
    _intentDataStreamSubscription =
        ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> value) {
        if (value.isNotEmpty) {
          _handleIncomingShare(value);
        } else {
          _checkFallbackNativeShare();
        }
      },
      onError: (err) {
        debugPrint('getIntentDataStream error: $err');
        _checkFallbackNativeShare();
      },
    );

    // B. For shares that cold-launched the app
    ReceiveSharingIntent.instance
        .getInitialMedia()
        .then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _handleIncomingShare(value);
        ReceiveSharingIntent.instance.reset();
      } else {
        _checkFallbackNativeShare();
      }
    }).catchError((err) {
      debugPrint('getInitialMedia error: $err');
      _checkFallbackNativeShare();
    });
  }

  Future<Map<String, dynamic>> _consumeNativeExtras() async {
    try {
      final raw = await _shareChannel
          .invokeMethod<Map<dynamic, dynamic>>('consumeShareExtras');
      if (raw == null) return const {};
      final text = raw['text'] as String?;
      final subject = raw['subject'] as String?;
      final rawFiles = raw['files'] as List<dynamic>?;
      final files = rawFiles
          ?.whereType<Map<dynamic, dynamic>>()
          .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
      return {
        'text': ?text,
        'subject': ?subject,
        if (files != null && files.isNotEmpty) 'files': files,
      };
    } catch (_) {
      return const {};
    }
  }

  Future<void> _checkFallbackNativeShare() async {
    final extras = await _consumeNativeExtras();
    final nativeFiles = extras['files'] as List<Map<String, dynamic>>?;
    final extraText = extras['text'] as String?;
    final extraSubject = extras['subject'] as String?;

    if ((nativeFiles == null || nativeFiles.isEmpty) &&
        (extraText == null || extraText.trim().isEmpty)) {
      return;
    }

    _presentOrQueueShare(
      const <SharedMediaFile>[],
      extraText: extraText,
      extraSubject: extraSubject,
      nativeFiles: nativeFiles,
    );
  }

  Future<void> _handleIncomingShare(List<SharedMediaFile> files) async {
    if (files.isEmpty) return;

    final extras = await _consumeNativeExtras();
    final extraText = extras['text'] as String?;
    final extraSubject = extras['subject'] as String?;
    final nativeFiles = extras['files'] as List<Map<String, dynamic>>?;

    _presentOrQueueShare(
      files,
      extraText: extraText,
      extraSubject: extraSubject,
      nativeFiles: nativeFiles,
    );
  }

  void _presentOrQueueShare(
    List<SharedMediaFile> files, {
    String? extraText,
    String? extraSubject,
    List<Map<String, dynamic>>? nativeFiles,
  }) {
    final navContext = navigatorKey.currentContext;
    if (navContext != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = navigatorKey.currentContext;
        if (ctx != null) {
          QuickShareModal.show(
            ctx,
            files,
            extraText: extraText,
            extraSubject: extraSubject,
            nativeSharedFiles: nativeFiles,
          );
        }
      });
    } else {
      _queuedSharedFiles = files;
      _queuedExtraText = extraText;
      _queuedExtraSubject = extraSubject;
      _queuedNativeFiles = nativeFiles;
    }
  }

  // ==========================================
  // 3. Home Screen Interactive Widgets
  // ==========================================
  void _setupHomeWidget() {
    try {
      // Listen for widget clicks while app is open / paused
      HomeWidget.widgetClicked.listen(
        (Uri? uri) {
          if (uri != null) {
            _handleWidgetUri(uri);
          }
        },
        onError: (err) {
          debugPrint('widgetClicked stream error: $err');
        },
      );

      // Handle widget click that launched app from cold start
      HomeWidget.initiallyLaunchedFromHomeWidget()
          .then((Uri? uri) {
            if (uri != null) {
              _handleWidgetUri(uri);
            }
          })
          .catchError((err) {
            debugPrint('initiallyLaunchedFromHomeWidget error: $err');
          });
    } catch (e) {
      debugPrint('Failed to initialize home_widget: $e');
    }
  }

  void _handleWidgetUri(Uri uri) {
    debugPrint('HomeWidget clicked with URI: $uri');
    final nav = navigatorKey.currentState;
    if (nav == null) {
      _queuedWidgetUri = uri;
      return;
    }

    final host = uri.host.toLowerCase();
    final path = uri.pathSegments.isNotEmpty
        ? uri.pathSegments.first.toLowerCase()
        : '';

    if (host == 'home') {
      nav.popUntil((route) => route.isFirst);
      if (path == 'ritual') {
        final ctx = navigatorKey.currentContext;
        if (ctx != null) {
          final appState = ctx.read<AppState>();
          if (!appState.canStartReflection) {
            nav.push(
              DuskPageRoute.modalSheet(
                builder: (_) => const PaywallScreen(),
              ),
            );
            return;
          }
          final cycle = appState.currentCycle;
          if (cycle != null) {
            nav.push(
              DuskPageRoute.ritual(
                builder: (_) => AiCycleSummaryScreen(cycleId: cycle.id),
              ),
            );
          }
        }
      }
      return;
    }

    if (host == 'buddy' || path == 'buddy' || uri.toString().contains('buddy')) {
      _handleCaptureRoute('action_buddy');
      return;
    }

    if (host == 'capture' || uri.scheme == 'dusk') {
      if (path == 'voice' || uri.path.contains('voice')) {
        _handleCaptureRoute('action_voice');
      } else if (path == 'photo' || uri.path.contains('photo')) {
        _handleCaptureRoute('action_photo');
      } else {
        _handleCaptureRoute('action_thought');
      }
    }
  }

  /// Updates data for all Dusk Android AppWidgets and triggers RemoteViews refresh.
  Future<void> updateWidgetData({
    required int dumpCount,
    int? todayCount,
    int? totalCount,
    int? thoughtCount,
    int? voiceCount,
    int? photoCount,
    List<int>? weeklyCounts,
    List<String>? weeklyLabels,
    int? activeDays,
    int? ritualProgress,
    bool? ritualCompleted,
    String? peakPeriod,
  }) async {
    try {
      final resolvedToday = todayCount ?? dumpCount;
      final resolvedTotal = totalCount ?? dumpCount;

      await Future.wait([
        HomeWidget.saveWidgetData<int>('dump_count', resolvedToday),
        HomeWidget.saveWidgetData<int>('today_count', resolvedToday),
        HomeWidget.saveWidgetData<int>('total_count', resolvedTotal),
        if (thoughtCount != null)
          HomeWidget.saveWidgetData<int>('thought_count', thoughtCount),
        if (voiceCount != null)
          HomeWidget.saveWidgetData<int>('voice_count', voiceCount),
        if (photoCount != null)
          HomeWidget.saveWidgetData<int>('photo_count', photoCount),
        if (weeklyCounts != null && weeklyCounts.isNotEmpty)
          HomeWidget.saveWidgetData<String>(
            'weekly_counts',
            weeklyCounts.join(','),
          ),
        if (weeklyLabels != null && weeklyLabels.isNotEmpty)
          HomeWidget.saveWidgetData<String>(
            'weekly_labels',
            weeklyLabels.join(','),
          ),
        if (activeDays != null)
          HomeWidget.saveWidgetData<int>('active_days', activeDays),
        if (ritualProgress != null)
          HomeWidget.saveWidgetData<int>('ritual_progress', ritualProgress),
        if (ritualCompleted != null)
          HomeWidget.saveWidgetData<bool>('ritual_completed', ritualCompleted),
        if (peakPeriod != null && peakPeriod.isNotEmpty)
          HomeWidget.saveWidgetData<String>('peak_period', peakPeriod),
      ]);

      for (final provider in _widgetProviders) {
        await HomeWidget.updateWidget(
          name: provider,
          androidName: provider,
        );
      }
    } catch (e) {
      debugPrint('Error updating home widget data: $e');
    }
  }

  /// Requests Android launcher to pin one of Dusk's home screen widgets directly.
  Future<bool> requestPinWidget(String androidProviderName) async {
    try {
      final supported = await HomeWidget.isRequestPinWidgetSupported();
      if (supported == true) {
        await HomeWidget.requestPinWidget(
          name: androidProviderName,
          androidName: androidProviderName,
        );
        return true;
      }
    } catch (e) {
      debugPrint('Error requesting pin widget ($androidProviderName): $e');
    }
    return false;
  }

  // ==========================================
  // Navigation & Queued Ingress Handlers
  // ==========================================
  void _handleCaptureRoute(String shortcutType) {
    final nav = navigatorKey.currentState;
    if (nav == null) {
      // Retry in next frame if navigator isn't mounted yet
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleCaptureRoute(shortcutType);
      });
      return;
    }

    if (shortcutType == 'action_buddy') {
      nav.push(DuskPageRoute.modalSheet(builder: (_) => const DuskChatScreen()));
      return;
    }

    final ctx = navigatorKey.currentContext;
    if (ctx != null) {
      final appState = ctx.read<AppState>();
      if (!appState.canCaptureDump) {
        nav.push(DuskPageRoute.modalSheet(builder: (_) => const PaywallScreen()));
        return;
      }
    }

    Widget targetScreen;
    switch (shortcutType) {
      case 'action_voice':
        targetScreen = const VoiceCaptureScreen();
        break;
      case 'action_photo':
        targetScreen = const PhotoCaptureScreen();
        break;
      case 'action_thought':
      default:
        targetScreen = const TextCaptureScreen();
        break;
    }

    nav.push(DuskPageRoute.modalSheet(builder: (_) => targetScreen));
  }

  /// Call this from DuskApp after the first frame renders to dispatch any queued shares or widget taps
  void handleQueuedIngress() {
    final hasQueuedFiles =
        _queuedSharedFiles != null && _queuedSharedFiles!.isNotEmpty;
    final hasQueuedNative =
        _queuedNativeFiles != null && _queuedNativeFiles!.isNotEmpty;
    final hasQueuedText =
        _queuedExtraText != null && _queuedExtraText!.trim().isNotEmpty;

    if (hasQueuedFiles || hasQueuedNative || hasQueuedText) {
      final navContext = navigatorKey.currentContext;
      if (navContext != null) {
        final files = _queuedSharedFiles ?? const <SharedMediaFile>[];
        final extraText = _queuedExtraText;
        final extraSubject = _queuedExtraSubject;
        final nativeFiles = _queuedNativeFiles;
        _queuedSharedFiles = null;
        _queuedExtraText = null;
        _queuedExtraSubject = null;
        _queuedNativeFiles = null;
        QuickShareModal.show(
          navContext,
          files,
          extraText: extraText,
          extraSubject: extraSubject,
          nativeSharedFiles: nativeFiles,
        );
      }
    }

    if (_queuedWidgetUri != null) {
      final uri = _queuedWidgetUri!;
      _queuedWidgetUri = null;
      _handleWidgetUri(uri);
    }
  }
}
