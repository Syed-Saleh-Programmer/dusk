import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../../services/reflection_service.dart';
import '../../models/reflection_session.dart';
import 'reflection_flow_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/dusk_ui_components.dart';

class AiCycleSummaryScreen extends StatefulWidget {
  final String cycleId;

  const AiCycleSummaryScreen({super.key, required this.cycleId});

  @override
  State<AiCycleSummaryScreen> createState() => _AiCycleSummaryScreenState();
}

class _AiCycleSummaryScreenState extends State<AiCycleSummaryScreen> {
  bool _isLoading = true;
  ReflectionSession? _session;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchSummary();
  }

  Future<void> _fetchSummary() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final session = await ReflectionService().generateSummary(widget.cycleId);
      if (mounted) {
        setState(() {
          _session = session;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);

    return Scaffold(
      backgroundColor: p.background,
      body: DuskAmbientBackground(
        child: SafeArea(
          child: _isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(p.primary),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "Synthesizing your daily captures...",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: p.onSurface,
                        ),
                      ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: 0.5, end: 1.0),
                    ],
                  ),
                )
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline_rounded, size: 48, color: p.primary),
                            const SizedBox(height: 16),
                            Text(
                              "Could not synthesize reflection",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: p.onSurface),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _error!,
                              style: TextStyle(fontSize: 13, color: p.onSurfaceVariant),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                OutlinedButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text("Go Back"),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed: _fetchSummary,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: p.primary,
                                    foregroundColor: p.onPrimary,
                                  ),
                                  child: const Text("Retry"),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              DuskCircleButton(
                                icon: Icons.close_rounded,
                                size: 40,
                                iconSize: 18,
                                onTap: () => Navigator.pop(context),
                              ),
                              const DuskPillBadge(
                                text: "Step 1 of 3: Recall",
                                variant: DuskBadgeVariant.peach,
                              ),
                              const SizedBox(width: 40),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "Here is what defined your day.",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: p.onSurface,
                              letterSpacing: -0.3,
                            ),
                          ).animate().fade().slideY(begin: -0.1),
                          const SizedBox(height: 8),
                          Text(
                            "AI synthesis of your thoughts, voice memos, and moments.",
                            style: TextStyle(
                              fontSize: 14,
                              color: p.onSurfaceVariant,
                            ),
                          ).animate().fade(delay: 100.ms),
                          const SizedBox(height: 20),
                          
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: p.surface,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: p.outline),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.all(22),
                                child: MarkdownBody(
                                  data: _session?.generatedSummary?.trim().isNotEmpty == true 
                                    ? _session!.generatedSummary! 
                                    : "Take a quiet moment to look back on your day and center your thoughts before tomorrow.",
                                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                                    p: TextStyle(
                                      fontSize: 16,
                                      color: p.onSurface,
                                      height: 1.65,
                                    ),
                                    strong: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: p.onSurface,
                                    ),
                                  ),
                                ),
                              ),
                            ).animate().fade(delay: 200.ms).slideY(begin: 0.05),
                          ),
                          
                          const SizedBox(height: 20),
                          DuskPrimaryButton(
                            label: "Continue to Guided Questions",
                            icon: Icons.arrow_forward_rounded,
                            onPressed: () {
                              if (_session != null) {
                                Navigator.push(
                                  context,
                                  DuskPageRoute.ritual(
                                    builder: (_) => ReflectionFlowScreen(
                                      session: _session!,
                                      cycleId: widget.cycleId,
                                    ),
                                  ),
                                );
                              }
                            },
                          ).animate().fade(delay: 350.ms).slideY(begin: 0.1),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }
}
