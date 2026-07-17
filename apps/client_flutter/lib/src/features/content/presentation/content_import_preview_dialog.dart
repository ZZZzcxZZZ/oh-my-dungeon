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
            // Spec §资料包: 旧版 (formatVersion=1) 包会被自动迁移,
            // 但提示用户重新导出为 v2 以获得完整规则引用支持。
            if (report.formatVersion == 1) ...[
              const SizedBox(height: 12),
              _LegacyFormatBanner(formatVersion: report.formatVersion),
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
            for (final error in report.errors)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('${error.path}: ${error.message}'),
              ),
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

/// Spec §资料包: 旧版资料包 (formatVersion=1) 会在导入时被自动迁移,
/// 但缺失 v2 的结构化规则数据 (rule references, class feature
/// progression)。横幅提示用户在源端重新导出为 v2 以获得完整能力。
class _LegacyFormatBanner extends StatelessWidget {
  const _LegacyFormatBanner({required this.formatVersion});

  final int formatVersion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('legacy-format-banner'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '检测到旧版资料包格式 (v$formatVersion)。导入时会自动迁移基本字段，'
              '但缺少 v2 结构化规则数据（职业特性进度、规则引用等）。'
              '建议在源端重新导出为 v2 以获得完整能力。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
