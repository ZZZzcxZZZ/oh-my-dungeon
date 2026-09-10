import 'package:flutter/material.dart';

/// 统一空态组件（DESIGN.md Components 约定：空态 = 图标 + 标题，
/// 可选说明与操作）。
///
/// 此前空态各自为政：有纯文字无内边距、有 24/32 内边距、有 headlineSmall
/// 大标题 + CTA 的完整空态；统一后结构、内边距与次级文字风格一致，个别
/// 场景通过 [iconSize]/[iconColor]/[titleStyle] 保留原有视觉层级。
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.iconSize = 48,
    this.iconColor,
    this.titleStyle,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final double iconSize;
  final Color? iconColor;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: iconColor ?? theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: titleStyle ?? theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
