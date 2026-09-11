import 'package:flutter/material.dart';

import '../domain/content_import_report.dart';

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
      return AlertDialog(
        title: const Text('导入预览'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(report.packageName),
            Text(report.version),
            Text('${report.entryCount} 个条目'),
            // 规则契约的 warning 级诊断：只提示，不阻断导入。
            if (report.warnings.isNotEmpty) ...[
              const SizedBox(height: 12),
              _DiagnosticList(
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
            _DiagnosticList(
              key: const Key('import-preview-errors'),
              diagnostics: report.errors,
            ),
            if (report.warnings.isNotEmpty) ...[
              const SizedBox(height: 12),
              _DiagnosticList(
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

/// 诊断列表：error 用 `error` 色，warning 用次级样式（`tertiary` + info 图标）。
class _DiagnosticList extends StatelessWidget {
  const _DiagnosticList({
    required this.diagnostics,
    this.warning = false,
    super.key,
  });

  final List<ContentValidationError> diagnostics;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = warning
        ? theme.colorScheme.tertiary
        : theme.colorScheme.error;
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
        for (final diagnostic in diagnostics)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '${diagnostic.path}: ${diagnostic.message}',
              style: theme.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
      ],
    );
  }
}
