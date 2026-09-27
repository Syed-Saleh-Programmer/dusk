import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../services/reflection_service.dart';
import '../../models/reflection_session.dart';
import 'reflection_flow_screen.dart';
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
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F2),
      body: DuskAmbientBackground(
        child: SafeArea(
          child: _isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF7A1A)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        "Synthesizing your daily captures...",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1B1A19),
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
                            const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFFF7A1A)),
                            const SizedBox(height: 16),
                            const Text(
                              "Could not synthesize reflection",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B1A19)),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _error!,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF8E8880)),
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
                                    backgroundColor: const Color(0xFFFF7A1A),
                                    foregroundColor: Colors.white,
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
                          const Text(
                            "Here is what defined your day.",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1B1A19),
                              letterSpacing: -0.3,
                            ),
                          ).animate().fade().slideY(begin: -0.1),
                          const SizedBox(height: 8),
                          const Text(
                            "AI synthesis of your thoughts, voice memos, and moments.",
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6E6862),
                            ),
                          ).animate().fade(delay: 100.ms),
                          const SizedBox(height: 20),
                          
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Container(
                                padding: const EdgeInsets.all(22),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: const Color(0xFFF0EBE1)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: MarkdownBody(
                                  data: _session?.generatedSummary?.trim().isNotEmpty == true 
                                    ? _session!.generatedSummary! 
                                    : "Take a quiet moment to look back on your day and center your thoughts before tomorrow.",
                                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                                    p: const TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF2C2825),
                                      height: 1.65,
                                    ),
                                    strong: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1B1A19),
                                    ),
                                  ),
                                ),
                              ).animate().fade(delay: 200.ms).slideY(begin: 0.05),
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          DuskPrimaryButton(
                            label: "Continue to Guided Questions",
                            icon: Icons.arrow_forward_rounded,
                            onPressed: () {
                              if (_session != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
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
