import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:ai_coach/models/question.dart';
import 'package:ai_coach/services/question_bank_service.dart';
import 'package:ai_coach/services/user_progress_service.dart';
import 'package:ai_coach/services/user_statistics_service.dart';
import 'package:ai_coach/services/mistake_notebook_service.dart';
import 'package:ai_coach/widgets/question_card.dart';
import 'package:ai_coach/theme.dart';

class CategoryPracticeScreen extends StatefulWidget {
  final String categoryId;

  const CategoryPracticeScreen({super.key, required this.categoryId});

  @override
  State<CategoryPracticeScreen> createState() => _CategoryPracticeScreenState();
}

class _CategoryPracticeScreenState extends State<CategoryPracticeScreen> with WidgetsBindingObserver {
  int _currentQuestionIndex = 0;
  dynamic _selectedAnswer;
  bool _showExplanation = false;
  List<Question> _questions = [];
  late UserProgressService _userService;
  int _loadRetries = 0;
  String? _categoryName;
  
  // 答题卡相关数据
  final List<String> _seenQuestionIds = [];  // 已出现的题目ID列表
  final Map<String, String> _questionStatusMap = {};  // 题目状态map
  final Map<String, dynamic> _questionAnswers = {};  // 题目答案保存
  final Map<String, bool> _questionShowExplanation = {};  // 题目解释显示状态

  @override
  void initState() {
    super.initState();
    _userService = context.read<UserProgressService>();
    WidgetsBinding.instance.addObserver(this);
    _loadQuestions();
  }

