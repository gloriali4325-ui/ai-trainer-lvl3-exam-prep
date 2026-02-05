import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai_coach/models/question.dart';
import 'package:ai_coach/services/question_bank_service.dart';
import 'package:ai_coach/services/mistake_notebook_service.dart';
import 'package:ai_coach/services/user_progress_service.dart';
import 'package:ai_coach/services/user_statistics_service.dart';
import 'package:ai_coach/theme.dart';
import 'package:ai_coach/widgets/code_runner.dart';

class OperationalSkillsDrillingScreen extends StatefulWidget {
  const OperationalSkillsDrillingScreen({super.key});

  @override
  State<OperationalSkillsDrillingScreen> createState() => _OperationalSkillsDrillingScreenState();
}

class _OperationalSkillsDrillingScreenState extends State<OperationalSkillsDrillingScreen> {
  late List<CodeQuestion> _questions;
  int _currentIndex = 0;
  late Map<String, bool> _submittedStates;
  late Map<String, String> _userAnswers;
  late Map<String, bool> _isCorrectStates;
  final List<String> _seenQuestionIds = [];
  final Map<String, AnswerStatus> _questionStatusMap = {};

  Future<void> _submitAnswer(CodeQuestion question, String userCode) async {
    // 检查答案是否包含所有关键词
    final userCodeNormalized = userCode.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    final isCorrect = question.correctKeywords.every((keyword) {
      final keywordNormalized = keyword.toLowerCase().replaceAll(RegExp(r'\s+'), '');
      return userCodeNormalized.contains(keywordNormalized);
    });

    if (!mounted) return;

    // 在异步操作前获取 services
    final userService = context.read<UserProgressService>();
    final statisticsService = context.read<UserStatisticsService>();
    final mistakeService = context.read<MistakeNotebookService>();

    setState(() {
      _submittedStates[question.id] = true;
      _isCorrectStates[question.id] = isCorrect;
      _userAnswers[question.id] = userCode;
      _questionStatusMap[question.id] = isCorrect ? AnswerStatus.correct : AnswerStatus.incorrect;
    });

    // 记录用户答题进度
    await statisticsService.recordQuestionAttempt(isCorrect);

    // 如果答案错误，加入错题本
    if (!isCorrect) {
      await mistakeService.addMistake(
        userId: 'current_user',
        questionId: question.id,
        userAnswer: userCode,
      );
    }

    await _saveOperationalDrillingState(userService);
  }

