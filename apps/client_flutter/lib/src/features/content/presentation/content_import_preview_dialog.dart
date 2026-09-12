import 'package:flutter/material.dart';

import '../../characters/domain/declared_levels.dart';
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
}
