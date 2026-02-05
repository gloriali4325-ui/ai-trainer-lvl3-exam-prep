import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ai_coach/models/question.dart';
import 'package:ai_coach/widgets/question_card.dart';
import 'package:ai_coach/theme.dart';

class ExamResultAnalysisScreen extends StatefulWidget {
  final List<Question> allQuestions;
  final Map<String, dynamic> answers;
  final Map<String, dynamic> questionResults;

  const ExamResultAnalysisScreen({
    super.key,
    required this.allQuestions,
    required this.answers,
    required this.questionResults,
  });

  @override
  State<ExamResultAnalysisScreen> createState() => _ExamResultAnalysisScreenState();
}

class _ExamResultAnalysisScreenState extends State<ExamResultAnalysisScreen> {
  late List<Question> _wrongQuestions;
  int _currentWrongIndex = 0;

  @override
  void initState() {
    super.initState();
    // 获取所有错误的题目
    _wrongQuestions = [];
    for (final question in widget.allQuestions) {
      final result = widget.questionResults[question.id];
      if (result != null && !result['correct']) {
        _wrongQuestions.add(question);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_wrongQuestions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('错题解析'),
        ),
        body: Center(
          child: Padding(
            padding: AppSpacing.paddingLg,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle,
                  size: 80,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
                AppSpacing.lg.verticalSpace,
                Text(
                  '恭喜！没有错题',
                  style: context.textStyles.headlineSmall?.bold,
                ),
                AppSpacing.md.verticalSpace,
                Text(
                  '你的表现非常出色',
                  style: context.textStyles.bodyMedium,
                ),
                AppSpacing.xl.verticalSpace,
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.home, color: Colors.white),
                    label: const Text('返回首页', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currentQuestion = _wrongQuestions[_currentWrongIndex];
    debugPrint('[ExamAnalysis] Current question ID: ${currentQuestion.id}, Type: ${currentQuestion.runtimeType}');
    debugPrint('[ExamAnalysis] Is TheoryQuestion: ${currentQuestion is TheoryQuestion}');
    debugPrint('[ExamAnalysis] Is CodeQuestion: ${currentQuestion is CodeQuestion}');
    if (currentQuestion is TheoryQuestion) {
      debugPrint('[ExamAnalysis] TheoryQuestion.correctAnswer = ${currentQuestion.correctAnswer}');
    }
    final userAnswer = widget.answers[currentQuestion.id];
    final questionNumber = widget.allQuestions.indexOf(currentQuestion) + 1;
    final resultStatus = _buildResultStatus(currentQuestion, userAnswer);
    final correctAnswerText = currentQuestion is TheoryQuestion
        ? _formatCorrectAnswer(currentQuestion)
        : currentQuestion is CodeQuestion
            ? _formatCodeAnswer(currentQuestion)
            : '无法获取正确答案';

    return Scaffold(
      appBar: AppBar(
        title: const Text('错题解析'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentWrongIndex + 1) / _wrongQuestions.length,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: AppSpacing.paddingMd,
              child: Column(
                children: [
                  // 错题标记
                  Container(
                    padding: AppSpacing.paddingMd,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.cancel,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        AppSpacing.md.horizontalSpace,
                        Text(
                          '第 $questionNumber 题（共 ${widget.allQuestions.length} 题 · 本次考试错题）',
                          style: context.textStyles.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.md.verticalSpace,
                  
                  // 题目展示
                  QuestionCard(
                    question: currentQuestion,
                    questionNumber: questionNumber,
                    selectedAnswer: userAnswer,
                    onAnswerSelected: (_) {},
                    showExplanation: true,
                    explanationOverride: _stripCorrectAnswerPrefix(currentQuestion.explanation),
                    readOnly: true,
                    correctAnswer: currentQuestion is TheoryQuestion ? currentQuestion.correctAnswer : null,
                    showResultSummary: true,
                    userAnswerText: _formatAnswer(userAnswer),
                    correctAnswerText: correctAnswerText,
                    resultStatusText: resultStatus,
                  ),
                  AppSpacing.md.verticalSpace,
                ],
              ),
            ),
          ),
          
          // 导航按钮
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
                  if (_currentWrongIndex > 0)
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _currentWrongIndex--;
                        });
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('上一个'),
                    ),
                  const Spacer(),
                  Text(
                    '${_currentWrongIndex + 1} / ${_wrongQuestions.length}',
                    style: context.textStyles.bodyMedium?.semiBold,
                  ),
                  const Spacer(),
                  if (_currentWrongIndex < _wrongQuestions.length - 1)
                    FilledButton.icon(
                      onPressed: () {
                        setState(() {
                          _currentWrongIndex++;
                        });
                      },
                      icon: const Icon(Icons.arrow_forward, color: Colors.white),
                      label: const Text('下一个', style: TextStyle(color: Colors.white)),
                    )
                  else
                    FilledButton.icon(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.home, color: Colors.white),
                      label: const Text('返回首页', style: TextStyle(color: Colors.white)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatAnswer(dynamic answer) {
    if (answer == null) {
      return '未作答';
    }
    if (answer is List) {
      return answer.join('、');
    }
    return answer.toString();
  }

  String _formatCorrectAnswer(dynamic question) {
    if (question is! TheoryQuestion) {
      debugPrint('[ExamAnalysis] Not a TheoryQuestion, type: ${question.runtimeType}');
      return '[题目类型异常]';
    }
    try {
      debugPrint('[ExamAnalysis] TheoryQuestion - type: ${question.type}, correctAnswer: ${question.correctAnswer}');
      if (question.correctAnswer == null) {
        return '[正确答案未定义]';
      }
      
      String answerText = '';
      if (question.type == QuestionType.trueFalse) {
        answerText = _formatTrueFalseAnswer(question.correctAnswer);
      } else if (question.type == QuestionType.singleChoice) {
        final answer = question.correctAnswer.toString().trim();
        answerText = answer.isEmpty ? '[答案为空]' : answer;
      } else if (question.type == QuestionType.multipleChoice) {
        final correctAnswers = question.correctAnswer as List?;
        if (correctAnswers == null || correctAnswers.isEmpty) {
          answerText = '[多选答案为空]';
        } else {
          answerText = correctAnswers.join('、');
        }
      } else {
        final answer = question.correctAnswer.toString().trim();
        answerText = answer.isEmpty ? '[无法解析答案]' : answer;
      }
      
      debugPrint('[ExamAnalysis] Formatted answer text: $answerText');
      return answerText.isEmpty ? '[无法解析答案]' : answerText;
    } catch (e) {
      debugPrint('[ExamAnalysis] Error formatting answer: $e');
      return '[获取答案失败]';
    }
  }

  String _formatTrueFalseAnswer(dynamic correctAnswer) {
    if (correctAnswer is bool) {
      return correctAnswer ? '正确' : '错误';
    }
    if (correctAnswer is num) {
      if (correctAnswer == 1) return '正确';
      if (correctAnswer == 0) return '错误';
    }
    if (correctAnswer is String) {
      final normalized = correctAnswer.trim().toLowerCase();
      if (normalized.isEmpty) return '[答案为空]';
      if (normalized == 't' || normalized == 'true' || normalized == '正确' || normalized == '对' || normalized == '是') {
        return '正确';
      }
      if (normalized == 'f' || normalized == 'false' || normalized == '错误' || normalized == '错' || normalized == '否') {
        return '错误';
      }
      return correctAnswer.trim();
    }
    return correctAnswer?.toString() ?? '[正确答案未定义]';
  }

  String _formatCodeAnswer(dynamic question) {
    if (question is! CodeQuestion) {
      return '[题目类型异常]';
    }
    try {
      if (question.correctKeywords.isEmpty && question.correctCode.isEmpty) {
        return '[正确答案未定义]';
      }
      if (question.correctKeywords.isNotEmpty) {
        return '关键词：${question.correctKeywords.join('、')}';
      }
      if (question.correctCode.isNotEmpty) {
        return '正确代码：${question.correctCode}';
      }
      return '[无法获取答案]';
    } catch (e) {
      debugPrint('[ExamAnalysis] Error formatting code answer: $e');
      return '[获取答案失败]';
    }
  }

  String _buildResultStatus(Question question, dynamic userAnswer) {
    if (userAnswer == null) {
      return '未作答';
    }
    return question.checkAnswer(userAnswer) ? '正确' : '错误';
  }

  String _stripCorrectAnswerPrefix(String explanation) {
    final text = explanation.trim();
    if (text.isEmpty) {
      return text;
    }
    final colonMarkers = ['解析：', '解析:'];
    for (final marker in colonMarkers) {
      final idx = text.indexOf(marker);
      if (idx >= 0) {
        return text.substring(idx + marker.length).trim();
      }
    }
    if (text.startsWith('正确答案')) {
      final sentenceEnd = text.indexOf('。');
      if (sentenceEnd >= 0 && sentenceEnd + 1 < text.length) {
        return text.substring(sentenceEnd + 1).trim();
      }
    }
    return text;
  }
}

extension on double {
  Widget get horizontalSpace => SizedBox(width: this);
  Widget get verticalSpace => SizedBox(height: this);
}
