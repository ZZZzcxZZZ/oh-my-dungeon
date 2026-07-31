import 'package:flutter/material.dart';

import '../../domain/campaign.dart';
import '../widgets/campaign_avatar.dart';
import 'chat_helpers.dart';

class CampaignChatBubble extends StatelessWidget {
  const CampaignChatBubble({
    required this.message,
    this.isOwn = false,
    this.showIdentity = true,
    this.onRespondCheckRequest,
    this.hasResponded = false,
    this.onAvatarTap,
    super.key,
  });

  final CampaignChatMessage message;
  final bool isOwn;
  final bool showIdentity;
  final VoidCallback? onRespondCheckRequest;
  final bool hasResponded;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final displayName = message.displayName.trim().isEmpty
        ? chatText('unknownSpeaker')
        : message.displayName;

    if (message.speakerMode == 'narrator') {
      return _NarratorMessage(content: message.content);
    }
    if (message.kind == 'system') {
      return _SystemMessage(content: message.content);
    }
    if (message.kind == 'checkRequest') {
      return _CheckRequestMessage(
        message: message,
        hasResponded: hasResponded,
        onRespond: onRespondCheckRequest,
      );
    }
    if (message.kind == 'roll') {
      return _characterMessage(
        context,
        key: const Key('roll-message'),
        displayName: displayName,
        child: Chip(
          avatar: const Icon(Icons.casino_outlined, size: 18),
          label: Text(message.content),
        ),
      );
    }
    if (message.kind == 'action') {
      final snapshot = message.actionSnapshot;
      return _characterMessage(
        context,
        key: snapshot == null
            ? const Key('action-message')
            : const Key('rules-action-message'),
        displayName: displayName,
        child: Card(
          margin: const EdgeInsets.only(top: 4),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.content,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                ),
                if (snapshot != null &&
                    (snapshot['formula'] != null ||
                        snapshot['entryId'] != null)) ...[
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (snapshot['formula'] != null) '${snapshot['formula']}',
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
      );
    }

    return _characterMessage(
      context,
      key: const Key('say-message'),
      displayName: displayName,
      child: Card(
        margin: const EdgeInsets.only(top: 4),
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(message.content),
        ),
      ),
    );
  }

  Widget _characterMessage(
    BuildContext context, {
    required Key key,
    required String displayName,
    required Widget child,
  }) {
    return _CampaignCharacterMessage(
      key: key,
      displayName: displayName,
      avatarUrl: message.avatarUrl,
      healthState: message.publicHealthState,
      healthFraction: message.publicHealthFraction,
      isOwn: isOwn,
      showIdentity: showIdentity,
      onAvatarTap: onAvatarTap,
      child: child,
    );
  }
}

class _CampaignCharacterMessage extends StatelessWidget {
  const _CampaignCharacterMessage({
    required this.displayName,
    required this.avatarUrl,
    required this.healthState,
    required this.healthFraction,
    required this.isOwn,
    required this.showIdentity,
    required this.onAvatarTap,
    required this.child,
    super.key,
  });

  final String displayName;
  final String? avatarUrl;
  final String? healthState;
  final double? healthFraction;
  final bool isOwn;
  final bool showIdentity;
  final VoidCallback? onAvatarTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final avatar = showIdentity
        ? CampaignAvatar(
            initials: displayName,
            imageUrl: avatarUrl,
            health: CampaignAvatar.healthFromState(healthState),
            healthFraction: healthFraction,
            useHealthGradeFallback: false,
            tapTargetSize: 48,
            onTap: onAvatarTap,
          )
        : const SizedBox.square(dimension: 48);
    final content = Flexible(
      child: Column(
        crossAxisAlignment: isOwn
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (showIdentity)
            Text(displayName, style: Theme.of(context).textTheme.labelMedium),
          child,
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(top: showIdentity ? 6 : 1, bottom: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isOwn
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: isOwn
            ? [content, const SizedBox(width: 8), avatar]
            : [avatar, const SizedBox(width: 8), content],
      ),
    );
  }
}

class _NarratorMessage extends StatelessWidget {
  const _NarratorMessage({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      key: const Key('narrator-message'),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(
        children: [
          SizedBox(
            key: const Key('narrator-leading-rule'),
            width: 24,
            child: Divider(color: theme.colorScheme.outlineVariant),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              content,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            key: const Key('narrator-trailing-rule'),
            width: 24,
            child: Divider(color: theme.colorScheme.outlineVariant),
          ),
        ],
      ),
    );
  }
}

class _SystemMessage extends StatelessWidget {
  const _SystemMessage({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('system-message'),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Center(
        child: Text(
          content,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _CheckRequestMessage extends StatelessWidget {
  const _CheckRequestMessage({
    required this.message,
    required this.hasResponded,
    required this.onRespond,
  });

  final CampaignChatMessage message;
  final bool hasResponded;
  final VoidCallback? onRespond;

  @override
  Widget build(BuildContext context) {
    final dc = message.eventData?['dc'];
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
        trailing: onRespond == null
            ? null
            : hasResponded
            ? FilledButton.tonal(
                key: const Key('responded-check-request'),
                onPressed: null,
                child: const Text('已响应'),
              )
            : FilledButton.tonal(
                key: const Key('respond-check-request'),
                onPressed: onRespond,
                child: const Text('进行检定'),
              ),
      ),
    );
  }
}
