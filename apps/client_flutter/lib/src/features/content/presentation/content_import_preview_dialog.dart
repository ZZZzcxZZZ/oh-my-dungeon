import 'package:flutter/material.dart';

import '../../characters/domain/declared_levels.dart';
import '../../rules/domain/rule_field_path.dart';
import '../../rules/domain/rule_override_declaration.dart';
import '../../rules/domain/rule_profile.dart';
import '../domain/content_import_report.dart';
import 'widgets/content_diagnostic_list.dart';

class ContentImportPreviewDialog extends StatelessWidget {
  const ContentImportPreviewDialog({
    required this.report,
    required this.onConfirm,
    super.key,
  });

  final ContentImportReport report;
  final Future<void> Function() onConfirm;

  @override
  Widget build(BuildContext context) {
    if (report.valid) {
      final theme = Theme.of(context);
      // §3.12：部分声明是一等功能，导入前先把每个职业条目声明的等级范围摆出来
      // （信息样式，不是错误色）。
      final classLevels = <({String name, DeclaredLevels levels})>[
        for (final entry in report.entries)
          if (entry.type == 'class')
            (name: entry.name, levels: DeclaredLevels.fromEntry(entry)),
      ];
      return AlertDialog(
        title: const Text('导入预览'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(report.packageName),
            Text(report.version),
            Text('${report.entryCount} 个条目'),
            for (final item in classLevels) ...[
              const SizedBox(height: 4),
              Text(
                '${item.name} · ${item.levels.rangeLabel}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            // 列级来源摘要（契约 §3.7）：只提示每个条目的列最终取自哪里，不阻断
            // 确认。展示名的唯一实现是 [RuleFieldPath.labelFor]；"来源 id → 展示名"
            // 优先用**包名**（manifest 的 `name` 就是 [report].packageName），包名
            // 为空时才退回包 id——包 id 派生只有 `packageIdOf` 一处（按最后一个 `:`
            // 切分），不在这里 `split(':').first`。
            if (report.classRuleSources.isNotEmpty) ...[
              const SizedBox(height: 12),
              Column(
                key: const Key('import-preview-sources'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('规则来源', style: theme.textTheme.titleSmall),
                  for (final entry in report.classRuleSources.entries)
                    for (final source in entry.value)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${entry.key} · ${RuleFieldPath.labelFor(source.field)}'
                          ' ← ${source.tier == kBuiltinTier ? '内置档案' : _sourceLabel(source.originId)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                ],
              ),
            ],
            // 规则契约的 warning 级诊断：只提示，不阻断导入。
            if (report.warnings.isNotEmpty) ...[
              const SizedBox(height: 12),
              ContentDiagnosticList(
                key: const Key('import-preview-warnings'),
                diagnostics: report.warnings,
                warning: true,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            // 中性 key（不是 `…-sources-confirm`）：这个按钮是**通用**的"确认导入"，
            // 与"是否展示了规则来源"无关——`actions` 在有无 `classRuleSources` 的
            // 两种内容分支里都渲染，测试不该"恰好"才点得到它。
            key: const Key('import-preview-confirm'),
            onPressed: () async {
              await onConfirm();
              if (!context.mounted) return;
              Navigator.of(context).pop();
            },
            child: const Text('确认导入'),
          ),
        ],
      );
    }
    return AlertDialog(
      title: const Text('导入预览'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ContentDiagnosticList(
              key: const Key('import-preview-errors'),
              diagnostics: report.errors,
            ),
            if (report.warnings.isNotEmpty) ...[
              const SizedBox(height: 12),
              ContentDiagnosticList(
                key: const Key('import-preview-warnings'),
                diagnostics: report.warnings,
                warning: true,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  /// 非内置来源的展示名：**包名优先**（manifest 的 `name`），空则退回该来源的包 id。
  ///
  /// 包 id 派生只有 [RuleOverrideDeclaration.packageIdOf] 一处（按最后一个 `:`
  /// 切分，包 id 允许含 `:`）；这里不再 `split(':').first`——那会把
  /// `my:pack:class/wizard` 显示成 `my`。
  String _sourceLabel(String originId) {
    final packageName = report.packageName.trim();
    return packageName.isNotEmpty
        ? packageName
        : RuleOverrideDeclaration.packageIdOf(originId);
  }
}
