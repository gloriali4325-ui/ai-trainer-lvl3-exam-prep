import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:ai_coach/services/user_progress_service.dart';
import 'package:ai_coach/services/user_statistics_service.dart';
import 'package:ai_coach/services/question_bank_service.dart';
import 'package:ai_coach/services/mistake_notebook_service.dart';
import 'package:ai_coach/services/auth_service.dart';
import 'package:ai_coach/widgets/statistics_card.dart';
import 'package:ai_coach/theme.dart';
import 'package:ai_coach/nav.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    final userService = context.read<UserProgressService>();
    final statisticsService = context.read<UserStatisticsService>();
    final questionService = context.read<QuestionBankService>();
    final mistakeService = context.read<MistakeNotebookService>();

    await Future.wait([
      userService.initialize(),
      statisticsService.initialize(),
      questionService.initialize(),
      mistakeService.initialize(),
    ]);
  }

  Future<void> _handleAccountAction(_AccountAction action) async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (context) {
            final title = action == _AccountAction.switchUser ? '切换账号' : '退出登录';
            final message = action == _AccountAction.switchUser
                ? '确定要切换账号吗？当前账号会退出登录。'
                : '确定要退出登录吗？';
            return AlertDialog(
              title: Text(title),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('确定'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirm || !mounted) return;

    final userService = context.read<UserProgressService>();
    await AuthService().signOut();
    await userService.clearLocalUser();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已退出登录')),
    );
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer4<UserProgressService, UserStatisticsService, QuestionBankService,
            MistakeNotebookService>(
          builder: (context, userService, statisticsService, questionService, mistakeService, child) {
            if (userService.isLoading || questionService.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final user = userService.currentUser;
            if (user == null) {
              return const Center(child: Text('无法加载用户数据'));
            }

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: AppSpacing.paddingMd,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '人工智能训练师考试备考',
                                    style: context.textStyles.headlineMedium?.bold,
                                  ),
                                  AppSpacing.xs.verticalSpace,
                                  Text(
                                    '三级职业技能等级证书',
                                    style: context.textStyles.titleMedium?.withColor(
                                      Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _AccountMenuButton(
                              displayName: user.name,
                              onActionSelected: _handleAccountAction,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.md.verticalSpace,
                  Padding(
                    padding: AppSpacing.horizontalMd,
                    child: GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisSpacing: AppSpacing.md,
                      childAspectRatio: 1.3,
                      children: [
                        StatisticsCard(
                          title: '已答题目',
                          value: '${statisticsService.totalQuestionsAttempted}',
                          icon: Icons.psychology,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        StatisticsCard(
                          title: '正确率',
                          value: '${statisticsService.accuracyRate.toStringAsFixed(1)}%',
                          icon: Icons.track_changes,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        StatisticsCard(
                          title: '模拟测试',
                          value: '${statisticsService.mockExamsTaken}',
                          icon: Icons.assessment,
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                        StatisticsCard(
                          title: '错题本',
                          value: '${mistakeService.unreviewedMistakes.length}',
                          icon: Icons.error_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.lg.verticalSpace,
                  Padding(
                    padding: AppSpacing.horizontalMd,
                    child: Text(
                      '选择练习模式',
                      style: context.textStyles.titleLarge?.semiBold,
                    ),
                  ),
                  AppSpacing.md.verticalSpace,
                  Padding(
                    padding: AppSpacing.horizontalMd,
                    child: Text(
                      '随机练习',
                      style: context.textStyles.titleMedium?.semiBold,
                    ),
                  ),
                  AppSpacing.sm.verticalSpace,
                  _ModeTile(
                    icon: Icons.psychology,
                    title: '理论知识 · 随机练习',
                    subtitle: '单选 / 多选 / 判断',
                    color: Colors.blue,
                    onTap: () => context.push(AppRoutes.drilling),
                  ),
                  _ModeTile(
                    icon: Icons.code,
                    title: '操作技能 · 随机练习',
                    subtitle: 'Code / 数据分析 / 实操任务',
                    color: Colors.purple,
                    onTap: () => context.push(AppRoutes.drillingOperational),
                  ),
                  AppSpacing.lg.verticalSpace,
                  Padding(
                    padding: AppSpacing.horizontalMd,
                    child: Text(
                      '分类学习',
                      style: context.textStyles.titleMedium?.semiBold,
                    ),
                  ),
                  AppSpacing.md.verticalSpace,
                  _ModeTile(
                    icon: Icons.category,
                    title: '分类练习',
                    subtitle: '按特定主题学习',
                    color: Colors.green,
                    onTap: () => context.push('/categorized'),
                  ),
                  _ModeTile(
                    icon: Icons.timer,
                    title: '模拟考试',
                    subtitle: '全真模拟考试（限时）',
                    color: Colors.orange,
                    onTap: () => context.push('/mock-exam'),
                  ),
                  _ModeTile(
                    icon: Icons.bookmark,
                    title: '错题本',
                    subtitle: '查看和复习错题',
                    color: Colors.red,
                    onTap: () => context.push('/mistakes'),
                  ),
                  AppSpacing.lg.verticalSpace,
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ModeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: AppSpacing.paddingMd,
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                AppSpacing.md.horizontalSpace,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: context.textStyles.titleMedium?.semiBold,
                      ),
                      AppSpacing.xs.verticalSpace,
                      Text(
                        subtitle,
                        style: context.textStyles.bodySmall?.withColor(
                          Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _AccountAction { switchUser, signOut }

class _AccountMenuButton extends StatelessWidget {
  final String displayName;
  final ValueChanged<_AccountAction> onActionSelected;

  const _AccountMenuButton({
    required this.displayName,
    required this.onActionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final initials = displayName.trim().isEmpty ? 'U' : displayName.trim().substring(0, 1).toUpperCase();

    return PopupMenuButton<_AccountAction>(
      onSelected: onActionSelected,
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _AccountAction.switchUser,
          child: Text('切换账号'),
        ),
        PopupMenuItem(
          value: _AccountAction.signOut,
          child: Text('退出登录'),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
              child: Text(
                initials,
                style: context.textStyles.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            AppSpacing.xs.horizontalSpace,
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.labelLarge,
              ),
            ),
            AppSpacing.xs.horizontalSpace,
            Icon(
              Icons.expand_more,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

extension on double {
  Widget get horizontalSpace => SizedBox(width: this);
  Widget get verticalSpace => SizedBox(height: this);
}
