import 'package:flutter/material.dart';

import '../../domain/declared_levels.dart';

/// 职业声明范围（契约 §3.12）的共用信息条。
///
/// 只在**信息级**提示，不使用 error 色：超出最后声明等级时用
/// `colorScheme.tertiary` 说明"该职业未声明 N 级以上内容，你仍可继续"，
/// 声明范围内用 `colorScheme.primary`。
class DeclaredLevelBanner extends StatelessWidget {
  const DeclaredLevelBanner({
    required this.levels,
    required this.currentLevel,
    super.key,
  });

  final DeclaredLevels levels;
  final int currentLevel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final detail = levels.detailLabel(currentLevel);
    final undeclared = levels.isEmpty || detail != null;
    final color = undeclared ? colorScheme.tertiary : colorScheme.primary;
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              undeclared ? Icons.info_outline : Icons.rule_outlined,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(levels.rangeLabel, style: theme.textTheme.bodyMedium),
                  if (detail != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      style: theme.textTheme.bodySmall?.copyWith(color: color),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 未声明等级的法术位 / 职业资源区文案（**不渲染成 0**）。
///
/// 角色卡上"这个等级职业没声明过内容"必须可见：显示这句话，而不是 `0`。
class UndeclaredLevelNotice extends StatelessWidget {
  const UndeclaredLevelNotice({super.key});

  /// 该职业未声明该等级的内容（数值型未声明不得渲染成 0）。
  static const String label = '该职业未声明该等级的内容';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.info_outline, size: 18, color: theme.colorScheme.tertiary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.tertiary,
            ),
          ),
        ),
      ],
    );
  }
}
