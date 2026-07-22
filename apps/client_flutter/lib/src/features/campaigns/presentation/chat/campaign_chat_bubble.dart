import 'package:flutter/material.dart';

import '../../domain/campaign.dart';
import '../widgets/campaign_avatar.dart';
import 'chat_helpers.dart';

/// 战役聊天消息泡泡。按 [CampaignChatMessage.kind] 渲染：
/// system、checkRequest、roll、action、say 各有独立样式。
///
/// 头像点击通过 [onAvatarTap] 回调注入，宿主页面负责解析 actor 并打开
/// 完整角色卡；不传则头像不可点。
class CampaignChatBubble extends StatelessWidget {
  const CampaignChatBubble({
    required this.message,
    this.onRespondCheckRequest,
    this.hasResponded = false,
    this.onAvatarTap,
    super.key,
  });

  final CampaignChatMessage message;
  final VoidCallback? onRespondCheckRequest;
  /// 当前玩家是否已响应过此 checkRequest。true 时按钮变灰显示「已响应」。
  final bool hasResponded;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final displayName = message.displayName.trim().isEmpty
        ? chatText('unknownSpeaker')
        : message.displayName;
    if (message.speakerMode == 'narrator') {
      final theme = Theme.of(context);
      return Padding(
        key: const Key('narrator-message'),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        child: Row(
          children: [
            Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
            const SizedBox(width: 10),
            Icon(
              Icons.auto_stories_outlined,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Flexible(
              flex: 4,
              child: Text(
                message.content,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
          ],
        ),
      );
    }
    if (message.kind == 'system') {
      return Padding(
        key: const Key('system-message'),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Center(
          child: Text(
            message.content,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    if (message.kind == 'checkRequest') {
      final data = message.eventData;
      final dc = data?['dc'];
      return Card.filled(
        key: const Key('check-request-message'),
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: ListTile(
          leading: const Icon(Icons.fact_check_outlined),
          title: Text(
            message.content,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: dc == null ? null : Text('DC $dc'),
          trailing: onRespondCheckRequest == null
              ? null
              : hasResponded
                  ? FilledButton.tonal(
                      key: const Key('responded-check-request'),
                      onPressed: null,
                      child: const Text('已响应'),
                    )
                  : FilledButton.tonal(
                      key: const Key('respond-check-request'),
                      onPressed: onRespondCheckRequest,
                      child: const Text('进行检定'),
                    ),
        ),
      );
    }

    if (message.kind == 'roll') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CampaignAvatar(
              initials: displayName,
              imageUrl: message.avatarUrl,
              health: CampaignAvatar.healthFromState(
                message.publicHealthState,
              ),
              onTap: onAvatarTap,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  Chip(
                    avatar: const Icon(Icons.casino_outlined, size: 18),
                    label: Text(message.content),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (message.kind == 'action') {
      final snapshot = message.actionSnapshot;
      return Padding(
        key: snapshot == null
            ? const Key('action-message')
            : const Key('rules-action-message'),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CampaignAvatar(
              initials: displayName,
              imageUrl: message.avatarUrl,
              health: CampaignAvatar.healthFromState(
                message.publicHealthState,
              ),
              onTap: onAvatarTap,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  Card(
                    margin: const EdgeInsets.only(top: 4),
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message.content,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontStyle: FontStyle.italic),
                          ),
                          if (snapshot != null &&
                              (snapshot['formula'] != null ||
                                  snapshot['entryId'] != null)) ...[
                            const SizedBox(height: 4),
                            Text(
                              [
                                if (snapshot['formula'] != null)
                                  '${snapshot['formula']}',
                                if (snapshot['entryId'] != null)
                                  '来源 ${snapshot['entryId']}',
                              ].join(' · '),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      key: const Key('say-message'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CampaignAvatar(
            initials: displayName,
            imageUrl: message.avatarUrl,
            health: CampaignAvatar.healthFromState(message.publicHealthState),
            onTap: onAvatarTap,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                Card(
                  margin: const EdgeInsets.only(top: 4),
                  color: colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(message.content),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
