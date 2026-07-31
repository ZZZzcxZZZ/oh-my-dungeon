import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/backup/local_backup_models.dart';
import '../../../core/backup/local_data_archive_service.dart';

/// Page exposing local data backup, restore, campaign cache clearing and
/// content index rebuild actions.
///
/// The page is intentionally minimal: each action lives behind a [ListTile]
/// and destructive operations require a confirmation dialog showing preview
/// details (counts, size, error) before mutating any data.
class DataManagementPage extends StatefulWidget {
  const DataManagementPage({
    required this.archiveService,
    this.fileSaver,
    this.filePicker,
    super.key,
  });

  final LocalDataArchiveService archiveService;

  /// Platform-agnostic saver: writes [bytes] to a user-chosen path and
  /// returns whether the save succeeded. Defaults to a no-op when not
  /// provided (e.g. in tests).
  final Future<bool> Function(Uint8List bytes, String suggestedName)? fileSaver;

  /// Platform-agnostic picker: returns archive bytes selected by the user,
  /// or `null` if the user cancelled. Defaults to returning `null` when not
  /// provided.
  final Future<Uint8List?> Function()? filePicker;

  @override
  State<DataManagementPage> createState() => _DataManagementPageState();
}

class _DataManagementPageState extends State<DataManagementPage> {
  bool _busy = false;
  String? _statusMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('数据管理')),
      body: ListView(
        children: [
          if (_statusMessage != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_statusMessage!),
            ),
          ListTile(
            leading: const Icon(Icons.upload_outlined),
            title: const Text('导出备份'),
            subtitle: const Text('将本地角色、资料、收藏和笔记打包为 .dndtable-backup'),
            enabled: !_busy,
            onTap: _exportBackup,
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('恢复备份'),
            subtitle: const Text('从 .dndtable-backup 文件恢复本地数据'),
            enabled: !_busy,
            onTap: _restoreBackup,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('清理战役缓存'),
            subtitle: const Text('删除战役角色、内容缓存和同步游标，不影响本地角色或资料'),
            enabled: !_busy,
            onTap: _clearCampaignCache,
          ),
          ListTile(
            leading: const Icon(Icons.search_outlined),
            title: const Text('重建资料索引'),
            subtitle: const Text('从本地资料条目重建搜索索引'),
            enabled: !_busy,
            onTap: _rebuildContentIndex,
          ),
        ],
      ),
    );
  }

  Future<void> _exportBackup() async {
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      final bytes = await widget.archiveService.exportArchive();
      final saver = widget.fileSaver;
      if (saver != null) {
        final stamp = DateTime.now().toIso8601String();
        final saved = await saver(bytes, 'dnd-table-$stamp.dndtable-backup');
        if (!saved) {
          setState(() => _statusMessage = '备份已生成但未保存到文件。');
          return;
        }
      }
      setState(() => _statusMessage = '备份已导出。');
    } catch (e) {
      setState(() => _statusMessage = '导出失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreBackup() async {
    Uint8List? bytes;
    final picker = widget.filePicker;
    if (picker != null) {
      bytes = await picker();
      if (bytes == null) return;
    } else {
      // No picker available: use the bytes from a fresh export as a fallback
      // so the preview dialog still flows in tests.
      bytes = await widget.archiveService.exportArchive();
    }

    setState(() {
      _busy = true;
      _statusMessage = null;
    });

    ArchivePreview preview;
    try {
      preview = await widget.archiveService.previewArchive(bytes);
    } catch (e) {
      setState(() => _statusMessage = '预览失败：$e');
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }

    if (!mounted) return;
    final confirmed = await _showRestoreConfirmDialog(preview);
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await widget.archiveService.restoreArchive(preview);
      setState(() => _statusMessage = '恢复完成。');
    } catch (e) {
      setState(() => _statusMessage = '恢复失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _showRestoreConfirmDialog(ArchivePreview preview) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('恢复备份'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('将替换此设备上的本地数据'),
                const SizedBox(height: 12),
                if (!preview.valid) ...[
                  Text(
                    '无效存档：${preview.error ?? '未知错误'}',
                    style: TextStyle(
                      color: Theme.of(dialogContext).colorScheme.error,
                    ),
                  ),
                ] else ...[
                  _previewRow(dialogContext, '资料包', preview.packageCount),
                  _previewRow(dialogContext, '条目', preview.entryCount),
                  _previewRow(dialogContext, '资源', preview.assetCount),
                  _previewRow(dialogContext, '角色', preview.characterCount),
                  _previewRow(dialogContext, '总大小', '${preview.totalSize} B'),
                  if (preview.manifest != null)
                    _previewRow(
                      dialogContext,
                      '版本',
                      preview.manifest!.clientVersion,
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            if (preview.valid)
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('确认恢复'),
              ),
          ],
        );
      },
    );
  }

  Widget _previewRow(BuildContext context, String label, Object value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text('$value'),
        ],
      ),
    );
  }

  Future<void> _clearCampaignCache() async {
    final confirmed = await _showSimpleConfirm(
      title: '清理战役缓存',
      message: '将删除战役角色、内容缓存和同步游标。本地角色与资料不受影响。',
      confirmLabel: '确认清理',
    );
    if (confirmed != true) return;

    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      await widget.archiveService.clearCampaignCache();
      setState(() => _statusMessage = '战役缓存已清理。');
    } catch (e) {
      setState(() => _statusMessage = '清理失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rebuildContentIndex() async {
    final confirmed = await _showSimpleConfirm(
      title: '重建资料索引',
      message: '将根据本地资料条目重建搜索索引。该操作不会改变资料内容。',
      confirmLabel: '确认重建',
    );
    if (confirmed != true) return;

    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      await widget.archiveService.rebuildContentIndex();
      setState(() => _statusMessage = '索引已重建。');
    } catch (e) {
      setState(() => _statusMessage = '重建失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _showSimpleConfirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
  }
}
