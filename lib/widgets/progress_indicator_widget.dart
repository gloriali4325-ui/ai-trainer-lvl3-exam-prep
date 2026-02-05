import 'package:flutter/material.dart';
import 'package:ai_coach/theme.dart';

class ProgressIndicatorWidget extends StatelessWidget {
  final double progress;
  final String label;
  final Color? color;

  const ProgressIndicatorWidget({
    super.key,
    required this.progress,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progressColor = color ?? Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: context.textStyles.bodyMedium?.semiBold,
            ),
            Text(
              '${progress.toStringAsFixed(0)}%',
              style: context.textStyles.bodyMedium?.semiBold.withColor(progressColor),
            ),
          ],
        ),
        AppSpacing.sm.verticalSpace,
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: LinearProgressIndicator(
            value: progress / 100,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            color: progressColor,
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

extension on double {
  Widget get verticalSpace => SizedBox(height: this);
}
