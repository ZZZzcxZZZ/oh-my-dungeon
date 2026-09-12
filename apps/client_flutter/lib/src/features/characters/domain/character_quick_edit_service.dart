import 'character.dart';
import 'character_manual_overrides.dart';
import 'character_profile.dart';

class CharacterQuickEditService {
  const CharacterQuickEditService();

  CharacterSheet addFeature(CharacterSheet character, String entryId) {
    final overrides = CharacterManualOverrides.fromCharacter(character);
    return _withOverrides(
      character,
      overrides.copyWith(
        addedFeatureEntryIds: _add(overrides.addedFeatureEntryIds, entryId),
      ),
    );
  }

  CharacterSheet removeAddedFeature(CharacterSheet character, String entryId) {
    final overrides = CharacterManualOverrides.fromCharacter(character);
    return _withOverrides(
      character,
      overrides.copyWith(
        addedFeatureEntryIds: _remove(overrides.addedFeatureEntryIds, entryId),
      ),
    );
  }

  CharacterSheet addCustomFeature(
    CharacterSheet character, {
    required String name,
    String description = '',
  }) {
    final overrides = CharacterManualOverrides.fromCharacter(character);
    final normalized = name.trim();
    if (normalized.isEmpty) return character;
    final custom = <String, Object?>{
      'id': 'custom-feature-${DateTime.now().microsecondsSinceEpoch}',
      'name': normalized,
      if (description.trim().isNotEmpty) 'description': description.trim(),
    };
    return _withOverrides(
      character,
      overrides.copyWith(
        customFeatures: <Map<String, Object?>>[
          ...overrides.customFeatures,
          custom,
        ],
      ),
    );
  }

  CharacterSheet removeCustomFeature(CharacterSheet character, String id) {
    final overrides = CharacterManualOverrides.fromCharacter(character);
    return _withOverrides(
      character,
      overrides.copyWith(
        customFeatures: overrides.customFeatures
            .where((feature) => feature['id'] != id)
            .toList(growable: false),
      ),
    );
  }

  CharacterSheet setGrantHidden(
    CharacterSheet character,
    String grantKey,
    bool hidden,
  ) {
    final overrides = CharacterManualOverrides.fromCharacter(character);
    return _withOverrides(
      character,
      overrides.copyWith(
        hiddenGrantKeys: hidden
            ? _add(overrides.hiddenGrantKeys, grantKey)
            : _remove(overrides.hiddenGrantKeys, grantKey),
      ),
    );
  }

  CharacterSheet addCustomAction(
    CharacterSheet character, {
    required String name,
    String description = '',
  }) {
    final overrides = CharacterManualOverrides.fromCharacter(character);
    final normalized = name.trim();
    if (normalized.isEmpty) return character;
    return _withOverrides(
      character,
      overrides.copyWith(
        customActions: <Map<String, Object?>>[
          ...overrides.customActions,
          <String, Object?>{
            'id': 'custom-action-${DateTime.now().microsecondsSinceEpoch}',
            'name': normalized,
            if (description.trim().isNotEmpty)
              'description': description.trim(),
          },
        ],
      ),
    );
  }

  CharacterSheet removeCustomAction(CharacterSheet character, String id) {
    final overrides = CharacterManualOverrides.fromCharacter(character);
    return _withOverrides(
      character,
      overrides.copyWith(
        customActions: overrides.customActions
            .where((action) => action['id'] != id)
            .toList(growable: false),
      ),
    );
  }

  CharacterSheet addSpell(CharacterSheet character, String entryId) {
    final overrides = CharacterManualOverrides.fromCharacter(character);
    return _withOverrides(
      character,
      overrides.copyWith(
        addedSpellEntryIds: _add(overrides.addedSpellEntryIds, entryId),
        removedSpellEntryIds: _remove(overrides.removedSpellEntryIds, entryId),
      ),
    );
  }

  CharacterSheet removeSpell(CharacterSheet character, String entryId) {
    final overrides = CharacterManualOverrides.fromCharacter(character);
    return _withOverrides(
      character,
      overrides.copyWith(
        addedSpellEntryIds: _remove(overrides.addedSpellEntryIds, entryId),
        removedSpellEntryIds: _add(overrides.removedSpellEntryIds, entryId),
        preparedSpellEntryIds: _remove(
          overrides.preparedSpellEntryIds,
          entryId,
        ),
        // "始终准备"标记随法术一起移除，否则会留下一条指向不存在法术的
        // 孤儿标记（展示层还要再过滤一次才能不显示它）。
        alwaysPreparedEntryIds: _remove(
          overrides.alwaysPreparedEntryIds,
          entryId,
        ),
      ),
    );
  }

  CharacterSheet setSpellPrepared(
    CharacterSheet character,
    String entryId,
    bool prepared,
  ) {
    final overrides = CharacterManualOverrides.fromCharacter(character);
    return _withOverrides(
      character,
      overrides.copyWith(
        preparedSpellEntryIds: prepared
            ? _add(overrides.preparedSpellEntryIds, entryId)
            : _remove(overrides.preparedSpellEntryIds, entryId),
        // 取消准备时同时摘掉"始终准备"标记：两者不能互相矛盾。
        alwaysPreparedEntryIds: prepared
            ? overrides.alwaysPreparedEntryIds
            : _remove(overrides.alwaysPreparedEntryIds, entryId),
      ),
    );
  }

  CharacterSheet updateProfile(
    CharacterSheet character,
    CharacterProfile profile,
  ) {
    final data = Map<String, Object?>.from(character.dataMap);
    data['profile'] = profile.toJson();
    return character.copyWith(data: data, notes: profile.privateNotes);
  }

  CharacterSheet _withOverrides(
    CharacterSheet character,
    CharacterManualOverrides overrides,
  ) {
    final data = Map<String, Object?>.from(character.dataMap);
    data['manualOverrides'] = overrides.toJson();
    return character.copyWith(data: data);
  }
}

List<String> _add(List<String> values, String value) {
  final normalized = value.trim();
  if (normalized.isEmpty || values.contains(normalized)) return values;
  return <String>[...values, normalized];
}

List<String> _remove(List<String> values, String value) =>
    values.where((item) => item != value).toList(growable: false);
