import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/import/content_package_importer.dart';
import '../domain/content_file_picker.dart';
import '../domain/content_import_report.dart';

/// Spec §资料库 GUI 增强: 批量导入确认向导. 接收用户一次选择的多个
/// `.json` / `.dndpack` 文件, 并行生成预览报告, 让用户勾选要导入
/// 的资料包. 无效文件不可勾选, 但保留错误信息供查看. 确认后一次性
/// 导入所有勾选的有效资料包, 并显示汇总 SnackBar.
class BatchImportWizardDialog extends StatefulWidget {
  const BatchImportWizardDialog({
    required this.files,
    required this.importer,
    super.key,
  });

  final List<PickedContentFile> files;
  final ContentPackageImporter importer;

  @override
  State<BatchImportWizardDialog> createState() =>
      _BatchImportWizardDialogState();
}

class _BatchImportWizardDialogState extends State<BatchImportWizardDialog> {
  /// 每个文件对应的预览报告. key = 文件在 widget.files 中的索引.
  final Map<int, ContentImportReport> _reports = {};
  final Set<int> _selectedIndex = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _buildReports();
  }

  Future<void> _buildReports() async {
    final importer = widget.importer;
    for (var i = 0; i < widget.files.length; i++) {
      final file = widget.files[i];
      try {
        final report = file.name.toLowerCase().endsWith('.dndpack')
            ? await importer.previewDndPack(file.bytes)
            : await importer.previewJson(utf8.decode(file.bytes));
        _reports[i] = report;
        if (report.valid) {
          _selectedIndex.add(i);
        }
      } on FormatException catch (error) {
        // 解析失败时构造一个无效报告, 保留错误信息.
        _reports[i] = ContentImportReport(
          valid: false,
          formatVersion: 0,
          packageId: file.name,
          packageName: file.name,
          version: '',
          locale: '',
          system: '',
          entryCount: 0,
          entries: const [],
          errors: [
            ContentValidationError(path: file.name, message: error.message),
          ],
          assets: const {},
          contentHash: '',
        );
      } catch (error) {
        _reports[i] = ContentImportReport(
          valid: false,
          formatVersion: 0,
          packageId: file.name,
          packageName: file.name,
          version: '',
          locale: '',
          system: '',
          entryCount: 0,
          entries: const [],
          errors: [ContentValidationError(path: file.name, message: '$error')],
          assets: const {},
          contentHash: '',
        );
      }
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _runImport() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final selectedReports = [
      for (final index in _selectedIndex.toList()..sort())
        if (_reports[index]?.valid ?? false) _reports[index]!,
    ];
    var imported = 0;
    for (final report in selectedReports) {
      try {
        await widget.importer.importReport(report);
        imported++;
      } catch (_) {
        // 单个资料包导入失败时跳过, 由汇总提示告知用户.
      }
    }
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text('已导入 $imported 个资料包')));
    navigator.pop();
  }

  void _selectAll() {
    setState(() {
      _selectedIndex
        ..clear()
        ..addAll(
          _reports.entries.where((e) => e.value.valid).map((e) => e.key),
        );
    });
  }

  void _deselectAll() {
    setState(_selectedIndex.clear);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return AlertDialog(
        title: const Text('批量导入预览'),
        content: const SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    final sortedIndex = _reports.keys.toList()..sort();
    return AlertDialog(
      title: const Text('批量导入预览'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final index in sortedIndex)
                _PreviewCard(
                  report: _reports[index]!,
                  selected: _selectedIndex.contains(index),
                  onToggle: _reports[index]!.valid
                      ? (value) {
                          setState(() {
                            if (value == true) {
                              _selectedIndex.add(index);
                            } else {
                              _selectedIndex.remove(index);
                            }
                          });
                        }
                      : null,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _selectAll, child: const Text('全选')),
        TextButton(onPressed: _deselectAll, child: const Text('取消全选')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _selectedIndex.isEmpty ? null : _runImport,
          child: Text('导入 ${_selectedIndex.length} 个'),
        ),
      ],
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.report,
    required this.selected,
    required this.onToggle,
  });

  final ContentImportReport report;
  final bool selected;
  final ValueChanged<bool?>? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final valid = report.valid;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Screen readers must associate the checkbox with the package
            // name in the same row.
            Semantics(
              label: report.packageName,
              child: Checkbox(
                key: Key('batch-import-checkbox-${report.packageId}'),
                value: selected,
                onChanged: onToggle,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          report.packageName,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      Icon(
                        valid ? Icons.check_circle : Icons.error_outline,
                        size: 18,
                        color: valid ? colorScheme.primary : colorScheme.error,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (valid) ...[
                    Text(
                      '${report.version} · ${report.entryCount} 个条目',
                      style: theme.textTheme.bodySmall,
                    ),
                  ] else ...[
                    for (final error in report.errors.take(3))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Text(
                          '${error.path}: ${error.message}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.error,
                          ),
                        ),
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
