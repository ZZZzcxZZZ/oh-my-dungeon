import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/campaign_archive_entry.dart';
import '../../../content/domain/content_block.dart';
import '../../../content/presentation/widgets/content_block_view.dart';
import '../../../../core/presentation/dialog_sizes.dart';

/// Plan 2026-07-23 task 4.3: 将服务端 ISO 时间戳格式化为 `yyyy-MM-dd`，
/// 去除时分秒。使用显式 pattern 而非 `DateFormat.yMd()`，避免 locale
/// 差异导致格式不一致（en_US -> 7/23/2026，zh_CN -> 2026/7/23）。
/// ISO 风格在战役档案这种跨用户共享的场景中歧义最小。
String _formatArchiveDate(String isoTimestamp) {
  try {
    final parsed = DateTime.parse(isoTimestamp);
    return DateFormat('yyyy-MM-dd').format(parsed);
  } catch (_) {
    // 解析失败时回退到原始字符串，避免 UI 崩溃。
    return isoTimestamp;
  }
}

/// 详情页底部 footer：`更新于 yyyy-MM-dd` 或 `更新于 yyyy-MM-dd · 由 编辑者`。
/// 编辑者署名优先 `updatedByName`，回退 `createdByName`。
String _archiveFooter(CampaignArchiveEntry entry) {
  final date = _formatArchiveDate(entry.updatedAt);
  final name = entry.editorName;
  if (name == null || name.isEmpty) return '更新于 $date';
  return '更新于 $date · 由 $name';
}

/// 列表行底部元数据：`由 编辑者 · yyyy-MM-dd` 或仅 `yyyy-MM-dd`。
String _archiveRowMetadata(CampaignArchiveEntry entry) {
  final date = _formatArchiveDate(entry.updatedAt);
  final name = entry.editorName;
  if (name == null || name.isEmpty) return date;
  return '由 $name · $date';
}

/// Archive panel: lists shared campaign archives with kind filter chips,
/// pull-to-refresh, structured wiki content, and per-entry edit actions.
///
/// Plan 2026-07-23 task 3 — turns the archive into a readable, editable,
/// searchable campaign Wiki. Detail rendering is adaptive:
/// - narrow screens (`width < 600`) use a near-full-height modal BottomSheet;
/// - wide screens use a `Dialog` constrained to a max width of ~760.
///
/// Edit permission is per-entry: the current user may edit when they are
/// the entry creator OR when they hold the `canManageCampaign` capability.
/// The panel never derives capabilities from client-side DM mode; the
/// `canManage` flag must come from server-provided capabilities.
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
    this.currentUserId,
    this.onUpdate,
    this.selectedTags = const [],
    this.onTagsChanged,
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

  /// Optional callback invoked when the user submits the per-entry edit form.
  /// When `null`, the edit button is never shown.
  final Future<bool> Function(
    CampaignArchiveEntry entry, {
    String? title,
    String? summary,
    List<Map<String, Object?>>? bodyBlocks,
    List<String>? tags,
  })?
  onUpdate;

  /// ID of the user currently viewing the campaign. Used to determine whether
  /// the per-entry edit button should be shown (creator-or-manager rule).
  final String? currentUserId;

  /// Currently selected tag filters. Empty list means no tag filter is
  /// active. Plan 2026-07-23 task 4.2.
  final List<String> selectedTags;

  /// Invoked when the user toggles a tag FilterChip or clears the selection.
  /// Receives the new full list of selected tags (after the change).
  final ValueChanged<List<String>>? onTagsChanged;

  static const double _wideBreakpoint = 600;
  static const double _wideDialogMaxWidth = 760;

  bool _canEditEntry(CampaignArchiveEntry entry) {
    if (onUpdate == null) return false;
    if (canManage) return true;
    final creator = entry.createdBy;
    if (creator == null || currentUserId == null) return false;
    return creator == currentUserId;
  }

  bool _canArchiveEntry(CampaignArchiveEntry entry) {
    if (canManage) return true;
    final creator = entry.createdBy;
    if (creator == null || currentUserId == null) return false;
    return creator == currentUserId;
  }

  /// Distinct tags across every entry, sorted alphabetically and stable
  /// across rebuilds. Used to render the FilterChip row.
  List<String> _collectDistinctTags() {
    final set = <String>{};
    for (final entry in entries) {
      set.addAll(entry.tags);
    }
    final list = set.toList()..sort();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final distinctTags = _collectDistinctTags();
    final showTagFilter = distinctTags.isNotEmpty;
    final hasSelectedTags = selectedTags.isNotEmpty;

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
          if (showTagFilter)
            Padding(
              key: const Key('archive-tag-filter-area'),
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.label_outline,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '按标签筛选',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      if (hasSelectedTags)
                        TextButton(
                          key: const Key('archive-tag-clear'),
                          onPressed: onTagsChanged == null
                              ? null
                              : () => onTagsChanged!(const []),
                          child: const Text('清除标签'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final tag in distinctTags)
                        FilterChip(
                          label: Text(tag),
                          selected: selectedTags.contains(tag),
                          onSelected: onTagsChanged == null
                              ? null
                              : (selected) {
                                  final next = List<String>.from(selectedTags);
                                  if (selected) {
                                    if (!next.contains(tag)) next.add(tag);
                                  } else {
                                    next.remove(tag);
                                  }
                                  onTagsChanged!(next);
                                },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          Expanded(child: _buildBody(context)),
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
        child: Text('尚无共享档案', style: Theme.of(context).textTheme.bodyLarge),
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
          return _ArchiveListRow(
            entry: entry,
            canEdit: _canEditEntry(entry),
            canArchive: _canArchiveEntry(entry),
            onTap: () => _showArchiveDetail(context, entry),
            onArchive: () => onArchive(entry),
            onEdit: onUpdate == null
                ? null
                : () => _showEditForm(context, entry, onUpdate!),
          );
        },
      ),
    );
  }
}

