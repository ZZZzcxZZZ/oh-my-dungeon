import 'package:flutter/material.dart';

import '../../domain/campaign.dart';
import '../../domain/campaign_character.dart';
import '../../domain/campaign_health.dart';
import '../widgets/campaign_avatar.dart';
import 'campaign_composer_identity.dart';

class CampaignSpeakerChoice {
  const CampaignSpeakerChoice(this.speakerMode, [this.characterId])
    : createTemporary = false,
      changeBinding = false;

  const CampaignSpeakerChoice.temporary()
    : speakerMode = null,
      characterId = null,
      createTemporary = true,
      changeBinding = false;

  const CampaignSpeakerChoice.changeBinding()
    : speakerMode = null,
      characterId = null,
      createTemporary = false,
      changeBinding = true;

  final String? speakerMode;
  final String? characterId;
  final bool createTemporary;
  final bool changeBinding;
}

class CampaignIdentitySheet extends StatelessWidget {
  const CampaignIdentitySheet({
    required this.identity,
    required this.membership,
    required this.isManager,
    required this.persistentCharacters,
    required this.proxyCharacters,
    required this.campaignCharacters,
    required this.hasBoundCharacter,
    super.key,
  });

  final CampaignComposerIdentity identity;
  final CampaignMembership membership;
  final bool isManager;
  final List<CampaignWorkspaceCharacter> persistentCharacters;
  final List<CampaignWorkspaceCharacter> proxyCharacters;
  final List<CampaignCharacter> campaignCharacters;
  final bool hasBoundCharacter;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '切换发言身份',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              ListTile(
                leading: CampaignAvatar(
                  initials: identity.displayName,
                  imageUrl: identity.avatarUrl,
                  health: CampaignAvatar.healthFromState(identity.healthState),
                  healthFraction: identity.healthFraction,
                ),
                title: Text(identity.displayName),
                subtitle: Text('当前身份 · ${identity.subtitle}'),
              ),
              const Divider(height: 1),
              if (isManager) ...[
                _choiceTile(
                  context,
                  key: const Key('identity-narrator-entry'),
                  icon: Icons.auto_stories_outlined,
                  title: '旁白 / DM',
                  selected: membership.speakerMode == 'narrator',
                  choice: const CampaignSpeakerChoice('narrator'),
                ),
                _choiceTile(
                  context,
                  key: const Key('identity-ooc-entry'),
                  icon: Icons.forum_outlined,
                  title: '场外',
                  selected: membership.speakerMode == 'ooc',
                  choice: const CampaignSpeakerChoice('ooc'),
                ),
                _choiceTile(
                  context,
                  key: const Key('identity-quick-temporary-entry'),
                  icon: Icons.person_add_alt_1_outlined,
                  title: '快速临时身份',
                  subtitle: '仅用于下一条消息，不会保存为角色',
                  selected: false,
                  choice: const CampaignSpeakerChoice.temporary(),
                ),
                if (persistentCharacters.isNotEmpty) ...[
                  const _SectionTitle('常驻 NPC、怪物与同伴'),
                  for (final character in persistentCharacters)
                    _characterTile(context, character),
                ],
                if (proxyCharacters.isNotEmpty) ...[
                  const _SectionTitle('代管玩家角色'),
                  for (final character in proxyCharacters)
                    _characterTile(context, character, subtitle: 'DM 代管'),
                ],
              ] else ...[
                _choiceTile(
                  context,
                  key: const Key('identity-bound-character-entry'),
                  icon: Icons.person_outline,
                  title: '绑定角色',
                  subtitle: hasBoundCharacter ? '点击更换' : '点击选择角色',
                  selected: membership.speakerMode == 'boundCharacter',
                  choice: const CampaignSpeakerChoice.changeBinding(),
                ),
                _choiceTile(
                  context,
                  key: const Key('identity-ooc-entry'),
                  icon: Icons.forum_outlined,
                  title: '场外',
                  selected: membership.speakerMode == 'ooc',
                  choice: const CampaignSpeakerChoice('ooc'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _characterTile(
    BuildContext context,
    CampaignWorkspaceCharacter character, {
    String? subtitle,
  }) {
    final campaignCharacter = _campaignCharacterFor(character.id);
    final sheet = campaignCharacter?.sheet ?? const <String, Object?>{};
    return ListTile(
      key: Key('identity-character-${character.id}'),
      leading: CampaignAvatar(
        initials: character.displayName,
        health: CampaignAvatar.healthFromState(
          campaignHealthStateFromSheet(sheet) ?? character.publicHealthState,
        ),
        healthFraction: campaignHealthFractionFromSheet(sheet),
      ),
      title: Text(character.displayName),
      subtitle: subtitle == null ? null : Text(subtitle),
      selected:
          membership.speakerMode == 'character' &&
          membership.activeSpeakerCharacterId == character.id,
      onTap: () => Navigator.of(
        context,
      ).pop(CampaignSpeakerChoice('character', character.id)),
    );
  }

  CampaignCharacter? _campaignCharacterFor(String characterId) {
    for (final character in campaignCharacters) {
      if (character.id == characterId) return character;
    }
    return null;
  }

  Widget _choiceTile(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required String title,
    required bool selected,
    required CampaignSpeakerChoice? choice,
    String? subtitle,
  }) {
    return ListTile(
      key: key,
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      selected: selected,
      enabled: choice != null,
      trailing: selected ? const Icon(Icons.check_rounded) : null,
      onTap: choice == null ? null : () => Navigator.of(context).pop(choice),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
