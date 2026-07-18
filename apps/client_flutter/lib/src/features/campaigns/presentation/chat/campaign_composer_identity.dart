import '../../../characters/domain/character.dart';
import '../../domain/campaign.dart';
import '../../domain/campaign_actor.dart';

/// Presentation model for the identity currently used by the chat composer.
///
/// The server-side membership is authoritative. Local characters are only
/// joined back in to provide offline sheet details for the active actor.
class CampaignComposerIdentity {
  const CampaignComposerIdentity({
    required this.displayName,
    required this.speakerMode,
    required this.actorId,
    required this.avatarUrl,
    required this.healthState,
    required this.localCharacter,
    required this.campaignActor,
    required this.subtitle,
  });

  final String displayName;
  final String speakerMode;
  final String? actorId;
  final String? avatarUrl;
  final String? healthState;
  final CharacterSheet? localCharacter;
  final CampaignActor? campaignActor;
  final String subtitle;

  bool get isOoc => speakerMode == 'ooc';
  bool get hasCharacterSheet => localCharacter != null || campaignActor != null;

  Map<String, Object?> get characterData {
    final local = localCharacter;
    if (local != null) return local.dataMap;
    final data = campaignActor?.sheet['data'];
    return data is Map ? Map<String, Object?>.from(data) : const {};
  }
}

CampaignComposerIdentity resolveCampaignComposerIdentity({
  required CampaignWorkspaceContext? workspace,
  required List<CampaignActor> campaignActors,
  required List<CharacterSheet> localCharacters,
  CharacterSheet? fallbackCharacter,
  String? fallbackActorId,
}) {
  final membership = workspace?.membership;
  final speakerMode =
      membership?.speakerMode ??
      (fallbackActorId == null ? 'boundActor' : 'actor');

  if (speakerMode == 'narrator') {
    return const CampaignComposerIdentity(
      displayName: '旁白 / DM',
      speakerMode: 'narrator',
      actorId: null,
      avatarUrl: null,
      healthState: null,
      localCharacter: null,
      campaignActor: null,
      subtitle: '以旁白身份发言',
    );
  }

  if (speakerMode == 'ooc') {
    return CampaignComposerIdentity(
      displayName: membership?.displayName ?? '场外',
      speakerMode: 'ooc',
      actorId: null,
      avatarUrl: null,
      healthState: null,
      localCharacter: null,
      campaignActor: null,
      subtitle: '场外发言',
    );
  }

  final actorId =
      membership?.activeSpeakerActorId ??
      (speakerMode == 'boundActor' ? membership?.boundActorId : null) ??
      fallbackActorId;
  final workspaceActor = _firstWhereOrNull(
    workspace?.actors ?? const <CampaignWorkspaceActor>[],
    (actor) => actor.id == actorId,
  );
  final campaignActor = _firstWhereOrNull(
    campaignActors,
    (actor) => actor.id == actorId,
  );
  final sourceCharacterId = campaignActor?.sourceCharacterId;
  final localCharacter =
      _firstWhereOrNull(
        localCharacters,
        (character) => character.id == sourceCharacterId,
      ) ??
      ((fallbackCharacter != null &&
              (actorId == fallbackActorId ||
                  sourceCharacterId == fallbackCharacter.id ||
                  actorId == null))
          ? fallbackCharacter
          : null);
  final sheet = campaignActor?.sheet ?? const <String, Object?>{};
  final name =
      workspaceActor?.displayName ??
      _nonEmptyString(sheet['name']) ??
      localCharacter?.name ??
      fallbackCharacter?.name ??
      '未绑定角色';
  final avatarUrl =
      _nonEmptyString(sheet['avatarUrl']) ??
      localCharacter?.avatarUrl ??
      fallbackCharacter?.avatarUrl;
  final hp = localCharacter == null
      ? _exactStatsFromSheet(sheet)
      : 'HP ${localCharacter.currentHp}/${localCharacter.maxHp} · '
            'AC ${localCharacter.armorClass}';
  final actorLabel = _actorTypeLabel(
    workspaceActor?.actorType ?? campaignActor?.actorType,
  );

  return CampaignComposerIdentity(
    displayName: name,
    speakerMode: speakerMode,
    actorId: actorId,
    avatarUrl: avatarUrl,
    healthState: workspaceActor?.publicHealthState,
    localCharacter: localCharacter,
    campaignActor: campaignActor,
    subtitle: hp ?? actorLabel ?? '角色发言',
  );
}

T? _firstWhereOrNull<T>(Iterable<T> values, bool Function(T value) test) {
  for (final value in values) {
    if (test(value)) return value;
  }
  return null;
}

String? _nonEmptyString(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return value.trim();
}

String? _exactStatsFromSheet(Map<String, Object?> sheet) {
  final currentHp = sheet['currentHp'];
  final maxHp = sheet['maxHp'];
  final armorClass = sheet['armorClass'];
  if (currentHp is! num || maxHp is! num || armorClass is! num) return null;
  return 'HP ${currentHp.toInt()}/${maxHp.toInt()} · AC ${armorClass.toInt()}';
}

String? _actorTypeLabel(String? actorType) => switch (actorType) {
  'npc' => 'NPC',
  'monster' => '怪物',
  'companion' => '同伴',
  'player' => '玩家角色',
  _ => null,
};
