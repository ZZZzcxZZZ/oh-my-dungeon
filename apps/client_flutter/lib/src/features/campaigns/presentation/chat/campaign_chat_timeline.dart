import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/campaign.dart';
import 'campaign_chat_bubble.dart';
import 'campaign_message_grouping.dart';

class CampaignChatTimeline extends StatelessWidget {
  const CampaignChatTimeline({
    required this.messages,
    required this.currentUserId,
    required this.scrollController,
    required this.onAvatarTap,
    required this.canRespondToCheck,
    required this.hasRespondedToCheck,
    required this.onRespondToCheck,
    super.key,
  });

  final List<CampaignChatMessage> messages;
  final String? currentUserId;
  final ScrollController scrollController;
  final VoidCallback? Function(CampaignChatMessage message) onAvatarTap;
  final bool Function(CampaignChatMessage message) canRespondToCheck;
  final bool Function(CampaignChatMessage message) hasRespondedToCheck;
  final ValueChanged<CampaignChatMessage> onRespondToCheck;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ordinaryMaxWidth = math.min(
          720.0,
          constraints.maxWidth * (constraints.maxWidth < 600 ? 0.86 : 0.72),
        );
        return ListView.builder(
          key: const Key('campaign-chat-timeline'),
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final presentation = CampaignMessagePresentation.resolve(
              previous: index == 0 ? null : messages[index - 1],
              current: message,
              currentUserId: currentUserId,
            );
            final centered = message.speakerMode == 'narrator' ||
                message.kind == 'system' ||
                message.kind == 'checkRequest';
            final alignment = centered
                ? Alignment.center
                : presentation.isOwn
                ? Alignment.centerRight
                : Alignment.centerLeft;
            final maxWidth = centered ? 640.0 : ordinaryMaxWidth;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (presentation.showTimeDivider)
                  _TimeDivider(message: message),
                Align(
                  key: Key('message-align-${message.id}'),
                  alignment: alignment,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: CampaignChatBubble(
                      message: message,
                      isOwn: presentation.isOwn,
                      showIdentity: presentation.showIdentity,
                      onRespondCheckRequest: canRespondToCheck(message)
                          ? () => onRespondToCheck(message)
                          : null,
                      hasResponded: hasRespondedToCheck(message),
                      onAvatarTap: onAvatarTap(message),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _TimeDivider extends StatelessWidget {
  const _TimeDivider({required this.message});

  final CampaignChatMessage message;

  @override
  Widget build(BuildContext context) {
    final parsed = DateTime.tryParse(message.createdAt)?.toLocal();
    final label = parsed == null
        ? message.createdAt
        : '${parsed.hour.toString().padLeft(2, '0')}:'
              '${parsed.minute.toString().padLeft(2, '0')}';
    return Padding(
      key: Key('message-time-${message.id}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
