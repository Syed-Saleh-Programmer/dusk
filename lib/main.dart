import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ui/theme/app_theme.dart';
import 'ui/screens/home_screen.dart';

import 'services/notification_service.dart';

import 'package:provider/provider.dart';
import 'providers/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService().init();

  // TODO: Replace with real Supabase credentials
  await Supabase.initialize(
    url: 'https://placeholder-project-id.supabase.co',
    publishableKey: 'placeholder-anon-key',
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
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
