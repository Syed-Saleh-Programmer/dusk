import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ui/theme/app_theme.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/auth_screen.dart';
import 'services/supabase_service.dart';

import 'services/notification_service.dart';

import 'package:provider/provider.dart';
import 'providers/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService().init();

  await Supabase.initialize(
    url: 'https://cslpsosodlqsinmkhygn.supabase.co',
    publishableKey: 'sb_publishable_Khn9kIa-3nh27iSxlOWhoQ__gzkFLsV',
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: const DuskApp(),
    ),
  );
}

class DuskApp extends StatelessWidget {
  const DuskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dusk',
      theme: AppTheme.lightTheme,
      home: SupabaseService().currentUser == null ? const AuthScreen() : const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
