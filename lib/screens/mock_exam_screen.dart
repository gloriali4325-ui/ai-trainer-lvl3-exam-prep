import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:ai_coach/models/question.dart';
import 'package:ai_coach/services/question_bank_service.dart';
import 'package:ai_coach/services/user_progress_service.dart';
import 'package:ai_coach/services/user_statistics_service.dart';
import 'package:ai_coach/services/exam_service.dart';
import 'package:ai_coach/services/mistake_notebook_service.dart';
import 'package:ai_coach/widgets/question_card.dart';
import 'package:ai_coach/screens/exam_result_analysis_screen.dart';
import 'package:ai_coach/theme.dart';

class MockExamScreen extends StatefulWidget {
  const MockExamScreen({super.key});

  @override
  State<MockExamScreen> createState() => _MockExamScreenState();
}

class _MockExamScreenState extends State<MockExamScreen> {
  static const int _examDurationMinutes = 90;
  static const int _trueFalseQuestions = 40;
  static const int _singleChoiceQuestions = 140;
  static const int _multipleChoiceQuestions = 10;

  List<Question> _trueFalseList = [];
  List<Question> _singleChoiceList = [];
  List<Question> _multipleChoiceList = [];
  Map<String, dynamic> _answers = {};
  Timer? _timer;
  int _remainingSeconds = _examDurationMinutes * 60;
  bool _examStarted = false;
  bool _examSubmitted = false;
  bool _showingSectionIntro = true; // 标记是否显示部分介绍
  bool _examAbandoned = false;
  
  // 答题卡相关数据
  final Map<String, String> _questionStatusMap = {};  // 题目答题状态: answered/unanswered
  bool _showAnswerCard = true;  // 控制是否显示答题卡

