import 'package:flutter/material.dart';
import '../../models/reflection_session.dart';
import '../../services/reflection_service.dart';
import '../../services/supabase_service.dart';
import 'reflection_processing_screen.dart';
import 'voice_reflection_answer_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/dusk_ui_components.dart';

class ReflectionFlowScreen extends StatefulWidget {
  final ReflectionSession session;
  final String? cycleId; // for backward compatibility

  const ReflectionFlowScreen({
    super.key,
    required this.session,
    this.cycleId,
  });

  @override
  State<ReflectionFlowScreen> createState() => _ReflectionFlowScreenState();
}

class _ReflectionFlowScreenState extends State<ReflectionFlowScreen> {
  final ReflectionService _reflectionService = ReflectionService();
  
  bool _isLoading = true;
  String _loadingMessage = 'Crafting thoughtful questions from your past 7 days...';
  
  List<ReflectionQuestion> _questions = [];
  final List<ReflectionAnswer> _answers = [];
  
  int _currentQuestionIndex = 0;
  final TextEditingController _answerController = TextEditingController();

  String? _actualSessionId;

  @override
  void initState() {
    super.initState();
    _initFlow();
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _initFlow() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Crafting 10 thoughtful questions from your past 7 days...';
    });

    try {
      final actualCycleId = widget.cycleId ?? widget.session.cycleId;
      final questions = await _reflectionService.generateQuestions(
        widget.session.id,
        cycleId: actualCycleId,
      );

      if (mounted) {
        setState(() {
          _questions = questions;
          if (questions.isNotEmpty) {
            _actualSessionId = questions.first.sessionId;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error starting reflection flow: $e');
      if (mounted) {
        final fallbackTexts = [
          'Looking back across the past 7 days, what single moment or achievement brought you the most genuine fulfillment?',
          'Which of your pending goals or tasks feels most important right now, and what is holding you back from completing it?',
          'Connecting your recent notes and thoughts, what recurring pattern or emotion have you noticed showing up most often?',
          'What was a hidden win or subtle progress you made recently that you haven’t given yourself enough credit for?',
          'If you look at the challenges you navigated over the past week, what key lesson stands out?',
          'How well have your daily actions aligned with your core priorities and personal values this week?',
          'What project, task, or thought has been taking up unnecessary space in your mind, and how can you let it go?',
          'Who or what inspired you most recently, and how did it influence your mindset?',
          'What is one small boundary or habit change that would give you more energy and clarity starting tomorrow?',
          'Looking ahead, what is your single primary intention or focus for the upcoming days?',
        ];
        setState(() {
          _questions = List.generate(
            fallbackTexts.length,
            (idx) => ReflectionQuestion(
              id: 'default_q${idx + 1}',
              sessionId: widget.session.id,
              position: idx + 1,
              questionText: fallbackTexts[idx],
              createdAt: DateTime.now(),
            ),
          );
          _isLoading = false;
        });
      }
    }
  }

  void _saveCurrentAnswerIfAny() {
    final text = _answerController.text.trim();
    if (text.isNotEmpty) {
      final currentQ = _questions[_currentQuestionIndex];
      final answer = ReflectionAnswer(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        questionId: currentQ.id,
        userId: SupabaseService().currentUser?.id ?? 'unknown',
        answerType: AnswerType.text,
        answerText: text,
        createdAt: DateTime.now(),
      );
      _answers.add(answer);
      _answerController.clear();
    }
  }

  void _submitAnswer() {
    final text = _answerController.text.trim();
    if (text.isEmpty) {
      _skipQuestion();
      return;
    }

    _saveCurrentAnswerIfAny();

    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    } else {
      _finishReflection();
    }
  }

  void _skipQuestion() {
    final currentQ = _questions[_currentQuestionIndex];
    final answer = ReflectionAnswer(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      questionId: currentQ.id,
      userId: SupabaseService().currentUser?.id ?? 'unknown',
      answerType: AnswerType.text,
      answerText: 'Skipped reflection prompt.',
      createdAt: DateTime.now(),
    );
    _answers.add(answer);
    _answerController.clear();

    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    } else {
      _finishReflection();
    }
  }

  void _finishEarly() {
    _saveCurrentAnswerIfAny();
    _finishReflection();
  }

  void _finishReflection() {
    final targetSessionId = _actualSessionId ?? widget.session.id;
    Navigator.of(context).pushReplacement(
      DuskPageRoute.ritual(
        builder: (_) => ReflectionProcessingScreen(
          sessionId: targetSessionId,
          answers: _answers,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: p.background,
        body: DuskAmbientBackground(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(p.primary),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _loadingMessage,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: p.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_questions.isEmpty && !_isLoading) {
      return Scaffold(
        backgroundColor: p.background,
        body: DuskAmbientBackground(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'No questions available.',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: p.onSurface),
                ),
                const SizedBox(height: 16),
                DuskCircleButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final question = _questions[_currentQuestionIndex];
    final isLastQuestion = _currentQuestionIndex == _questions.length - 1;

    return Scaffold(
      backgroundColor: p.background,
      resizeToAvoidBottomInset: true,
      body: DuskAmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Top Header Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    DuskCircleButton(
                      icon: Icons.close_rounded,
                      size: 40,
                      iconSize: 18,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    DuskPillBadge(
                      text: 'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                      variant: DuskBadgeVariant.peach,
                    ),
                    TextButton.icon(
                      onPressed: _finishEarly,
                      icon: Icon(Icons.check_circle_outline_rounded, size: 16, color: p.primary),
                      label: Text(
                        'Summary',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: p.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable content area with 3D perspective question step transition
              Expanded(
                child: DuskStepCardTransition(
                  stepIndex: _currentQuestionIndex,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          question.questionText,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: p.onSurface,
                            letterSpacing: -0.3,
                            height: 1.35,
                          ),
                        ),

                        const SizedBox(height: 16),

                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(minHeight: 180),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: p.surface,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: p.outline),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                            controller: _answerController,
                            maxLines: null,
                            minLines: 6,
                            keyboardType: TextInputType.multiline,
                            style: TextStyle(
                              fontSize: 15.5,
                              color: p.onSurface,
                              height: 1.55,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Tap to write your reflection...',
                              hintStyle: TextStyle(
                                color: p.onSurfaceVariant,
                                fontSize: 15,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              filled: false,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Material(
                              color: p.primarySoftBg,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () async {
                                  final transcript = await Navigator.of(context).push<String>(
                                    DuskPageRoute.modalSheet(
                                      builder: (_) => VoiceReflectionAnswerScreen(
                                        questionText: question.questionText,
                                      ),
                                    ),
                                  );
                                  if (transcript != null && transcript.isNotEmpty && mounted) {
                                    setState(() {
                                      if (_answerController.text.trim().isEmpty) {
                                        _answerController.text = transcript;
                                      } else {
                                        _answerController.text =
                                            '${_answerController.text.trim()}\n\n$transcript';
                                      }
                                    });
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.mic_rounded, size: 16, color: p.primary),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Speak Answer',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: p.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                        const SizedBox(height: 14),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: TextButton.icon(
                                onPressed: _finishEarly,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: Icon(Icons.summarize_outlined, size: 16, color: p.secondary),
                                label: Text(
                                  'End & View Summary',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: p.secondary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: _skipQuestion,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Skip question',
                                maxLines: 1,
                                style: TextStyle(
                                  color: p.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        DuskPrimaryButton(
                          label: isLastQuestion ? 'Finish & View Summary' : 'Next Question',
                          icon: isLastQuestion ? Icons.check_circle_outline_rounded : Icons.arrow_forward_rounded,
                          onPressed: _submitAnswer,
                        ),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
