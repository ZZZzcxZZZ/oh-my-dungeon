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
    if (rawBuild is! Map || entries.isEmpty) return character;
    final savedBuild = CharacterBuild.fromJson(
      Map<String, Object?>.from(rawBuild),
    );
    if (savedBuild.selections.values.every((id) => !entries.containsKey(id))) {
      return character;
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
      'classResources',
      'actions',
    ]) {
      if (derivedData.containsKey(key)) mergedData[key] = derivedData[key];
    }
    mergedData['contentRefs'] = _mergeContentRefs(
      oldData['contentRefs'],
      derivedData['contentRefs'],
    );

    return character.copyWith(
      data: mergedData,
      contentReferences: _mergeReferences(
        character.contentReferences,
        derived.contentReferences,
      ),
    );
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
