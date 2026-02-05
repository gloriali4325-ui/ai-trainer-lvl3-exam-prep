import 'package:flutter/material.dart';
import 'package:ai_coach/models/question.dart';
import 'package:ai_coach/theme.dart';
import 'package:ai_coach/widgets/code_runner.dart';

class QuestionCard extends StatelessWidget {
  final Question question;
  final int questionNumber;
  final dynamic selectedAnswer;
  final Function(dynamic) onAnswerSelected;
  final bool showExplanation;
  final String? explanationOverride;
  final bool readOnly;
  final dynamic correctAnswer;
  final bool showResultSummary;
  final String? userAnswerText;
  final String? correctAnswerText;
  final String? resultStatusText;

  const QuestionCard({
    super.key,
    required this.question,
    required this.questionNumber,
    required this.selectedAnswer,
    required this.onAnswerSelected,
    this.showExplanation = false,
    this.explanationOverride,
    this.readOnly = false,
    this.correctAnswer,
    this.showResultSummary = false,
    this.userAnswerText,
    this.correctAnswerText,
    this.resultStatusText,
  });

  @override
  Widget build(BuildContext context) {
    final explanationText = explanationOverride ?? question.explanation;
    final answerIsUnanswered = (userAnswerText ?? '').trim() == '未作答';
    final resultStatus = (resultStatusText ?? '').trim();
    final resultIsCorrect = resultStatus == '正确';
    final resultIsUnanswered = resultStatus == '未作答';
    final userAnswerColor = answerIsUnanswered
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : resultIsCorrect
            ? Theme.of(context).colorScheme.secondary
            : Theme.of(context).colorScheme.error;
    final resultColor = resultIsCorrect
        ? Theme.of(context).colorScheme.secondary
        : resultIsUnanswered
            ? Theme.of(context).colorScheme.onSurfaceVariant
            : Theme.of(context).colorScheme.error;
    return Card(
      margin: AppSpacing.paddingMd,
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    '第 $questionNumber 题',
                    style: context.textStyles.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                AppSpacing.sm.horizontalSpace,
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: question.section == QuestionSection.theoretical
                        ? Theme.of(context).colorScheme.secondaryContainer
                        : Theme.of(context).colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    question.section == QuestionSection.theoretical ? '📚 Theory' : '💻 Code',
                    style: context.textStyles.labelSmall,
                  ),
                ),
              ],
            ),
            AppSpacing.md.verticalSpace,
            Text(
              question.text,
              style: context.textStyles.bodyLarge?.semiBold,
            ),
            AppSpacing.lg.verticalSpace,
            if (question is TheoryQuestion) _buildTheoryOptions(context, question as TheoryQuestion),
            if (question is CodeQuestion)
              CodeRunner(
                question: question as CodeQuestion,
                initialCode: selectedAnswer as String?,
                onCodeChanged: onAnswerSelected,
              ),
            if (showResultSummary) ...[
              AppSpacing.lg.verticalSpace,
              Container(
                padding: AppSpacing.paddingMd,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '你的答案：${userAnswerText ?? ''}',
                      style: context.textStyles.bodyMedium?.copyWith(
                        color: userAnswerColor,
                      ),
                    ),
                    AppSpacing.xs.verticalSpace,
                    Text(
                      '正确答案：${correctAnswerText ?? ''}',
                      style: context.textStyles.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                    AppSpacing.xs.verticalSpace,
                    Text(
                      '本题结果：${resultStatusText ?? ''}',
                      style: context.textStyles.bodyMedium?.copyWith(
                        color: resultColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (showExplanation) ...[
              AppSpacing.lg.verticalSpace,
              Container(
                padding: AppSpacing.paddingMd,
                decoration: BoxDecoration(
                  color: question.checkAnswer(selectedAnswer)
                      ? Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3)
                      : Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: question.checkAnswer(selectedAnswer)
                        ? Theme.of(context).colorScheme.secondary
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      explanationText,
                      style: context.textStyles.bodyMedium,
                    ),
                    if (question is CodeQuestion && (question as CodeQuestion).correctCode.isNotEmpty) ...[
                      AppSpacing.md.verticalSpace,
                      Text(
                        '参考答案：',
                        style: context.textStyles.labelLarge,
                      ),
                      AppSpacing.sm.verticalSpace,
                      Container(
                        width: double.infinity,
                        padding: AppSpacing.paddingMd,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: Theme.of(context).colorScheme.outline),
                        ),
                        child: SelectableText(
                          (question as CodeQuestion).correctCode,
                          style: context.textStyles.bodyMedium?.copyWith(fontFamily: 'monospace'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTheoryOptions(BuildContext context, TheoryQuestion question) {
    if (readOnly) {
      return _buildReadOnlyOptions(context, question);
    }
    if (question.type == QuestionType.trueFalse || question.type == QuestionType.singleChoice) {
      return Column(
        children: question.options.map((option) {
          final isSelected = selectedAnswer == option;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => onAnswerSelected(option),
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                padding: AppSpacing.paddingMd,
                decoration: BoxDecoration(
                  color: isSelected ? Theme.of(context).colorScheme.primaryContainer : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    AppSpacing.md.horizontalSpace,
                    Expanded(
                      child: Text(
                        option,
                        style: context.textStyles.bodyMedium?.copyWith(
                          color: isSelected ? Theme.of(context).colorScheme.onPrimaryContainer : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      );
    } else {
      return Column(
        children: question.options.map((option) {
          final selectedList = selectedAnswer is List ? selectedAnswer as List : [];
          final isSelected = selectedList.contains(option);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () {
                final newSelection = List.from(selectedList);
                if (isSelected) {
                  newSelection.remove(option);
                } else {
                  newSelection.add(option);
                }
                onAnswerSelected(newSelection);
              },
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                padding: AppSpacing.paddingMd,
                decoration: BoxDecoration(
                  color: isSelected ? Theme.of(context).colorScheme.primaryContainer : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                      color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    AppSpacing.md.horizontalSpace,
                    Expanded(
                      child: Text(
                        option,
                        style: context.textStyles.bodyMedium?.copyWith(
                          color: isSelected ? Theme.of(context).colorScheme.onPrimaryContainer : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      );
    }
  }

  Widget _buildReadOnlyOptions(BuildContext context, TheoryQuestion question) {
    final correctSet = _normalizeAnswerSet(question, correctAnswer ?? question.correctAnswer);
    final userSet = _normalizeAnswerSet(question, selectedAnswer);

    return Column(
      children: question.options.map((option) {
        final isCorrect = correctSet.contains(option);
        final isUserSelected = userSet.contains(option);
        final isUserWrong = isUserSelected && !isCorrect;

        Color? borderColor = Theme.of(context).colorScheme.outline;
        Color? backgroundColor = Colors.transparent;
        IconData? statusIcon;
        Color? statusColor;

        if (isCorrect) {
          borderColor = Theme.of(context).colorScheme.secondary;
          backgroundColor = Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.25);
          statusIcon = Icons.check_circle;
          statusColor = Theme.of(context).colorScheme.secondary;
        } else if (isUserWrong) {
          borderColor = Theme.of(context).colorScheme.error;
          backgroundColor = Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.25);
          statusIcon = Icons.cancel;
          statusColor = Theme.of(context).colorScheme.error;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: AppSpacing.paddingMd,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: borderColor,
                width: isCorrect || isUserWrong ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                if (statusIcon != null)
                  Icon(
                    statusIcon,
                    color: statusColor,
                  )
                else
                  Icon(
                    Icons.circle_outlined,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                AppSpacing.md.horizontalSpace,
                Expanded(
                  child: Text(
                    option,
                    style: context.textStyles.bodyMedium?.copyWith(
                      color: isCorrect
                          ? Theme.of(context).colorScheme.onSecondaryContainer
                          : isUserWrong
                              ? Theme.of(context).colorScheme.onErrorContainer
                              : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Set<String> _normalizeAnswerSet(TheoryQuestion question, dynamic answer) {
    if (answer == null) return {};
    if (answer is List) {
      return answer.map((item) => _normalizeAnswer(question, item)).whereType<String>().toSet();
    }
    final normalized = _normalizeAnswer(question, answer);
    return normalized == null ? {} : {normalized};
  }

  String? _normalizeAnswer(TheoryQuestion question, dynamic answer) {
    if (answer == null) return null;
    if (answer is String) {
      final trimmed = answer.trim();
      if (trimmed.isEmpty) return null;
      if (_isTrueFalseToken(trimmed)) {
        return _mapTrueFalseToken(trimmed, question.options);
      }
      final match = question.options.firstWhere(
        (option) => option.trim() == trimmed,
        orElse: () => '',
      );
      return match.isNotEmpty ? match : trimmed;
    }
    if (answer is bool) {
      return answer ? _mapTrueFalseToken('T', question.options) : _mapTrueFalseToken('F', question.options);
    }
    if (answer is num) {
      if (answer == 1) return _mapTrueFalseToken('T', question.options);
      if (answer == 0) return _mapTrueFalseToken('F', question.options);
    }
    return answer.toString();
  }

  bool _isTrueFalseToken(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized == 't' ||
        normalized == 'f' ||
        normalized == 'true' ||
        normalized == 'false' ||
        normalized == '正确' ||
        normalized == '错误' ||
        normalized == '对' ||
        normalized == '错' ||
        normalized == '是' ||
        normalized == '否';
  }

  String _mapTrueFalseToken(String token, List<String> options) {
    if (options.isEmpty) return token;
    final normalized = token.trim().toLowerCase();
    if (normalized == 't' || normalized == 'true' || normalized == '正确' || normalized == '对' || normalized == '是') {
      return options.first;
    }
    if (normalized == 'f' || normalized == 'false' || normalized == '错误' || normalized == '错' || normalized == '否') {
      return options.length > 1 ? options[1] : options.first;
    }
    return token;
  }

}

extension on double {
  Widget get horizontalSpace => SizedBox(width: this);
  Widget get verticalSpace => SizedBox(height: this);
}