  // 追踪当前的部分 (0:判断题, 1:单选题, 2:多选题)
  int _currentSection = 0;
  int _questionIndexInSection = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startExam() {
    final questionService = context.read<QuestionBankService>();
    final examService = context.read<ExamService>();

    final allQuestions = examService.generateMockExam(
      questionService.allQuestions,
      trueFalseCount: _trueFalseQuestions,
      singleChoiceCount: _singleChoiceQuestions,
      multipleChoiceCount: _multipleChoiceQuestions,
    );

    // 按题目类型分组
    _trueFalseList = allQuestions
        .where((q) => q is TheoryQuestion && q.type == QuestionType.trueFalse)
        .toList();
    _singleChoiceList = allQuestions
        .where((q) => q is TheoryQuestion && q.type == QuestionType.singleChoice)
        .toList();
    _multipleChoiceList = allQuestions
        .where((q) => q is TheoryQuestion && q.type == QuestionType.multipleChoice)
        .toList();

    // 初始化所有题目的答题状态
    for (final question in allQuestions) {
      _questionStatusMap[question.id] = 'unanswered';
    }

    setState(() {
      _examStarted = true;
    });

    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _examSubmitted || _examAbandoned) return;
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _submitExam();
        }
      });
    });
  }

  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _submitExam() async {
    if (_examSubmitted || _examAbandoned) return;

    _timer?.cancel();
    setState(() {
      _examSubmitted = true;
    });

    final userService = context.read<UserProgressService>();
    final examService = context.read<ExamService>();
    final mistakeService = context.read<MistakeNotebookService>();

    double totalScore = 0.0;
    double maxScore = 0.0;
    Map<String, dynamic> questionResults = {};

    // 合并所有题目
    final allQuestions = [..._trueFalseList, ..._singleChoiceList, ..._multipleChoiceList];

    for (final question in allQuestions) {
      final userAnswer = _answers[question.id];
      final isCorrect = userAnswer != null && question.checkAnswer(userAnswer);

      // 计算此题的分数
      double questionScore = 0.0;
      double questionMaxScore = 0.0;

      // 多选题每题 1 分，其他题型每题 0.5 分
      if (question is TheoryQuestion && question.type == QuestionType.multipleChoice) {
        questionMaxScore = 1.0;
        questionScore = isCorrect ? 1.0 : 0.0;
      } else {
        questionMaxScore = 0.5;
        questionScore = isCorrect ? 0.5 : 0.0;
      }

      totalScore += questionScore;
      maxScore += questionMaxScore;

      // 记录错题：包括答错和未作答的题目
      if (!isCorrect && userService.currentUser != null) {
        await mistakeService.addMistake(
          userId: userService.currentUser!.id,
          questionId: question.id,
          userAnswer: userAnswer,  // 未作答时为 null
        );
      }

      final statisticsService = context.read<UserStatisticsService>();
      await statisticsService.recordQuestionAttempt(isCorrect);

      questionResults[question.id] = {
        'answer': userAnswer,
        'correct': isCorrect,
        'score': questionScore,
        'maxScore': questionMaxScore,
      };
    }

    final statisticsService = context.read<UserStatisticsService>();
    await statisticsService.recordMockExam();

    final durationSeconds = (_examDurationMinutes * 60) - _remainingSeconds;
    final result = await examService.saveExamResult(
      userId: userService.currentUser!.id,
      totalQuestions: allQuestions.length,
      totalScore: totalScore,
      maxScore: maxScore,
      durationSeconds: durationSeconds,
      questionResults: questionResults,
    );

    if (mounted) {
      // 首先显示错题解析页面
      final navigator = Navigator.of(context);
      navigator.push(
        MaterialPageRoute(
          builder: (_) => ExamResultAnalysisScreen(
            allQuestions: allQuestions,
            answers: _answers,
            questionResults: questionResults,
          ),
        ),
      ).then((_) {
        // 错题解析页面关闭后，跳转到考试结果页面
        if (mounted) {
          context.goNamed('exam-result', pathParameters: {'id': result.id});
        }
      });
    }
  }

  void _abandonExam() {
    if (_examAbandoned) return;
    _examAbandoned = true;
    _timer?.cancel();
  }

  void _nextSection() {
    setState(() {
      _currentSection++;
      _questionIndexInSection = 0;
      _showingSectionIntro = true; // 显示新部分的介绍
    });
  }

  void _previousQuestion() {
    if (_questionIndexInSection > 0) {
      setState(() {
        _questionIndexInSection--;
      });
    } else if (_currentSection > 0) {
      setState(() {
        _currentSection--;
        final previousList = _getSectionQuestions();
        _questionIndexInSection = previousList.length - 1;
        _showingSectionIntro = true; // 返回上一部分时显示介绍
      });
    }
  }

  void _nextQuestion() {
    final currentList = _getSectionQuestions();
    if (_questionIndexInSection < currentList.length - 1) {
      setState(() {
        _questionIndexInSection++;
      });
    } else if (_currentSection < 2) {
      _nextSection();
    } else {
      // 最后一部分的最后一题，提交考试
      _submitExam();
    }
  }

  List<Question> _getSectionQuestions() {
    switch (_currentSection) {
      case 0:
        return _trueFalseList;
      case 1:
        return _singleChoiceList;
      case 2:
        return _multipleChoiceList;
      default:
        return [];
    }
  }

  bool _isAnswerProvided(dynamic answer) {
    if (answer == null) return false;
    if (answer is String) return answer.trim().isNotEmpty;
    if (answer is List) return answer.isNotEmpty;
    return true;
  }

  String _getSectionTitle() {
    switch (_currentSection) {
      case 0:
        return '判断题';
      case 1:
        return '单选题';
      case 2:
        return '多选题';
      default:
        return '';
    }
  }

  int _getSectionPoints() {
    switch (_currentSection) {
      case 0:
        return 20; // 40 * 0.5
      case 1:
        return 70; // 140 * 0.5
      case 2:
        return 10; // 10 * 1
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_examStarted) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('模拟考试'),
        ),
        body: Center(
          child: Padding(
            padding: AppSpacing.paddingLg,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.assignment,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                AppSpacing.lg.verticalSpace,
                Text(
                  'AI训练师三级 模拟考试',
                  style: context.textStyles.headlineSmall?.bold,
                  textAlign: TextAlign.center,
                ),
                AppSpacing.md.verticalSpace,
                Card(
                  child: Padding(
                    padding: AppSpacing.paddingLg,
                    child: Column(
                      children: [
                        _ExamInfoRow(
                          icon: Icons.quiz,
                          label: '总题数',
                          value: '${_trueFalseQuestions + _singleChoiceQuestions + _multipleChoiceQuestions}',
                        ),
                        AppSpacing.md.verticalSpace,
                        _ExamInfoRow(
                          icon: Icons.timer,
                          label: '考试时长',
                          value: '$_examDurationMinutes 分钟',
                        ),
                        AppSpacing.md.verticalSpace,
                        _ExamInfoRow(
                          icon: Icons.check_circle,
                          label: '及格线',
                          value: '60 分',
                        ),
                      ],
                    ),
                  ),
                ),
                AppSpacing.md.verticalSpace,
                Card(
                  child: Padding(
                    padding: AppSpacing.paddingMd,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '题目构成',
                          style: context.textStyles.titleSmall?.bold,
                        ),
                        AppSpacing.sm.verticalSpace,
                        _QuestionTypeRow(label: '判断题', count: _trueFalseQuestions, points: 20),
                        AppSpacing.xs.verticalSpace,
                        _QuestionTypeRow(label: '单选题', count: _singleChoiceQuestions, points: 70),
                        AppSpacing.xs.verticalSpace,
                        _QuestionTypeRow(label: '多选题', count: _multipleChoiceQuestions, points: 10),
                      ],
                    ),
                  ),
                ),
                AppSpacing.xl.verticalSpace,
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _startExam,
                    icon: const Icon(Icons.play_arrow, color: Colors.white),
                    label: const Text('开始考试', style: TextStyle(color: Colors.white)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 显示部分介绍页面
    if (_showingSectionIntro) {
      return _buildSectionIntro();
    }

    // 显示题目
    final currentList = _getSectionQuestions();
    if (currentList.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final question = currentList[_questionIndexInSection];
    final totalQuestionsInAllSections =
        _trueFalseList.length + _singleChoiceList.length + _multipleChoiceList.length;
    final totalQuestionsBeforeSectionAndQuestion =
        (_currentSection == 0 ? 0 : _trueFalseList.length) +
            (_currentSection == 0 || _currentSection == 1 ? 0 : _singleChoiceList.length);
    final overallQuestionNumber = totalQuestionsBeforeSectionAndQuestion + _questionIndexInSection + 1;
    final progress = overallQuestionNumber / totalQuestionsInAllSections;

    final currentAnswer = _answers[question.id];
    final isAnswered = _isAnswerProvided(currentAnswer);

    return WillPopScope(
      onWillPop: () async {
        _timer?.cancel();
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('退出考试？'),
            content: const Text('确定要退出吗？你的答题进度将丢失。'),
            actions: [
              TextButton(
                onPressed: () => context.pop(false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => context.pop(true),
                child: const Text('退出'),
              ),
            ],
          ),
        );
        if (shouldPop == true) {
          _abandonExam();
          return true;
        }
        if (_examStarted && !_examSubmitted && !_examAbandoned) {
          _startTimer();
        }
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('模拟考试'),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _remainingSeconds < 600
                    ? Theme.of(context).colorScheme.errorContainer
                    : Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer,
                    size: 20,
                    color: _remainingSeconds < 600 ? Theme.of(context).colorScheme.error : null,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(_remainingSeconds),
                    style: context.textStyles.labelLarge?.semiBold,
                  ),
                ],
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              color: Theme.of(context).colorScheme.tertiary,
            ),
          ),
        ),
        body: Row(
          children: [
            // 左侧：题目内容
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: QuestionCard(
                        question: question,
                        questionNumber: overallQuestionNumber,
                        selectedAnswer: _answers[question.id],
                        onAnswerSelected: (answer) {
                          setState(() {
                            if (_isAnswerProvided(answer)) {
                              _answers[question.id] = answer;
                              _questionStatusMap[question.id] = 'answered';
                            } else {
                              _answers.remove(question.id);
                              _questionStatusMap[question.id] = 'unanswered';
                            }
                          });
                        },
                        showExplanation: false,
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
                      child: Column(
                        children: [
                          if (!isAnswered)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '⚠️ 请先回答此题再继续',
                                  style: context.textStyles.labelMedium?.withColor(
                                    Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                            ),
                          Row(
                            children: [
                              if (_questionIndexInSection > 0)
                                OutlinedButton.icon(
                                  onPressed: _previousQuestion,
                                  icon: const Icon(Icons.arrow_back),
                                  label: const Text('上一题'),
                                ),
                              const Spacer(),
                              Text(
                                '$overallQuestionNumber / $totalQuestionsInAllSections',
                                style: context.textStyles.bodyMedium?.semiBold,
                              ),
                              const Spacer(),
                              if (isAnswered)
                                FilledButton.icon(
                                  onPressed: () {
                                    final currentList = _getSectionQuestions();
                                    if (_questionIndexInSection < currentList.length - 1) {
                                      _nextQuestion();
                                    } else if (_currentSection < 2) {
                                      _nextSection();
                                    } else {
                                      _submitExam();
                                    }
                                  },
                                  icon: const Icon(Icons.arrow_forward, color: Colors.white),
                                  label: Text(
                                    _currentSection == 2 && _questionIndexInSection == currentList.length - 1
                                        ? '提交'
                                        : '下一题',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                )
                              else
                                FilledButton.icon(
                                  onPressed: null,
                                  icon: const Icon(Icons.arrow_forward),
                                  label: const Text('下一题'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // 右侧：答题卡
            Container(
              width: 280,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                border: Border(
                  left: BorderSide(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Column(
                children: [
                  // 答题卡标题和统计
                  Container(
                    padding: AppSpacing.paddingMd,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '答题卡',
                              style: context.textStyles.titleSmall?.semiBold,
                            ),
                            IconButton(
                              icon: const Icon(Icons.unfold_less, size: 18),
                              onPressed: () {
                                setState(() {
                                  _showAnswerCard = !_showAnswerCard;
                                });
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        AppSpacing.sm.verticalSpace,
                        _buildAnswerCardStats(),
                      ],
                    ),
                  ),
                  
                  // 答题卡内容（网格）
                  if (_showAnswerCard)
                    Expanded(
                      child: SingleChildScrollView(
                        padding: AppSpacing.paddingMd,
                        child: _buildAnswerCardGrid(),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerCardStats() {
    int answeredCount = 0;
    int correctCount = 0;
    int wrongCount = 0;
    
    final allQuestions = [..._trueFalseList, ..._singleChoiceList, ..._multipleChoiceList];
    for (final question in allQuestions) {
      final status = _questionStatusMap[question.id];
      if (status == 'answered') {
        answeredCount++;
        final userAnswer = _answers[question.id];
        if (userAnswer != null && question.checkAnswer(userAnswer)) {
          correctCount++;
        } else {
          wrongCount++;
        }
      }
    }
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '已答: ${answeredCount}/${allQuestions.length}',
              style: context.textStyles.labelSmall,
            ),
            Text(
              '正确: $correctCount',
              style: context.textStyles.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.tertiary,
              ),
            ),
          ],
        ),
        AppSpacing.xs.verticalSpace,
        Text(
          '错误: $wrongCount',
          style: context.textStyles.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.error,
          ),
        ),
      ],
    );
  }

  Widget _buildAnswerCardGrid() {
    final allQuestions = [..._trueFalseList, ..._singleChoiceList, ..._multipleChoiceList];
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(allQuestions.length, (index) {
        final question = allQuestions[index];
        final status = _questionStatusMap[question.id] ?? 'unanswered';
        final isCurrentQuestion = _currentSection == 0 && _questionIndexInSection < _trueFalseList.length && _trueFalseList[_questionIndexInSection].id == question.id ||
            _currentSection == 1 && _questionIndexInSection < _singleChoiceList.length && _singleChoiceList[_questionIndexInSection].id == question.id ||
            _currentSection == 2 && _questionIndexInSection < _multipleChoiceList.length && _multipleChoiceList[_questionIndexInSection].id == question.id;
        
        // 计算该题目是否正确
        String displayStatus = status;
        if (status == 'answered') {
          final userAnswer = _answers[question.id];
          if (userAnswer != null && question.checkAnswer(userAnswer)) {
            displayStatus = 'correct';
          } else {
            displayStatus = 'incorrect';
          }
        }
        
        return _buildAnswerCardItem(
          questionNumber: index + 1,
          status: displayStatus,
          isCurrentQuestion: isCurrentQuestion,
          onTap: () => _jumpToQuestion(index, allQuestions),
          context: context,
        );
      }),
    );
  }

  void _jumpToQuestion(int overallIndex, List<Question> allQuestions) {
    // 计算该题在哪个部分
    int trueFalseLength = _trueFalseList.length;
    int singleChoiceLength = _singleChoiceList.length;
    
    if (overallIndex < trueFalseLength) {
      // 判断题
      setState(() {
        _currentSection = 0;
        _questionIndexInSection = overallIndex;
        _showingSectionIntro = false;
      });
    } else if (overallIndex < trueFalseLength + singleChoiceLength) {
      // 单选题
      setState(() {
        _currentSection = 1;
        _questionIndexInSection = overallIndex - trueFalseLength;
        _showingSectionIntro = false;
      });
    } else {
      // 多选题
      setState(() {
        _currentSection = 2;
        _questionIndexInSection = overallIndex - trueFalseLength - singleChoiceLength;
        _showingSectionIntro = false;
      });
    }
  }

  Widget _buildAnswerCardItem({
    required int questionNumber,
    required String status,
    required bool isCurrentQuestion,
    required VoidCallback onTap,
    required BuildContext context,
  }) {
    Color backgroundColor;
    Color borderColor;
    Color textColor;
    
    if (isCurrentQuestion) {
      backgroundColor = Theme.of(context).colorScheme.primaryContainer;
      borderColor = Theme.of(context).colorScheme.primary;
      textColor = Theme.of(context).colorScheme.onPrimaryContainer;
    } else {
      switch (status) {
        case 'correct':
          backgroundColor = Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.2);
          borderColor = Theme.of(context).colorScheme.tertiary;
          textColor = Theme.of(context).colorScheme.onSurface;
          break;
        case 'incorrect':
          backgroundColor = Theme.of(context).colorScheme.error.withValues(alpha: 0.2);
          borderColor = Theme.of(context).colorScheme.error;
          textColor = Theme.of(context).colorScheme.onSurface;
          break;
        case 'answered':
          backgroundColor = Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3);
          borderColor = Theme.of(context).colorScheme.primary.withValues(alpha: 0.5);
          textColor = Theme.of(context).colorScheme.onSurface;
          break;
        case 'unanswered':
        default:
          backgroundColor = Colors.transparent;
          borderColor = Theme.of(context).colorScheme.outline.withValues(alpha: 0.3);
          textColor = Theme.of(context).colorScheme.onSurfaceVariant;
          break;
      }
    }
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(
            color: borderColor,
            width: isCurrentQuestion ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Center(
          child: Text(
            '$questionNumber',
            style: context.textStyles.labelMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionIntro() {
    final sectionTitle = _getSectionTitle();
    final sectionCount = _getSectionQuestions().length;
    final sectionPoints = _getSectionPoints();
    final pointPerQuestion =
        _currentSection == 2 ? '1.0 分' : '0.5 分';

    return Scaffold(
      appBar: AppBar(
        title: const Text('模拟考试'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _remainingSeconds < 600
                  ? Theme.of(context).colorScheme.errorContainer
                  : Theme.of(context).colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.timer,
                  size: 20,
                  color: _remainingSeconds < 600 ? Theme.of(context).colorScheme.error : null,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatTime(_remainingSeconds),
                  style: context.textStyles.labelLarge?.semiBold,
                ),
              ],
            ),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: AppSpacing.paddingLg,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _currentSection == 0
                    ? Icons.help
                    : _currentSection == 1
                        ? Icons.radio_button_checked
                        : Icons.done_all,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              AppSpacing.xl.verticalSpace,
              Text(
                sectionTitle,
                style: context.textStyles.headlineSmall?.bold,
              ),
              AppSpacing.md.verticalSpace,
              Card(
                child: Padding(
                  padding: AppSpacing.paddingLg,
                  child: Column(
                    children: [
                      _ExamInfoRow(
                        icon: Icons.quiz,
                        label: '题目数量',
                        value: '$sectionCount 题',
                      ),
                      AppSpacing.md.verticalSpace,
                      _ExamInfoRow(
                        icon: Icons.check_circle,
                        label: '单题分值',
                        value: pointPerQuestion,
                      ),
                      AppSpacing.md.verticalSpace,
                      _ExamInfoRow(
                        icon: Icons.star,
                        label: '总分值',
                        value: '$sectionPoints 分',
                      ),
                    ],
                  ),
                ),
              ),
              AppSpacing.xl.verticalSpace,
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _showingSectionIntro = false;
                      _questionIndexInSection = 0;
                    });
                  },
                  icon: const Icon(Icons.play_arrow, color: Colors.white),
                  label: const Text('开始答题', style: TextStyle(color: Colors.white)),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
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

class _ExamInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ExamInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        AppSpacing.md.horizontalSpace,
        Text(
          label,
          style: context.textStyles.bodyMedium,
        ),
        const Spacer(),
        Text(
          value,
          style: context.textStyles.bodyMedium?.semiBold,
        ),
      ],
    );
  }
}

class _QuestionTypeRow extends StatelessWidget {
  final String label;
  final int count;
  final int points;

  const _QuestionTypeRow({
    required this.label,
    required this.count,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: context.textStyles.bodySmall,
        ),
        Text(
          '$count 题 / $points 分',
          style: context.textStyles.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

extension on double {
  Widget get horizontalSpace => SizedBox(width: this);
  Widget get verticalSpace => SizedBox(height: this);
}
