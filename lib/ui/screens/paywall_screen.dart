import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/dusk_ui_components.dart';

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  Widget _buildFeatureRow(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFFFF7A1A), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: const Color(0xFF1B1A19),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
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
                // Top Bar with seamless background matching the rest of the screen
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
                      Text(
                        'Unlock deep\nclarity with Pro.',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1B1A19),
                          letterSpacing: -0.5,
                          height: 1.2,
                        ),
                      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),
                const SizedBox(height: 28),
                
                _buildFeatureRow(context, 'Unlimited AI insight generation').animate().fadeIn(delay: 200.ms),
                _buildFeatureRow(context, 'Advanced context over past 30 days').animate().fadeIn(delay: 300.ms),
                _buildFeatureRow(context, 'Export reflections to beautiful PDFs').animate().fadeIn(delay: 400.ms),
                _buildFeatureRow(context, 'Custom scheduled reflection prompts').animate().fadeIn(delay: 500.ms),
                
                const SizedBox(height: 32),
                
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFF7A1A), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF7A1A).withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Annual Plan',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1B1A19),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '\$39.99 / year (7-day free trial)',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF88827A),
                            ),
                          ),
                        ],
                      ),
                      const Icon(Icons.check_circle_rounded, color: Color(0xFFFF7A1A), size: 24),
                    ],
                  ),
                ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1),
                
                const SizedBox(height: 24),
                
                DuskPrimaryButton(
                  label: 'Subscribe & Unlock',
                  icon: Icons.auto_awesome_rounded,
                  onPressed: () {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Pro unlocked (Simulation)')),
                    );
                  },
                ).animate().fadeIn(delay: 800.ms),
                
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () {},
                    child: const Text(
                      'Restore Purchases',
                      style: TextStyle(color: Color(0xFF88827A), fontWeight: FontWeight.w500),
                    ),
                  ),
                ).animate().fadeIn(delay: 1000.ms),
                    const SizedBox(height: 16),
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