/// Single archive list row. Renders title, summary, kind icon, optional
/// pinned indicator, and tag chips. Avoids nested cards: the row itself
/// is a `Card`, but the inline content stays flat (no further `Card`s).
class _ArchiveListRow extends StatelessWidget {
  const _ArchiveListRow({
    required this.entry,
    required this.canEdit,
    required this.canArchive,
    required this.onTap,
    required this.onArchive,
    required this.onEdit,
  });

  final CampaignArchiveEntry entry;
  final bool canEdit;
  final bool canArchive;
  final VoidCallback onTap;
  final VoidCallback onArchive;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tags = entry.tags;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_archiveIcon(entry.kind), color: colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.title,
                            style: theme.textTheme.titleMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (entry.pinned)
                          Icon(
                            Icons.push_pin,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                      ],
                    ),
                    if (entry.summary.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        entry.summary,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final tag in tags.take(4)) _TagChip(label: tag),
                        ],
                      ),
                    ],
                    // Plan 2026-07-23 task 4.3: 行底部元数据「由 编辑者 · yyyy-MM-dd」。
                    const SizedBox(height: 8),
                    Text(
                      _archiveRowMetadata(entry),
                      key: const Key('archive-row-metadata'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (canEdit && onEdit != null)
                IconButton(
                  tooltip: '编辑',
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: onEdit,
                ),
              if (canArchive)
                IconButton(
                  tooltip: '归档',
                  icon: const Icon(Icons.archive_outlined, size: 20),
                  onPressed: onArchive,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact, low-emphasis chip used for tags in list rows.
class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

/// Spec §档案: 点击档案条目后展示完整信息：标题、类型、正文 blocks、
/// 标签、关联条目、附件引用。详情自适应布局：窄屏 BottomSheet（接近全高），
/// 宽屏 Dialog（最大宽度 760）。
Future<void> _showArchiveDetail(
  BuildContext context,
  CampaignArchiveEntry entry,
) {
  final mediaQuery = MediaQuery.of(context);
  final isWide = mediaQuery.size.width >= CampaignArchivePanel._wideBreakpoint;
  final content = _ArchiveDetailContent(entry: entry);

  if (isWide) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final screenWidth = MediaQuery.of(dialogContext).size.width;
        // On wide screens, the dialog itself should not exceed ~760. The
        // `Dialog` widget expands to (screen width - insetPadding), so we
        // bump the horizontal padding to leave room for the max target width.
        final horizontalInset =
            ((screenWidth - CampaignArchivePanel._wideDialogMaxWidth) / 2)
                .clamp(24.0, double.infinity);
        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: horizontalInset,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: DialogSizes.wide,
              maxHeight: DialogSizes.detailHeight,
            ),
            child: content,
          ),
        );
      },
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final height = MediaQuery.of(sheetContext).size.height;
      return SafeArea(
        child: SizedBox(height: height * 0.9, child: content),
      );
    },
  );
}

