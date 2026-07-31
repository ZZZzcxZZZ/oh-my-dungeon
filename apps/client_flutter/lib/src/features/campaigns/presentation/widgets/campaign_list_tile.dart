import 'package:flutter/material.dart';

import '../../domain/campaign.dart';

enum CampaignConversationKind { group, direct }

class CampaignListConversation {
  const CampaignListConversation({
    required this.id,
    required this.title,
    required this.kind,
    this.lastMessage,
    this.unreadCount = 0,
  });

  final String id;
  final String title;
  final CampaignConversationKind kind;
  final String? lastMessage;
  final int unreadCount;
}

/// A compact campaign row that expands into secondary group and direct chats.
class CampaignListTile extends StatefulWidget {
  const CampaignListTile({
    required this.campaign,
    required this.currentUserId,
    this.conversations = const [],
    this.onTap,
    this.onConversationTap,
    this.onExpand,
    this.onCreateDirect,
    this.onCreateGroup,
    super.key,
  });

  final Campaign campaign;
  final String currentUserId;
  final List<CampaignListConversation> conversations;
  final VoidCallback? onTap;
  final ValueChanged<String>? onConversationTap;
  final VoidCallback? onExpand;
  final VoidCallback? onCreateDirect;
  final VoidCallback? onCreateGroup;

  static const mainChatKey = ValueKey('campaign-card-main-chat-entry');
  static const expandKey = ValueKey('campaign-card-expand-toggle');
  static const groupsToggleKey = ValueKey('campaign-list-groups-toggle');
  static const directToggleKey = ValueKey('campaign-list-direct-toggle');

  @override
  State<CampaignListTile> createState() => _CampaignListTileState();
}

class _CampaignListTileState extends State<CampaignListTile> {
  bool _expanded = false;
  bool _groupsExpanded = true;
  bool _directExpanded = true;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final groups = widget.conversations
        .where((item) => item.kind == CampaignConversationKind.group)
        .toList(growable: false);
    final direct = widget.conversations
        .where((item) => item.kind == CampaignConversationKind.direct)
        .toList(growable: false);

