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
import 'package:provider/provider.dart';
import 'providers/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  await NotificationService().init();
  await QuickCaptureService().init();

  await Supabase.initialize(
    url: 'https://cslpsosodlqsinmkhygn.supabase.co',
    publishableKey: 'sb_publishable_Khn9kIa-3nh27iSxlOWhoQ__gzkFLsV',
  );

  final prefs = await SharedPreferences.getInstance();
  final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: DuskApp(hasSeenOnboarding: hasSeenOnboarding),
    ),
  );
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class DuskApp extends StatefulWidget {
  final bool hasSeenOnboarding;
  
  const DuskApp({super.key, required this.hasSeenOnboarding});

  @override
  State<DuskApp> createState() => _DuskAppState();
}

class _DuskAppState extends State<DuskApp> {
  @override
  void initState() {
    super.initState();
    // After the first frame is painted, check if we launched from a notification or quick ingress
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().handleLaunchNotification();
      QuickCaptureService().handleQueuedIngress();
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget initialScreen;
    if (!widget.hasSeenOnboarding) {
      initialScreen = const OnboardingScreen();
    } else if (SupabaseService().currentUser == null) {
      initialScreen = const AuthScreen();
    } else {
      initialScreen = const HomeScreen();
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFFF9F7F2),
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Dusk',
        theme: AppTheme.lightTheme,
        home: initialScreen,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

