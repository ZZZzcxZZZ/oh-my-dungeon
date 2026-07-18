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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 40),
              const SizedBox(height: 12),
              Text(error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
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

/// Spec §档案: 点击档案条目后用更丰富的卡片浮窗展示完整信息：
/// 标题、类型、正文、来源消息、关联角色、关联地点、相关条目。
Future<void> _showArchiveDetail(
  BuildContext context,
  CampaignArchiveEntry entry,
) {
  final colorScheme = Theme.of(context).colorScheme;
  final payload = entry.payload;
  final body = payload['body'] as String?;
  final sourceMessageId = payload['sourceMessageId'] as String?;
  final relatedActorId = payload['relatedActorId'] as String?;
  final relatedLocationId = payload['relatedLocationId'] as String?;
  final relatedEntryIds = payload['relatedEntryIds'];

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.8,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top type banner — colored container with kind label and
                  // optional pinned indicator.
                  Container(
                    key: const Key('archive-detail-banner'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(_archiveIcon(entry.kind), size: 18),
                        const SizedBox(width: 6),
                        Text(
                          _archiveKindLabel(entry.kind),
                          style: Theme.of(sheetContext)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                color: colorScheme.onSurface,
                              ),
                        ),
                        const Spacer(),
                        if (entry.pinned)
                          Icon(
                            Icons.push_pin,
                            size: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Title.
                  Text(
                    entry.title,
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  // Summary (if present).
                  if (entry.summary.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      entry.summary,
                      style: Theme.of(sheetContext)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                  // Body content (from payload.body).
                  if (body != null && body.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      '正文',
                      style: Theme.of(sheetContext).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      key: const Key('archive-detail-body'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(body),
                    ),
                  ],
                  // Related metadata chips.
                  if (sourceMessageId != null ||
                      relatedActorId != null ||
                      relatedLocationId != null ||
                      relatedEntryIds != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      '关联',
                      style: Theme.of(sheetContext).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (sourceMessageId != null)
                          _ArchiveMetaChip(
                            icon: Icons.forum_outlined,
                            label: '来源消息：$sourceMessageId',
                          ),
                        if (relatedActorId != null)
                          _ArchiveMetaChip(
                            icon: Icons.person_outline,
                            label: '关联角色：$relatedActorId',
                          ),
                        if (relatedLocationId != null)
                          _ArchiveMetaChip(
                            icon: Icons.place_outlined,
                            label: '关联地点：$relatedLocationId',
                          ),
                        if (relatedEntryIds != null)
                          _ArchiveMetaChip(
                            icon: Icons.link,
                            label: '相关条目：$relatedEntryIds',
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Last updated timestamp.
                  Text(
                    '更新于 ${entry.updatedAt}',
                    style: Theme.of(sheetContext).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _ArchiveMetaChip extends StatelessWidget {
  const _ArchiveMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
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
