import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../data/export/dndpack_exporter.dart';
import '../data/import/content_package_importer.dart';
import '../data/local/content_repository.dart';
import '../data/local/local_homebrew_content_service.dart';
import '../domain/content_entry.dart';
import '../domain/content_entry_id.dart';
import '../domain/content_file_picker.dart';
import '../domain/content_import_report.dart';
import '../domain/content_package_manifest.dart';
import 'batch_import_wizard_dialog.dart';
import 'content_import_preview_dialog.dart';
import 'homebrew_entry_editor_dialog.dart';

class ContentPackageSettingsPage extends StatefulWidget {
  const ContentPackageSettingsPage({
    required this.repository,
    required this.importer,
    required this.filePicker,
    this.onExportDndPack,
    super.key,
  });

  final ContentRepository repository;
  final ContentPackageImporter importer;
  final ContentFilePicker filePicker;

  /// 导出 `.dndpack` 时的落盘方式。默认走 `FilePicker.saveFile`（与角色卡导出同一
  /// 入口）；测试注入一个记录器，就能在不碰文件系统的前提下断言产物。
  final Future<void> Function(String fileName, Uint8List bytes)? onExportDndPack;

  @override
  State<ContentPackageSettingsPage> createState() =>
      _ContentPackageSettingsPageState();
}

class _ContentPackageSettingsPageState
    extends State<ContentPackageSettingsPage> {
  List<ContentPackageManifest> _packages = const [];
  Map<String, bool> _enabled = {};
  List<ContentEntry> _homebrewEntries = const [];
  bool _exporting = false;
  StreamSubscription<List<ContentPackageManifest>>? _sub;

  LocalHomebrewContentService get _homebrew =>
      LocalHomebrewContentService(repository: widget.repository);

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
    await _reloadHomebrewEntries();
  }

  Future<void> _reloadHomebrewEntries() async {
    final entries = await widget.repository.search(
      const ContentQuery(packageId: LocalHomebrewContentService.packageId),
    );
    if (!mounted) return;
    setState(() => _homebrewEntries = entries);
  }

  /// 新建 / 编辑自制条目（作者 GUI 的唯一入口；写入走 `LocalHomebrewContentService`）。
  Future<void> _editHomebrewEntry([
    ContentEntry? existing,
    ContentEntry? overrideOf,
  ]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => HomebrewEntryEditorDialog(
        service: _homebrew,
        existing: existing,
        overrideOf: overrideOf,
      ),
    );
    if (saved == true) await _reloadHomebrewEntries();
  }

  /// 「基于已有条目创建覆盖」（S4）：先选来源条目，再把它的字段预填进编辑器。
  ///
  /// 候选 = 参与列级合并链的条目（`type: class` 且有 `structured.classRules`，
  /// 契约 D3）；自制包自己的条目已经在链上，不作为来源。
  Future<void> _createOverrideFromExisting() async {
    final all = await widget.repository.search(const ContentQuery(type: 'class'));
    if (!mounted) return;
    final takenKeys = <String>{
      for (final entry in _homebrewEntries) contentEntryAlignmentKey(entry.id),
    };
    final candidates = <ContentEntry>[
      for (final entry in all)
        // 自制包自己的条目由 `takenKeys` 排除：它们每个都占着自己的对齐键。
        // 不必再写 `id.startsWith(packageId:)`——生产装配下 id 带 `local:` 前缀，
        // 那个条件要么恒真、要么与 takenKeys 完全重复；包被停用时 `search` 也根本
        // 不会返回这些条目（`packages.enabled` 过滤）。
        if (entry.structured['classRules'] is Map &&
            !takenKeys.contains(contentEntryAlignmentKey(entry.id)))
          entry,
    ];
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('没有可覆盖的职业条目：先导入带 classRules 的资料包，或该键已有自制覆盖'),
        ),
      );
      return;
    }
    final picked = await showDialog<ContentEntry>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('选择要覆盖的条目'),
        children: [
          for (final entry in candidates)
            SimpleDialogOption(
              key: Key('homebrew-override-source-${entry.id}'),
              onPressed: () => Navigator.of(dialogContext).pop(entry),
              child: Text('${entry.name}（${entry.id}）'),
            ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    await _editHomebrewEntry(null, picked);
  }

  Future<void> _deleteHomebrewEntry(ContentEntry entry) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除自制条目'),
        content: Text('将删除「${entry.name}」，此操作不可撤销。'),
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
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _homebrew.delete(entry);
    await _reloadHomebrewEntries();
    messenger.showSnackBar(SnackBar(content: Text('已删除「${entry.name}」')));
  }

  /// 导出自制内容为 `.dndpack`（S4）。产物先经**真实导入器**自校验，
  /// 不合法时把字段级错误显示出来，而不是写一个导不回来的包。
  Future<void> _exportHomebrewDndPack() async {
    if (_homebrewEntries.isEmpty || _exporting) return;
    setState(() => _exporting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final export = await DndPackExporter(
        repository: widget.repository,
        importer: widget.importer,
      ).build(packageId: LocalHomebrewContentService.packageId);
      final save = widget.onExportDndPack ?? _saveBytesWithPicker;
      await save(export.fileName, export.bytes);
      messenger.showSnackBar(
        SnackBar(content: Text('已导出 ${export.fileName}（${export.report.entryCount} 个条目）')),
      );
    } on DndPackExportException catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('导出被拦下：${error.message}')),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('导出失败：$error')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _saveBytesWithPicker(String fileName, Uint8List bytes) =>
      FilePicker.platform.saveFile(
        dialogTitle: '导出资料包',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['dndpack'],
        bytes: bytes,
      );

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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '我的自制内容',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        TextButton.icon(
                          key: const Key('homebrew-entry-create-button'),
                          onPressed: () => _editHomebrewEntry(),
                          icon: const Icon(Icons.add),
                          label: const Text('新建条目'),
                        ),
                        TextButton.icon(
                          key: const Key('homebrew-entry-create-override-button'),
                          onPressed: _createOverrideFromExisting,
                          icon: const Icon(Icons.copy_all_outlined),
                          label: const Text('基于现有条目创建覆盖'),
                        ),
                      ],
                    ),
                    Text(
                      '自制条目与导入的资料包共用同一套契约与校验；导出为 .dndpack 前会先用真实导入器自校验。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_homebrewEntries.isEmpty)
                      const Text('还没有自制条目。')
                    else
                      for (final entry in _homebrewEntries)
                        ListTile(
                          key: Key('homebrew-entry-${entry.slug}'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(entry.name),
                          subtitle: Text('${entry.type} · ${entry.slug}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: '编辑',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _editHomebrewEntry(entry),
                              ),
                              IconButton(
                                tooltip: '删除',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _deleteHomebrewEntry(entry),
                              ),
                            ],
                          ),
                        ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const Key('homebrew-export-dndpack-button'),
                      onPressed: _homebrewEntries.isEmpty || _exporting
                          ? null
                          : _exportHomebrewDndPack,
                      icon: const Icon(Icons.archive_outlined),
                      label: const Text('导出 .dndpack'),
                    ),
                  ],
                ),
              ),
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
