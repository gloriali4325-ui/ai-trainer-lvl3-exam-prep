import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:ai_coach/models/category.dart';
import 'package:ai_coach/models/question.dart';
import 'package:ai_coach/services/question_bank_service.dart';
import 'package:ai_coach/theme.dart';

class CategorizedTrainingScreen extends StatelessWidget {
  const CategorizedTrainingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('分类练习'),
      ),
      body: Consumer<QuestionBankService>(
        builder: (context, questionService, child) {
          final categories = questionService.categories;

          if (categories.isEmpty) {
            return const Center(child: Text('暂无分类'));
          }

          // 按模块分组：理论知识和操作技能
          final theoreticalCategories = <Category>[];
          final operationalCategories = <Category>[];

          for (final category in categories) {
            final questions = questionService.getQuestionsByCategory(category.id);
            if (questions.isEmpty) {
              theoreticalCategories.add(category);
            } else {
              final isOperational = questions.first.section == QuestionSection.operational;
              if (isOperational) {
                operationalCategories.add(category);
              } else {
                theoreticalCategories.add(category);
              }
            }
          }

          return ListView(
            padding: AppSpacing.paddingMd,
            children: [
              // 理论知识模块
              if (theoreticalCategories.isNotEmpty)
                _ModuleSection(
                  title: '理论知识',
                  description: '通过习题巩固知识，掌握理论基础',
                  icon: Icons.school,
                  backgroundColor: const Color(0xFFE8F5E9),
                  iconColor: const Color(0xFF2E7D32),
                  children: theoreticalCategories.map((category) {
                    final questions = questionService.getQuestionsByCategory(category.id);
                    return _CategoryCard(
                      category: category,
                      questionCount: questions.length,
                      isOperational: false,
                      onTap: () {
                        context.push('/category/${category.id}');
                      },
                    );
                  }).toList(),
                ),
              if (theoreticalCategories.isNotEmpty && operationalCategories.isNotEmpty)
                AppSpacing.lg.verticalSpace,

              // 操作技能模块
              if (operationalCategories.isNotEmpty)
                _ModuleSection(
                  title: '操作技能',
                  description: '通过实践任务锻炼动手能力',
                  icon: Icons.code,
                  backgroundColor: const Color(0xFFE3F2FD),
                  iconColor: const Color(0xFF1565C0),
                  children: operationalCategories.map((category) {
                    final questions = questionService.getQuestionsByCategory(category.id);
                    return _CategoryCard(
                      category: category,
                      questionCount: questions.length,
                      isOperational: true,
                      onTap: () {
                        context.push('/operational-skills/${category.id}');
                      },
                    );
                  }).toList(),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ModuleSection extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final List<Widget> children;

  const _ModuleSection({
    required this.title,
    required this.description,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 模块标题栏
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: iconColor,
                size: 28,
              ),
              AppSpacing.md.horizontalSpace,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.textStyles.titleMedium?.copyWith(
                        color: iconColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    AppSpacing.xs.verticalSpace,
                    Text(
                      description,
                      style: context.textStyles.bodySmall?.copyWith(
                        color: iconColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        AppSpacing.md.verticalSpace,

        // 分类卡片列表
        ...children.map((child) => Column(
              children: [
                child,
                AppSpacing.sm.verticalSpace,
              ],
            )),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final Category category;
  final int questionCount;
  final bool isOperational;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.category,
    required this.questionCount,
    this.isOperational = false,
    required this.onTap,
  });

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'label':
        return Icons.label;
      case 'assessment':
        return Icons.assessment;
      case 'device_hub':
        return Icons.device_hub;
      case 'code':
        return Icons.code;
      case 'psychology':
        return Icons.psychology;
      default:
        return Icons.book;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = isOperational
        ? const Color(0xFF7B1FA2)
        : const Color(0xFFC2185B);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border(
              left: BorderSide(
                color: accentColor,
                width: 4,
              ),
            ),
          ),
          child: Padding(
            padding: AppSpacing.paddingMd,
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    _getIconData(category.icon),
                    color: accentColor,
                    size: 32,
                  ),
                ),
                AppSpacing.md.horizontalSpace,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              category.name,
                              style: context.textStyles.titleMedium?.semiBold,
                            ),
                          ),
                          // 类型标签
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.15),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              isOperational ? '实践' : '刷题',
                              style: context.textStyles.labelSmall?.copyWith(
                                color: accentColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      AppSpacing.xs.verticalSpace,
                      Text(
                        category.description,
                        style: context.textStyles.bodySmall?.withColor(
                          Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      AppSpacing.xs.verticalSpace,
                      Text(
                        '$questionCount 题',
                        style: context.textStyles.labelSmall?.withColor(
                          accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
                AppSpacing.sm.horizontalSpace,
                Icon(
                  Icons.arrow_forward_ios,
                  color: accentColor.withValues(alpha: 0.6),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension on double {
  Widget get horizontalSpace => SizedBox(width: this);
  Widget get verticalSpace => SizedBox(height: this);
}
