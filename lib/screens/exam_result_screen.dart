import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:ai_coach/services/exam_service.dart';
import 'package:ai_coach/theme.dart';

class ExamResultScreen extends StatelessWidget {
  final String resultId;

  const ExamResultScreen({super.key, required this.resultId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('考试成绩'),
        automaticallyImplyLeading: false,
      ),
      body: Consumer<ExamService>(
        builder: (context, examService, child) {
          final result = examService.examResults.cast<dynamic>().firstWhere(
                (r) => r.id == resultId,
                orElse: () => null,
              );

          if (result == null) {
            return const Center(child: Text('成绩信息未找到'));
          }

          final scorePercentage = result.scorePercentage;
          final passed = result.passed;
          final minutes = result.duration ~/ 60;
          final seconds = result.duration % 60;

          return SingleChildScrollView(
            child: Padding(
              padding: AppSpacing.paddingLg,
              child: Column(
                children: [
                  AppSpacing.lg.verticalSpace,
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: passed
                          ? Theme.of(context).colorScheme.secondaryContainer
                          : Theme.of(context).colorScheme.errorContainer,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            passed ? Icons.check_circle : Icons.cancel,
                            size: 60,
                            color: passed
                                ? Theme.of(context).colorScheme.secondary
                                : Theme.of(context).colorScheme.error,
                          ),
                          AppSpacing.xs.verticalSpace,
                          Text(
                            passed ? '通过' : '未通过',
                            style: context.textStyles.titleLarge?.bold.withColor(
                              passed
                                  ? Theme.of(context).colorScheme.secondary
                                  : Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AppSpacing.xl.verticalSpace,
                  Text(
                    '${scorePercentage.toStringAsFixed(1)}%',
                    style: context.textStyles.displayLarge?.bold.withColor(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  AppSpacing.xs.verticalSpace,
                  Text(
                    '${result.totalScore.toStringAsFixed(1)} / ${result.maxScore.toStringAsFixed(1)} 分',
                    style: context.textStyles.bodyLarge?.withColor(
                      Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  AppSpacing.xl.verticalSpace,
                  Card(
                    child: Padding(
                      padding: AppSpacing.paddingLg,
                      child: Column(
                        children: [
                          _ResultRow(
                            icon: Icons.quiz,
                            label: '总题数',
                            value: '${result.totalQuestions}',
                          ),
                          const Divider(height: 24),
                          _ResultRow(
                            icon: Icons.check_circle,
                            label: '总分数',
                            value: '${result.totalScore.toStringAsFixed(1)}',
                            valueColor: Theme.of(context).colorScheme.secondary,
                          ),
                          const Divider(height: 24),
                          _ResultRow(
                            icon: Icons.cancel,
                            label: '满分',
                            value: '${result.maxScore.toStringAsFixed(1)}',
                            valueColor: Theme.of(context).colorScheme.error,
                          ),
                          const Divider(height: 24),
                          _ResultRow(
                            icon: Icons.timer,
                            label: '耗时',
                            value: '${minutes} 分 ${seconds} 秒',
                          ),
                        ],
                      ),
                    ),
                  ),
                  AppSpacing.xl.verticalSpace,
                  if (!passed)
                    Container(
                      padding: AppSpacing.paddingMd,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          AppSpacing.md.horizontalSpace,
                          Expanded(
                            child: Text(
                              '需要达到60%或以上才能通过。继续加油！',
                              style: context.textStyles.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  AppSpacing.xl.verticalSpace,
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => context.go('/'),
                      icon: const Icon(Icons.home, color: Colors.white),
                      label: const Text('返回首页', style: TextStyle(color: Colors.white)),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  AppSpacing.md.verticalSpace,
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        context.go('/');
                        Future.delayed(const Duration(milliseconds: 100), () {
                          context.push('/mock-exam');
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('再考一次'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _ResultRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        AppSpacing.md.horizontalSpace,
        Expanded(
          child: Text(
            label,
            style: context.textStyles.bodyMedium,
          ),
        ),
        Text(
          value,
          style: context.textStyles.titleMedium?.semiBold.withColor(
            valueColor ?? Theme.of(context).colorScheme.onSurface,
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
