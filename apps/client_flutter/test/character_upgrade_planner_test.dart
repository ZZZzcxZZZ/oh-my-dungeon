import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/characters/domain/character_rule_projector.dart';
import 'package:dnd_table_client/src/features/characters/domain/character_upgrade_planner.dart';
import 'package:dnd_table_client/src/features/characters/domain/declared_levels.dart';
import 'package:dnd_table_client/src/features/characters/domain/dnd5e_rules.dart';
import 'package:dnd_table_client/src/features/characters/domain/rules_driven_character_builder.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:dnd_table_client/src/features/rules/domain/character_build.dart';
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
      // P1-1/P2-11 之后派生**无条件**写法术自动准备镜像（否则取消全部选择后
      // 清不掉旧镜像），所以不再与旧 map 逐字相等；这里按载荷逐项断言：手动覆盖
      // 原样保留、手动专属的 preparedEntryIds 不被派生写入、镜像为空。
      final overrides = upgraded.dataMap['manualOverrides']! as Map;
      expect(
        (overrides['features']! as Map)['addedEntryIds'],
        <String>['feature:homebrew'],
        reason: '手动覆盖必须原样保留（apply 只负责合并派生镜像）',
      );
      expect(
        (overrides['spells']! as Map)['preparedEntryIds'],
        isEmpty,
        reason:
            'preparedEntryIds 是用户手动准备的专属存储（本夹具没有手动准备，'
            '`toJson` 把缺省序列化为空列表）；派生不覆盖它由专门的反向回归断言',
      );
      expect(
        (overrides['spells']! as Map)['alwaysPreparedEntryIds'],
        isEmpty,
        reason: '本角色没有显式法术选择：自动准备镜像被无条件清空',
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

  // §3.12：`beyondDeclaredLevel` 的语义是"低于最早声明等级、或高于最后声明等级"，
  // 另外"完全没有声明"（max == null）也算范围之外——不能把"不知道"当成"已覆盖"。
  group('beyondDeclaredLevel 与声明范围同义', () {
    CharacterUpgradePlan planFor(DeclaredLevels levels, int target) =>
        CharacterUpgradePlan(
          currentLevel: target - 1,
          targetLevel: target,
          build: CharacterBuild(
            level: target,
            selections: const <String, String>{},
          ),
          newGrants: const [],
          choices: const [],
          missingEntryIds: const [],
          declaredLevels: levels,
        );

    test('范围内 false；高于 max / 低于 min / 完全没有声明 都 true', () {
      const range = DeclaredLevels(min: 1, max: 5);
      expect(planFor(range, 1).beyondDeclaredLevel, isFalse);
      expect(planFor(range, 5).beyondDeclaredLevel, isFalse);
      expect(planFor(range, 6).beyondDeclaredLevel, isTrue);
      expect(
        planFor(const DeclaredLevels(min: 1, max: 20), 20).beyondDeclaredLevel,
        isFalse,
      );

      const late = DeclaredLevels(min: 5, max: 10);
      expect(planFor(late, 4).beyondDeclaredLevel, isTrue);
      expect(planFor(late, 5).beyondDeclaredLevel, isFalse);

      // 完全没有声明：min/max 都无从比较，界面必须提示而不是静默放行。
      expect(planFor(const DeclaredLevels(), 4).beyondDeclaredLevel, isTrue);
    });

    test('读角色持久化的声明范围：1–5 级的角色升到 6 级置位，升到 4 级不置位', () {
      CharacterSheet atLevel(int level) {
        final base = _character();
        return base.copyWith(
          level: level,
          data: <String, Object?>{
            ...base.dataMap,
            'classIdentity': <String, Object?>{
              'entryId': null,
              'slug': 'tester',
              'name': 'Tester',
              'declared': true,
              'declaredLevels': <String, Object?>{'min': 1, 'max': 5},
            },
          },
        );
      }

      final planner = CharacterUpgradePlanner(entries: entries);
      final beyond = planner.plan(atLevel(5));
      expect(beyond.targetLevel, 6);
      expect(beyond.beyondDeclaredLevel, isTrue);

      final inside = planner.plan(atLevel(3));
      expect(inside.targetLevel, 4);
      expect(inside.beyondDeclaredLevel, isFalse);
    });
  });

  // 缺陷 4：角色卡上的 `abilities` 是**最终值**（含已生效的 `kind: ability`
  // 加值），再派生时必须先减回基础值，否则同一份授予会反复叠加。
  group('再派生不重复叠加 ability grant', () {
    final ascendant = _entry(
      id: 'class:ascendant',
      type: 'class',
      name: 'Ascendant',
      structured: const <String, Object?>{
        'classRules': <String, Object?>{
          'hitDie': 10,
          'savingThrowAbilities': <String>['str', 'con'],
          'resources': <Map<String, Object?>>[
            <String, Object?>{
              'id': 'focus',
              'name': '专注',
              'recovery': 'longRest',
              'maximum': <String, Object?>{'formula': 'ability:cha'},
            },
          ],
        },
      },
      rules: const <String, Object?>{
        'progression': <Map<String, Object?>>[
          <String, Object?>{
            'levels': <int>[1, 4],
            'grants': <Map<String, Object?>>[
              <String, Object?>{
                'id': 'asi-dex',
                'kind': 'ability',
                'target': 'dex',
                'value': 2,
                'label': '敏捷提升',
              },
              <String, Object?>{
                'id': 'asi-cha',
                'kind': 'ability',
                'target': 'cha',
                'value': 2,
                'label': '魅力提升',
              },
            ],
          },
        ],
      },
    );
    final entries4 = <String, ContentEntry>{ascendant.id: ascendant};
    const baseAbilities = <String, int>{
      'str': 16,
      'dex': 13,
      'con': 14,
      'int': 10,
      'wis': 12,
      'cha': 14,
    };
    const levelOneBuild = CharacterBuild(
      level: 1,
      selections: <String, String>{'class': 'class:ascendant'},
    );

    CharacterSheet createLevelOne() => RulesDrivenCharacterBuilder(
      entries: entries4,
    ).build(
      name: 'Ayla',
      build: levelOneBuild,
      abilities: baseAbilities,
    ).toLocalCharacter();

    CharacterSheet upgradeToLevelFour() {
      final planner = CharacterUpgradePlanner(entries: entries4);
      var character = createLevelOne();
      for (var target = 2; target <= 4; target++) {
        final plan = planner.plan(character);
        expect(plan.targetLevel, target);
        character = planner.apply(character, plan);
      }
      return character;
    }

    test('L1 创建时每份加值各生效一次', () {
      final levelOne = createLevelOne();

      expect(levelOne.abilityMap['dex'], 15, reason: '13 + 2');
      expect(levelOne.abilityMap['cha'], 16, reason: '14 + 2');
    });

    test('L1→L4：只叠加 4 级新增的一份，dex 只 +2（不是 +4）', () {
      final planner = CharacterUpgradePlanner(entries: entries4);
      var character = createLevelOne();
      final dexIncrements = <int>[];

      for (var target = 2; target <= 4; target++) {
        final next = planner.apply(character, planner.plan(character));
        dexIncrements.add(
          Dnd5eRules.abilityScore(next.abilityMap, 'dex') -
              Dnd5eRules.abilityScore(character.abilityMap, 'dex'),
        );
        character = next;
      }

      expect(
        dexIncrements,
        <int>[0, 0, 2],
        reason: '只有 4 级那一份 +2；把最终值当基础值会变成每次 +2',
      );
      expect(character.abilityMap['dex'], 17, reason: '13 + 2×2');
      expect(character.abilityMap['cha'], 18, reason: '14 + 2×2');
      // AC / 先攻都读同一份 effectiveAbilities：敏捷 15(+2) → 17(+3)，只涨 1。
      expect(character.armorClass, 13, reason: '10 + dex 调整值 3');
      expect(character.initiativeBonus, 3);
      // 豁免 / 技能只反映一次：职业豁免仍是 str/con，没有凭空多出技能熟练。
      expect(character.saveMap['str'], isTrue);
      expect(character.saveMap['con'], isTrue);
      expect(character.saveMap['dex'], isFalse);
      expect(character.skillMap.values.every((value) => value == false), isTrue);
    });

    test('连续再派生 3 次数值不变（projector 往返稳定）', () {
      final upgraded = upgradeToLevelFour();
      final projector = CharacterRuleProjector(entries: entries4);
      var sheet = upgraded;

      for (var round = 0; round < 3; round++) {
        sheet = projector.project(sheet);

        expect(Dnd5eRules.abilityScore(sheet.abilityMap, 'dex'), 17);
        expect(Dnd5eRules.abilityScore(sheet.abilityMap, 'cha'), 18);
        expect(sheet.armorClass, upgraded.armorClass);
        expect(sheet.maxHp, upgraded.maxHp);
        expect(sheet.initiativeBonus, upgraded.initiativeBonus);
        // classResources 的 `formula: ability:cha` 按**含加值的有效属性**结算
        // （与 spellSaveDc 等派生同源）：cha 基础 14、1/4 级各 +2 → 有效 18
        // → 调整值 +4。若错用基础值 14，这里会算出 +2。
        final resources = (sheet.dataMap['classResources']! as List)
            .cast<Map<Object?, Object?>>();
        expect(resources.single['maximum'], 4);
      }
    });
  });

  // 决策 D4：`requires` 的能力门槛读**基础属性**（`build.abilities`），不是角色卡
  // 上的最终值。升级规划器必须与引擎同口径，否则门槛其实满足的选择会被判为不可选。
  group('升级规划的 requires 能力门槛读基础属性', () {
    final pact = _entry(
      id: 'class:pact-bound',
      type: 'class',
      name: 'Pact Bound',
      structured: const <String, Object?>{
        'classRules': <String, Object?>{
          'hitDie': 8,
          'savingThrowAbilities': <String>['cha', 'wis'],
        },
      },
      rules: const <String, Object?>{
        'progression': <Map<String, Object?>>[
          <String, Object?>{
            'levels': <int>[2],
            'choices': <Map<String, Object?>>[
              <String, Object?>{
                'id': 'invocation',
                'label': 'Invocation',
                'optionType': 'classFeature',
                'minimum': 1,
                'maximum': 1,
                'optionTags': <String>['invocation'],
                'requires': <Map<String, Object?>>[
                  <String, Object?>{'ability': 'cha', 'minimum': 13},
                ],
              },
            ],
          },
        ],
      },
    );
    final invocation = _entry(
      id: 'feature:agonizing',
      type: 'classFeature',
      name: 'Agonizing Blast',
      tags: const <String>['invocation'],
    );
    final entries5 = <String, ContentEntry>{
      pact.id: pact,
      invocation.id: invocation,
    };

    CharacterSheet pactCharacter({required bool recordAbilities}) {
      final base = _character();
      return base.copyWith(
        level: 1,
        classSummary: 'Pact Bound',
        abilities: const <String, Object?>{'cha': 15},
        data: <String, Object?>{
          ...base.dataMap,
          'build': <String, Object?>{
            'level': 1,
            'selections': <String, Object?>{'class': 'class:pact-bound'},
            'choices': <String, Object?>{},
            if (recordAbilities) 'abilities': <String, Object?>{'cha': 15},
          },
        },
      );
    }

    test('存档已记录基础属性：门槛满足，选择可完成', () {
      final planner = CharacterUpgradePlanner(entries: entries5);
      final plan = planner.plan(pactCharacter(recordAbilities: true));

      expect(plan.choices, hasLength(1));
      expect(
        plan.choices.single.requiresSatisfied,
        isTrue,
        reason: 'cha 基础 15 ≥ 13；门槛读的就是 build.abilities',
      );

      final selected = planner.select(
        pactCharacter(recordAbilities: true),
        plan,
        plan.choices.single.key,
        <String>[invocation.id],
      );
      expect(selected.isComplete, isTrue);
    });

    test('旧存档缺 build.abilities：用角色卡最终值反推基础属性后仍可完成', () {
      final planner = CharacterUpgradePlanner(entries: entries5);
      // 角色卡最终 cha = 15，本职业没有 ability 加值 → 基础值也是 15。
      final plan = planner.plan(pactCharacter(recordAbilities: false));

      expect(
        plan.choices.single.requiresSatisfied,
        isTrue,
        reason: '缺记录时用 baseAbilitiesFrom 现算（与项目器同一个唯一实现点）',
      );
    });
  });

  // 任务 9 / 契约 §3.11 A3（P1-1 修订）：升级派生出的自动准备镜像写
  // `alwaysPreparedEntryIds`；`preparedSpellEntryIds` 是**用户手动准备**的专属存储，
  // 派生一律不覆盖——否则"升级一次 = 用户手动准备丢失"。
  test('升级只更新自动准备镜像，手动准备的法术不被覆盖（§3.11 A3）', () {
    final mage = _entry(
      id: 'class:mage',
      type: 'class',
      name: 'Mage',
      structured: const {
        'classRules': {'hitDie': 6},
      },
      rules: const {
        'progression': [
          {
            'levels': [2],
            'choices': [
              {
                'id': 'spells-2',
                'label': 'Spells',
                'optionType': 'spell',
                'minimum': 0,
                'maximum': 1,
                'optionTags': ['spell-list:mage'],
                'maximumOptionLevel': 1,
              },
            ],
          },
        ],
      },
    );
    final spark = _entry(
      id: 'spell:spark',
      type: 'spell',
      name: 'Spark',
      tags: const ['spell-list:mage'],
      structured: const {'level': 0},
    );
    final planner = CharacterUpgradePlanner(
      entries: {mage.id: mage, spark.id: spark},
    );
    final base = _character();
    final initial = base.copyWith(
      data: <String, Object?>{
        ...base.dataMap,
        'build': <String, Object?>{
          'level': 1,
          'selections': <String, String>{'class': 'class:mage'},
          'choices': <String, List<String>>{},
        },
        // 用户手动准备了一个**非选择来源**的法术。
        'manualOverrides': <String, Object?>{
          'features': <String, Object?>{
            'addedEntryIds': <String>['feature:homebrew'],
          },
          'spells': <String, Object?>{
            'preparedEntryIds': <String>['spell:manual'],
          },
        },
      },
    );

    final plan = planner.plan(initial);
    final completed = planner.select(
      initial,
      plan,
      plan.choices.single.key,
      <String>['spell:spark'],
    );
    final upgraded = planner.apply(initial, completed);

    final overrides = upgraded.dataMap['manualOverrides']! as Map;
    final spells = overrides['spells']! as Map;
    expect(
      spells['alwaysPreparedEntryIds'],
      <String>['spell:spark'],
      reason: '选择派生的自动准备镜像照常更新（读取侧按并集判定已准备）',
    );
    expect(
      spells['preparedEntryIds'],
      <String>['spell:manual'],
      reason: '手动准备的法术必须原样保留，派生不得覆盖（反向回归）',
    );
    expect(
      (overrides['features']! as Map)['addedEntryIds'],
      <String>['feature:homebrew'],
      reason: '合并只改法术镜像，手动覆盖必须保留',
    );
  });

  // P1-2 反向回归：语言选择的选中值必须进 `data['profile']['languages']`
  // （角色卡读的就是它），且**嵌套合并**不得删掉同 map 的 backstory 等字段。
  test('升级把派生语言合并进 profile.languages，不删 profile 其它字段', () {
    final sage = _entry(
      id: 'class:sage',
      type: 'class',
      name: 'Sage',
      structured: const {
        'classRules': {'hitDie': 6},
      },
      rules: const {
        'progression': [
          {
            'levels': [2],
            'choices': [
              {
                'id': 'extra-language',
                'label': '额外语言',
                'optionType': 'language',
                'minimum': 1,
                'maximum': 1,
                'options': ['龙语', '精灵语'],
              },
            ],
          },
        ],
      },
    );
    final planner = CharacterUpgradePlanner(entries: {sage.id: sage});
    final base = _character();
    final initial = base.copyWith(
      data: <String, Object?>{
        ...base.dataMap,
        'build': <String, Object?>{
          'level': 1,
          'selections': <String, String>{'class': 'class:sage'},
          'choices': <String, List<String>>{},
        },
      },
    );

    final plan = planner.plan(initial);
    expect(plan.choices.single.definition.optionType, 'language');
    final completed = planner.select(
      initial,
      plan,
      plan.choices.single.key,
      <String>['龙语'],
    );
    final upgraded = planner.apply(initial, completed);

    final profile = upgraded.dataMap['profile']! as Map;
    expect(
      profile['languages'],
      <String>['龙语'],
      reason: '语言选择必须落到角色卡读取的 profile.languages，而不是只进 build.choices',
    );
    expect(
      profile['backstory'],
      'Veteran',
      reason: '嵌套合并只改 languages，profile 的其它字段必须保留',
    );
  });
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
  List<String> tags = const <String>[],
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
    'tags': tags,
    'structured': structured,
    'relations': relations,
    'rules': ?rules,
  });
}
