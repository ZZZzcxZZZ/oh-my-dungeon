import 'package:flutter/material.dart';

import '../../domain/campaign_change.dart';
import 'campaign_content_controller.dart';
import 'campaign_content_editor.dart';
import 'campaign_json_import_dialog.dart';

/// 战役资料管理页。列表从 Drift 战役缓存读取，断网时可查阅；只有发布、编辑和
/// 删除操作要求连接服务器。owner/DM 可见编辑入口，player 只读。
class CampaignContentPage extends StatefulWidget {
  const CampaignContentPage({
    required this.controller,
    required this.campaignId,
    required this.canEdit,
    super.key,
  });

  final CampaignContentController controller;
  final String campaignId;
  final bool canEdit;

  @override
  State<CampaignContentPage> createState() => _CampaignContentPageState();
}

class _CampaignContentPageState extends State<CampaignContentPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant CampaignContentPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final entries = widget.controller.filteredEntries;
    return Scaffold(
      key: const Key('campaign-content-page'),
      appBar: AppBar(
        title: const Text('战役资料'),
        actions: [
          if (widget.canEdit)
            IconButton(
              key: const Key('import-json-button'),
              icon: const Icon(Icons.file_upload_outlined),
              tooltip: '导入 JSON',
              onPressed: () => _showImportDialog(context),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                hintText: '搜索条目名称、slug 或类型',
                isDense: true,
              ),
              onChanged: widget.controller.setQuery,
            ),
          ),
          if (widget.controller.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 18, color: colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.controller.error!,
                      style: TextStyle(color: colorScheme.error),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: widget.controller.clearError,
                  ),
                ],
              ),
            ),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 48,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '暂无战役资料',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.canEdit ? '点击"新建条目"创建' : '主持人尚未添加资料',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return _ContentEntryTile(
                        entry: entry,
                        canEdit: widget.canEdit,
                        onDelete: () => _confirmDelete(entry),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: widget.canEdit
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('新建条目'),
              onPressed: () => _showEditor(context),
            )
          : null,
    );
  }

  Future<void> _showEditor(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => CampaignContentEditor(
        controller: widget.controller,
      ),
    );
  }

  Future<void> _showImportDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => CampaignJsonImportDialog(
        controller: widget.controller,
      ),
    );
  }

  Future<void> _confirmDelete(CampaignContentEntrySummary entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除条目'),
        content: Text('确认删除「${entry.name}」？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.controller.deleteEntry(entry.id);
  }
}

class _ContentEntryTile extends StatelessWidget {
  const _ContentEntryTile({
    required this.entry,
    required this.canEdit,
    required this.onDelete,
  });

  final CampaignContentEntrySummary entry;
  final bool canEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.secondaryContainer,
          foregroundColor: colorScheme.onSecondaryContainer,
          child: Icon(_typeIcon(entry.type)),
        ),
        title: Text(entry.name),
        subtitle: Text(
          '${entry.type} · ${entry.slug}',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
        trailing: canEdit
            ? IconButton(
                tooltip: '删除${entry.name}',
                icon: Icon(Icons.delete_outline, color: colorScheme.error),
                onPressed: onDelete,
              )
            : null,
      ),
    );
  }

  IconData _typeIcon(String type) {
    return switch (type) {
      'location' => Icons.place_outlined,
      'npc' => Icons.person_outline,
      'monster' => Icons.cruelty_free,
      'item' => Icons.inventory_2_outlined,
      'quest' => Icons.assignment_outlined,
      _ => Icons.article_outlined,
    };
  }
}
