import 'character.dart';
import 'character_manual_overrides.dart';

class ResolvedCharacterOverrides {
  const ResolvedCharacterOverrides({
    required this.featureEntryIds,
    required this.spellEntryIds,
    required this.preparedSpellEntryIds,
    required this.alwaysPreparedSpellEntryIds,
    required this.customFeatures,
    required this.customSpells,
    required this.actions,
  });

  final List<String> featureEntryIds;
  final List<String> spellEntryIds;
  final List<String> preparedSpellEntryIds;

  /// `countsToward == null` 的显式法术选择选中的法术（契约 §3.11 A3），
  /// 与 [preparedSpellEntryIds] 一样只保留**当前确实存在的法术**。
  final List<String> alwaysPreparedSpellEntryIds;

  final List<Map<String, Object?>> customFeatures;
  final List<Map<String, Object?>> customSpells;
  final List<Map<String, Object?>> actions;
}

class CharacterOverrideResolver {
  const CharacterOverrideResolver._();

  static ResolvedCharacterOverrides resolve(CharacterSheet character) {
    final overrides = CharacterManualOverrides.fromCharacter(character);
    final contentRefs = _map(character.dataMap['contentRefs']);
    final hiddenEntries = <String>{};
    for (final rawGrant in _list(character.dataMap['resolvedGrants'])) {
      final grant = _map(rawGrant);
      if (grant['kind'] != 'feature') continue;
      if (overrides.hiddenGrantKeys.contains(grantKey(grant))) {
        final entryId = grant['entryId'];
        if (entryId is String) hiddenEntries.add(entryId);
      }
    }

    final features = <String>{
      ..._strings(
        contentRefs['features'],
      ).where((entryId) => !hiddenEntries.contains(entryId)),
      ...overrides.addedFeatureEntryIds,
    };
    final spells = <String>{
      ..._strings(
        contentRefs['spells'],
      ).where((entryId) => !overrides.removedSpellEntryIds.contains(entryId)),
      ...overrides.addedSpellEntryIds,
    };
    final prepared = overrides.preparedSpellEntryIds
        .where(spells.contains)
        .toList(growable: false);
    final alwaysPrepared = overrides.alwaysPreparedEntryIds
        .where(spells.contains)
        .toList(growable: false);

    return ResolvedCharacterOverrides(
      featureEntryIds: features.toList(growable: false),
      spellEntryIds: spells.toList(growable: false),
      preparedSpellEntryIds: prepared,
      alwaysPreparedSpellEntryIds: alwaysPrepared,
      customFeatures: overrides.customFeatures,
      customSpells: overrides.customSpells,
      actions: <Map<String, Object?>>[
        ..._maps(character.dataMap['actions']),
        ...overrides.customActions,
      ],
    );
  }

  static String grantKey(Map<String, Object?> grant) {
    final source = grant['sourceEntryId'] ?? 'unknown';
    final level = grant['sourceLevel'] ?? 0;
    final id = grant['id'] ?? grant['entryId'] ?? grant['label'] ?? 'grant';
    return '$source:$level:$id';
  }
}

Map<String, Object?> _map(Object? value) =>
    value is Map ? Map<String, Object?>.from(value) : const <String, Object?>{};

List<Object?> _list(Object? value) =>
    value is List ? List<Object?>.from(value) : const <Object?>[];

Iterable<String> _strings(Object? value) =>
    _list(value).whereType<String>().where((item) => item.isNotEmpty);

List<Map<String, Object?>> _maps(Object? value) => _list(value)
    .whereType<Map>()
    .map((item) => Map<String, Object?>.from(item))
    .toList(growable: false);