    return Card(
      clipBehavior: Clip.antiAlias,
      color: colorScheme.surfaceContainerLow,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  key: CampaignListTile.mainChatKey,
                  onTap: widget.onTap,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
                    child: _CampaignSummary(
                      campaign: widget.campaign,
                      roleLabel: _roleLabel(),
                    ),
                  ),
                ),
              ),
              IconButton(
                key: CampaignListTile.expandKey,
                tooltip: _expanded ? '收起会话' : '展开会话',
                onPressed: () {
                  final expanding = !_expanded;
                  setState(() => _expanded = expanding);
                  if (expanding) widget.onExpand?.call();
                },
                icon: AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.expand_more),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: !_expanded
                ? const SizedBox.shrink()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Divider(height: 1),
                      _CampaignMetadata(campaign: widget.campaign),
                      if (widget.campaign.description.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              widget.campaign.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                        ),
                      _ConversationSection(
                        title: '小群',
                        icon: Icons.groups_outlined,
                        toggleKey: CampaignListTile.groupsToggleKey,
                        expanded: _groupsExpanded,
                        conversations: groups,
                        onToggle: () =>
                            setState(() => _groupsExpanded = !_groupsExpanded),
                        onTap: widget.onConversationTap,
                      ),
                      _ConversationSection(
                        title: '私聊',
                        icon: Icons.person_outline,
                        toggleKey: CampaignListTile.directToggleKey,
                        expanded: _directExpanded,
                        conversations: direct,
                        onToggle: () =>
                            setState(() => _directExpanded = !_directExpanded),
                        onTap: widget.onConversationTap,
                      ),
                      if (widget.onCreateDirect != null ||
                          widget.onCreateGroup != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                          child: Row(
                            children: [
                              if (widget.onCreateDirect != null)
                                Expanded(
                                  child: TextButton.icon(
                                    onPressed: widget.onCreateDirect,
                                    icon: const Icon(
                                      Icons.person_add_alt_1_outlined,
                                    ),
                                    label: const Text('发起私聊'),
                                  ),
                                ),
                              if (widget.onCreateDirect != null &&
                                  widget.onCreateGroup != null)
                                const SizedBox(width: 8),
                              if (widget.onCreateGroup != null)
                                Expanded(
                                  child: TextButton.icon(
                                    onPressed: widget.onCreateGroup,
                                    icon: const Icon(Icons.group_add_outlined),
                                    label: const Text('创建小群'),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  String? _roleLabel() {
    if (widget.campaign.ownerId == widget.currentUserId) return '主持人';
    final me = widget.campaign.memberPreview
        .where((member) => member.userId == widget.currentUserId)
        .firstOrNull;
    if (me == null) return null;
    return switch (me.role) {
      'owner' || 'dm' => '主持人',
      'spectator' => '旁观者',
      _ => '玩家',
    };
  }
}

class _CampaignSummary extends StatelessWidget {
  const _CampaignSummary({required this.campaign, required this.roleLabel});

  final Campaign campaign;
  final String? roleLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      children: [
        CircleAvatar(
          key: const Key('campaign-card-leading-icon'),
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
          child: Text(
            campaign.name.isEmpty
                ? '?'
                : campaign.name.characters.first.toUpperCase(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      campaign.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (roleLabel != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      roleLabel!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      campaign.lastMessage?.content ?? '暂无消息',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (_activityTime(campaign) case final activityTime?) ...[
                    const SizedBox(width: 8),
                    Text(
                      activityTime,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (campaign.unreadCount > 0) ...[
          const SizedBox(width: 8),
          Badge(label: Text('${campaign.unreadCount}')),
        ],
      ],
    );
  }
}

class _CampaignMetadata extends StatelessWidget {
  const _CampaignMetadata({required this.campaign});

  final Campaign campaign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            _MetadataItem(
              icon: Icons.group_outlined,
              label: '${campaign.memberPreview.length} 位成员',
              color: color,
            ),
            _MetadataItem(
              icon: Icons.auto_stories_outlined,
              label: _systemLabel(campaign.system),
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetadataItem extends StatelessWidget {
  const _MetadataItem({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}

class _ConversationSection extends StatelessWidget {
  const _ConversationSection({
    required this.title,
    required this.icon,
    required this.toggleKey,
    required this.expanded,
    required this.conversations,
    required this.onToggle,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Key toggleKey;
  final bool expanded;
  final List<CampaignListConversation> conversations;
  final VoidCallback onToggle;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          key: toggleKey,
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(child: Text(title)),
                Text(
                  '${conversations.length}',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(width: 4),
                Icon(expanded ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),
        ),
        if (expanded)
          for (final conversation in conversations)
            ListTile(
              contentPadding: const EdgeInsets.only(left: 48, right: 16),
              leading: Icon(
                conversation.kind == CampaignConversationKind.group
                    ? Icons.forum_outlined
                    : Icons.chat_bubble_outline,
              ),
              title: Text(
                conversation.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: conversation.lastMessage == null
                  ? null
                  : Text(
                      conversation.lastMessage!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
              trailing: conversation.unreadCount > 0
                  ? Badge(label: Text('${conversation.unreadCount}'))
                  : null,
              onTap: () => onTap?.call(conversation.id),
            ),
      ],
    );
  }
}

String _systemLabel(String system) {
  return switch (system.toLowerCase()) {
    'dnd5e' || 'dnd5e-2024' => 'D&D 5E',
    final value when value.trim().isEmpty => '未设置规则',
    final value => value,
  };
}

String? _activityTime(Campaign campaign) {
  final raw = campaign.lastMessage?.createdAt ?? campaign.updatedAt;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;
  final local = parsed.toLocal();
  final now = DateTime.now();
  if (local.year == now.year &&
      local.month == now.month &&
      local.day == now.day) {
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
  if (local.year == now.year) {
    return '${local.month.toString().padLeft(2, '0')}/'
        '${local.day.toString().padLeft(2, '0')}';
  }
  return '${local.year}/'
      '${local.month.toString().padLeft(2, '0')}/'
      '${local.day.toString().padLeft(2, '0')}';
}
