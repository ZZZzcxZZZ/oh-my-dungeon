import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/characters/domain/character_upgrade_planner.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fighter = _entry(
    id: 'class:fighter',
    type: 'class',
    name: 'Fighter',
    // 任务 8：生命骰只读 `structured.classRules`（旧的 `structured.hitDie`
    // 是散文展示字段，不再参与规则计算）。
    structured: <String, Object?>{
      'classRules': <String, Object?>{
        'hitDie': 10,
        'savingThrowAbilities': <String>['str', 'con'],
      },
    },
    rules: <String, Object?>{
      'progression': <Map<String, Object?>>[
        <String, Object?>{
          'levels': [2],
          'grants': <Map<String, Object?>>[
            <String, Object?>{
              'id': 'action-surge',
              'kind': 'feature',
              'label': 'Action Surge',
              'entryId': 'feature:action-surge',
            },
          ],
          'choices': <Map<String, Object?>>[
            <String, Object?>{
              'id': 'fighting-style',
              'label': 'Fighting Style',
              'optionType': 'feat',
              'minimum': 1,
              'maximum': 1,
            },
          ],
        },
      ],
    },
  );
  final actionSurge = _entry(
    id: 'feature:action-surge',
    type: 'classFeature',
    name: 'Action Surge',
  );
  final defense = _entry(id: 'feat:defense', type: 'feat', name: 'Defense');
  final entries = <String, ContentEntry>{
    fighter.id: fighter,
    actionSurge.id: actionSurge,
    defense.id: defense,
  };

  test('next level plan exposes only new grants and current choices', () {
    final plan = CharacterUpgradePlanner(entries: entries).plan(_character());

    expect(plan.currentLevel, 1);
    expect(plan.targetLevel, 2);
    expect(plan.newGrants.map((grant) => grant.label), <String>[
      'Action Surge',
    ]);
    expect(plan.choices.single.definition.label, 'Fighting Style');
    expect(plan.isComplete, isFalse);
  });

  test(
    'selection completes plan and apply preserves manual character state',
    () {
      final planner = CharacterUpgradePlanner(entries: entries);
      final initial = _character();
      final pending = planner.plan(initial);
      final completed = planner.select(
        initial,
        pending,
        pending.choices.single.key,
        <String>['feat:defense'],
      );

      expect(completed.isComplete, isTrue);
      final upgraded = planner.apply(initial, completed);
      expect(upgraded.level, 2);
      expect(upgraded.currentHp, greaterThan(initial.currentHp));
      expect(upgraded.inventory, initial.inventory);
      expect(upgraded.runtimeMap['temporaryHp'], 3);
      expect(
        upgraded.dataMap['manualOverrides'],
        initial.dataMap['manualOverrides'],
      );
      expect(upgraded.dataMap['profile'], initial.dataMap['profile']);
      expect(
        (upgraded.dataMap['contentRefs'] as Map)['features'],
        contains('feature:action-surge'),
      );
      expect(
        (upgraded.dataMap['ruleSnapshots'] as Map)['feature:action-surge'],
        containsPair('name', 'Action Surge'),
      );
    },
  );

  test('incomplete plan cannot be applied', () {
    final planner = CharacterUpgradePlanner(entries: entries);
    final initial = _character();
    expect(
      () => planner.apply(initial, planner.plan(initial)),
      throwsStateError,
    );
  });

  test('level 20 character cannot create another level-up plan', () {
    final planner = CharacterUpgradePlanner(entries: entries);
    expect(
      () => planner.plan(_character().copyWith(level: 20)),
      throwsStateError,
    );
  });

  test(
    'level three upgrade requires a related subclass and applies its feature',
    () {
      final wizard = _entry(
        id: 'class:wizard',
        type: 'class',
        name: 'Wizard',
        rules: <String, Object?>{
          'progression': <Map<String, Object?>>[
            <String, Object?>{
              'levels': [3],
              'choices': <Map<String, Object?>>[
                <String, Object?>{
                  'id': 'subclass',
                  'label': 'Wizard Subclass',
                  'optionType': 'subclass',
                  'minimum': 1,
                  'maximum': 1,
                },
              ],
            },
          ],
        },
      );
      final evoker = _entry(
        id: 'subclass:evoker',
        type: 'subclass',
        name: 'Evoker',
        relations: const <Map<String, Object?>>[
          <String, Object?>{'type': 'subclassOf', 'targetId': 'class:wizard'},
        ],
        rules: <String, Object?>{
          'progression': <Map<String, Object?>>[
            <String, Object?>{
              'levels': [3],
              'grants': <Map<String, Object?>>[
                <String, Object?>{
                  'id': 'sculpt-spells',
                  'kind': 'feature',
                  'label': 'Sculpt Spells',
                  'entryId': 'feature:sculpt-spells',
                },
              ],
            },
          ],
        },
      );
      final feature = _entry(
        id: 'feature:sculpt-spells',
        type: 'classFeature',
        name: 'Sculpt Spells',
      );
      final planner = CharacterUpgradePlanner(
        entries: <String, ContentEntry>{
          wizard.id: wizard,
          evoker.id: evoker,
          feature.id: feature,
        },
      );
      final initial = _character().copyWith(
        level: 2,
        classSummary: 'Wizard',
        data: <String, Object?>{
          ..._character().dataMap,
          'build': <String, Object?>{
            'level': 2,
            'selections': <String, String>{'class': wizard.id},
            'choices': <String, List<String>>{},
          },
        },
      );

      final pending = planner.plan(initial);
      expect(pending.choices.single.definition.optionType, 'subclass');
      final selected = planner.select(
        initial,
        pending,
        pending.choices.single.key,
        <String>[evoker.id],
      );
      final upgraded = planner.apply(initial, selected);

      expect(
        (upgraded.dataMap['contentRefs'] as Map)['features'],
        contains(feature.id),
      );
    },
  );
}

CharacterSheet _character() {
  return CharacterSheet.local(
    id: 'fighter',
    name: 'Ayla',
    level: 1,
    classSummary: 'Fighter',
    notes: 'Private',
  ).copyWith(
    currentHp: 10,
    maxHp: 10,
    abilities: <String, int>{
      'str': 16,
      'dex': 12,
      'con': 14,
      'int': 10,
      'wis': 10,
      'cha': 8,
    },
    inventory: <Map<String, Object>>[
      <String, Object>{'name': 'Longsword', 'quantity': 1},
    ],
    data: <String, Object?>{
      'build': <String, Object?>{
        'level': 1,
        'selections': <String, String>{'class': 'class:fighter'},
        'choices': <String, List<String>>{},
      },
      'runtime': <String, Object?>{'temporaryHp': 3},
      'profile': <String, Object?>{'backstory': 'Veteran'},
      'manualOverrides': <String, Object?>{
        'features': <String, Object?>{
          'addedEntryIds': <String>['feature:homebrew'],
        },
      },
    },
  );
}

ContentEntry _entry({
  required String id,
  required String type,
  required String name,
  Map<String, Object?> structured = const <String, Object?>{},
  List<Map<String, Object?>> relations = const <Map<String, Object?>>[],
  Map<String, Object?>? rules,
}) {
  return ContentEntry.fromJson(<String, Object?>{
    'id': id,
    'type': type,
    'slug': id.replaceAll(':', '-'),
    'name': name,
    'body': <Object?>[],
    'revision': 1,
    'structured': structured,
    'relations': relations,
    'rules': ?rules,
  });
}
