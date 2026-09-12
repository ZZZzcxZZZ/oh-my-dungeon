import 'package:flutter/material.dart';

import '../../domain/content_import_report.dart';

/// 诊断列表（导入预览 / 批量导入向导**共用**）：error 用 `error` 色，
/// warning 用次级样式（`tertiary` + info 图标）。
///
/// 两种样式在这里只有一份渲染参数（icon 16 / gap 6 / `labelLarge` 标题 /
/// `bodyMedium` 正文）：以前批量导入向导自己拼了一套（icon 14 / gap 4 /
/// `bodySmall`），同一个 warning 在两个对话框里长得不一样。
///
/// 长列表**不静默截断**：最多渲染 [maxVisible] 条，其余用"还有 N 条"说明
/// （本组件存在的理由之一就是"诊断不能静默丢掉"）。[keyPrefix] 给每条诊断
/// 一个**带索引**的 key，同一包的 N 条 warning 各有各的定位点。
class ContentDiagnosticList extends StatelessWidget {
  const ContentDiagnosticList({
    required this.diagnostics,
    this.warning = false,
    this.maxVisible = 3,
    this.keyPrefix,
    super.key,
  });

  final List<ContentValidationError> diagnostics;
  final bool warning;

  /// 最多渲染多少条；其余折叠成"还有 N 条（共 M 条）"。
  final int maxVisible;

  /// 每条诊断的 key 前缀（如 `batch-import-warning-gamma`）；实际 key 会
  /// 追加 `-<索引>`，同一列表内不重复。
  final String? keyPrefix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = warning
        ? theme.colorScheme.tertiary
        : theme.colorScheme.error;
    final visible = diagnostics.take(maxVisible).toList(growable: false);
    final hidden = diagnostics.length - visible.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (warning)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  '提示（不阻断导入）',
                  style: theme.textTheme.labelLarge?.copyWith(color: color),
                ),
              ],
            ),
          ),
        for (var index = 0; index < visible.length; index++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '${visible[index].path}: ${visible[index].message}',
              key: keyPrefix == null ? null : Key('$keyPrefix-$index'),
              style: theme.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
        if (hidden > 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '还有 $hidden 条（共 ${diagnostics.length} 条）',
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
      ],
    );
  }
}
