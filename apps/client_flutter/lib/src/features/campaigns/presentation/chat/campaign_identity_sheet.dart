import 'package:flutter/material.dart';

import '../../domain/campaign.dart';
import '../../domain/campaign_actor.dart';
import '../../domain/campaign_health.dart';
import '../widgets/campaign_avatar.dart';
import 'campaign_composer_identity.dart';

class CampaignSpeakerChoice {
  const CampaignSpeakerChoice(this.speakerMode, [this.actorId])
    : createTemporary = false;

  const CampaignSpeakerChoice.temporary()
    : speakerMode = null,
      actorId = null,
      createTemporary = true;

  final String? speakerMode;
  final String? actorId;
  final bool createTemporary;
}

class CampaignIdentitySheet extends StatelessWidget {
  const CampaignIdentitySheet({
    required this.identity,
    required this.membership,
    required this.isManager,
    required this.persistentActors,
    required this.temporaryActors,
    required this.proxyActors,
    required this.campaignActors,
    required this.hasBoundCharacter,
    super.key,
  });

  final CampaignComposerIdentity identity;
  final CampaignMembership membership;
  final bool isManager;
  final List<CampaignWorkspaceActor> persistentActors;
  final List<CampaignWorkspaceActor> temporaryActors;
  final List<CampaignWorkspaceActor> proxyActors;
  final List<CampaignActor> campaignActors;
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
                  subtitle: '只输入名称，首次发言时创建',
                  selected: false,
                  choice: const CampaignSpeakerChoice.temporary(),
                ),
                if (persistentActors.isNotEmpty) ...[
                  const _SectionTitle('常驻 NPC、怪物与同伴'),
                  for (final actor in persistentActors)
                    _actorTile(context, actor),
                ],
                if (temporaryActors.isNotEmpty) ...[
                  const _SectionTitle('临时角色'),
                  for (final actor in temporaryActors)
                    _actorTile(context, actor, subtitle: '临时身份'),
                ],
                if (proxyActors.isNotEmpty) ...[
                  const _SectionTitle('代管玩家角色'),
                  for (final actor in proxyActors)
                    _actorTile(context, actor, subtitle: 'DM 代管'),
                ],
              ] else ...[
                _choiceTile(
                  context,
                  key: const Key('identity-bound-character-entry'),
                  icon: Icons.person_outline,
                  title: '绑定角色',
                  subtitle: hasBoundCharacter ? null : '尚未绑定角色',
                  selected: membership.speakerMode == 'boundActor',
                  choice: hasBoundCharacter
                      ? const CampaignSpeakerChoice('boundActor')
                      : null,
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

  Widget _actorTile(
    BuildContext context,
    CampaignWorkspaceActor actor, {
    String? subtitle,
  }) {
    final campaignActor = _campaignActorFor(actor.id);
    final sheet = campaignActor?.sheet ?? const <String, Object?>{};
    return ListTile(
      key: Key('identity-actor-${actor.id}'),
      leading: CampaignAvatar(
        initials: actor.displayName,
        health: CampaignAvatar.healthFromState(
          campaignHealthStateFromSheet(sheet) ?? actor.publicHealthState,
        ),
        healthFraction: campaignHealthFractionFromSheet(sheet),
      ),
      title: Text(actor.displayName),
      subtitle: subtitle == null ? null : Text(subtitle),
      selected:
          membership.speakerMode == 'actor' &&
          membership.activeSpeakerActorId == actor.id,
      onTap: () =>
          Navigator.of(context).pop(CampaignSpeakerChoice('actor', actor.id)),
    );
  }

  CampaignActor? _campaignActorFor(String actorId) {
    for (final actor in campaignActors) {
      if (actor.id == actorId) return actor;
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
