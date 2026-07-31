import 'package:flutter/material.dart';

import '../widgets/campaign_avatar.dart';
import 'campaign_composer_identity.dart';

enum CampaignChatToolAction {
  openCharacterSheet,
  switchIdentity,
  rollDice,
  skillCheck,
  manageHp,
  grantItem,
  addCondition,
  contentEntries,
  recordClue,
  shareLocation,
  characterActions,
}

/// One-level Material 3 tool grid opened from the composer identity button.
class CampaignChatToolSheet extends StatelessWidget {
  const CampaignChatToolSheet({
    required this.identity,
    required this.isManager,
    required this.hasCharacterActions,
    super.key,
  });

  final CampaignComposerIdentity identity;
  final bool isManager;
  final bool hasCharacterActions;

  @override
  Widget build(BuildContext context) {
    final actions = <_ToolDefinition>[
      const _ToolDefinition(
        action: CampaignChatToolAction.rollDice,
        keyName: 'tool-roll-dice',
        label: '掷骰',
        icon: Icons.casino_outlined,
      ),
      if (isManager) ...const [
        _ToolDefinition(
          action: CampaignChatToolAction.skillCheck,
          keyName: 'tool-skill-check',
          label: '代掷检定',
          icon: Icons.fact_check_outlined,
        ),
        _ToolDefinition(
          action: CampaignChatToolAction.manageHp,
          keyName: 'tool-manage-hp',
          label: '生命值',
          icon: Icons.favorite_outline,
        ),
        _ToolDefinition(
          action: CampaignChatToolAction.grantItem,
          keyName: 'tool-grant-item',
          label: '给予物品',
          icon: Icons.inventory_2_outlined,
        ),
        _ToolDefinition(
          action: CampaignChatToolAction.addCondition,
          keyName: 'tool-add-condition',
          label: '给予状态',
          icon: Icons.health_and_safety_outlined,
        ),
      ],
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
        label: '资料库',
        icon: Icons.menu_book_outlined,
      ),
      const _ToolDefinition(
        action: CampaignChatToolAction.recordClue,
        keyName: 'tool-record-clue',
        label: '记录线索',
        icon: Icons.lightbulb_outline,
      ),
      const _ToolDefinition(
        action: CampaignChatToolAction.shareLocation,
        keyName: 'tool-share-location',
        label: '分享地点',
        icon: Icons.place_outlined,
      ),
    ];

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                key: const Key('tool-current-identity'),
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
                clipBehavior: Clip.antiAlias,
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        key: identity.hasCharacterSheet
                            ? const Key('tool-open-character-sheet')
                            : null,
                        onTap: identity.hasCharacterSheet
                            ? () => Navigator.of(
                                context,
                              ).pop(CampaignChatToolAction.openCharacterSheet)
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              CampaignAvatar(
                                initials: identity.displayName,
                                imageUrl: identity.avatarUrl,
                                health: CampaignAvatar.healthFromState(
                                  identity.healthState,
                                ),
                                healthFraction: identity.healthFraction,
                                size: 40,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      identity.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    Text(
                                      identity.subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              if (identity.hasCharacterSheet)
                                const Icon(Icons.chevron_right),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: IconButton.filledTonal(
                        key: Key(
                          isManager
                              ? 'tool-dm-identity-switch'
                              : 'tool-player-identity-switch',
                        ),
                        tooltip: '切换身份',
                        onPressed: () => Navigator.of(
                          context,
                        ).pop(CampaignChatToolAction.switchIdentity),
                        icon: const Icon(Icons.switch_account_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 520 ? 5 : 4;
                  return GridView.builder(
                    key: const Key('campaign-tool-grid'),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: actions.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisExtent: 78,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemBuilder: (context, index) =>
                        _ToolButton(definition: actions[index]),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
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
  const _ToolButton({required this.definition});

  final _ToolDefinition definition;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key(definition.keyName),
        onTap: () => Navigator.of(context).pop(definition.action),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(definition.icon, size: 24, color: colors.primary),
              const SizedBox(height: 5),
              Text(
                definition.label,
                maxLines: 1,
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