  @override
  void dispose() {
    _persistState();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _persistState();
    }
  }

  void _persistState() {
    if (_questions.isEmpty) return;
    _saveCategoryState(_userService);
  }

  void _loadQuestions() async {
    final questionService = context.read<QuestionBankService>();
    final userService = _userService;

    _categoryName = questionService.getCategoryById(widget.categoryId)?.name;

    if ((userService.isLoading || userService.currentUser == null) && _loadRetries < 5) {
      _loadRetries++;
      await Future.delayed(const Duration(milliseconds: 120));
      if (mounted) {
        _loadQuestions();
      }
      return;
    }
    
    // 确保 currentUser 已经完全初始化
    final userId = userService.currentUser?.id;
    if (userId == null) {
      debugPrint('[CategoryPractice] Current user ID is null, cannot proceed');
      if (_loadRetries < 5) {
        _loadRetries++;
        await Future.delayed(const Duration(milliseconds: 120));
        if (mounted) {
          _loadQuestions();
        }
      }
      return;
    }
    
    // 首先尝试加载保存的状态（现在传递 userId，避免依赖 _currentUser）
    final savedState = await userService.getCategoryState(
      widget.categoryId,
      categoryName: _categoryName,
      userId: userId,  // 新增：显式传递 userId
    );
    
    if (savedState != null) {
      // 恢复保存的状态
      try {
        final questionIds = List<String>.from(savedState['questionIds'] as List);
        final currentIndexRaw = savedState['currentIndex'] as num? ?? 0;
        final currentIndex = currentIndexRaw.toInt();
        final seenQuestionIds = List<String>.from(savedState['seenQuestionIds'] as List);
        final questionStatusMapData = savedState['questionStatusMap'] as Map<String, dynamic>;
        final questionAnswersData = savedState['questionAnswers'] as Map<String, dynamic>;
        final questionShowExplanationData = savedState['questionShowExplanation'] as Map<String, dynamic>;
        
        // 根据保存的 ID 列表恢复题目顺序
        final allQuestions = questionService.getQuestionsByCategory(widget.categoryId);
        if (allQuestions.isEmpty && questionService.isLoading && _loadRetries < 5) {
          _loadRetries++;
          await Future.delayed(const Duration(milliseconds: 120));
          if (mounted) {
            _loadQuestions();
          }
          return;
        }

        final questionById = {for (final q in allQuestions) q.id: q};
        final restoredQuestions = <Question>[];
        for (final id in questionIds) {
          final question = questionById[id];
          if (question != null) {
            restoredQuestions.add(question);
          }
        }
        if (restoredQuestions.length < allQuestions.length) {
          for (final question in allQuestions) {
            if (!questionIds.contains(question.id)) {
              restoredQuestions.add(question);
            }
          }
        }
        if (restoredQuestions.isEmpty) {
          throw StateError('No questions restored for category ${widget.categoryId}');
        }

        final safeIndex = currentIndex.clamp(0, restoredQuestions.length - 1);
        
        setState(() {
          _questions = restoredQuestions;
          _currentQuestionIndex = safeIndex;
          _seenQuestionIds.clear();
          _seenQuestionIds.addAll(seenQuestionIds);
          
          // 恢复题目状态 map
          _questionStatusMap.clear();
          for (var entry in questionStatusMapData.entries) {
            _questionStatusMap[entry.key] = entry.value as String;
          }
          
          // 恢复答案和解释显示状态
          _questionAnswers.clear();
          _questionAnswers.addAll(questionAnswersData);
          
          _questionShowExplanation.clear();
          _questionShowExplanation.addAll(Map<String, bool>.from(questionShowExplanationData));
          
          // 恢复当前题目的答案和解释显示状态
          if (_questions.isNotEmpty && safeIndex < _questions.length) {
            final currentQuestionId = _questions[safeIndex].id;
            _selectedAnswer = _questionAnswers[currentQuestionId];
            _showExplanation = _questionShowExplanation[currentQuestionId] ?? false;
          }
        });
        
        debugPrint('[CategoryPractice] Successfully restored category ${widget.categoryId} state');
        return;
      } catch (e) {
        debugPrint('[CategoryPractice] Failed to restore category state: $e');
        // 如果恢复失败，继续使用新的随机顺序
      }
    }
    
    // 如果没有保存的状态，创建新的随机顺序
    setState(() {
      _questions = questionService.getQuestionsByCategory(widget.categoryId);
      _questions.shuffle();
      
      // 初始化第一个题目为已见
      if (_questions.isNotEmpty) {
        final firstQuestionId = _questions[0].id;
        _seenQuestionIds.add(firstQuestionId);
        _questionStatusMap[firstQuestionId] = 'unanswered';
        _questionAnswers[firstQuestionId] = null;
        _questionShowExplanation[firstQuestionId] = false;
      }
      _currentQuestionIndex = 0;
    });

    _persistState();
  }

  void _submitAnswer() async {
    if (_selectedAnswer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择一个答案')),
      );
      return;
    }

    final question = _questions[_currentQuestionIndex];
    final isCorrect = question.checkAnswer(_selectedAnswer);

    final userService = context.read<UserProgressService>();
    final statisticsService = context.read<UserStatisticsService>();
    final mistakeService = context.read<MistakeNotebookService>();

    await statisticsService.recordQuestionAttempt(isCorrect);

    if (!isCorrect && userService.currentUser != null) {
      await mistakeService.addMistake(
        userId: userService.currentUser!.id,
        questionId: question.id,
        userAnswer: _selectedAnswer,
      );
    }

    setState(() {
      _showExplanation = true;
      _questionAnswers[question.id] = _selectedAnswer;
      _questionShowExplanation[question.id] = true;
      _questionStatusMap[question.id] = isCorrect ? 'correct' : 'incorrect';
    });
    
    // 保存完整状态到 SharedPreferences
    await _saveCategoryState(userService);
  }
  
  // 辅助方法：保存完整的分类练习状态
  Future<void> _saveCategoryState(UserProgressService userService) async {
    await userService.saveCategoryState(
      categoryId: widget.categoryId,
      categoryName: _categoryName,
      questionIds: _questions.map((q) => q.id).toList(),
      currentIndex: _currentQuestionIndex,
      seenQuestionIds: _seenQuestionIds.toList(),
      questionStatusMap: _questionStatusMap,
      questionAnswers: _questionAnswers,
      questionShowExplanation: _questionShowExplanation,
    );
  }

  void _nextQuestion() async {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        
        // 添加新题目到已见列表
        final nextQuestion = _questions[_currentQuestionIndex];
        if (!_seenQuestionIds.contains(nextQuestion.id)) {
          _seenQuestionIds.add(nextQuestion.id);
          _questionStatusMap[nextQuestion.id] = 'unanswered';
          _questionAnswers[nextQuestion.id] = null;
          _questionShowExplanation[nextQuestion.id] = false;
        }
        
        // 恢复该题目的之前的答案和解释状态
        _selectedAnswer = _questionAnswers[nextQuestion.id];
        _showExplanation = _questionShowExplanation[nextQuestion.id] ?? false;
      });
      
      // 保存完整状态到 SharedPreferences
      final userService = context.read<UserProgressService>();
      await _saveCategoryState(userService);
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('🎉 分类完成!'),
          content: const Text('你已完成本分类的所有题目。'),
          actions: [
            TextButton(
              onPressed: () async {
                final userService = context.read<UserProgressService>();
                await userService.clearCategoryProgress(
                  widget.categoryId,
                  categoryName: _categoryName,
                );
                if (context.mounted) {
                  context.pop();
                  context.pop();
                }
              },
              child: const Text('返回'),
            ),
            FilledButton(
              onPressed: () async {
                final userService = context.read<UserProgressService>();
                await userService.clearCategoryProgress(
                  widget.categoryId,
                  categoryName: _categoryName,
                );
                if (mounted) {
                  context.pop();
                  setState(() {
                    _currentQuestionIndex = 0;
                    _selectedAnswer = null;
                    _showExplanation = false;
                    _questions.shuffle();
                    _seenQuestionIds.clear();
                    _questionStatusMap.clear();
                    _questionAnswers.clear();
                    _questionShowExplanation.clear();
                    
                    // 重新初始化第一个题目
                    if (_questions.isNotEmpty) {
                      final firstQuestionId = _questions[0].id;
                      _seenQuestionIds.add(firstQuestionId);
                      _questionStatusMap[firstQuestionId] = 'unanswered';
                      _questionAnswers[firstQuestionId] = null;
                      _questionShowExplanation[firstQuestionId] = false;
                    }
                  });
                }
              },
              child: const Text('重新开始'),
            ),
          ],
        ),
      );
    }
  }

  void _jumpToQuestion(int index) async {
    setState(() {
      _currentQuestionIndex = index;
      final targetQuestion = _questions[index];
      // 恢复该题目的之前的答案和解释状态
      _selectedAnswer = _questionAnswers[targetQuestion.id];
      _showExplanation = _questionShowExplanation[targetQuestion.id] ?? false;
    });
    
    // 保存完整状态到 SharedPreferences
    final userService = context.read<UserProgressService>();
    await _saveCategoryState(userService);
  }

  @override
  Widget build(BuildContext context) {
    final questionService = context.watch<QuestionBankService>();
    final userService = context.watch<UserProgressService>();
    final category = questionService.getCategoryById(widget.categoryId);

    if (questionService.isLoading || userService.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(category?.name ?? 'Category Practice'),
        ),
        body: const Center(child: Text('该分类暂无题目')),
      );
    }

    final question = _questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / _questions.length;
    
    // 计算答题卡统计
    int correctCount = 0;
    int incorrectCount = 0;
    for (var status in _questionStatusMap.values) {
      if (status == 'correct') {
        correctCount++;
      } else if (status == 'incorrect') {
        incorrectCount++;
      }
    }

    return WillPopScope(
      onWillPop: () async {
        await _saveCategoryState(_userService);
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(category?.name ?? 'Category Practice'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              color: Theme.of(context).colorScheme.secondary,
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
                        questionNumber: _currentQuestionIndex + 1,
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
                            '${_currentQuestionIndex + 1} / ${_questions.length}',
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
                                _currentQuestionIndex < _questions.length - 1 ? '下一题' : '完成',
                                style: const TextStyle(color: Colors.white),
                              ),
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
                        Text(
                          '答题卡',
                          style: context.textStyles.titleSmall?.semiBold,
                        ),
                        AppSpacing.sm.verticalSpace,
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '已出现: ${_seenQuestionIds.length}',
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
                          '错误: $incorrectCount',
                          style: context.textStyles.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 答题卡内容（网格）
                  Expanded(
                    child: SingleChildScrollView(
                      padding: AppSpacing.paddingMd,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(_seenQuestionIds.length, (index) {
                          final questionId = _seenQuestionIds[index];
                          final status = _questionStatusMap[questionId] ?? 'unanswered';
                          final question = _questions.firstWhere((q) => q.id == questionId);
                          final questionNumber = _questions.indexOf(question) + 1;
                          final isCurrentQuestion = _questions[_currentQuestionIndex].id == questionId;

                          return _buildAnswerCard(
                            questionNumber: questionNumber,
                            status: status,
                            isCurrentQuestion: isCurrentQuestion,
                            onTap: () => _jumpToQuestion(_questions.indexOf(question)),
                            context: context,
                          );
                        }),
                      ),
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

  Widget _buildAnswerCard({
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
}

extension on double {
  Widget get verticalSpace => SizedBox(height: this);
}
