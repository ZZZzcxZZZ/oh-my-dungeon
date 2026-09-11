import '../../content/domain/content_entry.dart';
import '../../rules/domain/character_build.dart';
import 'character.dart';
import 'character_content_reference.dart';
import 'dnd5e_rules.dart';
import 'rules_driven_character_builder.dart';

/// Recomputes derived rule snapshots for characters saved before rules existed.
class CharacterRuleProjector {
  const CharacterRuleProjector({required this.entries});

  final Map<String, ContentEntry> entries;

  CharacterSheet project(CharacterSheet character) {
    final rawBuild = character.dataMap['build'];
    if (rawBuild is! Map || entries.isEmpty) {
      return _withClassIdentity(character);
    }
    final savedBuild = CharacterBuild.fromJson(
      Map<String, Object?>.from(rawBuild),
    );
    if (savedBuild.selections.values.every((id) => !entries.containsKey(id))) {
      return _withClassIdentity(character);
    }

    final build = CharacterBuild(
      level: character.level,
      selections: savedBuild.selections,
      choices: savedBuild.choices,
    );
    final derived = RulesDrivenCharacterBuilder(entries: entries).build(
      name: character.name,
      build: build,
      abilities: {
        for (final key in Dnd5eRules.defaultAbilities.keys)
          key: _abilityValue(character.abilityMap[key], key),
      },
      notes: character.notes,
    );
    final oldData = character.dataMap;
    final derivedData = derived.data;
    final mergedData = Map<String, Object?>.from(oldData);
    for (final key in const [
      'build',
      'resolvedGrants',
      'pendingChoices',
      'spellSlots',
      'spellcastingAbility',
      'preparedSpellLimit',
      'hitDie',
      'savingThrowAbilities',
      'classResources',
      'actions',
    ]) {
      if (derivedData.containsKey(key)) mergedData[key] = derivedData[key];
    }
    mergedData['contentRefs'] = _mergeContentRefs(
      oldData['contentRefs'],
      derivedData['contentRefs'],
    );
    mergedData['ruleSnapshots'] = _mergeMaps(
      oldData['ruleSnapshots'],
      derivedData['ruleSnapshots'],
    );

    mergedData['classIdentity'] = _classIdentity(
      Map<String, Object?>.from(
        (derivedData['classIdentity'] as Map?) ?? const <String, Object?>{},
      ),
      character,
    );

    return character.copyWith(
      data: mergedData,
      contentReferences: _mergeReferences(
        character.contentReferences,
        derived.contentReferences,
      ),
    );
  }

  /// 老角色回填 `data.classIdentity`（契约 §3.12：声明范围随角色持久化）。
  ///
  /// - 优先用派生结果（条目身份 + 条目声明的 `declaredLevels`）；
  /// - 派生结果里 `entryId` 为空（原始存档没有 `build.selections.class`）时，
  ///   按 **slug / name / aliases 精确匹配**回填（[Dnd5eRules.resolveClassSlug]
  ///   只做精确相等或 `<别名><分隔符>` 前缀，**禁止裸子串**）；
  /// - 匹配不到就显式标记 `declared: false`（"未声明"），界面据此不显示 0。
  Map<String, Object?> _classIdentity(
    Map<String, Object?> derivedIdentity,
    CharacterSheet character,
  ) {
    final entryId = '${derivedIdentity['entryId'] ?? ''}'.trim();
    if (entryId.isNotEmpty) return derivedIdentity;

    final slug = Dnd5eRules.resolveClassSlug(
      classSummary: character.classSummary,
    );
    if (slug.isEmpty) {
      return <String, Object?>{
        'entryId': null,
        'slug': null,
        'name': character.classSummary,
        'declaredLevels': const <String, Object?>{'min': null, 'max': null},
        'declared': false,
      };
    }
    return <String, Object?>{
      'entryId': null,
      'slug': slug,
      'name': character.classSummary,
      'declaredLevels': const <String, Object?>{'min': null, 'max': null},
      'declared': true,
    };
  }

  CharacterSheet _withClassIdentity(CharacterSheet character) {
    final identity = _classIdentity(const <String, Object?>{}, character);
    final existing = character.dataMap['classIdentity'];
    if (existing is Map &&
        '${existing['slug'] ?? ''}' == '${identity['slug'] ?? ''}' &&
        existing['declared'] == identity['declared']) {
      return character;
    }
    final data = Map<String, Object?>.from(character.dataMap)
      ..['classIdentity'] = identity;
    return character.copyWith(data: data);
  }

  int _abilityValue(Object? value, String key) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? Dnd5eRules.defaultAbilities[key] ?? 10;
  }

  Map<String, Object?> _mergeContentRefs(Object? current, Object? derived) {
    final oldRefs = current is Map
        ? Map<String, Object?>.from(current)
        : const <String, Object?>{};
    final newRefs = derived is Map
        ? Map<String, Object?>.from(derived)
        : const <String, Object?>{};
    return {
      ...oldRefs,
      for (final key in const ['features', 'spells', 'items'])
        key: {
          ..._stringList(oldRefs[key]),
          ..._stringList(newRefs[key]),
        }.toList(growable: false),
    };
  }

  Map<String, Object?> _mergeMaps(Object? current, Object? derived) => {
    if (current is Map) ...Map<String, Object?>.from(current),
    if (derived is Map) ...Map<String, Object?>.from(derived),
  };

  List<CharacterContentReference> _mergeReferences(
    List<CharacterContentReference> current,
    List<CharacterContentReference> derived,
  ) {
    final byKey = <String, CharacterContentReference>{
      for (final reference in current) reference.entryKey: reference,
      for (final reference in derived) reference.entryKey: reference,
    };
    return byKey.values.toList(growable: false);
  }

  Iterable<String> _stringList(Object? value) {
    return value is List
        ? value.map((item) => '$item').where((item) => item.isNotEmpty)
        : const <String>[];
  }
}
