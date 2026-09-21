import 'package:flutter/material.dart';
import '../../models/reflection_session.dart';
import '../../models/insight_card.dart';
import '../../services/reflection_service.dart';

class ReflectionFlowScreen extends StatefulWidget {
  final String cycleId;
  const ReflectionFlowScreen({super.key, required this.cycleId});

  @override
  State<ReflectionFlowScreen> createState() => _ReflectionFlowScreenState();
}

class _ReflectionFlowScreenState extends State<ReflectionFlowScreen> {
  final ReflectionService _reflectionService = ReflectionService();
  
  bool _isLoading = true;
  String _loadingMessage = 'Preparing your reflection...';
  
  ReflectionSession? _session;
  List<ReflectionQuestion> _questions = [];
  final List<ReflectionAnswer> _answers = [];
  
  int _currentQuestionIndex = 0;
  final TextEditingController _answerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initFlow();
  }

  Future<void> _initFlow() async {
    try {
      final session = await _reflectionService.generateSummary(widget.cycleId);
      setState(() {
        _session = session;
        _loadingMessage = 'Generating questions...';
      });

      final questions = await _reflectionService.generateQuestions(session.id);
      setState(() {
        _questions = questions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _loadingMessage = 'Error starting reflection: \$e';
      });
    }
  }

  void _submitAnswer() {
    final text = _answerController.text.trim();
    if (text.isEmpty) return;

    final answer = ReflectionAnswer(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      questionId: _questions[_currentQuestionIndex].id,
      userId: 'local_user',
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
      _generateFinalInsight();
    }
  }

  Future<void> _generateFinalInsight() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Creating your insight card...';
    });

    try {
      final insight = await _reflectionService.generateInsightCard(_session!.id, _answers);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => InsightCardScreen(insight: insight)),
        );
      }
    } catch (e) {
      setState(() {
        _loadingMessage = 'Error generating insight: \$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(_loadingMessage, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      );
    }

    final question = _questions[_currentQuestionIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text('Question \${_currentQuestionIndex + 1} of \${_questions.length}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              question.questionText,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 32),
            Expanded(
              child: TextField(
                controller: _answerController,
                maxLines: null,
                expands: true,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: InputDecoration(
                  hintText: 'Type your answer here...',
                  hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  border: InputBorder.none,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: _submitAnswer,
              child: Text(_currentQuestionIndex == _questions.length - 1 ? 'Finish' : 'Next'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class InsightCardScreen extends StatelessWidget {
  final InsightCard insight;
  
  const InsightCardScreen({super.key, required this.insight});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Insight'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Theme.of(context).colorScheme.secondary),
          ),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Insight',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                insight.title,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 16),
              Text(
                insight.mainInsight,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              Text(
                'What Stood Out',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                insight.standout,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Text(
                'Gentle Suggestion',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                insight.suggestion,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