  Future<void> _loadQuestions() async {
    final questionBank = context.read<QuestionBankService>();
    final userService = context.read<UserProgressService>();

    // 确保 currentUser 已经完全初始化
    final userId = userService.currentUser?.id;
    if (userId == null) {
      debugPrint('[OperationalDrilling] Current user ID is null, cannot proceed');
      return;
    }

    final savedState = await userService.getOperationalDrillingState(userId: userId);
    if (savedState != null) {
      try {
        final questionIds = List<String>.from(savedState['questionIds'] as List);
        final currentIndex = savedState['currentIndex'] as int;
        final seenQuestionIds = List<String>.from(savedState['seenQuestionIds'] as List);
        final questionStatusMapData = savedState['questionStatusMap'] as Map<String, dynamic>;
        final questionAnswersData = savedState['questionAnswers'] as Map<String, dynamic>;
        final submittedStatesData = savedState['submittedStates'] as Map<String, dynamic>;
        final isCorrectStatesData = savedState['isCorrectStates'] as Map<String, dynamic>;

        final allQuestions = questionBank.codeQuestions;
        final questionById = {
          for (final question in allQuestions) question.id: question,
        };
        final restoredQuestions = <CodeQuestion>[];
        for (final id in questionIds) {
          final question = questionById[id];
          if (question != null) {
            restoredQuestions.add(question);
          }
        }
        if (restoredQuestions.isEmpty) {
          throw StateError('No operational questions to restore');
        }

        setState(() {
          _questions = restoredQuestions;
          _currentIndex = restoredQuestions.isEmpty
              ? 0
              : currentIndex.clamp(0, restoredQuestions.length - 1);
          _submittedStates = {};
          _userAnswers = {};
          _isCorrectStates = {};
          _seenQuestionIds.clear();
          _questionStatusMap.clear();

          _seenQuestionIds.addAll(seenQuestionIds.where(questionById.containsKey));
          for (var entry in questionStatusMapData.entries) {
            if (questionById.containsKey(entry.key)) {
              _questionStatusMap[entry.key] = AnswerStatus.values.firstWhere(
                (e) => e.toString() == 'AnswerStatus.${entry.value}',
              );
            }
          }
          for (var entry in questionAnswersData.entries) {
            if (questionById.containsKey(entry.key)) {
              _userAnswers[entry.key] = entry.value.toString();
            }
          }
          for (var entry in submittedStatesData.entries) {
            if (questionById.containsKey(entry.key)) {
              _submittedStates[entry.key] = entry.value as bool;
            }
          }
          for (var entry in isCorrectStatesData.entries) {
            if (questionById.containsKey(entry.key)) {
              _isCorrectStates[entry.key] = entry.value as bool;
            }
          }

          if (_questions.isNotEmpty) {
            _markQuestionSeen(_questions[_currentIndex]);
          }
        });

        debugPrint('[OperationalDrilling] Restored drilling state');
        return;
      } catch (e) {
        debugPrint('[OperationalDrilling] Failed to restore drilling state: $e');
      }
    }

    setState(() {
      _questions = questionBank.codeQuestions;
      _questions.shuffle();
      _submittedStates = {};
      _userAnswers = {};
      _isCorrectStates = {};
      _seenQuestionIds.clear();
      _questionStatusMap.clear();
      if (_questions.isNotEmpty) {
        _markQuestionSeen(_questions.first);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('操作技能 · 随机练习')),
        body: Center(
          child: Text(
            '没有操作技能题目',
            style: context.textStyles.bodyLarge,
          ),
        ),
      );
    }

    final currentQuestion = _questions[_currentIndex];
    final isSubmitted = _submittedStates[currentQuestion.id] ?? false;
    final userCode = _userAnswers[currentQuestion.id] ?? currentQuestion.codeTemplate;
    final correctCount = _questionStatusMap.values.where((s) => s == AnswerStatus.correct).length;
    final incorrectCount = _questionStatusMap.values.where((s) => s == AnswerStatus.incorrect).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('操作技能 · 随机练习'),
        centerTitle: false,
      ),
      body: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Padding(
                  padding: AppSpacing.paddingMd,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '第 ${_currentIndex + 1}/${_questions.length} 题',
                            style: context.textStyles.labelLarge,
                          ),
                        ],
                      ),
                      AppSpacing.sm.verticalSpace,
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: LinearProgressIndicator(
                          value: (_currentIndex + 1) / _questions.length,
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      children: [
                        _buildQuestionSection(currentQuestion),
                        if (currentQuestion.dataFiles?.isNotEmpty ?? false)
                          _buildDataAttachmentSection(currentQuestion),
                        _buildCodeEditorSection(currentQuestion, userCode),
                        if (isSubmitted)
                          _buildExplanationSection(currentQuestion),
                      ],
                    ),
                  ),
                ),
                _buildBottomBar(currentQuestion, isSubmitted, userCode),
              ],
            ),
          ),
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
                Expanded(
                  child: SingleChildScrollView(
                    padding: AppSpacing.paddingMd,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(_seenQuestionIds.length, (index) {
                        final questionId = _seenQuestionIds[index];
                        final status = _questionStatusMap[questionId] ?? AnswerStatus.unanswered;
                        final question = _questions.firstWhere((q) => q.id == questionId);
                        final questionNumber = _questions.indexOf(question) + 1;
                        final isCurrentQuestion = _questions[_currentIndex].id == questionId;

                        return _buildAnswerCard(
                          questionNumber: questionNumber,
                          status: status,
                          isCurrentQuestion: isCurrentQuestion,
                          onTap: () => _setCurrentIndex(_questions.indexOf(question)),
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
    );
  }

  Widget _buildQuestionSection(CodeQuestion question) {
    return Padding(
      padding: AppSpacing.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.text,
            style: context.textStyles.bodyMedium,
          ),
          AppSpacing.md.verticalSpace,
        ],
      ),
    );
  }

  Widget _buildDataAttachmentSection(CodeQuestion question) {
    return Padding(
      padding: AppSpacing.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSpacing.md.verticalSpace,
          Text(
            '📎 数据附件',
            style: context.textStyles.titleMedium?.semiBold,
          ),
          AppSpacing.sm.verticalSpace,
          Column(
            children: question.dataFiles!
                .map((fileName) => _buildDataFileCard(fileName))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDataFileCard(String fileName) {
    return Card(
      margin: EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: Icon(
          Icons.description,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          fileName,
          style: context.textStyles.bodyMedium?.semiBold,
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        onTap: () {
          _showDataPreview(fileName);
        },
      ),
    );
  }

  void _showDataPreview(String fileName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('数据预览: $fileName'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '📋 字段说明',
                style: context.textStyles.titleSmall?.semiBold,
              ),
              AppSpacing.md.verticalSpace,
              _buildFileFieldsInfo(fileName),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildFileFieldsInfo(String fileName) {
    final fieldsInfo = _getDataFileFields(fileName);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: fieldsInfo.entries
          .map((e) => Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ${e.key}',
                      style: context.textStyles.bodySmall?.semiBold,
                    ),
                    Text(
                      e.value,
                      style: context.textStyles.labelSmall?.withColor(
                        Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Map<String, String> _getDataFileFields(String fileName) {
    if (fileName.contains('patient')) {
      return {
        'PatientID': '患者ID',
        'Age': '年龄',
        'BMI': '体重指数',
        'BloodPressure': '血压',
        'Cholesterol': '胆固醇水平',
        'DaysInHospital': '住院天数',
      };
    } else if (fileName.contains('sensor')) {
      return {
        'SensorID': '传感器ID',
        'Timestamp': '时间戳',
        'SensorType': '传感器类型',
        'Value': '传感器读数',
        'Location': '传感器安装位置',
      };
    }
    return {};
  }

  Widget _buildCodeEditorSection(CodeQuestion question, String userCode) {
    return CodeRunner(
      question: question,
      initialCode: userCode,
      onCodeChanged: (newCode) {
        _userAnswers[question.id] = newCode;
      },
    );
  }

  Widget _buildExplanationSection(CodeQuestion question) {
    return Container(
      color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
      padding: AppSpacing.paddingMd,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSpacing.md.verticalSpace,
            Text(
              '✓ 答案解析',
              style: context.textStyles.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            AppSpacing.md.verticalSpace,
            Text(
              question.explanation,
              style: context.textStyles.bodySmall?.withColor(
                Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            AppSpacing.md.verticalSpace,
            Text(
              '🔑 关键词要求',
              style: context.textStyles.titleSmall?.semiBold,
            ),
            AppSpacing.sm.verticalSpace,
            Wrap(
              spacing: 8,
              children: question.correctKeywords
                  .map((keyword) => Chip(
                        label: Text(keyword),
                        backgroundColor:
                            Theme.of(context).colorScheme.secondaryContainer,
                      ))
                  .toList(),
            ),
            AppSpacing.md.verticalSpace,
            Text(
              '✓ 完整正确代码',
              style: context.textStyles.titleSmall?.semiBold,
            ),
            AppSpacing.sm.verticalSpace,
            Container(
              padding: AppSpacing.paddingSm,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: SelectableText(
                question.correctCode,
                style: const TextStyle(
                  fontFamily: 'Courier New',
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(CodeQuestion question, bool isSubmitted, String userCode) {
    return Padding(
      padding: AppSpacing.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isSubmitted)
            FilledButton.icon(
              onPressed: () => _submitAnswer(question, userCode),
              icon: const Icon(Icons.check),
              label: const Text('提交答案'),
            )
          else
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _submittedStates[question.id] = false;
                });
              },
              icon: const Icon(Icons.edit),
              label: const Text('重新作答'),
            ),
          AppSpacing.sm.verticalSpace,
          // 显示答案正确/错误的提示
          if (isSubmitted && _isCorrectStates[question.id] == true)
            Container(
              padding: AppSpacing.paddingSm,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                border: Border.all(color: Colors.green),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  AppSpacing.sm.horizontalSpace,
                  const Expanded(
                    child: Text(
                      '✓ 答案正确！',
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            )
          else if (isSubmitted && _isCorrectStates[question.id] == false)
            Container(
              padding: AppSpacing.paddingSm,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                border: Border.all(color: Colors.red),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cancel, color: Colors.red),
                  AppSpacing.sm.horizontalSpace,
                  const Expanded(
                    child: Text(
                      '✗ 答案错误，已加入错题本',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          AppSpacing.md.verticalSpace,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                onPressed: _currentIndex > 0
                    ? () {
                        _setCurrentIndex(_currentIndex - 1);
                      }
                    : null,
                icon: const Icon(Icons.arrow_back),
                label: const Text('上一题'),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  '${_currentIndex + 1}/${_questions.length}',
                  style: context.textStyles.labelMedium,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _currentIndex < _questions.length - 1
                    ? () {
                        _setCurrentIndex(_currentIndex + 1);
                      }
                    : null,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('下一题'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _setCurrentIndex(int index) {
    setState(() {
      _currentIndex = index;
      _markQuestionSeen(_questions[index]);
    });
    final userService = context.read<UserProgressService>();
    _saveOperationalDrillingState(userService);
  }

  void _markQuestionSeen(CodeQuestion question) {
    if (!_seenQuestionIds.contains(question.id)) {
      _seenQuestionIds.add(question.id);
    }
    _questionStatusMap.putIfAbsent(question.id, () => AnswerStatus.unanswered);
  }

  Widget _buildAnswerCard({
    required int questionNumber,
    required AnswerStatus status,
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
        case AnswerStatus.correct:
          backgroundColor = Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.2);
          borderColor = Theme.of(context).colorScheme.tertiary;
          textColor = Theme.of(context).colorScheme.onSurface;
          break;
        case AnswerStatus.incorrect:
          backgroundColor = Theme.of(context).colorScheme.error.withValues(alpha: 0.2);
          borderColor = Theme.of(context).colorScheme.error;
          textColor = Theme.of(context).colorScheme.onSurface;
          break;
        case AnswerStatus.unanswered:
          backgroundColor = Colors.transparent;
          borderColor = Theme.of(context).colorScheme.outline.withValues(alpha: 0.3);
          textColor = Theme.of(context).colorScheme.onSurfaceVariant;
          break;
        case AnswerStatus.unseen:
          backgroundColor = Colors.transparent;
          borderColor = Theme.of(context).colorScheme.outline.withValues(alpha: 0.1);
          textColor = Theme.of(context).colorScheme.outlineVariant;
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

  Future<void> _saveOperationalDrillingState(UserProgressService userService) async {
    final questionStatusMapString = <String, String>{};
    for (var entry in _questionStatusMap.entries) {
      questionStatusMapString[entry.key] = entry.value.toString().split('.').last;
    }

    await userService.saveOperationalDrillingState(
      questionIds: _questions.map((q) => q.id).toList(),
      currentIndex: _currentIndex,
      seenQuestionIds: _seenQuestionIds.toList(),
      questionStatusMap: questionStatusMapString,
      questionAnswers: _userAnswers,
      submittedStates: _submittedStates,
      isCorrectStates: _isCorrectStates,
    );
  }
}

enum AnswerStatus { unseen, unanswered, correct, incorrect }

extension on double {
  Widget get verticalSpace => SizedBox(height: this);
  Widget get horizontalSpace => SizedBox(width: this);
}
