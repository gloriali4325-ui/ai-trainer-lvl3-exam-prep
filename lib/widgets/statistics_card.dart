import 'package:flutter/material.dart';
import 'package:ai_coach/theme.dart';

class StatisticsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? color;

  const StatisticsCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = color ?? Theme.of(context).colorScheme.primary;

    return Card(
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: cardColor, size: 32),
            AppSpacing.md.verticalSpace,
            Text(
              value,
              style: context.textStyles.headlineMedium?.semiBold.withColor(cardColor),
            ),
            AppSpacing.xs.verticalSpace,
            Text(
              title,
              style: context.textStyles.bodySmall?.withColor(
                Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

extension on double {
  Widget get verticalSpace => SizedBox(height: this);
}
