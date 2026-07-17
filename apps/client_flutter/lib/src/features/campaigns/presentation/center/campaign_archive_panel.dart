import 'package:flutter/material.dart';

import '../../domain/campaign_archive_entry.dart';

/// Archive panel: lists shared campaign archives with kind filter chips
/// and pull-to-refresh. DMs can archive entries inline.
///
/// Plan 3 task 2 — extracted from the legacy `_ArchivesTab`.
class CampaignArchivePanel extends StatelessWidget {
  const CampaignArchivePanel({
    required this.entries,
    required this.isLoading,
    required this.error,
    required this.canManage,
    required this.selectedKind,
    required this.onKindChanged,
    required this.onRefresh,
    required this.onArchive,
    super.key,
  });

  final List<CampaignArchiveEntry> entries;
  final bool isLoading;
  final String? error;
  final bool canManage;
  final String? selectedKind;
  final ValueChanged<String?> onKindChanged;
  final Future<void> Function() onRefresh;
  final Future<bool> Function(CampaignArchiveEntry entry) onArchive;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: key ?? const Key('campaign-archive-panel'),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                for (final option in const <(String?, String)>[
                  (null, '全部'),
                  ('document', '资料'),
                  ('location', '地点'),
                  ('clue', '线索'),
                  ('file', '文件'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(option.$2),
                      selected: selectedKind == option.$1,
                      onSelected: (_) => onKindChanged(option.$1),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _buildBody(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (isLoading && entries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && entries.isEmpty) {
      return Center(child: Text(error!));
    }
    if (entries.isEmpty) {
      return Center(
        child: Text(
          '尚无共享档案',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final entry = entries[index];
          return Card(
            child: ListTile(
              leading: Icon(_archiveIcon(entry.kind)),
              title: Text(entry.title),
              subtitle: entry.summary.isEmpty
                  ? Text(_archiveKindLabel(entry.kind))
                  : Text(
                      entry.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
              trailing: canManage
                  ? IconButton(
                      tooltip: '归档条目',
                      icon: const Icon(Icons.archive_outlined),
                      onPressed: () => onArchive(entry),
                    )
                  : null,
              onTap: () => _showArchiveDetail(context, entry),
            ),
          );
        },
      ),
    );
  }
}

void _showArchiveDetail(BuildContext context, CampaignArchiveEntry entry) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _archiveKindLabel(entry.kind),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            if (entry.summary.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(entry.summary),
            ],
          ],
        ),
      ),
    ),
  );
}

IconData _archiveIcon(String kind) => switch (kind) {
      'location' => Icons.place_outlined,
      'document' => Icons.description_outlined,
      'file' => Icons.attach_file_outlined,
      _ => Icons.lightbulb_outline,
    };

String _archiveKindLabel(String kind) => switch (kind) {
      'location' => '地点',
      'document' => '文档',
      'file' => '文件',
      _ => '线索',
    };
