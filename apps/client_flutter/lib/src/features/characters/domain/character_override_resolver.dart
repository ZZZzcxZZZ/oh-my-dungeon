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

  /// **用户手动准备**的法术（只保留当前确实存在的法术）。
  final List<String> preparedSpellEntryIds;

  /// 显式法术选择派生出的**自动准备**法术（契约 §3.11 A3），同样只保留当前确实
  /// 存在的法术。
  final List<String> alwaysPreparedSpellEntryIds;

  /// 界面判定"已准备"的唯一入口：**手动准备 ∪ 选择派生的自动准备**。
  ///
  /// 两条来源分属两个存储（`preparedEntryIds` / `alwaysPreparedEntryIds`），
  /// 任何读取方都不得只看其中一条——只看 `preparedSpellEntryIds` 会让派生的法术
  /// 显示成"未准备"，只看 `alwaysPreparedSpellEntryIds` 会漏掉用户的手动操作。
  List<String> get effectivePreparedSpellEntryIds => <String>[
    ...preparedSpellEntryIds,
    for (final entryId in alwaysPreparedSpellEntryIds)
      if (!preparedSpellEntryIds.contains(entryId)) entryId,
  ];

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
