import '../../../characters/domain/character.dart';
import '../../domain/campaign.dart';
import '../../domain/campaign_character.dart';
import '../../domain/campaign_health.dart';

/// Presentation model for the identity currently used by the chat composer.
///
/// The server-side membership is authoritative. Local characters are only
/// joined back in to provide offline sheet details for the active character.
class CampaignComposerIdentity {
  const CampaignComposerIdentity({
    required this.displayName,
    required this.speakerMode,
    required this.characterId,
    required this.avatarUrl,
    required this.healthState,
    this.healthFraction,
    required this.localCharacter,
    required this.campaignCharacter,
    required this.subtitle,
  });

  final String displayName;
  final String speakerMode;
  final String? characterId;
  final String? avatarUrl;
  final String? healthState;
  final double? healthFraction;
  final CharacterSheet? localCharacter;
  final CampaignCharacter? campaignCharacter;
  final String subtitle;

  bool get isOoc => speakerMode == 'ooc';
  bool get supportsSayAction =>
      speakerMode != 'narrator' && speakerMode != 'ooc';
  bool get hasCharacterSheet =>
      localCharacter != null || campaignCharacter != null;

  Map<String, Object?> get characterData {
    final local = localCharacter;
    if (local != null) return local.dataMap;
    final data = campaignCharacter?.sheet['data'];
    return data is Map ? Map<String, Object?>.from(data) : const {};
  }
}

CampaignComposerIdentity resolveCampaignComposerIdentity({
  required CampaignWorkspaceContext? workspace,
  required List<CampaignCharacter> campaignCharacters,
  required List<CharacterSheet> localCharacters,
  CharacterSheet? fallbackCharacter,
  String? fallbackCharacterId,
}) {
  final membership = workspace?.membership;
  final speakerMode =
      membership?.speakerMode ??
      (fallbackCharacterId == null ? 'boundCharacter' : 'character');

  if (speakerMode == 'narrator') {
    return const CampaignComposerIdentity(
      displayName: '旁白 / DM',
      speakerMode: 'narrator',
      characterId: null,
      avatarUrl: null,
      healthState: null,
      localCharacter: null,
      campaignCharacter: null,
      subtitle: '以旁白身份发言',
    );
  }

  if (speakerMode == 'ooc') {
    return CampaignComposerIdentity(
      displayName: membership?.displayName ?? '场外',
      speakerMode: 'ooc',
      characterId: null,
      avatarUrl: null,
      healthState: null,
      localCharacter: null,
      campaignCharacter: null,
      subtitle: '场外发言',
    );
  }

  final characterId =
      membership?.activeSpeakerCharacterId ??
      (speakerMode == 'boundCharacter' ? membership?.boundCharacterId : null) ??
      fallbackCharacterId;
  final workspaceCharacter = _firstWhereOrNull(
    workspace?.characters ?? const <CampaignWorkspaceCharacter>[],
    (character) => character.id == characterId,
  );
  final campaignCharacter = _firstWhereOrNull(
    campaignCharacters,
    (character) => character.id == characterId,
  );
  final sourceCharacterId = campaignCharacter?.sourceCharacterId;
  final localCharacter =
      _firstWhereOrNull(
        localCharacters,
        (character) => character.id == sourceCharacterId,
      ) ??
      ((fallbackCharacter != null &&
              (characterId == fallbackCharacterId ||
                  sourceCharacterId == fallbackCharacter.id ||
                  characterId == null))
          ? fallbackCharacter
          : null);
  final sheet = campaignCharacter?.sheet ?? const <String, Object?>{};
  final name =
      workspaceCharacter?.displayName ??
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
  final characterLabel = _characterTypeLabel(
    workspaceCharacter?.characterType ?? campaignCharacter?.characterType,
  );

  return CampaignComposerIdentity(
    displayName: name,
    speakerMode: speakerMode,
    characterId: characterId,
    avatarUrl: avatarUrl,
    healthState:
        campaignHealthStateFromSheet(sheet) ??
        (localCharacter == null
            ? null
            : campaignHealthStateFromHp(
                localCharacter.currentHp,
                localCharacter.maxHp,
              )) ??
        workspaceCharacter?.publicHealthState,
    healthFraction:
        campaignHealthFractionFromSheet(sheet) ??
        (localCharacter == null
            ? null
            : campaignHealthFractionFromHp(
                localCharacter.currentHp,
                localCharacter.maxHp,
              )),
    localCharacter: localCharacter,
    campaignCharacter: campaignCharacter,
    subtitle: hp ?? characterLabel ?? '角色发言',
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

String? _characterTypeLabel(String? characterType) => switch (characterType) {
  'npc' => 'NPC',
  'monster' => '怪物',
  'companion' => '同伴',
  'player' => '玩家角色',
  _ => null,
};
