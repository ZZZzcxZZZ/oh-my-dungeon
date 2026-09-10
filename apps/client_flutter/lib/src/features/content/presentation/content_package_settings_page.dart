import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/import/content_package_importer.dart';
import '../data/local/content_repository.dart';
import '../domain/content_file_picker.dart';
import '../domain/content_import_report.dart';
import '../domain/content_package_manifest.dart';
import 'batch_import_wizard_dialog.dart';
import 'content_import_preview_dialog.dart';

class ContentPackageSettingsPage extends StatefulWidget {
  const ContentPackageSettingsPage({
    required this.repository,
    required this.importer,
    required this.filePicker,
    super.key,
  });

  final ContentRepository repository;
  final ContentPackageImporter importer;
  final ContentFilePicker filePicker;

  @override
  State<ContentPackageSettingsPage> createState() =>
      _ContentPackageSettingsPageState();
}

class _ContentPackageSettingsPageState
    extends State<ContentPackageSettingsPage> {
  List<ContentPackageManifest> _packages = const [];
  Map<String, bool> _enabled = {};
  StreamSubscription<List<ContentPackageManifest>>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.repository.watchPackages().listen(_onPackages);
  }

  Future<void> _onPackages(List<ContentPackageManifest> packages) async {
    final enabled = <String, bool>{};
    for (final p in packages) {
      enabled[p.id] = await widget.repository.isPackageEnabled(p.id);
    }
    if (!mounted) return;
    setState(() {
      _packages = packages;
      _enabled = enabled;
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _pickAndPreview() async {
    final file = await widget.filePicker.pick();
    if (file == null) return;
    ContentImportReport report;
    try {
      report = file.name.toLowerCase().endsWith('.dndpack')
          ? await widget.importer.previewDndPack(file.bytes)
          : await widget.importer.previewJson(utf8.decode(file.bytes));
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to read package: $error')));
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => ContentImportPreviewDialog(
        report: report,
        onConfirm: () async {
          await widget.importer.importReport(report);
        },
      ),
    );
  }

  /// Spec §资料库 GUI 增强: 批量导入确认向导. 一次选择多个文件,
  /// 弹出 [BatchImportWizardDialog] 让用户勾选要导入的资料包.
  Future<void> _pickMultipleAndPreview() async {
    final files = await widget.filePicker.pickMultiple();
    if (files.isEmpty) return;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) =>
          BatchImportWizardDialog(files: files, importer: widget.importer),
    );
  }

  Future<void> _confirmDelete(ContentPackageManifest package) async {
    final impact = await widget.repository.deletionImpact(package.id);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除资料包'),
        content: Text(
          '将删除 ${impact.entryCount} 个条目，${impact.favoriteCount} 个收藏，${impact.noteCount} 条笔记',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () {
              widget.repository.deletePackage(package.id);
              Navigator.of(context).pop();
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  /// Spec §资料包: 一键清除所有本地资料包。删除前必须二次确认并显示
  /// 影响范围 (资料包数量)。仅当本地存在资料包时显示入口。
  Future<void> _confirmClearAll() async {
    final packageCount = _packages.length;
    if (packageCount == 0) return;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清除所有本地资料包'),
        content: Text(
          '将删除 $packageCount 个资料包及其全部条目、收藏、笔记和资源。'
          '此操作不可撤销。私有资料包需要重新导入才能恢复。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final entryCount = await widget.repository.clearAllPackages();
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text('已清除 $entryCount 个条目')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('资料包管理')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: _pickAndPreview,
              icon: const Icon(Icons.file_upload_outlined),
              label: const Text('从文件导入'),
            ),
            const SizedBox(height: 8),
            // Spec §资料库 GUI 增强: 批量导入入口, 一次选择多个文件
            // 并在确认向导中勾选要导入的资料包.
            OutlinedButton.icon(
              key: const Key('content-batch-import-button'),
              onPressed: _pickMultipleAndPreview,
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('批量导入'),
            ),
            const SizedBox(height: 16),
            for (final package in _packages)
              Card(
                child: ListTile(
                  title: Text(package.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(package.version),
                      Text(
                        '${package.entryCount} 个条目 · ${package.locale} · ${package.system}',
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: _enabled[package.id] ?? false,
                        onChanged: (value) => widget.repository
                            .setPackageEnabled(package.id, value),
                      ),
                      IconButton(
                        tooltip: '删除资料包',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmDelete(package),
                      ),
                    ],
                  ),
                ),
              ),
            // Spec §资料包: 一键清除所有本地资料包入口；仅在本地存在
            // 资料包时显示，避免空状态误操作。
            if (_packages.isNotEmpty) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                key: const Key('content-clear-all-packages-button'),
                onPressed: _confirmClearAll,
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text('清除所有本地资料包'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
