import 'package:flutter/material.dart';
import '../../models/reflection_session.dart';
import '../../services/reflection_service.dart';
import '../../services/supabase_service.dart';
import 'voice_reflection_answer_screen.dart';
import 'reflection_processing_screen.dart';
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
  String _loadingMessage = 'Crafting thoughtful questions...';
  
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
      _loadingMessage = 'Crafting thoughtful questions...';
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
        setState(() {
          _questions = [
            ReflectionQuestion(
              id: 'default_q1',
              sessionId: widget.session.id,
              position: 1,
              questionText: 'What was the most meaningful or memorable moment of your day?',
              createdAt: DateTime.now(),
            ),
            ReflectionQuestion(
              id: 'default_q2',
              sessionId: widget.session.id,
              position: 2,
              questionText: 'What is something you learned, navigated, or want to let go of today?',
              createdAt: DateTime.now(),
            ),
            ReflectionQuestion(
              id: 'default_q3',
              sessionId: widget.session.id,
              position: 3,
              questionText: 'What is your primary intention, priority, or mindset focus for tomorrow?',
              createdAt: DateTime.now(),
            ),
          ];
          _isLoading = false;
        });
      }
    }
  }

  void _submitAnswer() {
    final text = _answerController.text.trim();
    if (text.isEmpty) {
      _skipQuestion();
      return;
    }

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

  void _finishReflection() {
    final targetSessionId = _actualSessionId ?? widget.session.id;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ReflectionProcessingScreen(
          sessionId: targetSessionId,
          answers: _answers,
        ),
      ),
    );
  }

  void _openVoiceAnswer() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: VoiceReflectionAnswerScreen(
          questionText: _questions[_currentQuestionIndex].questionText,
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      final answer = ReflectionAnswer(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        questionId: _questions[_currentQuestionIndex].id,
        userId: SupabaseService().currentUser?.id ?? 'unknown',
        answerType: AnswerType.voice,
        transcript: result,
        createdAt: DateTime.now(),
      );
      _answers.add(answer);
      
      if (_currentQuestionIndex < _questions.length - 1) {
        setState(() {
          _currentQuestionIndex++;
        });
      } else {
        _finishReflection();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF9F7F2),
        body: DuskAmbientBackground(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF7A1A)),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _loadingMessage,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1B1A19),
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
        backgroundColor: const Color(0xFFF9F7F2),
        body: DuskAmbientBackground(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'No questions available.',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1B1A19)),
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
      backgroundColor: const Color(0xFFF9F7F2),
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
                    const SizedBox(width: 40),
                  ],
                ),
              ),

              // Scrollable content area
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        question.questionText,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1B1A19),
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
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFECE7DE)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _answerController,
                          maxLines: null,
                          minLines: 6,
                          keyboardType: TextInputType.multiline,
                          style: const TextStyle(
                            fontSize: 15.5,
                            color: Color(0xFF1B1A19),
                            height: 1.55,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Tap to start writing your reflection...',
                            hintStyle: TextStyle(
                              color: Color(0xFFAFA99E),
                              fontSize: 15,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            filled: false,
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      Row(
                        children: [
                          InkWell(
                            onTap: _openVoiceAnswer,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFECE7DE)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.mic_none_rounded, size: 18, color: Color(0xFF4A84D8)),
                                  SizedBox(width: 6),
                                  Text(
                                    'Voice Answer',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF4A84D8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: _skipQuestion,
                            child: const Text(
                              'Skip prompt',
                              style: TextStyle(
                                color: Color(0xFF88827A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      DuskPrimaryButton(
                        label: isLastQuestion ? 'Finish Reflection' : 'Next Question',
                        icon: isLastQuestion ? Icons.check_circle_outline_rounded : Icons.arrow_forward_rounded,
                        onPressed: _submitAnswer,
                      ),

                      const SizedBox(height: 16),
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
}
