import 'dart:async';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../main.dart';
import '../ui/screens/text_capture_screen.dart';
import '../ui/screens/voice_capture_screen.dart';
import '../ui/screens/photo_capture_screen.dart';
import '../ui/widgets/quick_share_modal.dart';

class QuickCaptureService {
  static final QuickCaptureService _instance = QuickCaptureService._internal();
  factory QuickCaptureService() => _instance;
  QuickCaptureService._internal();

  StreamSubscription<List<SharedMediaFile>>? _intentDataStreamSubscription;
  final QuickActions _quickActions = const QuickActions();
  bool _isInitialized = false;

  List<SharedMediaFile>? _queuedSharedFiles;
  Uri? _queuedWidgetUri;

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
      _quickActions.initialize((shortcutType) {
        _handleCaptureRoute(shortcutType);
      });

      _quickActions.setShortcutItems([
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
      ]);
    } catch (e) {
      debugPrint('Failed to initialize quick_actions: $e');
    }
  }

  // ==========================================
  // 2. System Share Sheet Receiver
  // ==========================================
  void _setupShareReceiver() {
    // A. For listening to shares while app is in memory (running / backgrounded)
    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> value) {
        if (value.isNotEmpty) {
          _handleIncomingShare(value);
        }
      },
      onError: (err) {
        debugPrint('getIntentDataStream error: $err');
      },
    );

    // B. For shares that cold-launched the app
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _handleIncomingShare(value);
        ReceiveSharingIntent.instance.reset();
      }
    }).catchError((err) {
      debugPrint('getInitialMedia error: $err');
    });
  }

  void _handleIncomingShare(List<SharedMediaFile> files) {
    if (files.isEmpty) return;

    final navContext = navigatorKey.currentContext;
    if (navContext != null) {
      QuickShareModal.show(navContext, files);
    } else {
      _queuedSharedFiles = files;
    }
  }

  // ==========================================
  // 3. Home Screen Interactive Widget
  // ==========================================
  void _setupHomeWidget() {
    try {
      // Listen for widget clicks while app is open / paused
      HomeWidget.widgetClicked.listen((Uri? uri) {
        if (uri != null) {
          _handleWidgetUri(uri);
        }
      });

      // Handle widget click that launched app from cold start
      HomeWidget.initiallyLaunchedFromHomeWidget().then((Uri? uri) {
        if (uri != null) {
          _handleWidgetUri(uri);
        }
      });
    } catch (e) {
      debugPrint('Failed to initialize home_widget: $e');
    }
  }

  void _handleWidgetUri(Uri uri) {
    debugPrint('HomeWidget clicked with URI: $uri');
    final host = uri.host; // e.g. "capture"
    final path = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';

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

  /// Updates data for Android AppWidget and triggers RemoteViews refresh
  Future<void> updateWidgetData({required int dumpCount}) async {
    try {
      await HomeWidget.saveWidgetData<int>('dump_count', dumpCount);
      await HomeWidget.updateWidget(
        name: 'DuskQuickCaptureWidgetProvider',
        androidName: 'DuskQuickCaptureWidgetProvider',
      );
    } catch (e) {
      debugPrint('Error updating home widget data: $e');
    }
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

    nav.push(MaterialPageRoute(builder: (_) => targetScreen));
  }

  /// Call this from DuskApp after the first frame renders to dispatch any queued shares or widget taps
  void handleQueuedIngress() {
    if (_queuedSharedFiles != null && _queuedSharedFiles!.isNotEmpty) {
      final navContext = navigatorKey.currentContext;
      if (navContext != null) {
        QuickShareModal.show(navContext, _queuedSharedFiles!);
        _queuedSharedFiles = null;
      }
    }

    if (_queuedWidgetUri != null) {
      _handleWidgetUri(_queuedWidgetUri!);
      _queuedWidgetUri = null;
    }
  }
}
