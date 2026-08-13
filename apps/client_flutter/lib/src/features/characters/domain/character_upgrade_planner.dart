import '../../content/domain/content_entry.dart';
import '../../rules/domain/character_build.dart';
import '../../rules/domain/character_rules_engine.dart';
import 'character.dart';
import 'character_content_reference.dart';
import 'dnd5e_rules.dart';
import 'rules_driven_character_builder.dart';

class CharacterUpgradePlan {
  const CharacterUpgradePlan({
    required this.currentLevel,
    required this.targetLevel,
    required this.build,
    required this.newGrants,
    required this.choices,
    required this.missingEntryIds,
  });

  final int currentLevel;
  final int targetLevel;
  final CharacterBuild build;
  final List<ResolvedRuleGrant> newGrants;
  final List<ActiveRuleChoice> choices;
  final List<String> missingEntryIds;

  bool get isComplete =>
      missingEntryIds.isEmpty && choices.every((choice) => choice.isValid);
}

class CharacterUpgradePlanner {
  CharacterUpgradePlanner({required this.entries})
    : _engine = CharacterRulesEngine(entries: entries);

  final Map<String, ContentEntry> entries;
  final CharacterRulesEngine _engine;

  CharacterUpgradePlan plan(CharacterSheet character) {
    if (character.level >= 20) {
      throw StateError('This character has already reached level 20.');
    }
    final savedBuild = _savedBuild(character);
    final targetLevel = character.level + 1;
    final build = CharacterBuild(
      level: targetLevel,
      selections: savedBuild.selections,
      choices: savedBuild.choices,
    );
    return _evaluate(character.level, build);
  }

  CharacterUpgradePlan select(
    CharacterSheet character,
    CharacterUpgradePlan plan,
    String choiceKey,
    List<String> entryIds,
  ) {
    final choices = <String, List<String>>{
      ...plan.build.choices,
      choiceKey: List<String>.unmodifiable(entryIds),
    };
    return _evaluate(
      character.level,
      CharacterBuild(
        level: plan.targetLevel,
        selections: plan.build.selections,
        choices: choices,
      ),
    );
  }

  CharacterSheet apply(CharacterSheet character, CharacterUpgradePlan plan) {
    if (!plan.isComplete) {
      throw StateError(
        'Resolve all level-up choices before applying the plan.',
      );
    }
    if (plan.currentLevel != character.level ||
        plan.targetLevel != character.level + 1) {
      throw StateError('The level-up plan is stale.');
    }

    final derived = RulesDrivenCharacterBuilder(entries: entries).build(
      name: character.name,
      build: plan.build,
      abilities: <String, int>{
        for (final key in Dnd5eRules.defaultAbilities.keys)
          key: _int(
            character.abilityMap[key],
            Dnd5eRules.defaultAbilities[key] ?? 10,
          ),
      },
      notes: character.notes,
    );
    final oldData = character.dataMap;
    final mergedData = Map<String, Object?>.from(oldData);
    for (final key in const <String>[
      'build',
      'contentRefs',
      'resolvedGrants',
      'pendingChoices',
      'spellSlots',
      'spellcastingAbility',
      'classResources',
      'actions',
    ]) {
      if (derived.data.containsKey(key)) mergedData[key] = derived.data[key];
    }
    mergedData['ruleSnapshots'] = _mergeMaps(
      oldData['ruleSnapshots'],
      derived.data['ruleSnapshots'],
    );
    mergedData['runtime'] = oldData['runtime'] ?? derived.data['runtime'];

    final hpIncrease = derived.maxHp - character.maxHp;
    return character.copyWith(
      level: plan.targetLevel,
      classSummary: derived.classSummary,
      raceSummary: derived.raceSummary,
      currentHp: (character.currentHp + hpIncrease).clamp(0, derived.maxHp),
      maxHp: derived.maxHp,
      armorClass: derived.armorClass,
      speed: derived.speed,
      initiativeBonus: derived.initiativeBonus,
      saves: derived.saves,
      skills: derived.skills,
      inventory: _mergeInventory(character.inventoryList, derived.inventory),
      data: mergedData,
      contentReferences: _mergeReferences(
        character.contentReferences,
        derived.contentReferences,
      ),
    );
  }

  CharacterUpgradePlan _evaluate(int currentLevel, CharacterBuild build) {
    final ledger = _engine.evaluate(build);
    return CharacterUpgradePlan(
      currentLevel: currentLevel,
      targetLevel: build.level,
      build: CharacterBuild(
        level: build.level,
        selections: build.selections,
        choices: ledger.resolvedChoices,
      ),
      newGrants: ledger.grants
          .where((grant) => grant.sourceLevel == build.level)
          .toList(growable: false),
      choices: ledger.activeChoices
          .where((choice) => choice.sourceLevel == build.level)
          .toList(growable: false),
      missingEntryIds: ledger.missingEntryIds,
    );
  }

  CharacterBuild _savedBuild(CharacterSheet character) {
    final raw = character.dataMap['build'];
    if (raw is! Map) {
      throw StateError('This character has no rules-driven build data.');
    }
    return CharacterBuild.fromJson(Map<String, Object?>.from(raw));
  }
}

Map<String, Object?> _mergeMaps(Object? current, Object? derived) => {
  if (current is Map) ...Map<String, Object?>.from(current),
  if (derived is Map) ...Map<String, Object?>.from(derived),
};

int _int(Object? value, int fallback) {
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? fallback;
}

List<Map<String, Object?>> _mergeInventory(
  List<Object?> current,
  List<Map<String, Object>> derived,
) {
  final result = current
      .whereType<Map>()
      .map((item) => Map<String, Object?>.from(item))
      .toList(growable: true);
  final knownEntryIds = result
      .map((item) => item['entryId'])
      .whereType<String>()
      .toSet();
  for (final item in derived) {
    final entryId = item['entryId'];
    if (entryId is String && knownEntryIds.add(entryId)) {
      result.add(Map<String, Object?>.from(item));
    }
  }
  return result;
}

List<CharacterContentReference> _mergeReferences(
  List<CharacterContentReference> current,
  List<CharacterContentReference> derived,
) {
  final references = <String, CharacterContentReference>{
    for (final reference in current) reference.entryKey: reference,
    for (final reference in derived) reference.entryKey: reference,
  };
  return references.values.toList(growable: false);
}
