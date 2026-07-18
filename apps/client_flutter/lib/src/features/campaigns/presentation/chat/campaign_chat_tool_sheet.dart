import 'package:flutter/material.dart';

import 'campaign_composer_identity.dart';
import 'chat_avatar.dart';

enum CampaignChatToolAction {
  openCharacterSheet,
  switchIdentity,
  rollDice,
  skillCheck,
  hpStatus,
  contentEntries,
  viewJournal,
  recordClue,
  shareLocation,
  groupFiles,
  characterActions,
  temporaryIdentity,
}

/// Compact Material 3 tool surface opened from the composer identity avatar.
class CampaignChatToolSheet extends StatelessWidget {
  const CampaignChatToolSheet({
    required this.identity,
    required this.isManager,
    required this.hasCharacterActions,
    required this.draftIdentityName,
    super.key,
  });

  final CampaignComposerIdentity identity;
  final bool isManager;
  final bool hasCharacterActions;
  final String? draftIdentityName;

  @override
  Widget build(BuildContext context) {
    final actions = <_ToolDefinition>[
      const _ToolDefinition(
        action: CampaignChatToolAction.rollDice,
        keyName: 'tool-roll-dice',
        label: '掷骰',
        icon: Icons.casino_outlined,
      ),
      if (isManager)
        const _ToolDefinition(
          action: CampaignChatToolAction.skillCheck,
          keyName: 'tool-skill-check',
          label: '代掷检定',
          icon: Icons.fact_check_outlined,
        ),
      if (identity.hasCharacterSheet)
        const _ToolDefinition(
          action: CampaignChatToolAction.hpStatus,
          keyName: 'tool-hp-status',
          label: 'HP 与状态',
          icon: Icons.favorite_outline,
        ),
      if (hasCharacterActions)
        const _ToolDefinition(
          action: CampaignChatToolAction.characterActions,
          keyName: 'tool-character-actions',
          label: '角色动作',
          icon: Icons.bolt_outlined,
        ),
      const _ToolDefinition(
        action: CampaignChatToolAction.contentEntries,
        keyName: 'tool-content-entries',
        label: '资料条目',
        icon: Icons.menu_book_outlined,
      ),
      const _ToolDefinition(
        action: CampaignChatToolAction.viewJournal,
        keyName: 'tool-view-journal',
        label: '战役记录',
        icon: Icons.history_edu_outlined,
      ),
      if (isManager) ...const [
        _ToolDefinition(
          action: CampaignChatToolAction.recordClue,
          keyName: 'tool-record-clue',
          label: '记录线索',
          icon: Icons.lightbulb_outline,
        ),
        _ToolDefinition(
          action: CampaignChatToolAction.shareLocation,
          keyName: 'tool-share-location',
          label: '分享地点',
          icon: Icons.place_outlined,
        ),
        _ToolDefinition(
          action: CampaignChatToolAction.groupFiles,
          keyName: 'tool-group-files',
          label: '群文件',
          icon: Icons.folder_outlined,
        ),
        _ToolDefinition(
          action: CampaignChatToolAction.temporaryIdentity,
          keyName: 'identity-temporary-entry',
          label: '临时身份',
          icon: Icons.person_add_alt_1_outlined,
        ),
      ],
    ];

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.76,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('跑团工具', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Material(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
                child: ListTile(
                  key: const Key('tool-current-identity'),
                  leading: ChatAvatar(
                    name: identity.displayName,
                    avatarUrl: identity.avatarUrl,
                    healthState: identity.healthState,
                  ),
                  title: Text(identity.displayName),
                  subtitle: Text(identity.subtitle),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    key: Key(
                      isManager
                          ? 'tool-dm-identity-switch'
                          : 'tool-player-identity-switch',
                    ),
                    onPressed: () => _closeWith(
                      context,
                      CampaignChatToolAction.switchIdentity,
                    ),
                    icon: const Icon(Icons.switch_account_outlined),
                    label: const Text('切换身份'),
                  ),
                  if (identity.hasCharacterSheet)
                    FilledButton.tonalIcon(
                      key: const Key('tool-open-character-sheet'),
                      onPressed: () => _closeWith(
                        context,
                        CampaignChatToolAction.openCharacterSheet,
                      ),
                      icon: const Icon(Icons.badge_outlined),
                      label: const Text('角色卡'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('快捷操作', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 560
                      ? 4
                      : constraints.maxWidth >= 320
                      ? 3
                      : 2;
                  final width =
                      (constraints.maxWidth - (columns - 1) * 8) / columns;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final action in actions)
                        SizedBox(
                          width: width,
                          height: 76,
                          child: _ToolButton(
                            definition: action,
                            detail:
                                action.action ==
                                        CampaignChatToolAction
                                            .temporaryIdentity &&
                                    draftIdentityName != null
                                ? '草稿：$draftIdentityName'
                                : null,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _closeWith(BuildContext context, CampaignChatToolAction action) {
    Navigator.of(context).pop(action);
  }
}

class _ToolDefinition {
  const _ToolDefinition({
    required this.action,
    required this.keyName,
    required this.label,
    required this.icon,
  });

  final CampaignChatToolAction action;
  final String keyName;
  final String label;
  final IconData icon;
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.definition, this.detail});

  final _ToolDefinition definition;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainer,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        key: Key(definition.keyName),
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.of(context).pop(definition.action),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(definition.icon, size: 22, color: colors.primary),
              const SizedBox(height: 4),
              Text(
                detail ?? definition.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
