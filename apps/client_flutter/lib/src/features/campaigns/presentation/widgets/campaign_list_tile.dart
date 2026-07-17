import 'package:flutter/material.dart';

import '../../domain/campaign.dart';

/// 战役群聊列表条目（plan 2 任务3）。
///
/// 像 QQ 群聊条目：头像/首字母、战役名、最后消息摘要、未读 badge、当前用户
/// 在该战役的身份提示（主持人/玩家/旁观者）。点击进入战役聊天室。
class CampaignListTile extends StatelessWidget {
  const CampaignListTile({
    required this.campaign,
    required this.currentUserId,
    this.onTap,
    super.key,
  });

  final Campaign campaign;
  final String currentUserId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastMessage = campaign.lastMessage;
    final roleLabel = _roleLabel();

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(
          campaign.name.isNotEmpty
              ? campaign.name.characters.first.toUpperCase()
              : '?',
          style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              campaign.name,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          if (roleLabel != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                roleLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(
        lastMessage?.content ?? '暂无消息',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: campaign.unreadCount > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.error,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${campaign.unreadCount}',
                style: TextStyle(color: theme.colorScheme.onError, fontSize: 12),
              ),
            )
          : null,
    );
  }

  String? _roleLabel() {
    if (campaign.ownerId == currentUserId) return '主持人';
    final me = campaign.memberPreview
        .where((m) => m.userId == currentUserId)
        .firstOrNull;
    if (me == null) return null;
    return switch (me.role) {
      'owner' || 'dm' => '主持人',
      'spectator' => '旁观者',
      _ => '玩家',
    };
  }
}
