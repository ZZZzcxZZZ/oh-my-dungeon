import 'package:flutter/material.dart';

import '../widgets/campaign_avatar.dart';
import 'campaign_composer_identity.dart';
import 'chat_helpers.dart';
import 'chat_mode_picker.dart';

class CampaignChatComposer extends StatelessWidget {
  const CampaignChatComposer({
    required this.identity,
    required this.mode,
    required this.controller,
    required this.sending,
    required this.onIdentityTap,
    required this.onModeChanged,
    required this.onSend,
    this.draftIdentityName,
    this.onDiscardDraft,
    super.key,
  });

  final CampaignComposerIdentity identity;
  final ChatMode mode;
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onIdentityTap;
  final ValueChanged<ChatMode> onModeChanged;
  final Future<bool> Function(String content) onSend;
  final String? draftIdentityName;
  final VoidCallback? onDiscardDraft;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (draftIdentityName case final String name)
              _DraftIdentityBanner(
                name: name,
                enabled: !sending,
                onDiscard: onDiscardDraft,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Tooltip(
                    message: '当前身份与跑团工具',
                    child: CampaignAvatar(
                      key: const Key('campaign-chat-identity'),
                      initials: identity.displayName,
                      imageUrl: identity.avatarUrl,
                      health: CampaignAvatar.healthFromState(
                        identity.healthState,
                      ),
                      healthFraction: identity.healthFraction,
                      size: 44,
                      tapTargetSize: 48,
                      onTap: sending ? null : onIdentityTap,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      key: const Key('campaign-composer-input-surface'),
                      constraints: const BoxConstraints(minHeight: 48),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (identity.supportsSayAction) ...[
                            Padding(
                              padding: const EdgeInsets.all(4),
                              child: SizedBox.square(
                                dimension: 40,
                                child: ChatModePicker(
                                  mode: mode,
                                  enabled: !sending,
                                  onChanged: onModeChanged,
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),
                          ],
                          Expanded(
                            child: TextField(
                              key: const Key('campaign-chat-input'),
                              controller: controller,
                              enabled: !sending,
                              minLines: 1,
                              maxLines: 4,
                              textInputAction: TextInputAction.send,
                              decoration: InputDecoration(
                                hintText: _hintText,
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.fromLTRB(
                                  identity.supportsSayAction ? 4 : 16,
                                  12,
                                  14,
                                  12,
                                ),
                              ),
                              onSubmitted: sending ? null : (_) => _submit(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox.square(
                    key: const Key('campaign-chat-send-target'),
                    dimension: 48,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedContainer(
                          key: const Key('campaign-chat-send-visual'),
                          duration: const Duration(milliseconds: 150),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: sending
                                ? colors.onSurface.withValues(alpha: 0.12)
                                : colors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        IconButton(
                          key: const Key('campaign-chat-send'),
                          tooltip: chatText('send'),
                          style: IconButton.styleFrom(
                            fixedSize: const Size.square(48),
                            foregroundColor: colors.onPrimary,
                            disabledForegroundColor: colors.onSurface
                                .withValues(alpha: 0.38),
                          ),
                          onPressed: sending ? null : _submit,
                          icon: sending
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _hintText {
    if (draftIdentityName case final String name) return '以 $name 发言';
    if (identity.isOoc) return '发送场外消息';
    return mode == ChatMode.say ? chatText('sayHint') : chatText('actHint');
  }

  Future<void> _submit() async {
    final content = controller.text.trim();
    if (content.isEmpty || sending) return;
    await onSend(content);
  }
}

class _DraftIdentityBanner extends StatelessWidget {
  const _DraftIdentityBanner({
    required this.name,
    required this.enabled,
    required this.onDiscard,
  });

  final String name;
  final bool enabled;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('draft-identity-banner'),
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.person_add_alt_1_outlined,
            size: 18,
            color: colors.onSecondaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '临时身份：$name',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colors.onSecondaryContainer,
              ),
            ),
          ),
          IconButton(
            key: const Key('discard-draft-identity'),
            tooltip: '放弃临时身份',
            onPressed: enabled ? onDiscard : null,
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }
}
