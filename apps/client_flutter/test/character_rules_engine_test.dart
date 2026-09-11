import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:dnd_table_client/src/features/rules/domain/character_build.dart';
import 'package:dnd_table_client/src/features/rules/domain/character_rule_definition.dart';
import 'package:dnd_table_client/src/features/rules/domain/character_rules_engine.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_choice_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CharacterRulesEngine', () {
    test('activates class grants when the character reaches their level', () {
      final fighter = _entry(
        id: 'test:class/fighter',
        type: 'class',
        name: '战士',
        rules: {
          'grants': [
            {
              'id': 'fighter-training',
              'kind': 'proficiency',
              'target': 'armor:all',
              'label': '全部护甲训练',
            },
          ],
          'progression': [
            {
              'levels': [1],
              'grants': [
                {
                  'id': 'second-wind',
                  'kind': 'feature',
                  'entryId': 'test:class-feature/second-wind',
                  'label': '回气',
                },
              ],
            },
            {
              'levels': [2],
              'grants': [
                {
                  'id': 'action-surge',
                  'kind': 'feature',
                  'entryId': 'test:class-feature/action-surge',
                  'label': '动作如潮',
                },
              ],
            },
          ],
        },
      );
      final engine = CharacterRulesEngine(entries: {fighter.id: fighter});

      final levelOne = engine.evaluate(
        const CharacterBuild(
          level: 1,
          selections: {'class': 'test:class/fighter'},
        ),
      );
      final levelTwo = engine.evaluate(
        const CharacterBuild(
          level: 2,
          selections: {'class': 'test:class/fighter'},
        ),
      );

      expect(
        levelOne.grants.map((grant) => grant.id),
        containsAll(['fighter-training', 'second-wind']),
      );
      expect(
        levelOne.grants.map((grant) => grant.id),
        isNot(contains('action-surge')),
      );
      expect(
        levelTwo.grants.map((grant) => grant.id),
        contains('action-surge'),
      );
      expect(
        levelTwo.grants.firstWhere((grant) => grant.id == 'action-surge'),
        isA<ResolvedRuleGrant>()
            .having((grant) => grant.sourceEntryId, 'source entry', fighter.id)
            .having((grant) => grant.sourceLevel, 'source level', 2),
      );
    });

    test(
      'reports a required class choice until enough options are selected',
      () {
        final fighter = _entry(
          id: 'test:class/fighter',
          type: 'class',
          name: '战士',
          rules: {
            'progression': [
              {
                'levels': [1],
                'choices': [
                  {
                    'id': 'weapon-mastery',
                    'label': '武器精通',
                    'optionType': 'equipment',
                    'minimum': 2,
                    'maximum': 2,
                  },
                ],
              },
            ],
          },
        );
        final longsword = _entry(
          id: 'test:equipment/longsword',
          type: 'equipment',
          name: 'Longsword',
          rules: const {},
        );
        final engine = CharacterRulesEngine(
          entries: {fighter.id: fighter, longsword.id: longsword},
        );

        final ledger = engine.evaluate(
          const CharacterBuild(
            level: 1,
            selections: {'class': 'test:class/fighter'},
            choices: {
              'test:class/fighter#weapon-mastery': ['test:equipment/longsword'],
            },
          ),
        );

        expect(ledger.pendingChoices, hasLength(1));
        expect(ledger.pendingChoices.single.choiceId, 'weapon-mastery');
        expect(ledger.pendingChoices.single.remaining, 1);
      },
    );

    test('selected rule entries contribute their own grants', () {
      final fightingStyle = _entry(
        id: 'test:feat/defense',
        type: 'feat',
        name: '防御',
        rules: {
          'grants': [
            {
              'id': 'defense-ac',
              'kind': 'armorClass',
              'value': 1,
              'label': '防御战斗风格',
            },
          ],
        },
      );
      final fighter = _entry(
        id: 'test:class/fighter',
        type: 'class',
        name: '战士',
        rules: {
          'choices': [
            {
              'id': 'fighting-style',
              'label': '战斗风格',
              'optionType': 'feat',
              'minimum': 1,
              'maximum': 1,
            },
          ],
        },
      );
      final engine = CharacterRulesEngine(
        entries: {fighter.id: fighter, fightingStyle.id: fightingStyle},
      );

      final ledger = engine.evaluate(
        const CharacterBuild(
          level: 1,
          selections: {'class': 'test:class/fighter'},
          choices: {
            'test:class/fighter#fighting-style': ['test:feat/defense'],
          },
        ),
      );

      expect(ledger.pendingChoices, isEmpty);
      expect(
        ledger.grants.singleWhere((grant) => grant.id == 'defense-ac'),
        isA<ResolvedRuleGrant>().having(
          (grant) => grant.sourceEntryId,
          'source entry',
          fightingStyle.id,
        ),
      );
    });

    test('subclass choices only expose subclasses of the source class', () {
      final wizard = _entry(
        id: 'test:class/wizard',
        type: 'class',
        name: '法师',
        rules: const {
          'progression': [
            {
              'levels': [3],
              'choices': [
                {
                  'id': 'subclass',
                  'label': '选择法师子职',
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
        id: 'test:subclass/evoker',
        type: 'subclass',
        name: '塑能师',
        relations: const [
          {'type': 'subclassOf', 'targetId': 'test:class/wizard'},
        ],
        rules: const {
          'progression': [
            {
              'levels': [3],
              'grants': [
                {
                  'id': 'sculpt-spells',
                  'kind': 'feature',
                  'label': '法术塑形',
                  'entryId': 'test:class-feature/sculpt-spells',
                },
              ],
            },
          ],
        },
      );
      final champion = _entry(
        id: 'test:subclass/champion',
        type: 'subclass',
        name: '勇士',
        relations: const [
          {'type': 'subclassOf', 'targetId': 'test:class/fighter'},
        ],
        rules: const {},
      );
      final feature = _entry(
        id: 'test:class-feature/sculpt-spells',
        type: 'classFeature',
        name: '法术塑形',
        rules: const {},
      );
      final entries = {
        wizard.id: wizard,
        evoker.id: evoker,
        champion.id: champion,
        feature.id: feature,
      };
      final definition = wizard.rules!.progression.single.choices.single;
      final resolver = RuleChoiceResolver(entries: entries);

      expect(
        resolver
            .optionsFor(definition, sourceEntryId: wizard.id)
            .map((entry) => entry.id),
        [evoker.id],
      );

      final ledger = CharacterRulesEngine(entries: entries).evaluate(
        const CharacterBuild(
          level: 3,
          selections: {'class': 'test:class/wizard'},
          choices: {
            'test:class/wizard#subclass': ['test:subclass/evoker'],
          },
        ),
      );

      expect(ledger.pendingChoices, isEmpty);
      expect(ledger.grants.map((grant) => grant.id), contains('sculpt-spells'));
    });

    test('filters spell choices by tags and maximum spell level', () {
      final cantrip = _entry(
        id: 'test:spell/spark',
        type: 'spell',
        name: 'Spark',
        tags: const ['spell-list:mage'],
        structured: const {'level': 0},
        rules: const {},
      );
      final firstLevel = _entry(
        id: 'test:spell/ward',
        type: 'spell',
        name: 'Ward',
        tags: const ['spell-list:mage'],
        structured: const {'level': 1},
        rules: const {},
      );
      final unavailable = _entry(
        id: 'test:spell/storm',
        type: 'spell',
        name: 'Storm',
        tags: const ['spell-list:priest'],
        structured: const {'level': 1},
        rules: const {},
      );
      const definition = RuleChoiceDefinition(
        id: 'starting-spells',
        label: 'Starting spells',
        optionType: 'spell',
        minimum: 2,
        maximum: 2,
        optionTags: ['spell-list:mage'],
        maximumOptionLevel: 1,
        builderStep: 'spells',
      );
      final resolver = RuleChoiceResolver(
        entries: {
          cantrip.id: cantrip,
          firstLevel.id: firstLevel,
          unavailable.id: unavailable,
        },
      );

      expect(resolver.optionsFor(definition).map((entry) => entry.id), [
        cantrip.id,
        firstLevel.id,
      ]);
    });

    test('rejects ineligible choices instead of applying their rules', () {
      final mage = _entry(
        id: 'test:class/mage',
        type: 'class',
        name: 'Mage',
        rules: const {
          'choices': [
            {
              'id': 'cantrip',
              'label': 'Cantrip',
              'optionType': 'spell',
              'minimum': 1,
              'maximum': 1,
              'optionTags': ['spell-list:mage'],
              'maximumOptionLevel': 0,
              'builderStep': 'spells',
            },
          ],
        },
      );
      final invalidSpell = _entry(
        id: 'test:spell/forbidden',
        type: 'spell',
        name: 'Forbidden spell',
        tags: const ['spell-list:priest'],
        structured: const {'level': 0},
        rules: const {
          'grants': [
            {'id': 'forged-action', 'kind': 'action', 'label': 'Forged'},
          ],
        },
      );
      final engine = CharacterRulesEngine(
        entries: {mage.id: mage, invalidSpell.id: invalidSpell},
      );

      final ledger = engine.evaluate(
        const CharacterBuild(
          level: 1,
          selections: {'class': 'test:class/mage'},
          choices: {
            'test:class/mage#cantrip': ['test:spell/forbidden'],
          },
        ),
      );

      expect(ledger.pendingChoices, hasLength(1));
      expect(ledger.pendingChoices.single.selected, isEmpty);
      expect(ledger.pendingChoices.single.invalidSelected, [
        'test:spell/forbidden',
      ]);
      expect(ledger.resolvedChoiceEntryIds, isEmpty);
      expect(
        ledger.grants.map((grant) => grant.id),
        isNot(contains('forged-action')),
      );
    });

    test('resolves valid recommended equipment bundles recursively', () {
      final classEntry = _entry(
        id: 'test:class/guardian',
        type: 'class',
        name: 'Guardian',
        rules: const {
          'choices': [
            {
              'id': 'starting-equipment',
              'label': 'Starting equipment',
              'optionType': 'equipmentBundle',
              'minimum': 1,
              'maximum': 1,
              'recommendedEntryIds': ['test:equipment-bundle/defender'],
              'builderStep': 'equipment',
            },
          ],
        },
      );
      final bundle = _entry(
        id: 'test:equipment-bundle/defender',
        type: 'equipmentBundle',
        name: 'Defender pack',
        rules: const {
          'grants': [
            {
              'id': 'shield',
              'kind': 'equipment',
              'label': 'Shield',
              'entryId': 'test:equipment/shield',
            },
          ],
        },
      );
      final shield = _entry(
        id: 'test:equipment/shield',
        type: 'equipment',
        name: 'Shield',
        rules: const {},
      );
      final entries = {
        classEntry.id: classEntry,
        bundle.id: bundle,
        shield.id: shield,
      };
      final resolver = RuleChoiceResolver(entries: entries);
      final definition = classEntry.rules!.choices.single;
      final recommended = resolver.recommendedFor(definition);
      final ledger = CharacterRulesEngine(entries: entries).evaluate(
        CharacterBuild(
          level: 1,
          selections: const {'class': 'test:class/guardian'},
          choices: {'test:class/guardian#starting-equipment': recommended},
        ),
      );

      expect(recommended, [bundle.id]);
      expect(ledger.pendingChoices, isEmpty);
      expect(ledger.resolvedChoiceEntryIds, contains(bundle.id));
      expect(
        ledger.grantsOfKind(RuleGrantKind.equipment).single.entryId,
        shield.id,
      );
    });

    test('character runtime round-trips frequently changing table state', () {
      const runtime = CharacterRuntime(
        currentHp: 17,
        temporaryHp: 4,
        inspiration: true,
        conditions: ['中毒'],
        deathSaveSuccesses: 1,
        deathSaveFailures: 2,
        spellSlotsUsed: {'1': 2},
        classResourcesUsed: {'second-wind': 1},
      );

      expect(CharacterRuntime.fromJson(runtime.toJson()), runtime);
    });
  });

  group('RuleChoiceDefinition.options（内联选项解析与序列化）', () {
    test('字符串简写展开为 id == label', () {
      final choice = RuleChoiceDefinition.fromJson(const {
        'id': 'class-skills',
        'label': '职业技能',
        'optionType': 'skill',
        'minimum': 2,
        'maximum': 2,
        'options': ['察觉'],
      });

      expect(choice.options, hasLength(1));
      expect(choice.options.single.id, '察觉');
      expect(choice.options.single.label, '察觉');
      expect(choice.options.single.description, isNull);
      expect(choice.options.single.data, isEmpty);
      expect(choice.options.single.grants, isEmpty);
    });

    test('对象元素（description/data/grants）无损往返', () {
      const source = <String, Object?>{
        'id': 'class-skills',
        'label': '职业技能',
        'optionType': 'skill',
        'minimum': 1,
        'maximum': 3,
        'options': [
          {
            'id': 'perception',
            'label': '察觉',
            'description': '看穿隐藏事物',
            'data': {'ability': 'wis'},
            'grants': [
              {
                'id': 'perception-proficiency',
                'kind': 'proficiency',
                'label': '察觉熟练',
                'target': 'skill:perception',
                'value': 1,
              },
            ],
          },
          '运动',
        ],
      };

      final first = RuleChoiceDefinition.fromJson(source);
      expect(first.options, hasLength(2));

      final rich = first.options.first;
      expect(rich.id, 'perception');
      expect(rich.label, '察觉');
      expect(rich.description, '看穿隐藏事物');
      expect(rich.data, {'ability': 'wis'});
      expect(rich.grants, hasLength(1));
      expect(rich.grants.single.kind, RuleGrantKind.proficiency);
      expect(rich.grants.single.target, 'skill:perception');
      expect(rich.grants.single.value, 1);

      // fromJson → toJson → fromJson 后 toJson 稳定。
      final encoded = first.toJson();
      final second = RuleChoiceDefinition.fromJson(encoded);
      expect(second.toJson(), encoded);
      // 字符串简写在往返后依然是 id == label。
      expect(second.options[1].id, '运动');
      expect(second.options[1].label, '运动');
    });

    test('非法元素（非 string 非 map）抛 FormatException', () {
      expect(
        () => RuleChoiceDefinition.fromJson(const {
          'id': 'class-skills',
          'optionType': 'skill',
          'options': [42],
        }),
        throwsFormatException,
      );
    });

    test('对象元素缺 id 抛 FormatException', () {
      expect(
        () => RuleChoiceDefinition.fromJson(const {
          'id': 'class-skills',
          'optionType': 'skill',
          'options': [
            {'label': '察觉'},
          ],
        }),
        throwsFormatException,
      );
    });
  });
}

ContentEntry _entry({
  required String id,
  required String type,
  required String name,
  List<String> tags = const [],
  Map<String, Object?> structured = const {},
  List<Map<String, Object?>> relations = const [],
  required Map<String, Object?> rules,
}) {
  return ContentEntry.fromJson({
    'id': id,
    'type': type,
    'slug': id.split('/').last,
    'name': name,
    'body': <Map<String, Object?>>[],
    'revision': 1,
    'tags': tags,
    'structured': structured,
    'relations': relations,
    'rules': rules,
  });
}
