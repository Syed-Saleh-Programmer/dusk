import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import 'auth_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          ListTile(
            title: const Text('Reflection Schedule'),
            subtitle: const Text('Configure when Dusk prompts you.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Implement schedule UI
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Subscription'),
            subtitle: const Text('Manage your Dusk Premium subscription.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Implement revenuecat integration
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Log Out'),
            textColor: Theme.of(context).colorScheme.error,
            onTap: () async {
              await SupabaseService().signOut();
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
    );
  }
}
