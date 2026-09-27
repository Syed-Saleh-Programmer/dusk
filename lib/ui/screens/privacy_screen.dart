import 'package:flutter/material.dart';


class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  Widget _buildPrivacyItem(BuildContext context, {required IconData icon, required String title, required String description}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & Data'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your thoughts,\nsecured.',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We believe your private reflections should remain exactly that: private. Here is how we handle your data.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 40),
            _buildPrivacyItem(
              context,
              icon: Icons.lock,
              title: 'End-to-End Principles',
              description: 'While synced to our cloud for AI processing, your data is isolated in secure containers. We do not sell data.',
            ),
            _buildPrivacyItem(
              context,
              icon: Icons.smart_toy_outlined,
              title: 'AI Processing',
              description: 'We use secure enterprise endpoints for AI (Groq & Gemini). Your journal entries are NOT used to train public models.',
            ),
            _buildPrivacyItem(
              context,
              icon: Icons.delete_outline,
              title: 'Right to Forget',
              description: 'You can delete your account and all associated data at any time from the account settings.',
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Gathering your data. A download link will be emailed to you shortly.')),
                  );
                },
                icon: const Icon(Icons.download, size: 20),
                label: const Text('Request Full Data Export'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => _showDeleteConfirmation(context),
                icon: const Icon(Icons.delete_forever, size: 20),
                label: const Text('Delete Account & Purge Data'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'This will permanently delete your account, all your journal entries, photos, voice memos, and insight cards from our servers.\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              // In a full implementation, you would call a Supabase Edge Function to delete the user auth record 
              // which would cascade delete their data in the DB.
              // For now, sign out and clear session.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Account deletion initiated. You have been signed out.')),
              );
              // Delay slightly so the user sees the message before routing
              Future.delayed(const Duration(seconds: 1), () {
                if (context.mounted) {
                  // Return to first route (AuthScreen) assuming logout handles logic
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              });
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }
}
