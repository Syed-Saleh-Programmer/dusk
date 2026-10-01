import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../services/subscription_service.dart';
import '../widgets/dusk_ui_components.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final SubscriptionService _subscription = SubscriptionService();
  int _selectedTierIndex = 0; // 0: Annual, 1: Monthly, 2: Lifetime
  bool _isPurchasing = false;
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    _subscription.refresh().then((_) {
      if (mounted) setState(() {});
    });
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: const Color(0xFFFDE8D7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFFFF7A1A), size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF1B1A19),
                  height: 1.25,
                ),
                children: [
                  TextSpan(
                    text: '$title  ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B1A19),
                    ),
                  ),
                  TextSpan(
                    text: subtitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF767068),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierCard({
    required int index,
    required String title,
    required String price,
    String? period,
    required String periodNote,
    String? badgeText,
    bool isPopular = false,
  }) {
    final isSelected = _selectedTierIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTierIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF9F5) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF7A1A) : const Color(0xFFE8E4DC),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFFFF7A1A).withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected ? const Color(0xFFFF7A1A) : const Color(0xFFA59F95),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1B1A19),
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (badgeText != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isPopular
                                ? const Color(0xFFFF7A1A)
                                : const Color(0xFF2E7D32),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText,
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    periodNote,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF88827A),
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  price,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B1A19),
                  ),
                ),
                if (period != null)
                  Text(
                    period,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF88827A),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePurchase() async {
    if (_isPurchasing) return;
    setState(() => _isPurchasing = true);

    try {
      if (_subscription.offerings?.current?.availablePackages == null) {
        await _subscription.refresh();
      }
      final packages = _subscription.offerings?.current?.availablePackages;
      if (packages != null && packages.isNotEmpty) {
        Package? selectedPkg;
        if (_selectedTierIndex == 0) {
          selectedPkg = packages.firstWhere(
            (p) => p.packageType == PackageType.annual,
            orElse: () => packages.first,
          );
        } else if (_selectedTierIndex == 1) {
          selectedPkg = packages.firstWhere(
            (p) => p.packageType == PackageType.monthly,
            orElse: () => packages.first,
          );
        } else {
          selectedPkg = packages.firstWhere(
            (p) => p.packageType == PackageType.lifetime,
            orElse: () => packages.last,
          );
        }

        final success = await _subscription.purchasePackage(selectedPkg);
        if (success && mounted) {
          Navigator.of(context).pop();
          showDuskSnackBar(
            context,
            content: const Text('✨ Dusk Pro unlocked successfully!'),
          );
          return;
        }
      } else {
        if (mounted) {
          if (!_subscription.isPurchasesConfigured) {
            showDuskSnackBar(
              context,
              content: const Text('Store billing is in offline mode for this build. You can test Pro features using the toggle below.'),
            );
          } else {
            showDuskSnackBar(
              context,
              content: const Text('Subscription store packages are loading. Please check your network connection and try again in a moment.'),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        showDuskSnackBar(
          context,
          content: Text('Purchase notice: $e'),
        );
      }
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  Future<void> _handleRestore() async {
    if (_isRestoring) return;
    setState(() => _isRestoring = true);
    try {
      final hasPro = await _subscription.restorePurchases();
      if (mounted) {
        if (hasPro) {
          Navigator.of(context).pop();
          showDuskSnackBar(
            context,
            content: const Text('Purchases successfully restored! Pro active.'),
          );
        } else {
          showDuskSnackBar(
            context,
            content: const Text('No active subscriptions found to restore.'),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showDuskSnackBar(
          context,
          content: Text('Restore notice: $e'),
        );
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFFF9F7F2),
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F7F2),
        body: DuskAmbientBackground(
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 20.0, top: 12.0, bottom: 4.0),
                  child: DuskCircleButton(
                    icon: Icons.close_rounded,
                    size: 40,
                    iconSize: 20,
                    tooltip: 'Close',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Unlock deep\nclarity with Pro.',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1B1A19),
                            letterSpacing: -0.5,
                            height: 1.15,
                          ),
                        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08),
                        const SizedBox(height: 6),
                        const Text(
                          'Choose the plan that fits your reflection practice.',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: Color(0xFF88827A),
                            fontWeight: FontWeight.w500,
                          ),
                        ).animate().fadeIn(delay: 100.ms),
                        const SizedBox(height: 18),

                        // Subscription Options (Annual, Monthly, Lifetime)
                        _buildTierCard(
                          index: 0,
                          title: 'Annual Plan',
                          price: '\$29.99',
                          period: '/ year',
                          periodNote: '7-day free trial, then \$2.49/mo',
                          badgeText: 'BEST VALUE',
                          isPopular: true,
                        ).animate().fadeIn(delay: 160.ms).slideY(begin: 0.06),

                        _buildTierCard(
                          index: 1,
                          title: 'Monthly Plan',
                          price: '\$3.99',
                          period: '/ month',
                          periodNote: 'Cancel anytime in store settings',
                          badgeText: 'FLEXIBLE',
                        ).animate().fadeIn(delay: 230.ms).slideY(begin: 0.06),

                        _buildTierCard(
                          index: 2,
                          title: 'Lifetime Pass',
                          price: '\$59.99',
                          period: 'one-time',
                          periodNote: 'Pay once, enjoy forever',
                          badgeText: 'FOUNDING',
                        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.06),

                        const SizedBox(height: 14),

                        // Concise Feature Highlights (Below Subscription Options)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFEAE6DE)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.stars_rounded, size: 16, color: Color(0xFFFF7A1A)),
                                  SizedBox(width: 6),
                                  Text(
                                    'EVERYTHING INCLUDED WITH PRO',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF88827A),
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildFeatureItem(
                                icon: Icons.all_inclusive_rounded,
                                title: 'Unlimited Captures',
                                subtitle: 'No daily limits (Free tier has 20/day)',
                              ),
                              _buildFeatureItem(
                                icon: Icons.mic_rounded,
                                title: '10-Min Voice Notes',
                                subtitle: 'Record up to 10 min (Free stops at 60s)',
                              ),
                              _buildFeatureItem(
                                icon: Icons.cloud_done_rounded,
                                title: 'Encrypted Cloud Sync',
                                subtitle: 'Multi-device backup via Supabase',
                              ),
                              _buildFeatureItem(
                                icon: Icons.auto_stories_rounded,
                                title: 'Lifetime Vault Archive',
                                subtitle: 'Full history & trends (Free is 14 days)',
                              ),
                              _buildFeatureItem(
                                icon: Icons.wb_twilight_rounded,
                                title: 'All Daily Rituals',
                                subtitle: 'Dawn, Shutdown & Dusk anytime',
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 370.ms),

                        const SizedBox(height: 18),

                        // Purchase Button
                        DuskPrimaryButton(
                          label: _isPurchasing
                              ? 'Processing...'
                              : _selectedTierIndex == 0
                                  ? 'Start 7-Day Free Trial'
                                  : _selectedTierIndex == 1
                                      ? 'Subscribe Monthly'
                                      : 'Unlock Lifetime Access',
                          icon: Icons.auto_awesome_rounded,
                          onPressed: _isPurchasing ? null : _handlePurchase,
                        ).animate().fadeIn(delay: 440.ms),

                        const SizedBox(height: 14),

                        // Restore Purchases
                        Center(
                          child: TextButton(
                            onPressed: _isRestoring ? null : _handleRestore,
                            child: Text(
                              _isRestoring ? 'Restoring...' : 'Restore Purchases',
                              style: const TextStyle(
                                color: Color(0xFF88827A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        // Demo / Tester Override Toggle for Shipathon
                        const SizedBox(height: 8),
                        ValueListenableBuilder<bool>(
                          valueListenable: _subscription.isProNotifier,
                          builder: (context, isPro, _) {
                            return Center(
                              child: GestureDetector(
                                onTap: () async {
                                  final newPro = await _subscription.toggleProForTesting();
                                  if (context.mounted) {
                                    showDuskSnackBar(
                                      context,
                                      content: Text(
                                        newPro
                                            ? '✨ Dusk Pro activated for testing!'
                                            : 'Dusk Pro deactivated.',
                                      ),
                                    );
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE2DED6)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isPro ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                                        size: 16,
                                        color: isPro ? const Color(0xFF2E7D32) : const Color(0xFF88827A),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        isPro
                                            ? 'Pro Status: Active (Tap to toggle)'
                                            : 'Pro Status: Inactive (Tap to toggle)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isPro ? const Color(0xFF2E7D32) : const Color(0xFF767068),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 18),
                        const Center(
                          child: Text(
                            'Subscriptions auto-renew unless cancelled at least 24h before renewal.\nTerms of Service & Privacy Policy apply.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFFA59F95),
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
