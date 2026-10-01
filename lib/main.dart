import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ui/theme/app_theme.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/screens/auth_screen.dart';
import 'services/supabase_service.dart';
import 'services/notification_service.dart';
import 'services/quick_capture_service.dart';
import 'services/subscription_service.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Catch unhandled errors gracefully in release mode to prevent white-screen crashes
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('⚠️ FlutterError caught: ${details.exceptionAsString()}');
  };

  // Set system UI overlay (status bar & system navigation bar colors)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFFF9F7F2), // Matches Dusk canvas / app navbar background
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize background notification service safely
  try {
    await NotificationService().init();
  } catch (e, stack) {
    debugPrint('⚠️ NotificationService init failed: $e\n$stack');
  }

  // Initialize quick capture and app shortcuts safely
  try {
    await QuickCaptureService().init();
  } catch (e, stack) {
    debugPrint('⚠️ QuickCaptureService init failed: $e\n$stack');
  }

  // Initialize Supabase client safely
  try {
    await Supabase.initialize(
      url: 'https://cslpsosodlqsinmkhygn.supabase.co',
      publishableKey: 'sb_publishable_Khn9kIa-3nh27iSxlOWhoQ__gzkFLsV',
    );
  } catch (e, stack) {
    debugPrint('⚠️ Supabase.initialize failed: $e\n$stack');
  }

  // Initialize RevenueCat subscription service safely
  try {
    await SubscriptionService().initialize(
      userId: SupabaseService().currentUser?.id,
    );
  } catch (e, stack) {
    debugPrint('⚠️ SubscriptionService.initialize failed: $e\n$stack');
  }

  bool hasSeenOnboarding = false;
  bool hasChosenGuestMode = false;
  try {
    final prefs = await SharedPreferences.getInstance();
    hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;
    hasChosenGuestMode = prefs.getBool('hasChosenGuestMode') ?? false;
    final currentUid = SupabaseService().currentUser?.id;
    final savedThemeId = (currentUid != null && currentUid.isNotEmpty)
        ? (prefs.getString('${AppState.colorThemePrefKey}_$currentUid') ??
            prefs.getString(AppState.colorThemePrefKey))
        : prefs.getString(AppState.colorThemePrefKey);
    AppTheme.setActiveTheme(AppColorThemeId.fromId(savedThemeId));
  } catch (e, stack) {
    debugPrint('⚠️ SharedPreferences initialization failed: $e\n$stack');
  }

  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.backgroundColor,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: DuskApp(
        hasSeenOnboarding: hasSeenOnboarding,
        hasChosenGuestMode: hasChosenGuestMode,
      ),
    ),
  );
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class DuskApp extends StatefulWidget {
  final bool hasSeenOnboarding;
  final bool hasChosenGuestMode;

  const DuskApp({
    super.key,
    required this.hasSeenOnboarding,
    required this.hasChosenGuestMode,
  });

  @override
  State<DuskApp> createState() => _DuskAppState();
}

class _DuskAppState extends State<DuskApp> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // After the first frame is painted, check if we launched from a notification or quick ingress
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().handleLaunchNotification();
      QuickCaptureService().handleQueuedIngress();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorTheme = context.select<AppState, AppColorThemeId>(
      (state) => state.colorTheme,
    );
    AppTheme.setActiveTheme(colorTheme);
    final palette = colorTheme.palette;

    Widget initialScreen;
    if (!widget.hasSeenOnboarding) {
      initialScreen = const OnboardingScreen();
    } else if (SupabaseService().currentUser != null || widget.hasChosenGuestMode) {
      initialScreen = const HomeScreen();
    } else {
      initialScreen = const AuthScreen();
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: palette.background,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Dusk',
        theme: AppTheme.themeFor(colorTheme),
        themeAnimationDuration: const Duration(milliseconds: 220),
        themeAnimationCurve: Curves.easeOutCubic,
        builder: (context, child) => _ThemeRebuildScope(
          colorTheme: colorTheme,
          child: child ?? const SizedBox.shrink(),
        ),
        onGenerateRoute: (settings) => DuskPageRoute(
          settings: settings,
          builder: (_) => initialScreen,
        ),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

/// Ensures every mounted screen and custom widget in the navigation tree rebuilds
/// immediately when the active [AppColorThemeId] changes, while preserving navigation
/// history and scroll positions.
class _ThemeRebuildScope extends StatefulWidget {
  final AppColorThemeId colorTheme;
  final Widget child;

  const _ThemeRebuildScope({
    required this.colorTheme,
    required this.child,
  });

  @override
  State<_ThemeRebuildScope> createState() => _ThemeRebuildScopeState();
}

class _ThemeRebuildScopeState extends State<_ThemeRebuildScope> {
  @override
  void didUpdateWidget(covariant _ThemeRebuildScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.colorTheme != widget.colorTheme) {
      AppTheme.setActiveTheme(widget.colorTheme);
      void rebuildDescendants(Element element) {
        element.markNeedsBuild();
        element.visitChildren(rebuildDescendants);
      }

      (context as Element).visitChildren(rebuildDescendants);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}


