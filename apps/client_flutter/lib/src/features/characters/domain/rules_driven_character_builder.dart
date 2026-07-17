import '../../content/domain/content_entry.dart';
import '../../rules/domain/character_build.dart';
import '../../rules/domain/character_rule_definition.dart';
import '../../rules/domain/character_rules_engine.dart';
import 'character_content_reference.dart';
import 'character_edit_draft.dart';
import 'dnd5e_rules.dart';

class RulesDrivenCharacterBuilder {
  RulesDrivenCharacterBuilder({required this.entries})
    : _engine = CharacterRulesEngine(entries: entries);

  final Map<String, ContentEntry> entries;
  final CharacterRulesEngine _engine;

  CharacterEditDraft build({
    required String name,
    required CharacterBuild build,
    required Map<String, int> abilities,
    String notes = '',
    String? avatarUrl,
    List<String> extraSpellRefs = const <String>[],
    List<String> extraItemRefs = const <String>[],
  }) {
    final classEntry = _selectedEntry(build, 'class');
    final speciesEntry = _selectedEntry(build, 'species');
    final backgroundEntry = _selectedEntry(build, 'background');
    final ledger = _engine.evaluate(build);
    final effectiveBuild = CharacterBuild(
      level: build.level,
      selections: build.selections,
      choices: ledger.resolvedChoices,
    );
    final saves = {for (final key in Dnd5eRules.abilityLabels.keys) key: false};
    final skills = {for (final skill in Dnd5eRules.skills) skill.name: false};

    for (final grant in ledger.grantsOfKind(RuleGrantKind.proficiency)) {
      final target = grant.target;
      if (target == null) continue;
      if (target.startsWith('save:')) {
        final key = target.substring('save:'.length);
        if (saves.containsKey(key)) saves[key] = true;
      } else if (target.startsWith('skill:')) {
        final key = target.substring('skill:'.length);
        if (skills.containsKey(key)) skills[key] = true;
      }
    }

    final featureRefs = {
      ..._entryRefs(ledger, RuleGrantKind.feature),
      ..._choiceEntryRefs(ledger, const {'classFeature', 'feature', 'feat'}),
    }.toList(growable: false);
    final spellRefs = {
      ..._entryRefs(ledger, RuleGrantKind.spell),
      ..._choiceEntryRefs(ledger, const {'spell'}),
      ...extraSpellRefs.where(entries.containsKey),
    }.toList(growable: false);
    final itemRefs = {
      ..._entryRefs(ledger, RuleGrantKind.equipment),
      ..._choiceEntryRefs(ledger, const {'equipment', 'item'}),
      ...extraItemRefs.where(entries.containsKey),
    }.toList(growable: false);
    final resources = ledger.grantsOfKind(RuleGrantKind.resource).toList();
    final spellSlotResources = resources
        .where((resource) => resource.target?.startsWith('spellSlot:') == true)
        .toList(growable: false);
    final classResources = resources
        .where((resource) => resource.target?.startsWith('spellSlot:') != true)
        .toList(growable: false);
    final actions = ledger.grantsOfKind(RuleGrantKind.action).toList();
    final armorBonus = ledger
        .grantsOfKind(RuleGrantKind.armorClass)
        .fold<num>(0, (sum, grant) => sum + (grant.value ?? 0))
        .toInt();
    final speedGrant = ledger.grantsOfKind(RuleGrantKind.speed).lastOrNull;
    final maxHp = _averageHitPoints(
      classEntry: classEntry,
      level: build.level,
      constitution: abilities['con'] ?? 10,
    );

    return CharacterEditDraft(
      name: name.trim(),
      level: build.level,
      classSummary: classEntry?.name ?? '',
      raceSummary: speciesEntry?.name ?? '',
      currentHp: maxHp,
      maxHp: maxHp,
      armorClass: Dnd5eRules.baseArmorClass(abilities) + armorBonus,
      speed: speedGrant?.value?.toInt() ?? 30,
      initiativeBonus: Dnd5eRules.initiativeBonus(abilities),
      abilities: Map<String, int>.from(abilities),
      saves: saves,
      skills: skills,
      inventory: [
        for (final entryId in itemRefs)
          {
            'entryId': entryId,
            'name': entries[entryId]?.name ?? entryId,
            'quantity': 1,
          },
      ],
      currency: const {'cp': 0, 'sp': 0, 'ep': 0, 'gp': 0, 'pp': 0},
      notes: notes.isEmpty
          ? 'D&D 2024 引导创建：${backgroundEntry?.name ?? ''} / ${speciesEntry?.name ?? ''} / ${classEntry?.name ?? ''}。'
          : notes,
      avatarUrl: avatarUrl,
      contentReferences: _contentReferences(
        effectiveBuild,
        ledger,
        extraEntryIds: {...extraSpellRefs, ...extraItemRefs},
      ),
      data: {
        'build': effectiveBuild.toJson(),
        'contentRefs': {
          'features': featureRefs,
          'spells': spellRefs,
          'items': itemRefs,
        },
        'resolvedGrants': [
          for (final grant in ledger.grants)
            {
              'id': grant.id,
              'kind': grant.kind.name,
              'label': grant.label,
              'sourceEntryId': grant.sourceEntryId,
              'sourceEntryName': grant.sourceEntryName,
              if (grant.sourceLevel != null) 'sourceLevel': grant.sourceLevel,
              if (grant.entryId != null) 'entryId': grant.entryId,
              if (grant.target != null) 'target': grant.target,
              if (grant.value != null) 'value': grant.value,
              if (grant.data.isNotEmpty) 'data': grant.data,
            },
        ],
        'pendingChoices': [
          for (final choice in ledger.pendingChoices)
            {
              'key': choice.key,
              'label': choice.label,
              'minimum': choice.minimum,
              'maximum': choice.maximum,
              'selected': choice.selected,
            },
        ],
        if (spellSlotResources.isNotEmpty)
          'spellSlots': {
            for (final resource in spellSlotResources)
              resource.target!.substring('spellSlot:'.length):
                  resource.value?.toInt() ?? 0,
          },
        if (classEntry?.structured['spellcastingAbility']
            case final String ability)
          'spellcastingAbility': ability,
        if (classResources.isNotEmpty)
          'classResources': [
            for (final resource in classResources)
              {
                'id': resource.id,
                'name': resource.label,
                'maximum': resource.value?.toInt() ?? 1,
                'recovery':
                    resource.data['recovery'] == 'shortRest'
                        ? 'shortRest'
                        : resource.data['recovery'] == 'none'
                        ? 'none'
                        : 'longRest',
              },
          ],
        if (actions.isNotEmpty)
          'actions': [
            for (final action in actions)
              {
                'id': action.id,
                'name': action.label,
                if (action.entryId != null) 'entryId': action.entryId,
                if (action.formula != null) 'formula': action.formula,
              },
          ],
        'runtime': {
          if (classResources.isNotEmpty)
            'classResourcesUsed': {
              for (final resource in classResources) resource.id: 0,
            },
        },
      },
    );
  }

