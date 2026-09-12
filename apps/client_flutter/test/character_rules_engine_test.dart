import 'package:dnd_table_client/src/features/content/domain/content_block.dart';
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
        poolLimits: const <String, int>{},
      );
      final levelTwo = engine.evaluate(
        const CharacterBuild(
          level: 2,
          selections: {'class': 'test:class/fighter'},
        ),
        poolLimits: const <String, int>{},
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
          poolLimits: const <String, int>{},
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
        poolLimits: const <String, int>{},
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
        poolLimits: const <String, int>{},
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
        poolLimits: const <String, int>{},
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
        poolLimits: const <String, int>{},
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

  // §3.5：`levels: [4,8,12,16]` 是"同一批效果在多个等级**重复生效**"，
  // 每个已达等级都是独立的生效单元——不能被后一次展开覆盖掉。
  group('多等级生效单元：每个已达等级各生效一次', () {
    final ascendant = _entry(
      id: 'test:class/ascendant',
      type: 'class',
      name: '晋升者',
      rules: const {
        'progression': [
          {
            'levels': [1, 2, 3],
            'grants': [
              {
                'id': 'asi-int',
                'kind': 'ability',
                'target': 'int',
                'value': 1,
                'label': '属性提升：智力 +1',
              },
            ],
            'choices': [
              {
                'id': 'asi-or-feat',
                'label': '属性提升或专长',
                'optionType': 'feat',
                'minimum': 1,
                'maximum': 1,
              },
            ],
          },
        ],
      },
    );
    final gift = _entry(
      id: 'test:feat/gift',
      type: 'feat',
      name: '天赋',
      rules: const {},
    );
    final engine = CharacterRulesEngine(
      entries: {ascendant.id: ascendant, gift.id: gift},
    );

    test('levels:[1,2,3] 的属性加值到 3 级累计 3 份，不被覆盖', () {
      final ledger = engine.evaluate(
        const CharacterBuild(
          level: 3,
          selections: {'class': 'test:class/ascendant'},
        ),
        poolLimits: const <String, int>{},
      );

      final units = ledger.grantsOfKind(RuleGrantKind.ability).toList();
      expect(
        units,
        hasLength(3),
        reason: 'ledger 键必须带生效等级，否则 1/2 级会被 3 级覆盖成 1 份',
      );
      expect(units.map((grant) => grant.sourceLevel).toSet(), {1, 2, 3});
      expect(
        units.fold<num>(0, (sum, grant) => sum + (grant.value ?? 0)),
        3,
        reason: '3 级应累计 +3',
      );
      // 派生是"按等级各生效一次"的输入：AC / HP 等消费方直接对 ledger 求和。
      final levelOne = engine.evaluate(
        const CharacterBuild(
          level: 1,
          selections: {'class': 'test:class/ascendant'},
        ),
        poolLimits: const <String, int>{},
      );
      expect(levelOne.grantsOfKind(RuleGrantKind.ability), hasLength(1));
    });

    test('choices 采用同一种语义：每个已达等级独立一次', () {
      final ledger = engine.evaluate(
        const CharacterBuild(
          level: 3,
          selections: {'class': 'test:class/ascendant'},
        ),
        poolLimits: const <String, int>{},
      );

      expect(ledger.activeChoices.map((choice) => choice.sourceLevel), [
        1,
        2,
        3,
      ]);
      expect(
        ledger.activeChoices.map((choice) => choice.key).toSet(),
        hasLength(3),
        reason: '同一份选择在多个等级各问一次，键必须能区分等级',
      );
      expect(ledger.pendingChoices, hasLength(3));
    });

    test('兼容旧存档：不带等级的 choice 键仍能被解析', () {
      final ledger = engine.evaluate(
        const CharacterBuild(
          level: 1,
          selections: {'class': 'test:class/ascendant'},
          choices: {
            'test:class/ascendant#asi-or-feat': ['test:feat/gift'],
          },
        ),
        poolLimits: const <String, int>{},
      );

      expect(ledger.pendingChoices, isEmpty);
      expect(ledger.resolvedChoiceEntryIds, contains(gift.id));
      expect(
        ledger.resolvedChoices['test:class/ascendant#asi-or-feat#1'],
        [gift.id],
        reason: '解析结果写回带等级的键，下次派生即可自愈',
      );
    });

    test('兼容旧存档：裸键在 levels:[4,8,12,16] 的 16 级 fan-out 全部命中', () {
      // 旧存档只有一条不带等级的键，但多等级步骤在 16 级会产生 4 个独立生效
      // 单元（键各带等级）。裸键必须对**每一个**都生效，而不是只命中第一个。
      final plan = _entry(
        id: 'test:class/ascendant-16',
        type: 'class',
        name: '晋升者（四级提升）',
        rules: const {
          'progression': [
            {
              'levels': [4, 8, 12, 16],
              'choices': [
                {
                  'id': 'asi-or-feat',
                  'label': '属性提升或专长',
                  'optionType': 'feat',
                  'minimum': 1,
                  'maximum': 1,
                },
              ],
            },
          ],
        },
      );
      final legacyEngine = CharacterRulesEngine(
        entries: {plan.id: plan, gift.id: gift},
      );
      const bareKey = 'test:class/ascendant-16#asi-or-feat';

      final ledger = legacyEngine.evaluate(
        const CharacterBuild(
          level: 16,
          selections: {'class': 'test:class/ascendant-16'},
          choices: {
            'test:class/ascendant-16#asi-or-feat': ['test:feat/gift'],
          },
        ),
        poolLimits: const <String, int>{},
      );

      expect(ledger.pendingChoices, isEmpty);
      expect(
        ledger.resolvedChoices.keys,
        containsAll(<String>[
          '$bareKey#4',
          '$bareKey#8',
          '$bareKey#12',
          '$bareKey#16',
        ]),
        reason: '16 级的 4 个生效单元都必须从裸键解析出来',
      );
      expect(
        ledger.resolvedChoices.values.every((ids) => ids.length == 1),
        isTrue,
      );
    });
  });

  group('内联选项与 repeatable（契约 §3.10.2 / §3.10.3）', () {
    final plan = _entry(
      id: 'test:class/ascendant-choices',
      type: 'class',
      name: '晋升者',
      rules: const {
        'choices': [
          {
            'id': 'asi',
            'label': '属性提升',
            'optionType': 'ability',
            'minimum': 1,
            'maximum': 2,
            'repeatable': true,
            'options': [
              {
                'id': 'str',
                'label': '力量 +1',
                'grants': [
                  {
                    'id': 'asi-str',
                    'kind': 'ability',
                    'label': '力量提升',
                    'target': 'str',
                    'value': 1,
                  },
                ],
              },
            ],
          },
          {
            'id': 'training',
            'label': '技能训练',
            'optionType': 'skill',
            'minimum': 1,
            'maximum': 1,
            'options': ['察觉'],
          },
        ],
      },
    );
    final engine = CharacterRulesEngine(entries: {plan.id: plan});

    test('内联 grants 选中即进 ledger；option id 不被当条目排进 missing', () {
      final ledger = engine.evaluate(
        const CharacterBuild(
          level: 1,
          selections: {'class': 'test:class/ascendant-choices'},
          choices: {'test:class/ascendant-choices#asi': ['str']},
        ),
        poolLimits: const <String, int>{},
      );

      expect(ledger.missingEntryIds, isEmpty, reason: 'str 是内联选项，不是条目 id');
      expect(ledger.resolvedChoiceEntryIds, isEmpty);
      expect(
        ledger.resolvedChoices['test:class/ascendant-choices#asi'],
        ['str'],
        reason: '内联选中值同样落进 resolvedChoices（§3.10.3-4 的落库形状）',
      );
      final grant = ledger.grants.singleWhere((grant) => grant.id == 'asi-str');
      expect(grant.kind, RuleGrantKind.ability);
      expect(grant.target, 'str');
      expect(grant.value, 1);
    });

    test('一个内联选项的多条 grants 全部进 ledger（键必须带 grant 下标）', () {
      final multi = _entry(
        id: 'test:class/multi-grant',
        type: 'class',
        name: '多重授予',
        rules: const {
          'choices': [
            {
              'id': 'gift',
              'label': '赠礼',
              'optionType': 'value',
              'minimum': 1,
              'maximum': 1,
              'options': [
                {
                  'id': 'boon',
                  'label': '恩赐',
                  'grants': [
                    {
                      'id': 'boon-str',
                      'kind': 'ability',
                      'label': '力量 +1',
                      'target': 'str',
                      'value': 1,
                    },
                    {
                      'id': 'boon-hp',
                      'kind': 'hitPoints',
                      'label': '生命 +2',
                      'value': 2,
                    },
                  ],
                },
              ],
            },
          ],
        },
      );
      final multiEngine = CharacterRulesEngine(entries: {multi.id: multi});

      final ledger = multiEngine.evaluate(
        const CharacterBuild(
          level: 1,
          selections: {'class': 'test:class/multi-grant'},
          choices: {'test:class/multi-grant#gift': ['boon']},
        ),
        poolLimits: const <String, int>{},
      );

      expect(ledger.pendingChoices, isEmpty);
      expect(
        ledger.grants,
        hasLength(2),
        reason: '两条 grants 同属一次选取，键缺 grant 维度会让前一条被后一条覆盖',
      );
      expect(
        ledger.grants.map((grant) => grant.id),
        containsAll(<String>['boon-str', 'boon-hp']),
      );
      expect(
        ledger.grants.singleWhere((grant) => grant.id == 'boon-str').kind,
        RuleGrantKind.ability,
      );
      expect(
        ledger.grants.singleWhere((grant) => grant.id == 'boon-str').value,
        1,
      );
      expect(
        ledger.grants.singleWhere((grant) => grant.id == 'boon-hp').kind,
        RuleGrantKind.hitPoints,
      );
      expect(
        ledger.grants.singleWhere((grant) => grant.id == 'boon-hp').value,
        2,
      );
    });

    test('同一 grant id 在一个选项里出现两次：按下标区分，不按 id 覆盖', () {
      final twin = _entry(
        id: 'test:class/twin-grant',
        type: 'class',
        name: '同名授予',
        rules: const {
          'choices': [
            {
              'id': 'gift',
              'label': '赠礼',
              'optionType': 'value',
              'minimum': 1,
              'maximum': 1,
              'options': [
                {
                  'id': 'boon',
                  'label': '恩赐',
                  'grants': [
                    {
                      'id': 'same-id',
                      'kind': 'ability',
                      'label': '力量 +1',
                      'target': 'str',
                      'value': 1,
                    },
                    {
                      'id': 'same-id',
                      'kind': 'hitPoints',
                      'label': '生命 +2',
                      'value': 2,
                    },
                  ],
                },
              ],
            },
          ],
        },
      );
      final twinEngine = CharacterRulesEngine(entries: {twin.id: twin});

      final ledger = twinEngine.evaluate(
        const CharacterBuild(
          level: 1,
          selections: {'class': 'test:class/twin-grant'},
          choices: {'test:class/twin-grant#gift': ['boon']},
        ),
        poolLimits: const <String, int>{},
      );

      expect(
        ledger.grants,
        hasLength(2),
        reason: 'grant.id 没有唯一性校验；键若用 id 就会把后一条覆盖掉',
      );
      expect(
        ledger.grants.map((grant) => grant.kind),
        containsAll(<RuleGrantKind>[
          RuleGrantKind.ability,
          RuleGrantKind.hitPoints,
        ]),
      );
    });

    test('repeatable: true 同一选项选两次 → 两份生效单元；resolvedChoices 保留重复', () {
      final ledger = engine.evaluate(
        const CharacterBuild(
          level: 1,
          selections: {'class': 'test:class/ascendant-choices'},
          choices: {
            'test:class/ascendant-choices#asi': ['str', 'str'],
            'test:class/ascendant-choices#training': ['察觉'],
          },
        ),
        poolLimits: const <String, int>{},
      );

      expect(ledger.grants.where((grant) => grant.id == 'asi-str'), hasLength(2));
      expect(
        ledger.resolvedChoices['test:class/ascendant-choices#asi'],
        ['str', 'str'],
      );
      expect(ledger.pendingChoices, isEmpty);
      expect(
        ledger.grants.map((grant) => grant.value).whereType<num>().fold<num>(
          0,
          (sum, value) => sum + value,
        ),
        2,
        reason: '选两次"力量 +1"必须累计 +2，而不是被去重成 +1',
      );
    });

    test('repeatable: false 的重复选中进 invalidSelected，且不重复结算', () {
      final ledger = engine.evaluate(
        const CharacterBuild(
          level: 1,
          selections: {'class': 'test:class/ascendant-choices'},
          choices: {
            'test:class/ascendant-choices#asi': ['str'],
            'test:class/ascendant-choices#training': ['察觉', '察觉'],
          },
        ),
        poolLimits: const <String, int>{},
      );

      final pending = ledger.pendingChoices.singleWhere(
        (choice) => choice.choiceId == 'training',
      );
      expect(pending.selected, ['察觉']);
      expect(pending.invalidSelected, ['察觉']);
      expect(pending.reason, RuleChoicePendingReason.notRepeatable);
      expect(
        ledger.grants.where((grant) => grant.kind == RuleGrantKind.proficiency),
        hasLength(1),
      );
    });

    test('字符串简写 skill 选项自动授予熟练（无需显式 grants）', () {
      final ledger = engine.evaluate(
        const CharacterBuild(
          level: 1,
          selections: {'class': 'test:class/ascendant-choices'},
          choices: {'test:class/ascendant-choices#training': ['察觉']},
        ),
        poolLimits: const <String, int>{},
      );

      final grant = ledger.grants.singleWhere(
        (grant) => grant.kind == RuleGrantKind.proficiency,
      );
      expect(grant.target, 'skill:察觉');
    });

    test('非候选值进 invalidSelected，原值不被静默丢弃', () {
      final ledger = engine.evaluate(
        const CharacterBuild(
          level: 1,
          selections: {'class': 'test:class/ascendant-choices'},
          choices: {
            'test:class/ascendant-choices#training': ['test:feat/不存在'],
          },
        ),
        poolLimits: const <String, int>{},
      );

      final pending = ledger.pendingChoices.singleWhere(
        (choice) => choice.choiceId == 'training',
      );
      expect(pending.selected, isEmpty);
      expect(pending.invalidSelected, ['test:feat/不存在']);
      expect(pending.reason, RuleChoicePendingReason.notACandidate);
      expect(ledger.grants, isEmpty);
    });

    test('多等级步骤的内联选择每个已达等级各生效一次（§3.5）', () {
      final multiLevel = _entry(
        id: 'test:class/ascendant-inline-multilevel',
        type: 'class',
        name: '晋升者（多级内联）',
        rules: const {
          'progression': [
            {
              'levels': [4, 8],
              'choices': [
                {
                  'id': 'asi',
                  'label': '属性提升',
                  'optionType': 'ability',
                  'minimum': 1,
                  'maximum': 1,
                  'repeatable': true,
                  'options': [
                    {
                      'id': 'str',
                      'label': '力量 +1',
                      'grants': [
                        {
                          'id': 'asi-str',
                          'kind': 'ability',
                          'label': '力量提升',
                          'target': 'str',
                          'value': 1,
                        },
                      ],
                    },
                  ],
                },
              ],
            },
          ],
        },
      );
      final multiEngine = CharacterRulesEngine(entries: {multiLevel.id: multiLevel});

      final ledger = multiEngine.evaluate(
        const CharacterBuild(
          level: 8,
          selections: {'class': 'test:class/ascendant-inline-multilevel'},
          choices: {
            'test:class/ascendant-inline-multilevel#asi#4': ['str'],
            'test:class/ascendant-inline-multilevel#asi#8': ['str'],
          },
        ),
        poolLimits: const <String, int>{},
      );

      expect(ledger.pendingChoices, isEmpty);
      final strGrants = ledger.grants
          .where((grant) => grant.id == 'asi-str')
          .toList(growable: false);
      expect(strGrants, hasLength(2), reason: '4 级与 8 级各是一个独立生效单元');
      expect(
        strGrants.map((grant) => grant.sourceLevel).toList()..sort(),
        [4, 8],
      );
    });
  });

  group('requires（契约 §3.10.2 / §3.10.3-5）', () {
    final plan = _entry(
      id: 'test:class/warlockish',
      type: 'class',
      name: '契术师',
      rules: const {
        'choices': [
          {
            'id': 'spellbook',
            'label': '法术书',
            'optionType': 'feat',
            'minimum': 1,
            'maximum': 1,
            'optionTags': ['grimoire'],
          },
          {
            'id': 'invocations',
            'label': '祈唤',
            'optionType': 'classFeature',
            'minimum': 1,
            'maximum': 1,
            'optionTags': ['invocation'],
            'requires': [
              {'ability': 'cha', 'minimum': 13},
              {'choice': 'spellbook', 'option': 'test:feat/grimoire'},
            ],
          },
        ],
      },
    );
    final grimoire = _entry(
      id: 'test:feat/grimoire',
      type: 'feat',
      name: '魔典',
      tags: const ['grimoire'],
      rules: const {},
    );
    final invocation = _entry(
      id: 'test:class-feature/agonizing',
      type: 'classFeature',
      name: '苦痛祈唤',
      tags: const ['invocation'],
      rules: const {},
    );
    final engine = CharacterRulesEngine(
      entries: {
        plan.id: plan,
        grimoire.id: grimoire,
        invocation.id: invocation,
      },
    );

    CharacterGrantLedger evaluate({
      required int cha,
      required List<String> book,
    }) => engine.evaluate(
      CharacterBuild(
        level: 1,
        abilities: {'cha': cha},
        selections: {'class': plan.id},
        choices: {
          'test:class/warlockish#spellbook': book,
          'test:class/warlockish#invocations': [invocation.id],
        },
      ),
      poolLimits: const <String, int>{},
    );

    test('能力门槛不满足 → requiresSatisfied=false 且进 pending', () {
      final ledger = evaluate(cha: 12, book: [grimoire.id]);
      final active = ledger.activeChoices.singleWhere(
        (c) => c.definition.id == 'invocations',
      );
      expect(active.requiresSatisfied, isFalse);
      expect(active.isValid, isFalse);
      expect(
        ledger.pendingChoices
            .firstWhere((p) => p.choiceId == 'invocations')
            .reason,
        RuleChoicePendingReason.requiresUnsatisfied,
      );
      expect(
        active.selected,
        [invocation.id],
        reason: '前置不满足不得静默丢弃选中值（§3.10.3-5）',
      );
    });

    test('引用的选择未满足 → 不可选；两项都满足 → 生效', () {
      expect(
        evaluate(cha: 13, book: const [])
            .pendingChoices
            .firstWhere((p) => p.choiceId == 'invocations')
            .reason,
        RuleChoicePendingReason.requiresUnsatisfied,
      );
      expect(evaluate(cha: 13, book: [grimoire.id]).pendingChoices, isEmpty);
    });

    test('未记录属性（空 abilities）≠ 属性为 0：一律判不满足', () {
      final ledger = engine.evaluate(
        const CharacterBuild(
          level: 1,
          selections: {'class': 'test:class/warlockish'},
          choices: {
            'test:class/warlockish#spellbook': ['test:feat/grimoire'],
            'test:class/warlockish#invocations': [
              'test:class-feature/agonizing',
            ],
          },
        ),
        poolLimits: const <String, int>{},
      );

      expect(
        ledger.activeChoices
            .singleWhere((c) => c.definition.id == 'invocations')
            .requiresSatisfied,
        isFalse,
        reason: '缺 build.abilities = "未记录"，不猜成 10（决策 D4）',
      );
    });

    test('内联选项的门槛不满足 → 该选择的 grants 真的不生效，只留在 pending', () {
      final gated = _entry(
        id: 'test:class/gated-gift',
        type: 'class',
        name: '有门槛的赠礼',
        rules: const {
          'choices': [
            {
              'id': 'gift',
              'label': '高阶赠礼',
              'optionType': 'value',
              'minimum': 1,
              'maximum': 1,
              'requires': [
                {'ability': 'cha', 'minimum': 13},
              ],
              'options': [
                {
                  'id': 'boon',
                  'label': '魅力 +1',
                  'grants': [
                    {
                      'id': 'gift-cha',
                      'kind': 'ability',
                      'label': '魅力 +1',
                      'target': 'cha',
                      'value': 1,
                    },
                  ],
                },
              ],
            },
          ],
        },
      );
      final gatedEngine = CharacterRulesEngine(entries: {gated.id: gated});
      CharacterGrantLedger evaluateGift(int cha) => gatedEngine.evaluate(
        CharacterBuild(
          level: 1,
          abilities: {'cha': cha},
          selections: {'class': 'test:class/gated-gift'},
          choices: {'test:class/gated-gift#gift': ['boon']},
        ),
        poolLimits: const <String, int>{},
      );

      final blocked = evaluateGift(12);
      expect(
        blocked.grants.where((grant) => grant.id == 'gift-cha'),
        isEmpty,
        reason: '前置不满足 = 不生效，内联 grants 不得展开进账',
      );
      final active = blocked.activeChoices.single;
      expect(active.requiresSatisfied, isFalse);
      expect(active.isValid, isFalse);
      expect(active.selected, ['boon'], reason: '不静默丢弃选中值（§3.10.3-5）');
      expect(
        blocked.resolvedChoices['test:class/gated-gift#gift'],
        ['boon'],
        reason: '仍保留在 resolvedChoices，UI 才能显示"已选但未生效"',
      );
      final pending = blocked.pendingChoices.single;
      expect(pending.reason, RuleChoicePendingReason.requiresUnsatisfied);
      expect(pending.selected, ['boon']);

      final allowed = evaluateGift(13);
      expect(allowed.pendingChoices, isEmpty);
      expect(allowed.activeChoices.single.requiresSatisfied, isTrue);
      final grant = allowed.grants.singleWhere(
        (grant) => grant.id == 'gift-cha',
      );
      expect(grant.target, 'cha');
      expect(grant.value, 1);
    });

    // P2-1：**选项级** `requires`（`options[].requires`，决策 D6）也要真的生效。
    // 选择本身合法（数量够、choice 级 requires 满足），因此不会进 pending；但被
    // 选项级前置挡住的候选**不得展开 grants**——UI 侧同时把"被隐藏但已选"的值列为
    // "已选但未生效"（`rule_choice_section_test`），两处口径同源
    // （`RuleChoiceSemantics.candidateRequiresSatisfied`）。
    test('选项级 requires 不满足的已选候选不生效（不展开 grants）', () {
      final gatedOption = _entry(
        id: 'test:class/gated-option',
        type: 'class',
        name: '带选项门槛的选择',
        rules: const {
          'choices': [
            {
              'id': 'invocations',
              'label': '祈唤',
              'optionType': 'value',
              'minimum': 1,
              'maximum': 2,
              'options': [
                {
                  'id': 'basic',
                  'label': '基础祈唤',
                  'grants': [
                    {
                      'id': 'basic-str',
                      'kind': 'ability',
                      'label': '力量 +1',
                      'target': 'str',
                      'value': 1,
                    },
                  ],
                },
                {
                  'id': 'high',
                  'label': '高阶祈唤',
                  'requires': [
                    {'ability': 'cha', 'minimum': 13},
                  ],
                  'grants': [
                    {
                      'id': 'high-cha',
                      'kind': 'ability',
                      'label': '魅力 +1',
                      'target': 'cha',
                      'value': 1,
                    },
                  ],
                },
              ],
            },
          ],
        },
      );
      final optionEngine = CharacterRulesEngine(
        entries: {gatedOption.id: gatedOption},
      );
      CharacterGrantLedger evaluateOptions(int cha) => optionEngine.evaluate(
        CharacterBuild(
          level: 1,
          abilities: {'cha': cha},
          selections: {'class': 'test:class/gated-option'},
          choices: {
            'test:class/gated-option#invocations': ['basic', 'high'],
          },
        ),
        poolLimits: const <String, int>{},
      );

      final blocked = evaluateOptions(12);
      expect(
        blocked.grants.map((grant) => grant.id),
        <String>['basic-str'],
        reason: '选项级前置不满足的候选不产出 grants（与 UI 隐藏同一判据）',
      );
      expect(
        blocked.resolvedChoices['test:class/gated-option#invocations'],
        <String>['basic', 'high'],
        reason: '不静默丢弃选中值（§3.10.3-5）：UI 据此显示"已选但未生效"',
      );
      expect(
        blocked.grants.where((grant) => grant.id == 'high-cha'),
        isEmpty,
        reason: '不生效不是"少给一条"而是"这条候选根本没生效"',
      );

      final allowed = evaluateOptions(13);
      expect(
        allowed.grants.map((grant) => grant.id),
        unorderedEquals(<String>['basic-str', 'high-cha']),
        reason: '前置满足后同一条选中值必须生效',
      );
    });

    test('门槛不满足 → 引用的条目也不授予（不入队）；满足后才生效', () {
      final gatedPlan = _entry(
        id: 'test:class/gated-invocation',
        type: 'class',
        name: '有门槛的祈唤',
        rules: const {
          'choices': [
            {
              'id': 'invocations',
              'label': '祈唤',
              'optionType': 'classFeature',
              'minimum': 1,
              'maximum': 1,
              'optionTags': ['invocation'],
              'requires': [
                {'ability': 'cha', 'minimum': 13},
              ],
            },
          ],
        },
      );
      final invocationWithRules = _entry(
        id: 'test:class-feature/gift-of-power',
        type: 'classFeature',
        name: '力量馈赠',
        tags: const ['invocation'],
        rules: const {
          'grants': [
            {
              'id': 'gift-of-power',
              'kind': 'feature',
              'label': '力量馈赠',
              'entryId': 'test:class-feature/gift-of-power',
            },
          ],
        },
      );
      final gatedEngine = CharacterRulesEngine(
        entries: {
          gatedPlan.id: gatedPlan,
          invocationWithRules.id: invocationWithRules,
        },
      );
      CharacterGrantLedger evaluateGated(int cha) => gatedEngine.evaluate(
        CharacterBuild(
          level: 1,
          abilities: {'cha': cha},
          selections: {'class': 'test:class/gated-invocation'},
          choices: {
            'test:class/gated-invocation#invocations': [
              'test:class-feature/gift-of-power',
            ],
          },
        ),
        poolLimits: const <String, int>{},
      );

      final blocked = evaluateGated(12);
      expect(
        blocked.grants.where((grant) => grant.id == 'gift-of-power'),
        isEmpty,
        reason: '该选择不生效，它引用的条目也不得入队授予',
      );
      expect(blocked.resolvedChoiceEntryIds, isEmpty);
      expect(blocked.missingEntryIds, isEmpty);
      expect(
        blocked.pendingChoices.single.reason,
        RuleChoicePendingReason.requiresUnsatisfied,
      );

      final allowed = evaluateGated(13);
      expect(allowed.pendingChoices, isEmpty);
      expect(allowed.resolvedChoiceEntryIds, [
        'test:class-feature/gift-of-power',
      ]);
      expect(
        allowed.grants.where((grant) => grant.id == 'gift-of-power'),
        hasLength(1),
      );
    });

    test('CharacterBuild.abilities JSON 往返，缺省为空 map', () {
      const build = CharacterBuild(level: 3, abilities: {'cha': 15});
      expect(CharacterBuild.fromJson(build.toJson()).abilities, {'cha': 15});
      expect(const CharacterBuild(level: 1).abilities, isEmpty);
      expect(CharacterBuild.fromJson(const {'level': 1}).abilities, isEmpty);
      expect(
        CharacterBuild.fromJson(const {
          'level': 1,
          'abilities': {'cha': '15'},
        }).abilities,
        isEmpty,
        reason: '非数值条目视为未记录，不猜',
      );
      expect(
        const CharacterBuild(level: 1).toJson().containsKey('abilities'),
        isFalse,
        reason: '空 map 不写进 JSON（旧存档形状不膨胀）',
      );
    });
  });

  group('countsToward 额度池（契约 §3.10.2 / 决策 D8）', () {
    final plan = _entry(
      id: 'test:class/spellkeeper',
      type: 'class',
      name: '持法者',
      rules: const {
        'choices': [
          {
            'id': 'book',
            'label': '法术书',
            'optionType': 'spell',
            'minimum': 0,
            'maximum': 3,
            'countsToward': 'prepared',
            'optionTags': ['spell-list:mage'],
          },
          {
            'id': 'extra',
            'label': '额外法术',
            'optionType': 'spell',
            'minimum': 0,
            'maximum': 2,
            'countsToward': 'prepared',
            'optionTags': ['spell-list:mage'],
          },
          {
            'id': 'free',
            'label': '额外戏法',
            'optionType': 'spell',
            'minimum': 0,
            'maximum': 2,
            'optionTags': ['spell-list:mage'],
          },
        ],
      },
    );
    final spells = [
      for (final suffix in const ['a', 'b', 'c', 'd'])
        _entry(
          id: 'test:spell/$suffix',
          type: 'spell',
          name: '法术 $suffix',
          tags: const ['spell-list:mage'],
          rules: const {},
        ),
    ];
    final engine = CharacterRulesEngine(
      entries: {
        plan.id: plan,
        for (final spell in spells) spell.id: spell,
      },
    );

    test('两个选择共享 prepared 池：先声明先占，超出部分进 pending（poolExceeded）', () {
      final ledger = engine.evaluate(
        const CharacterBuild(
          level: 1,
          selections: {'class': 'test:class/spellkeeper'},
          choices: {
            'test:class/spellkeeper#book': [
              'test:spell/a',
              'test:spell/b',
              'test:spell/c',
            ],
            'test:class/spellkeeper#extra': ['test:spell/d'],
          },
        ),
        poolLimits: const {'prepared': 3},
      );

      expect(
        ledger.resolvedChoices['test:class/spellkeeper#book'],
        hasLength(3),
      );
      expect(ledger.resolvedChoices['test:class/spellkeeper#extra'], isEmpty);
      expect(
        ledger.pendingChoices.single.reason,
        RuleChoicePendingReason.poolExceeded,
      );
      expect(ledger.pendingChoices.single.invalidSelected, ['test:spell/d']);
      final book = ledger.activeChoices.singleWhere(
        (choice) => choice.definition.id == 'book',
      );
      expect(book.poolCap, 3);
      expect(book.pool, 'prepared');
    });

    test('池额度按声明顺序扣减：前者少占，后者就能多占', () {
      final ledger = engine.evaluate(
        const CharacterBuild(
          level: 1,
          selections: {'class': 'test:class/spellkeeper'},
          choices: {
            'test:class/spellkeeper#book': ['test:spell/a'],
            'test:class/spellkeeper#extra': ['test:spell/b', 'test:spell/c'],
          },
        ),
        poolLimits: const {'prepared': 3},
      );

      expect(ledger.resolvedChoices['test:class/spellkeeper#book'], [
        'test:spell/a',
      ]);
      expect(ledger.resolvedChoices['test:class/spellkeeper#extra'], [
        'test:spell/b',
        'test:spell/c',
      ]);
      expect(ledger.pendingChoices, isEmpty);
    });

    test('未声明 countsToward 的选择不受池限制，只受自身 maximum', () {
      final ledger = engine.evaluate(
        const CharacterBuild(
          level: 1,
          selections: {'class': 'test:class/spellkeeper'},
          choices: {
            'test:class/spellkeeper#free': ['test:spell/a', 'test:spell/b'],
          },
        ),
        // 池已被占满，但 `free` 不占池。
        poolLimits: const {'prepared': 0},
      );

      expect(ledger.resolvedChoices['test:class/spellkeeper#free'], [
        'test:spell/a',
        'test:spell/b',
      ]);
      expect(ledger.pendingChoices, isEmpty);
      final free = ledger.activeChoices.singleWhere(
        (choice) => choice.definition.id == 'free',
      );
      expect(free.pool, isNull);
      expect(free.poolCap, isNull);
    });

    test('声明了 countsToward 但池没有声明额度（spellbook）→ 有效上限是 maximum，原因 aboveMaximum', () {
      final bookPlan = _entry(
        id: 'test:class/spellbook-keeper',
        type: 'class',
        name: '法术书持用者',
        rules: const {
          'choices': [
            {
              'id': 'book',
              'label': '法术书',
              'optionType': 'spell',
              'minimum': 0,
              'maximum': 2,
              'countsToward': 'spellbook',
              'optionTags': ['spell-list:mage'],
            },
          ],
        },
      );
      final bookEngine = CharacterRulesEngine(
        entries: {
          bookPlan.id: bookPlan,
          for (final spell in spells) spell.id: spell,
        },
      );

      final ledger = bookEngine.evaluate(
        const CharacterBuild(
          level: 1,
          selections: {'class': 'test:class/spellbook-keeper'},
          choices: {
            'test:class/spellbook-keeper#book': [
              'test:spell/a',
              'test:spell/b',
              'test:spell/c',
            ],
          },
        ),
        // 只声明了 prepared，法术书池没有上限（决策 D3：没声明上限 = 不限）。
        poolLimits: const {'prepared': 1},
      );

      expect(
        ledger.resolvedChoices['test:class/spellbook-keeper#book'],
        hasLength(2),
        reason: '仍受自身 maximum = 2，不被 prepared 列反向限制',
      );
      expect(
        ledger.pendingChoices.single.reason,
        RuleChoicePendingReason.aboveMaximum,
        reason: '池没有声明额度（spellbook 不在 poolLimits 里）→ 超额归因于自身 maximum',
      );
      final book = ledger.activeChoices.single;
      expect(book.pool, 'spellbook');
      expect(book.poolCap, 2, reason: '池没声明上限 → 有效上限就是 maximum');
    });

    test('未知池名（程序化构造绕过解析层）按不占池处理，不抛异常', () {
      // 解析层把非法池名挡在门外（`kCountsTowardPools`），因此这个输入只可能来自
      // 直接构造的 `ContentEntry`（程序化构造）；引擎必须按"不占池"处理而不是崩。
      const oddPlan = ContentEntry(
        id: 'test:class/odd-keeper',
        type: 'class',
        slug: 'odd-keeper',
        name: '异池持用者',
        body: <ContentBlock>[],
        revision: 1,
        rules: CharacterRuleDefinition(
          choices: <RuleChoiceDefinition>[
            RuleChoiceDefinition(
              id: 'odd',
              label: '异池',
              optionType: 'spell',
              minimum: 0,
              maximum: 2,
              countsToward: 'rituals',
              optionTags: <String>['spell-list:mage'],
            ),
          ],
        ),
      );
      final oddEngine = CharacterRulesEngine(
        entries: {
          oddPlan.id: oddPlan,
          for (final spell in spells) spell.id: spell,
        },
      );

      final ledger = oddEngine.evaluate(
        const CharacterBuild(
          level: 1,
          selections: {'class': 'test:class/odd-keeper'},
          choices: {
            'test:class/odd-keeper#odd': ['test:spell/a'],
          },
        ),
        poolLimits: const <String, int>{},
      );

      expect(ledger.pendingChoices, isEmpty);
      expect(ledger.activeChoices.single.pool, 'rituals');
      expect(ledger.activeChoices.single.poolCap, 2);
    });

    test('未声明 countsToward 但超自身 maximum → aboveMaximum（不是 poolExceeded）', () {
      final ledger = engine.evaluate(
        const CharacterBuild(
          level: 1,
          selections: {'class': 'test:class/spellkeeper'},
          choices: {
            'test:class/spellkeeper#free': [
              'test:spell/a',
              'test:spell/b',
              'test:spell/c',
            ],
          },
        ),
        // 即便池列表非空，`free` 自己不占池 → 超额与池无关。
        poolLimits: const {'prepared': 3},
      );

      expect(
        ledger.resolvedChoices['test:class/spellkeeper#free'],
        hasLength(2),
      );
      final pending = ledger.pendingChoices.single;
      expect(pending.reason, RuleChoicePendingReason.aboveMaximum);
      expect(pending.invalidSelected, ['test:spell/c']);
      expect(
        ledger.activeChoices
            .singleWhere((choice) => choice.definition.id == 'free')
            .pool,
        isNull,
      );
    });

    test('跨条目争用同一池：按 build.selections 的迭代顺序 FCFS（顺序随存档复现）', () {
      final first = _entry(
        id: 'test:class/pool-first',
        type: 'class',
        name: '先声明者',
        rules: const {
          'choices': [
            {
              'id': 'book',
              'label': '法术书',
              'optionType': 'spell',
              'minimum': 0,
              'maximum': 2,
              'countsToward': 'prepared',
              'optionTags': ['spell-list:mage'],
            },
          ],
        },
      );
      final second = _entry(
        id: 'test:class/pool-second',
        type: 'class',
        name: '后声明者',
        rules: const {
          'choices': [
            {
              'id': 'book',
              'label': '法术书',
              'optionType': 'spell',
              'minimum': 0,
              'maximum': 2,
              'countsToward': 'prepared',
              'optionTags': ['spell-list:mage'],
            },
          ],
        },
      );
      final crossEngine = CharacterRulesEngine(
        entries: {
          first.id: first,
          second.id: second,
          for (final spell in spells) spell.id: spell,
        },
      );

      CharacterGrantLedger evaluateCross(List<String> order) =>
          crossEngine.evaluate(
            CharacterBuild(
              level: 1,
              selections: {
                for (var index = 0; index < order.length; index++)
                  'slot$index': order[index],
              },
              choices: const {
                'test:class/pool-first#book': ['test:spell/a', 'test:spell/b'],
                'test:class/pool-second#book': ['test:spell/c', 'test:spell/d'],
              },
            ),
            poolLimits: const {'prepared': 2},
          );

      final firstWins = evaluateCross([first.id, second.id]);
      expect(firstWins.resolvedChoices['test:class/pool-first#book'], [
        'test:spell/a',
        'test:spell/b',
      ]);
      expect(firstWins.resolvedChoices['test:class/pool-second#book'], isEmpty);
      expect(
        firstWins.pendingChoices.single.reason,
        RuleChoicePendingReason.poolExceeded,
        reason: '池声明了额度，超额归因于池',
      );

      final secondWins = evaluateCross([second.id, first.id]);
      expect(secondWins.resolvedChoices['test:class/pool-second#book'], [
        'test:spell/c',
        'test:spell/d',
      ]);
      expect(secondWins.resolvedChoices['test:class/pool-first#book'], isEmpty);
      expect(
        secondWins.pendingChoices.single.reason,
        RuleChoicePendingReason.poolExceeded,
      );
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
