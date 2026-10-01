import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/dusk_ui_components.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  Widget _buildPrivacyCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String badgeText,
    required DuskBadgeVariant badgeVariant,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEDE6DA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1B1A19),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DuskPillBadge(
                      text: badgeText,
                      variant: badgeVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6E6862),
                    height: 1.45,
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
      backgroundColor: const Color(0xFFF9F7F2),
      body: DuskAmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    DuskCircleButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      size: 38,
                      iconSize: 17,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'Privacy & Security',
                        style: TextStyle(
                          fontSize: 17.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1B1A19),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your thoughts,\nkept private.',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1B1A19),
                          letterSpacing: -0.5,
                          height: 1.2,
                        ),
                      ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05),
                      const SizedBox(height: 8),
                      const Text(
                        'We believe your personal reflections should remain yours alone. Here is how Dusk protects and handles your data.',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF88827A),
                          height: 1.45,
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 80.ms, duration: 350.ms)
                          .slideY(begin: 0.05),
                      const SizedBox(height: 24),
                      _buildPrivacyCard(
                        icon: Icons.lock_outline_rounded,
                        iconColor: const Color(0xFFFF7A1A),
                        iconBg: const Color(0xFFFDE8D7),
                        badgeText: 'Isolated',
                        badgeVariant: DuskBadgeVariant.peach,
                        title: 'End-to-End Principles',
                        description:
                            'While synced to our cloud for cross-device continuity and AI synthesis, your captures are isolated in strict row-level security containers. We never sell or share your data.',
                      )
                          .animate()
                          .fadeIn(delay: 140.ms, duration: 350.ms)
                          .slideY(begin: 0.05),
                      _buildPrivacyCard(
                        icon: Icons.auto_awesome_outlined,
                        iconColor: const Color(0xFF4A84D8),
                        iconBg: const Color(0xFFE8F1FC),
                        badgeText: 'Zero Training',
                        badgeVariant: DuskBadgeVariant.blue,
                        title: 'Private AI Processing',
                        description:
                            'We use secure enterprise APIs for transcription and reflection synthesis. Your journal entries and voice memos are never used to train public AI models.',
                      )
                          .animate()
                          .fadeIn(delay: 200.ms, duration: 350.ms)
                          .slideY(begin: 0.05),
                      _buildPrivacyCard(
                        icon: Icons.verified_user_outlined,
                        iconColor: const Color(0xFF2DC48D),
                        iconBg: const Color(0xFFE4F5EE),
                        badgeText: 'Full Control',
                        badgeVariant: DuskBadgeVariant.green,
                        title: 'Right to Forget',
                        description:
                            'You own everything you capture. Export your complete archive or permanently purge your account and all cloud records at any time.',
                      )
                          .animate()
                          .fadeIn(delay: 260.ms, duration: 350.ms)
                          .slideY(begin: 0.05),
                      const SizedBox(height: 18),
                      DuskPrimaryButton(
                        label: 'Request Full Data Export',
                        icon: Icons.download_rounded,
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Gathering your archive. A download link will be emailed shortly.',
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: const Color(0xFF1B1A19),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              margin: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                            ),
                          );
                        },
                      ).animate().fadeIn(delay: 320.ms, duration: 350.ms),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () => _showDeleteConfirmation(context),
                          icon: const Icon(
                            Icons.delete_forever_rounded,
                            size: 19,
                          ),
                          label: const Text(
                            'Delete Account & Purge Data',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            foregroundColor: const Color(0xFFD9383A),
                          ),
                        ),
                      ).animate().fadeIn(delay: 360.ms, duration: 350.ms),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Delete Account?',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF1B1A19),
          ),
        ),
        content: const Text(
          'This will permanently delete your account, all your journal entries, photos, voice memos, and insight cards from our servers.\n\nThis action cannot be undone.',
          style: TextStyle(
            color: Color(0xFF6E6862),
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF6E6862),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Account deletion initiated. You have been signed out.',
                  ),
                ),
              );
              Future.delayed(const Duration(seconds: 1), () {
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              });
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFD9383A),
            ),
            child: const Text(
              'Delete Permanently',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
