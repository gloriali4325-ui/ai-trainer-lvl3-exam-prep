import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai_coach/models/mistake_record.dart';
import 'package:ai_coach/models/question.dart';
import 'package:ai_coach/services/mistake_notebook_service.dart';
import 'package:ai_coach/services/question_bank_service.dart';
import 'package:ai_coach/widgets/question_card.dart';
import 'package:ai_coach/theme.dart';

class MistakeReinforcementScreen extends StatefulWidget {
  final List<MistakeRecord> mistakes;

  const MistakeReinforcementScreen({super.key, required this.mistakes});

  @override
  State<MistakeReinforcementScreen> createState() => _MistakeReinforcementScreenState();
}

class _ReinforcementItem {
  final MistakeRecord mistake;
  final Question question;

  _ReinforcementItem({
    required this.mistake,
    required this.question,
  });
}

class _MistakeReinforcementScreenState extends State<MistakeReinforcementScreen> {
  final List<_ReinforcementItem> _items = [];
  int _currentIndex = 0;
  dynamic _selectedAnswer;
  bool _showExplanation = false;

  @override
  void initState() {
    super.initState();
    _buildItems();
  }

  void _buildItems() {
    final questionService = context.read<QuestionBankService>();
    _items.clear();
    for (final mistake in widget.mistakes) {
      final question = questionService.getQuestionById(mistake.questionId);
      if (question != null) {
        _items.add(_ReinforcementItem(mistake: mistake, question: question));
      }
    }
    if (_items.isNotEmpty) {
      _selectedAnswer = null;
      _showExplanation = false;
    }
  }

  bool _isAnswerProvided(dynamic answer) {
    if (answer == null) return false;
    if (answer is String) return answer.trim().isNotEmpty;
    if (answer is List) return answer.isNotEmpty;
    return true;
  }

  Future<void> _submitAnswer() async {
    if (!_isAnswerProvided(_selectedAnswer)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择或填写答案')),
      );
      return;
    }

    final item = _items[_currentIndex];
    final isCorrect = item.question.checkAnswer(_selectedAnswer);

    final mistakeService = context.read<MistakeNotebookService>();
    await mistakeService.recordReviewAttempt(
      mistakeId: item.mistake.id,
      userAnswer: _selectedAnswer,
      isCorrect: isCorrect,
    );

    setState(() {
      _showExplanation = true;
    });
  }

  void _nextQuestion() {
    if (_currentIndex < _items.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedAnswer = null;
        _showExplanation = false;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('强化练习')),
        body: const Center(child: Text('暂无可强化的错题')),
      );
    }

    final item = _items[_currentIndex];
    final question = item.question;
    final isLast = _currentIndex == _items.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('强化练习'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: QuestionCard(
                question: question,
                questionNumber: _currentIndex + 1,
                selectedAnswer: _selectedAnswer,
                onAnswerSelected: (answer) {
                  if (!_showExplanation) {
                    setState(() {
                      _selectedAnswer = answer;
                    });
                  }
                },
                showExplanation: _showExplanation,
              ),
            ),
          ),
          Container(
            padding: AppSpacing.paddingMd,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Text(
                    '${_currentIndex + 1} / ${_items.length}',
                    style: context.textStyles.bodyMedium?.semiBold,
                  ),
                  const Spacer(),
                  if (!_showExplanation)
                    FilledButton.icon(
                      onPressed: _submitAnswer,
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text('提交', style: TextStyle(color: Colors.white)),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _nextQuestion,
                      icon: const Icon(Icons.arrow_forward, color: Colors.white),
                      label: Text(
                        isLast ? '完成' : '下一题',
                        style: const TextStyle(color: Colors.white),
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
}