class _ArchiveDetailContent extends StatelessWidget {
  const _ArchiveDetailContent({required this.entry});

  final CampaignArchiveEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final legacyBody = entry.legacyBody;
    final sourceMessageId = entry.payload['sourceMessageId'] as String?;
    final relatedCharacterId = entry.payload['relatedCharacterId'] as String?;
    final relatedLocationId = entry.payload['relatedLocationId'] as String?;
    final relatedEntryIds = entry.payload['relatedEntryIds'];

    final bodyBlocks = _parseArchiveBodyBlocks(entry.bodyBlocks);
    final tags = entry.tags;
    final links = entry.links;
    final attachments = entry.attachmentRefs;

    final hasLegacyMetadata =
        sourceMessageId != null ||
        relatedCharacterId != null ||
        relatedLocationId != null ||
        relatedEntryIds != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top type banner — colored container with kind label and
            // optional pinned indicator.
            Container(
              key: const Key('archive-detail-banner'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(_archiveIcon(entry.kind), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _archiveKindLabel(entry.kind),
                    style: theme.textTheme.labelLarge?.copyWith(
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
            Text(
              entry.title,
              key: const Key('archive-detail-title'),
              style: theme.textTheme.titleLarge,
            ),
            if (entry.summary.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                entry.summary,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            // Body: structured blocks take precedence; fall back to legacy text.
            if (bodyBlocks.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('正文', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Container(
                key: const Key('archive-detail-body-blocks'),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ContentBlockView(blocks: bodyBlocks),
              ),
            ] else if (legacyBody.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('正文', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              Container(
                key: const Key('archive-detail-body'),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(legacyBody),
              ),
            ],
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('标签', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final tag in tags) _TagChip(label: tag)],
              ),
            ],
            if (links.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('关联条目', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final link in links)
                    _ArchiveMetaChip(
                      icon: _linkIcon(link['kind'] as String?),
                      label: _linkLabel(link),
                    ),
                ],
              ),
            ],
            if (attachments.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('附件', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final att in attachments) _AttachmentRow(ref: att),
                ],
              ),
            ],
            if (hasLegacyMetadata) ...[
              const SizedBox(height: 16),
              Text('关联', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (sourceMessageId != null)
                    _ArchiveMetaChip(
                      icon: Icons.forum_outlined,
                      label: '来源消息：$sourceMessageId',
                    ),
                  if (relatedCharacterId != null)
                    _ArchiveMetaChip(
                      icon: Icons.person_outline,
                      label: '关联角色：$relatedCharacterId',
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
            // Plan 2026-07-23 task 4.3: footer 显示「更新于 yyyy-MM-dd · 由 编辑者」。
            // 时间戳去除时分秒；署名优先 updatedByName，回退 createdByName，
            // 均缺失时不展示「由 ...」后缀。
            Text(
              _archiveFooter(entry),
              key: const Key('archive-detail-footer'),
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<ContentBlock> _parseArchiveBodyBlocks(
  List<Map<String, Object?>> rawBlocks,
) {
  final blocks = <ContentBlock>[];
  for (final raw in rawBlocks) {
    try {
      blocks.add(ContentBlock.fromJson(raw));
    } on Object {
      final text = raw['text'];
      if (text is String && text.trim().isNotEmpty) {
        blocks.add(ParagraphBlock(text: text));
      }
    }
  }
  return blocks;
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
        Icon(
          icon,
          size: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
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

class _AttachmentRow extends StatelessWidget {
  const _AttachmentRow({required this.ref});
  final Map<String, Object?> ref;

  @override
  Widget build(BuildContext context) {
    final kind = ref['kind'] as String? ?? 'file';
    final label = ref['label'] as String? ?? ref['url'] as String? ?? '';
    final url = ref['url'] as String?;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _attachmentIcon(kind),
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label.isEmpty ? (url ?? '') : label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _archiveIcon(String kind) => switch (kind) {
  'location' => Icons.place_outlined,
  'document' => Icons.description_outlined,
  'file' => Icons.attach_file_outlined,
  _ => Icons.lightbulb_outline,
};

IconData _linkIcon(String? kind) => switch (kind) {
  'character' => Icons.person_outline,
  'location' => Icons.place_outlined,
  'document' => Icons.description_outlined,
  _ => Icons.link,
};

IconData _attachmentIcon(String kind) => switch (kind) {
  'image' => Icons.image_outlined,
  'audio' => Icons.audiotrack_outlined,
  'video' => Icons.movie_outlined,
  _ => Icons.attach_file_outlined,
};

String _archiveKindLabel(String kind) => switch (kind) {
  'location' => '地点',
  'document' => '文档',
  'file' => '文件',
  _ => '线索',
};

String _linkLabel(Map<String, Object?> link) {
  final label = link['label'] as String?;
  if (label != null && label.isNotEmpty) return label;
  final id = link['id'] as String? ?? '';
  final kind = link['kind'] as String? ?? '';
  return '$kind:$id';
}

/// Per-entry edit form. Allows editing title, summary, body (paragraph text),
/// and tags (comma-separated). The body editor is a simple multiline text
/// field; paragraph lines map to bodyBlocks of type 'paragraph'.
///
/// Plan 2026-07-23 task 3b: 创建/编辑表单可编辑正文，不再只有名称和说明。
Future<void> _showEditForm(
  BuildContext context,
  CampaignArchiveEntry entry,
  Future<bool> Function(
    CampaignArchiveEntry entry, {
    String? title,
    String? summary,
    List<Map<String, Object?>>? bodyBlocks,
    List<String>? tags,
  })
  onUpdate,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          20 + MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: _ArchiveEditForm(
          entry: entry,
          onSubmit: ({bodyBlocks, summary, tags, title}) => onUpdate(
            entry,
            bodyBlocks: bodyBlocks,
            summary: summary,
            tags: tags,
            title: title,
          ),
        ),
      );
    },
  );
}

class _ArchiveEditForm extends StatefulWidget {
  const _ArchiveEditForm({required this.entry, required this.onSubmit});

  final CampaignArchiveEntry entry;

  final Future<bool> Function({
    String? title,
    String? summary,
    List<Map<String, Object?>>? bodyBlocks,
    List<String>? tags,
  })
  onSubmit;

  @override
  State<_ArchiveEditForm> createState() => _ArchiveEditFormState();
}

class _ArchiveEditFormState extends State<_ArchiveEditForm> {
  late final TextEditingController _title;
  late final TextEditingController _summary;
  late final TextEditingController _body;
  late final TextEditingController _tags;
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.entry.title);
    _summary = TextEditingController(text: widget.entry.summary);
    // Body: flatten existing blocks (or legacy body) into paragraph lines.
    final blocks = widget.entry.bodyBlocks;
    final buffer = StringBuffer();
    if (blocks.isNotEmpty) {
      for (var i = 0; i < blocks.length; i++) {
        final block = blocks[i];
        final text = block['text'] as String? ?? '';
        if (i > 0) buffer.writeln();
        buffer.write(text);
      }
    } else {
      buffer.write(widget.entry.legacyBody);
    }
    _body = TextEditingController(text: buffer.toString());
    _tags = TextEditingController(text: widget.entry.tags.join(', '));
  }

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    _body.dispose();
    _tags.dispose();
    super.dispose();
  }

  List<Map<String, Object?>> _bodyBlocksFromText(String text) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    return lines
        .map((line) => <String, Object?>{'type': 'paragraph', 'text': line})
        .toList(growable: false);
  }

  List<String> _tagsFromText(String text) {
    return text
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final success = await widget.onSubmit(
      title: _title.text.trim(),
      summary: _summary.text.trim(),
      bodyBlocks: _bodyBlocksFromText(_body.text),
      tags: _tagsFromText(_tags.text),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (success) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存失败，请稍后重试')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('编辑条目', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('archive-edit-title'),
            controller: _title,
            decoration: const InputDecoration(labelText: '名称'),
            validator: (value) =>
                value == null || value.trim().isEmpty ? '请输入名称' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('archive-edit-summary'),
            controller: _summary,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: '说明'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('archive-edit-body'),
            controller: _body,
            minLines: 4,
            maxLines: 10,
            decoration: const InputDecoration(
              labelText: '正文',
              helperText: '每个换行表示一个段落',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('archive-edit-tags'),
            controller: _tags,
            decoration: const InputDecoration(
              labelText: '标签',
              helperText: '用英文逗号分隔，例如：lore, map',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _submitting
                    ? null
                    : () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key('archive-edit-save'),
                onPressed: _submitting ? null : _submit,
                child: const Text('保存'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