  ContentEntry? _selectedEntry(CharacterBuild build, String slot) {
    final id = build.selections[slot];
    return id == null ? null : entries[id];
  }

  List<String> _entryRefs(CharacterGrantLedger ledger, RuleGrantKind kind) {
    return ledger
        .grantsOfKind(kind)
        .map((grant) => grant.entryId)
        .whereType<String>()
        .toSet()
        .toList(growable: false);
  }

  Iterable<String> _choiceEntryRefs(
    CharacterGrantLedger ledger,
    Set<String> entryTypes,
  ) sync* {
    for (final entryId in ledger.resolvedChoiceEntryIds) {
      if (entryTypes.contains(entries[entryId]?.type)) yield entryId;
    }
  }

  List<CharacterContentReference> _contentReferences(
    CharacterBuild build,
    CharacterGrantLedger ledger, {
    Set<String> extraEntryIds = const <String>{},
  }) {
    final references = <String, CharacterContentReference>{};
    for (final selection in build.selections.entries) {
      final entry = entries[selection.value];
      if (entry == null) continue;
      references[entry.id] = CharacterContentReference(
        slot: selection.key,
        entryKey: entry.id,
        sourceRevision: entry.revision,
        snapshot: {'name': entry.name, 'type': entry.type},
      );
    }
    for (final choice in build.choices.entries) {
      for (final entryId in choice.value) {
        final entry = entries[entryId];
        if (entry == null || references.containsKey(entry.id)) continue;
        references[entry.id] = CharacterContentReference(
          slot: 'choice:${choice.key}',
          entryKey: entry.id,
          sourceRevision: entry.revision,
          snapshot: {'name': entry.name, 'type': entry.type},
        );
      }
    }
    for (final grant in ledger.grants) {
      final entryId = grant.entryId;
      final entry = entryId == null ? null : entries[entryId];
      if (entry == null || references.containsKey(entry.id)) continue;
      references[entry.id] = CharacterContentReference(
        slot: grant.kind.name,
        entryKey: entry.id,
        sourceRevision: entry.revision,
        snapshot: {'name': entry.name, 'type': entry.type},
      );
    }
    for (final entryId in extraEntryIds) {
      final entry = entries[entryId];
      if (entry == null || references.containsKey(entry.id)) continue;
      references[entry.id] = CharacterContentReference(
        slot: 'manual',
        entryKey: entry.id,
        sourceRevision: entry.revision,
        snapshot: {'name': entry.name, 'type': entry.type},
      );
    }
    return references.values.toList(growable: false);
  }

  int _averageHitPoints({
    required ContentEntry? classEntry,
    required int level,
    required int constitution,
  }) {
    final rawHitDie = classEntry?.structured['hitDie'];
    final hitDie = switch (rawHitDie) {
      num value => value.toInt(),
      String value =>
        int.tryParse(value.replaceFirst(RegExp(r'^[dD]'), '')) ?? 8,
      _ => 8,
    };
    final conModifier = Dnd5eRules.abilityModifier(constitution);
    final safeLevel = level.clamp(1, 20);
    final total =
        hitDie +
        conModifier +
        (safeLevel - 1) * ((hitDie ~/ 2) + 1 + conModifier);
    return total.clamp(1, 9999);
  }
}

extension<T> on Iterable<T> {
  T? get lastOrNull => isEmpty ? null : last;
}
