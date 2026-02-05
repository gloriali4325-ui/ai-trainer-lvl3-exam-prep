import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:ai_coach/models/question.dart';
import 'package:ai_coach/models/mistake_record.dart';
import 'package:ai_coach/services/mistake_notebook_service.dart';
import 'package:ai_coach/services/question_bank_service.dart';
import 'package:ai_coach/services/user_progress_service.dart';
import 'package:ai_coach/widgets/question_card.dart';
import 'package:ai_coach/theme.dart';
import 'package:ai_coach/screens/mistake_reinforcement_screen.dart';

class MistakeNotebookScreen extends StatefulWidget {
  const MistakeNotebookScreen({super.key});

  @override
  State<MistakeNotebookScreen> createState() => _MistakeNotebookScreenState();
}

class _MistakeNotebookScreenState extends State<MistakeNotebookScreen> {
  int? _currentMistakeIndex;

  // 获取错题类型标签 - 区分答错题和未作答题
  Widget _buildMistakeTypeTag(MistakeType type, BuildContext context) {
    if (type == MistakeType.unanswered) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0).withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: const Color(0xFFFF9800).withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.help_outline,
              size: 14,
              color: const Color(0xFFE65100),
            ),
            const SizedBox(width: 4),
            Text(
              '未作答题',
              style: context.textStyles.labelSmall?.copyWith(
                color: const Color(0xFFE65100),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: Theme.of(context).colorScheme.error.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.close_rounded,
              size: 14,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 4),
            Text(
              '答错题',
              style: context.textStyles.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
  }

  // 获取错题状态标签
  Widget _buildStatusTag(MistakeStatus status, BuildContext context) {
    switch (status) {
      case MistakeStatus.mastered:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle,
                size: 12,
                color: Colors.green,
              ),
              const SizedBox(width: 3),
              Text(
                '已掌握',
                style: context.textStyles.labelSmall?.copyWith(
                  color: Colors.green,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        );
      case MistakeStatus.reinforced:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.flash_on,
                size: 12,
                color: Colors.blue,
              ),
              const SizedBox(width: 3),
              Text(
                '强化中',
                style: context.textStyles.labelSmall?.copyWith(
                  color: Colors.blue,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        );
      case MistakeStatus.continued:
      case MistakeStatus.reviewing:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.schedule,
                size: 12,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 3),
              Text(
                '复习中',
                style: context.textStyles.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        );
    }
  }

  // 格式化正确答案
  String _formatCorrectAnswer(Question question) {
    if (question is TheoryQuestion) {
      if (question.correctAnswer == null) return '[正确答案未定义]';

      if (question.type == QuestionType.trueFalse) {
        return _formatTrueFalseAnswer(question.correctAnswer);
      } else if (question.type == QuestionType.singleChoice) {
        return question.correctAnswer.toString().trim();
      } else if (question.type == QuestionType.multipleChoice) {
        final correctAnswers = question.correctAnswer as List?;
        if (correctAnswers == null || correctAnswers.isEmpty) {
          return '[多选答案为空]';
        }
        return correctAnswers.join('、');
      }
      return question.correctAnswer.toString();
    } else if (question is CodeQuestion) {
      if (question.correctKeywords.isNotEmpty) {
        return '关键词：${question.correctKeywords.join('、')}';
      }
      if (question.correctCode.isNotEmpty) {
        return '正确代码：${question.correctCode}';
      }
      return '[正确答案未定义]';
    }
    return '[无法获取答案]';
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

  // 移到下一个错题
  void _moveToNextMistake(MistakeNotebookService mistakeService) {
    final mistakes = mistakeService.getUnmasteredMistakes();
    if (_currentMistakeIndex != null) {
      if (_currentMistakeIndex! < mistakes.length - 1) {
        setState(() {
          _currentMistakeIndex = _currentMistakeIndex! + 1;
        });
      } else {
        setState(() {
          _currentMistakeIndex = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('错题本'),
      ),
      body: Consumer3<MistakeNotebookService, QuestionBankService, UserProgressService>(
        builder: (context, mistakeService, questionService, userService, child) {
          final mistakes = mistakeService.getUnmasteredMistakes();
          mistakes.sort((a, b) {
            final aRank = a.status == MistakeStatus.reinforced ? 0 : 1;
            final bRank = b.status == MistakeStatus.reinforced ? 0 : 1;
            return aRank.compareTo(bRank);
          });
          final reinforcedMistakes = mistakes.where((m) => m.status == MistakeStatus.reinforced).toList();

          if (mistakes.isEmpty) {
            return Center(
              child: Padding(
                padding: AppSpacing.paddingLg,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 80,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    AppSpacing.lg.verticalSpace,
                    Text(
                      '恭喜！已掌握所有错题！',
                      style: context.textStyles.headlineSmall?.bold,
                    ),
                    AppSpacing.md.verticalSpace,
                    Text(
                      '你已经成功完成所有错题的复习。继续加油！',
                      style: context.textStyles.bodyMedium?.withColor(
                        Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          // 详细题目复盘视图
          if (_currentMistakeIndex != null && _currentMistakeIndex! < mistakes.length) {
            final mistake = mistakes[_currentMistakeIndex!];
            debugPrint('[MistakeNotebook] showing detail for mistakeId=${mistake.id}, questionId=${mistake.questionId}');
            final question = questionService.getQuestionById(mistake.questionId);

            if (question == null) {
              debugPrint('[MistakeNotebook] question not found for id=${mistake.questionId}');
              return Center(child: Text('题目未找到（id=${mistake.questionId}）'));
            }

            debugPrint('[MistakeNotebook] question found: ${question.id}');

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // 错题类型提示区域 - 明确区分错题来源
                        Container(
                          width: double.infinity,
                          padding: AppSpacing.paddingMd,
                          decoration: BoxDecoration(
                            color: mistake.mistakeType == MistakeType.unanswered
                                ? const Color(0xFFFFF3E0)
                                : Theme.of(context).colorScheme.errorContainer,
                            border: Border(
                              bottom: BorderSide(
                                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _buildMistakeTypeTag(mistake.mistakeType, context),
                                  const Spacer(),
                                  _buildStatusTag(mistake.status, context),
                                ],
                              ),
                              AppSpacing.md.verticalSpace,
                              Text(
                                mistake.mistakeType == MistakeType.unanswered
                                    ? '⚠️ 此题未作答 - 你在考试时未选择任何答案'
                                    : '❌ 答错题 - 你选择的答案有误',
                                style: context.textStyles.bodyMedium?.copyWith(
                                  color: mistake.mistakeType == MistakeType.unanswered
                                      ? const Color(0xFFE65100)
                                      : Theme.of(context).colorScheme.error,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              AppSpacing.sm.verticalSpace,
                              Text(
                                '尝试次数：${mistake.attemptCount}',
                                style: context.textStyles.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AppSpacing.md.verticalSpace,
                        // 题目卡片
                        Padding(
                          padding: AppSpacing.paddingMd,
                          child: QuestionCard(
                            question: question,
                            questionNumber: (_currentMistakeIndex ?? 0) + 1,
                            selectedAnswer: mistake.userAnswer,
                            onAnswerSelected: (_) {},
                            showExplanation: true,
                          ),
                        ),
                        AppSpacing.md.verticalSpace,
                        // 作答对比区域 - 明确展示答案对比
                        Padding(
                          padding: AppSpacing.paddingMd,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '📋 作答对比',
                                style: context.textStyles.titleMedium?.bold,
                              ),
                              AppSpacing.md.verticalSpace,
                              // 你的答案
                              Container(
                                padding: AppSpacing.paddingMd,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.person,
                                          size: 16,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '你的答案',
                                          style: context.textStyles.labelMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    AppSpacing.sm.verticalSpace,
                                    Text(
                                      mistake.userAnswer == null ? '未作答' : mistake.userAnswer.toString(),
                                      style: context.textStyles.bodyMedium?.copyWith(
                                        color: mistake.userAnswer == null
                                            ? Theme.of(context).colorScheme.onSurfaceVariant
                                            : Theme.of(context).colorScheme.error,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              AppSpacing.md.verticalSpace,
                              // 正确答案
                              Container(
                                padding: AppSpacing.paddingMd,
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  border: Border.all(
                                    color: Colors.green.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '正确答案',
                                          style: context.textStyles.labelMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                    AppSpacing.sm.verticalSpace,
                                    Text(
                                      _formatCorrectAnswer(question),
                                      style: context.textStyles.bodyMedium?.copyWith(
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // 复盘行为引导按钮区域 - 三个复习决策选项
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
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Padding(
                        padding: EdgeInsets.zero,
                        child: Consumer<MistakeNotebookService>(
                          builder: (context, service, _) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _currentMistakeIndex = null;
                                    });
                                  },
                                  icon: const Icon(Icons.arrow_back),
                                  label: const Text('返回'),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${(_currentMistakeIndex ?? 0) + 1} / ${mistakes.length}',
                                  style: context.textStyles.bodyMedium?.semiBold,
                                ),
                                const SizedBox(width: 8),
                                // 已掌握 - 移出错题本
                                Tooltip(
                                  message: '标记为已掌握，将从错题本中移出',
                                  child: FilledButton.icon(
                                    onPressed: () async {
                                      await service.markAsMastered(mistake.id);
                                      _moveToNextMistake(service);
                                    },
                                    icon: const Icon(Icons.check_circle),
                                    label: const Text('已掌握'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.green,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // 继续复习 - 保留在错题本
                                Tooltip(
                                  message: '继续复习此题',
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      await service.markAsContinued(mistake.id);
                                      _moveToNextMistake(service);
                                    },
                                    icon: const Icon(Icons.schedule),
                                    label: const Text('继续复习'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // 加入再练 - 强化练习
                                Tooltip(
                                  message: '加入强化练习',
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      await service.markForReinforcement(mistake.id);
                                      _moveToNextMistake(service);
                                    },
                                    icon: const Icon(Icons.flash_on),
                                    label: const Text('加入再练'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.blue,
                                      side: const BorderSide(color: Colors.blue),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          // 错题列表视图
          return Column(
            children: [
              Padding(
                padding: AppSpacing.paddingMd,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '共 ${mistakes.length} 个待复习错题',
                          style: context.textStyles.bodyMedium?.semiBold,
                        ),
                        Text(
                          '包括 ${mistakes.where((m) => m.mistakeType == MistakeType.unanswered).length} 个未作答 + ${mistakes.where((m) => m.mistakeType == MistakeType.wrongAnswer).length} 个答错 · 强化 ${reinforcedMistakes.length} 个',
                          style: context.textStyles.bodySmall?.withColor(
                            Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (reinforcedMistakes.isNotEmpty) ...[
                          AppSpacing.xs.verticalSpace,
                          Text(
                            '加入再练后会进入强化练习列表，答对自动标记为已掌握。',
                            style: context.textStyles.labelSmall?.withColor(
                              Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        if (reinforcedMistakes.isNotEmpty)
                          TextButton.icon(
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => MistakeReinforcementScreen(
                                    mistakes: reinforcedMistakes,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.flash_on),
                            label: const Text('强化练习'),
                          ),
                        TextButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('清空所有错题？'),
                                content: const Text(
                                  '这将清除你的所有错题。此操作无法撤销。',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => context.pop(),
                                    child: const Text('取消'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      mistakeService.clearAllMistakes();
                                      context.pop();
                                    },
                                    child: const Text('清空'),
                                  ),
                                ],
                              ),
                            );
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('清空'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: AppSpacing.horizontalMd,
                  itemCount: mistakes.length,
                  itemBuilder: (context, index) {
                    final mistake = mistakes[index];
                    final question = questionService.getQuestionById(mistake.questionId);

                    if (question == null) return const SizedBox.shrink();

                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: InkWell(
                        onTap: () {
                          debugPrint('[MistakeNotebook] tapped index=$index');
                          setState(() {
                            _currentMistakeIndex = index;
                          });
                        },
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: Padding(
                          padding: AppSpacing.paddingMd,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _buildMistakeTypeTag(mistake.mistakeType, context),
                                  const Spacer(),
                                  _buildStatusTag(mistake.status, context),
                                ],
                              ),
                              AppSpacing.sm.verticalSpace,
                              Text(
                                question.text,
                                style: context.textStyles.bodyMedium,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              AppSpacing.sm.verticalSpace,
                              Row(
                                children: [
                                  Text(
                                    '尝试 ${mistake.attemptCount} 次',
                                    style: context.textStyles.labelSmall?.withColor(
                                      Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 14,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

extension on double {
  Widget get verticalSpace => SizedBox(height: this);
}
