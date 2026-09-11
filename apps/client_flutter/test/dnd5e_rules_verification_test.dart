import 'package:dnd_table_client/src/features/characters/domain/ability_score_generator.dart';
import 'package:dnd_table_client/src/features/characters/domain/equipment_cost.dart';
import 'package:dnd_table_client/src/features/characters/domain/dnd5e_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// 独立 D&D 5e/2024 规则核算：期望值来自 SRD/PHB 表格，与实现交叉验证。
/// 任何失败都代表产品规则逻辑与规则书不一致。
void main() {
  group('属性与熟练', () {
    test('属性调整值覆盖 1..30', () {
      const expected = {
        1: -5, 2: -4, 3: -4, 4: -3, 5: -3, 6: -2, 7: -2, 8: -1, 9: -1,
        10: 0, 11: 0, 12: 1, 13: 1, 14: 2, 15: 2, 16: 3, 17: 3, 18: 4,
        19: 4, 20: 5, 22: 6, 24: 7, 26: 8, 28: 9, 30: 10,
      };
      expected.forEach((score, modifier) {
        expect(
          Dnd5eRules.abilityModifier(score),
          modifier,
          reason: '属性 $score 的调整值应为 $modifier',
        );
      });
    });

    test('熟练加值覆盖 1..20', () {
      for (var level = 1; level <= 20; level++) {
        final expected = 2 + ((level - 1) ~/ 4);
        expect(
          Dnd5eRules.proficiencyBonus(level),
          expected,
          reason: '$level 级熟练加值应为 +$expected',
        );
      }
    });

    test('豁免与技能加值 = 属性调整值 + 熟练加值', () {
      const abilities = {'str': 16, 'dex': 14, 'con': 15, 'int': 10, 'wis': 12, 'cha': 8};
      expect(
        Dnd5eRules.saveBonus(ability: 'str', abilities: abilities, level: 5, proficient: true),
        3 + 3,
      );
      expect(
        Dnd5eRules.saveBonus(ability: 'cha', abilities: abilities, level: 5, proficient: false),
        -1,
      );
      // 运动（力量）熟练、5 级
      expect(
        Dnd5eRules.skillBonus(skillName: '运动', abilities: abilities, level: 5, proficient: true),
        6,
      );
      // 隐匿（敏捷）未熟练
      expect(
        Dnd5eRules.skillBonus(skillName: '隐匿', abilities: abilities, level: 5, proficient: false),
        2,
      );
    });

    test('先攻与法术豁免 DC', () {
      const abilities = {'str': 10, 'dex': 16, 'con': 10, 'int': 18, 'wis': 10, 'cha': 10};
      expect(Dnd5eRules.initiativeBonus(abilities), 3);
      expect(
        Dnd5eRules.spellSaveDc(classSummary: '法师', abilities: abilities, level: 5),
        8 + 3 + 4,
      );
      expect(
        Dnd5eRules.spellSaveDc(classSummary: '战士', abilities: abilities, level: 5),
        isNull,
      );
    });
  });

  group('法术位（独立表格核算）', () {
    // 全施法者标准表（法师/牧师/德鲁伊/吟游诗人/术士）
    const fullCaster = {
      1: {1: 2},
      2: {1: 3},
      3: {1: 4, 2: 2},
      4: {1: 4, 2: 3},
      5: {1: 4, 2: 3, 3: 2},
      6: {1: 4, 2: 3, 3: 3},
      7: {1: 4, 2: 3, 3: 3, 4: 1},
      8: {1: 4, 2: 3, 3: 3, 4: 2},
      9: {1: 4, 2: 3, 3: 3, 4: 3, 5: 1},
      10: {1: 4, 2: 3, 3: 3, 4: 3, 5: 2},
      11: {1: 4, 2: 3, 3: 3, 4: 3, 5: 2, 6: 1},
      13: {1: 4, 2: 3, 3: 3, 4: 3, 5: 2, 6: 1, 7: 1},
      15: {1: 4, 2: 3, 3: 3, 4: 3, 5: 2, 6: 1, 7: 1, 8: 1},
      17: {1: 4, 2: 3, 3: 3, 4: 3, 5: 2, 6: 1, 7: 1, 8: 1, 9: 1},
      18: {1: 4, 2: 3, 3: 3, 4: 3, 5: 3, 6: 1, 7: 1, 8: 1, 9: 1},
      19: {1: 4, 2: 3, 3: 3, 4: 3, 5: 3, 6: 2, 7: 1, 8: 1, 9: 1},
      20: {1: 4, 2: 3, 3: 3, 4: 3, 5: 3, 6: 2, 7: 2, 8: 1, 9: 1},
    };

    for (final className in ['法师', '牧师', '德鲁伊', '吟游诗人', '术士']) {
      test('$className 全施法者法术位 1..20', () {
        fullCaster.forEach((level, table) {
          final actual = Dnd5eRules.spellSlotMaximums(
            classSummary: className,
            level: level,
          );
          final expected = table.map((k, v) => MapEntry('$k', v));
          expect(actual, expected, reason: '$className $level 级');
        });
      });
    }

    // 半施法者（圣武士/游侠）：2024 起 1 级即有法术位，等效等级 = ceil(level/2)
    const halfCaster = {
      1: {1: 2},
      2: {1: 2},
      3: {1: 3},
      4: {1: 3},
      5: {1: 4, 2: 2},
      6: {1: 4, 2: 2},
      7: {1: 4, 2: 3},
      9: {1: 4, 2: 3, 3: 2},
      13: {1: 4, 2: 3, 3: 3, 4: 1},
      17: {1: 4, 2: 3, 3: 3, 4: 3, 5: 1},
      19: {1: 4, 2: 3, 3: 3, 4: 3, 5: 2},
      20: {1: 4, 2: 3, 3: 3, 4: 3, 5: 2},
    };

    for (final className in ['圣武士', '游侠']) {
      test('$className 半施法者法术位', () {
        halfCaster.forEach((level, table) {
          final actual = Dnd5eRules.spellSlotMaximums(
            classSummary: className,
            level: level,
          );
          final expected = table.map((k, v) => MapEntry('$k', v));
          expect(actual, expected, reason: '$className $level 级');
        });
      });
    }

    test('非施法者无法术位', () {
      for (final className in ['战士', '野蛮人', '武僧', '游荡者']) {
        expect(
          Dnd5eRules.spellSlotMaximums(classSummary: className, level: 10),
          isEmpty,
          reason: className,
        );
      }
    });

    // 邪术师使用契约魔法：短休恢复、单个环阶、数量随等级
    const pactMagic = {
      1: {1: 1},
      2: {1: 2},
      3: {2: 2},
      5: {3: 2},
      7: {4: 2},
      9: {5: 2},
      11: {5: 3},
      17: {5: 4},
      20: {5: 4},
    };

    test('邪术师契约魔法（短休恢复、单环阶）', () {
      pactMagic.forEach((level, table) {
        final actual = Dnd5eRules.spellSlotMaximums(
          classSummary: '邪术师',
          level: level,
        );
        final expected = table.map((k, v) => MapEntry('$k', v));
        expect(actual, expected, reason: '邪术师 $level 级');
      });
    });
  });

  group('契约魔法判据（只看 archetype，不看 mode）', () {
    // 契约魔法属于"法术位进阶"而不是"法术选择模型"：唯一信号是
    // `archetype: "pact"`。内置档案的邪术师写 `mode: "prepared"`（它准备法术），
    // 仍然使用契约魔法；`mode: "pact"` 已不是合法取值。
    const pactEntry = <String, Object?>{
      'classRules': <String, Object?>{
        'hitDie': 8,
        'spellcasting': <String, Object?>{
          'mode': 'prepared',
          'ability': 'cha',
          'archetype': 'pact',
        },
      },
    };

    test('mode: prepared + archetype: pact → 契约魔法，法术位来自 pact 原型', () {
      final rules = Dnd5eRules.resolveClassRules(
        entryId: 'test-pack:class/star-pact',
        classSummary: '星之契约者',
        structured: pactEntry,
      );
      expect(rules.spellcastingMode, 'prepared');
      expect(
        rules.usesPactMagic,
        isTrue,
        reason: '判据来自 archetype，而不是 mode（mode 是 prepared）',
      );
      // 档案 pact 原型 5 级：slotLevel=3、每级计数 2 → {"3": 2}；
      // 若误按行下标展开会得到 {"1": 2}，这里的断言把它钉死。
      expect(rules.spellSlots(5), {'3': 2});
    });

    test('mode: pact 已非法，且不再表示契约魔法', () {
      final rules = Dnd5eRules.resolveClassRules(
        entryId: 'test-pack:class/legacy-pact',
        classSummary: '旧契约者',
        structured: const <String, Object?>{
          'classRules': <String, Object?>{
            'hitDie': 8,
            'spellcasting': <String, Object?>{
              'mode': 'pact',
              'ability': 'cha',
            },
          },
        },
      );
      // 没有 archetype 可回退：旧的双重信号已被移除，mode: pact 不再算契约魔法。
      expect(rules.usesPactMagic, isFalse);
      expect(rules.pactSlotLevel(5), isNull);
      expect(rules.spellSlots(5), isEmpty);
    });
  });

  group('职业资源', () {
    test('战士：第二气息与动作如潮', () {
      final l1 = Dnd5eRules.classResourceMaximums(classSummary: '战士', level: 1);
      expect(l1['second_wind'], 2);
      expect(l1.containsKey('action_surge'), isFalse);

      final l2 = Dnd5eRules.classResourceMaximums(classSummary: '战士', level: 2);
      expect(l2['second_wind'], 2);
      expect(l2['action_surge'], 1);

      final l4 = Dnd5eRules.classResourceMaximums(classSummary: '战士', level: 4);
      expect(l4['second_wind'], 3);

      final l10 = Dnd5eRules.classResourceMaximums(classSummary: '战士', level: 10);
      expect(l10['second_wind'], 4);

      // 2024：17 级动作如潮 2 次
      final l17 = Dnd5eRules.classResourceMaximums(classSummary: '战士', level: 17);
      expect(l17['action_surge'], 2, reason: '17 级动作如潮应为 2 次');
    });

    test('野蛮人：狂暴次数', () {
      const expected = {1: 2, 2: 2, 3: 3, 5: 3, 6: 4, 11: 4, 12: 5, 16: 5, 17: 6, 20: 6};
      expected.forEach((level, uses) {
        expect(
          Dnd5eRules.classResourceMaximums(classSummary: '野蛮人', level: level)['rage'],
          uses,
          reason: '野蛮人 $level 级狂暴',
        );
      });
    });
  });

  group('生命值', () {
    test('1 级取满骰 + CON 调整值', () {
      const abilities = {'con': 14};
      expect(Dnd5eRules.averageHitPoints(className: '战士', level: 1, abilities: abilities), 10 + 2);
      expect(Dnd5eRules.averageHitPoints(className: '法师', level: 1, abilities: abilities), 6 + 2);
      expect(Dnd5eRules.averageHitPoints(className: '野蛮人', level: 1, abilities: abilities), 12 + 2);
    });

    test('后续等级取平均值（骰面/2+1）+ CON', () {
      const abilities = {'con': 14};
      // 战士 d10：1 级 12，2 级 12+8=20，5 级 12+4*8=44
      expect(Dnd5eRules.averageHitPoints(className: '战士', level: 2, abilities: abilities), 20);
      expect(Dnd5eRules.averageHitPoints(className: '战士', level: 5, abilities: abilities), 44);
      // 法师 d6：1 级 8，3 级 8+2*6=20
      expect(Dnd5eRules.averageHitPoints(className: '法师', level: 3, abilities: abilities), 20);
    });

    test('每级至少获得 1 点生命（负 CON 时）', () {
      const abilities = {'con': 1}; // -5
      // 规则：升级时至少 +1 HP。d6 平均 4 + (-5) = -1 → 应为 1
      final level2 = Dnd5eRules.averageHitPoints(
        className: '法师',
        level: 2,
        abilities: abilities,
      );
      expect(level2, 6 - 5 + 1, reason: '2 级至少 +1 HP');
    });
  });

  group('货币换算（D&D 5e 汇率）', () {
    test('1pp=10gp=1000cp，1ep=5sp=50cp', () {
      expect(EquipmentCost.parse('1 GP')!.copperPieces, 100);
      expect(EquipmentCost.parse('1 PP')!.copperPieces, 1000);
      expect(EquipmentCost.parse('1 EP')!.copperPieces, 50);
      expect(EquipmentCost.parse('1 SP')!.copperPieces, 10);
      expect(EquipmentCost.parse('1 CP')!.copperPieces, 1);
      // 混合面额累加
      expect(EquipmentCost.parse('1 GP 5 SP 3 CP')!.copperPieces, 100 + 50 + 3);
      // 数量倍率
      expect((EquipmentCost.parse('2 GP')! * 3).copperPieces, 600);
    });
  });

  group('购点与掷骰', () {
    test('购点成本表与预算', () {
      const costs = {8: 0, 9: 1, 10: 2, 11: 3, 12: 4, 13: 5, 14: 7, 15: 9};
      costs.forEach((score, cost) {
        expect(AbilityScoreGenerator.pointBuyCost(score), cost, reason: '$score 分应花费 $cost');
      });
      expect(AbilityScoreGenerator.pointBuyBudget, 27);
      expect(AbilityScoreGenerator.standardArray, [15, 14, 13, 12, 10, 8]);
      // 标准数组折算购点为 27（9+7+5+4+2+0）
      var spent = 0;
      for (final score in AbilityScoreGenerator.standardArray) {
        spent += AbilityScoreGenerator.pointBuyCost(score)!;
      }
      expect(spent, 27);
    });

    test('长休恢复全部法术位，短休只恢复契约魔法', () {
      const used = {'1': 2, '2': 1};
      // 长休：全部清空
      expect(
        Dnd5eRules.spellSlotsAfterRest(
          classSummary: '法师',
          used: used,
          longRest: true,
        ),
        isEmpty,
      );
      // 普通施法者短休：保持不变
      expect(
        Dnd5eRules.spellSlotsAfterRest(
          classSummary: '法师',
          used: used,
          longRest: false,
        ),
        used,
      );
      // 邪术师短休：契约魔法恢复
      expect(
        Dnd5eRules.spellSlotsAfterRest(
          classSummary: '邪术师',
          used: const {'5': 2},
          longRest: false,
        ),
        isEmpty,
      );
    });

    test('4d6 去最低', () {
      // nextInt(6) 返回 5,4,1,0 → 点数 6,5,2,1 → 去最低 1 → 2+5+6 = 13
      final rolls = [5, 4, 1, 0];
      var index = 0;
      final total = AbilityScoreGenerator.rollOne(nextInt: (_) => rolls[index++]);
      expect(total, 13);

      // 全 6 → 18
      final maxed = AbilityScoreGenerator.rollOne(nextInt: (_) => 5);
      expect(maxed, 18);

      // 全 1 → 3
      final minimum = AbilityScoreGenerator.rollOne(nextInt: (_) => 0);
      expect(minimum, 3);
    });
  });

  group('伤害与治疗结算（2024）', () {
    Dnd5eHitPoints apply({
      required int current,
      required int temporary,
      required int delta,
      int maximum = 30,
    }) {
      return Dnd5eRules.applyHitPointDelta(
        current: current,
        maximum: maximum,
        temporary: temporary,
        delta: delta,
      );
    }

    test('临时生命值足够时完全吸收伤害', () {
      final result = apply(current: 20, temporary: 10, delta: -6);
      expect(result.current, 20);
      expect(result.temporary, 4);
    });

    test('溢出伤害扣除当前生命值', () {
      final result = apply(current: 20, temporary: 4, delta: -10);
      expect(result.current, 14);
      expect(result.temporary, 0);
    });

    test('临时生命值恰好吸收全部伤害', () {
      final result = apply(current: 20, temporary: 10, delta: -10);
      expect(result.current, 20);
      expect(result.temporary, 0);
    });

    test('当前生命值不会低于 0（转入死亡豁免）', () {
      final result = apply(current: 3, temporary: 0, delta: -30);
      expect(result.current, 0);
      expect(result.temporary, 0);
    });

    test('治疗不超过上限且不改变临时生命值', () {
      final result = apply(current: 25, temporary: 7, delta: 20);
      expect(result.current, 30);
      expect(result.temporary, 7);
    });

    test('负临时生命值按 0 处理', () {
      final result = apply(current: 10, temporary: -5, delta: -3);
      expect(result.current, 7);
      expect(result.temporary, 0);
    });
  });

  group('职业生命骰（2024 官方核心表）', () {
    // SRD 5.2 各职业 Core Traits：Hit Point Die + 豁免熟练（独立字面量 oracle）。
    const expected = {
      'barbarian': [12, ['str', 'con']],
      'bard': [8, ['dex', 'cha']],
      'cleric': [8, ['wis', 'cha']],
      'druid': [8, ['int', 'wis']],
      'fighter': [10, ['str', 'con']],
      'monk': [8, ['dex', 'wis']],
      'paladin': [10, ['wis', 'cha']],
      'ranger': [10, ['dex', 'str']],
      'rogue': [8, ['dex', 'int']],
      'sorcerer': [6, ['con', 'cha']],
      'warlock': [8, ['wis', 'cha']],
      'wizard': [6, ['int', 'wis']],
    };

    test('12 职业生命骰与豁免对照 SRD 5.2（直接断言档案）', () {
      expected.forEach((slug, value) {
        final rules = Dnd5eRules.profile.classRules(slug)!;
        expect(rules.hitDie, value[0], reason: slug);
        expect(
          rules.savingThrowAbilities,
          (value[1] as List).toSet(),
          reason: slug,
        );
      });
    });

    test('中文展示名经档案别名解析到同一职业（过渡 shim）', () {
      const names = {
        '野蛮人': 12,
        '战士': 10,
        '圣武士': 10,
        '游侠': 10,
        '吟游诗人': 8,
        '牧师': 8,
        '德鲁伊': 8,
        '武僧': 8,
        '游荡者': 8,
        '邪术师': 8,
        '术士': 6,
        '法师': 6,
      };
      names.forEach((name, die) {
        expect(Dnd5eRules.hitDieFor(classSummary: name), die, reason: '$name 生命骰');
      });
      expect(
        Dnd5eRules.hitDieFor(classSummary: 'Warlock'),
        8,
        reason: '邪术师是 d8，不是 d6',
      );
      expect(Dnd5eRules.hitDieFor(classSummary: 'Sorcerer'), 6);
      expect(Dnd5eRules.hitDieFor(classSummary: 'Wizard'), 6);
      expect(Dnd5eRules.hitDieFor(classSummary: 'Barbarian'), 12);
      // 未声明职业不猜：没有生命骰。
      expect(Dnd5eRules.hitDieFor(classSummary: '自定义职业'), isNull);
    });

    test('1 级生命值 = 生命骰满骰 + 体质调整值', () {
      const abilities = {'con': 14};
      expected.forEach((slug, value) {
        expect(
          Dnd5eRules.averageHitPoints(
            className: slug,
            level: 1,
            abilities: abilities,
          ),
          (value[0] as int) + 2,
          reason: slug,
        );
      });
    });

    test('邪术师 5 级生命值（d8 平均 + CON）', () {
      const abilities = {'con': 14};
      // 1 级 8+2=10；后续每级 5+2=7 → 10 + 4*7 = 38
      expect(
        Dnd5eRules.averageHitPoints(
          className: 'warlock',
          level: 5,
          abilities: abilities,
        ),
        38,
      );
    });

    test('生命骰直算接口与职业接口一致', () {
      expect(
        Dnd5eRules.averageHitPointsForHitDie(
          hitDie: 10,
          level: 3,
          constitution: 14,
        ),
        Dnd5eRules.averageHitPoints(
          className: 'fighter',
          level: 3,
          abilities: const {'con': 14},
        ),
      );
    });
  });

  group('准备法术上限（2024 逐级表，不再叠加属性调整值）', () {
    // SRD 5.2 各类 "Prepared Spells" 列（1..20 级）
    const clericLike = [
      4, 5, 6, 7, 9, 10, 11, 12, 14, 15, 16, 16, 17, 17, 18, 18, 19, 20, 21, 22,
    ];
    const sorcerer = [
      2, 4, 6, 7, 9, 10, 11, 12, 14, 15, 16, 16, 17, 17, 18, 18, 19, 20, 21, 22,
    ];
    const wizard = [
      4, 5, 6, 7, 9, 10, 11, 12, 14, 15, 16, 16, 17, 18, 19, 21, 22, 23, 24, 25,
    ];
    const halfCaster = [
      2, 3, 4, 5, 6, 6, 7, 7, 9, 9, 10, 10, 11, 11, 12, 12, 14, 14, 15, 15,
    ];
    const warlock = [
      2, 3, 4, 5, 6, 7, 8, 9, 10, 10, 11, 11, 12, 12, 13, 13, 14, 14, 15, 15,
    ];

    void expectTable(String className, List<int> table) {
      for (var level = 1; level <= 20; level++) {
        expect(
          Dnd5eRules.preparedSpellMaximums(
            classSummary: className,
            level: level,
          ),
          table[level - 1],
          reason: '$className $level 级准备法术上限',
        );
      }
    }

    test('牧师/德鲁伊/吟游诗人共用 4,5,6,7,9... 表', () {
      for (final className in ['牧师', '德鲁伊', '吟游诗人']) {
        expectTable(className, clericLike);
      }
    });

    test('术士 1 级 2 个、法师 1 级 4 个', () {
      expectTable('术士', sorcerer);
      expectTable('法师', wizard);
    });

    test('圣武士/游侠 1 级 2 个', () {
      for (final className in ['圣武士', '游侠']) {
        expectTable(className, halfCaster);
      }
    });

    test('邪术师 1 级 2 个、20 级 15 个', () {
      expectTable('邪术师', warlock);
    });

    test('英文职业名同样解析', () {
      expect(
        Dnd5eRules.preparedSpellMaximums(classSummary: 'Wizard', level: 5),
        9,
      );
      expect(
        Dnd5eRules.preparedSpellMaximums(classSummary: 'Cleric', level: 1),
        4,
      );
      expect(
        Dnd5eRules.preparedSpellMaximums(classSummary: 'Warlock', level: 1),
        2,
      );
    });

    test('非施法者没有准备法术上限', () {
      for (final className in ['战士', '野蛮人', '武僧', '游荡者']) {
        expect(
          Dnd5eRules.preparedSpellMaximums(classSummary: className, level: 10),
          isNull,
          reason: className,
        );
      }
    });

    test('上限与属性无关（2024 取消“调整值 + 等级”）', () {
      // 旧公式：智力 20（+5）+ 5 级 = 10；2024 官方表为 9
      expect(
        Dnd5eRules.preparedSpellMaximums(classSummary: '法师', level: 5),
        9,
      );
      expect(
        Dnd5eRules.preparedSpellMaximums(classSummary: '法师', level: 20),
        25,
      );
    });
  });

  group('1/3 施法者（第三个原型由条目声明，不再按职业名推断）', () {
    // 新契约：子职业的 1/3 施法由**条目**声明 `archetype: third-caster`
    // （档案里没有"奥法骑士/诡术师"职业，刻意不按名字相近推断）。
    const thirdCasterEntry = <String, Object?>{
      'classRules': <String, Object?>{
        'hitDie': 10,
        'savingThrowAbilities': <String>['str', 'con'],
        'spellcasting': <String, Object?>{
          'mode': 'prepared',
          'ability': 'int',
          'archetype': 'third-caster',
        },
      },
    };

    test('3 级起获得法术位，等效等级 = ceil(level/3)', () {
      final rules = Dnd5eRules.resolveClassRules(
        entryId: 'test-pack:class/eldritch-knight',
        classSummary: '奥法骑士',
        structured: thirdCasterEntry,
      );
      expect(
        rules.spellSlots(2),
        isEmpty,
        reason: '3 级前没有法术位',
      );
      const expected = {
        3: {'1': 2},
        4: {'1': 3},
        6: {'1': 3},
        7: {'1': 4, '2': 2},
        10: {'1': 4, '2': 3},
        13: {'1': 4, '2': 3, '3': 2},
        16: {'1': 4, '2': 3, '3': 3},
        19: {'1': 4, '2': 3, '3': 3, '4': 1},
        20: {'1': 4, '2': 3, '3': 3, '4': 1},
      };
      expected.forEach((level, table) {
        expect(rules.spellSlots(level), table, reason: '1/3 施法者 $level 级');
      });
    });

    test('施法属性来自条目声明而不是职业名', () {
      expect(
        Dnd5eRules.resolveClassRules(
          entryId: 'test-pack:class/eldritch-knight',
          classSummary: '奥法骑士',
          structured: thirdCasterEntry,
        ).spellcastingAbility,
        'int',
      );
    });

    test('散文职业名只解析到母职业：不推断施法子职业，无法术位', () {
      // 过渡 shim 的展示名解析：`战士` + `（` 前缀 → fighter（§3.6 第 2 步）。
      expect(Dnd5eRules.hitDieFor(classSummary: '战士（奥法骑士）'), 10);
      expect(
        Dnd5eRules.classSavingThrows('战士（奥法骑士）'),
        {'str', 'con'},
      );
      // 但 fighter 的档案声明是 mode: none，因此没有法术位、也没有施法属性。
      expect(
        Dnd5eRules.spellSlotMaximums(classSummary: '战士（奥法骑士）', level: 10),
        isEmpty,
      );
      expect(Dnd5eRules.spellcastingAbility('战士（奥法骑士）'), isNull);
      expect(Dnd5eRules.spellcastingAbility('Eldritch Knight'), isNull);
      expect(Dnd5eRules.spellcastingAbility('游荡者（诡术师）'), isNull);
      expect(Dnd5eRules.spellcastingAbility('Arcane Trickster'), isNull);
    });

    test('纯战士 / 纯游荡者仍然没有法术位', () {
      for (final className in ['战士', '游荡者', 'Fighter', 'Rogue']) {
        expect(
          Dnd5eRules.spellSlotMaximums(classSummary: className, level: 10),
          isEmpty,
          reason: className,
        );
      }
    });
  });

  group('展示名 slug 解析（§3.6 第 2 步：精确相等或 <别名><分隔符> 前缀）', () {
    test('别名 + 分隔符前缀命中母职业', () {
      // `战士（奥法骑士）` → fighter；前缀 `战士` 后紧跟 `（`。
      expect(Dnd5eRules.hitDieFor(classSummary: '战士（奥法骑士）'), 10);
      expect(Dnd5eRules.classSavingThrows('战士（奥法骑士）'), {'str', 'con'});
      // `法师 / Wizard` → wizard；前缀 `法师` 后紧跟空格。
      expect(Dnd5eRules.hitDieFor(classSummary: '法师 / Wizard'), 6);
      expect(Dnd5eRules.classSavingThrows('法师 / Wizard'), {'int', 'wis'});
    });

    test('禁止裸子串：星界游侠不命中游侠（ranger）', () {
      expect(Dnd5eRules.hitDieFor(classSummary: '星界游侠'), isNull);
      expect(Dnd5eRules.classSavingThrows('星界游侠'), isEmpty);
    });

    test('别名后必须紧跟白名单分隔符：无分隔符不命中，三种分隔符命中', () {
      // `战士奥法骑士` 的 `战士` 后没有分隔符，不是前缀命中 → 不猜成 fighter。
      expect(Dnd5eRules.hitDieFor(classSummary: '战士奥法骑士'), isNull);
      // 白名单分隔符 `-` / ASCII `(` / 空格各自命中母职业 fighter。
      expect(Dnd5eRules.hitDieFor(classSummary: '战士-奥法骑士'), 10);
      expect(Dnd5eRules.hitDieFor(classSummary: '战士(奥法骑士)'), 10);
      expect(Dnd5eRules.hitDieFor(classSummary: '战士 奥法骑士'), 10);
    });

    test('精确相等命中（别名与 slug 都可）', () {
      expect(Dnd5eRules.hitDieFor(classSummary: '战士'), 10);
      expect(Dnd5eRules.hitDieFor(classSummary: 'Fighter'), 10);
    });
  });

  group('职业豁免熟练（2024 官方核心表）', () {
    const savingThrows = {
      '野蛮人': {'str', 'con'},
      '吟游诗人': {'dex', 'cha'},
      '牧师': {'wis', 'cha'},
      '德鲁伊': {'int', 'wis'},
      '战士': {'str', 'con'},
      '武僧': {'dex', 'wis'},
      '圣武士': {'wis', 'cha'},
      '游侠': {'dex', 'str'},
      '游荡者': {'dex', 'int'},
      '术士': {'con', 'cha'},
      '邪术师': {'wis', 'cha'},
      '法师': {'int', 'wis'},
    };

    test('12 个职业的豁免熟练', () {
      savingThrows.forEach((name, expected) {
        expect(
          Dnd5eRules.classSavingThrows(name),
          expected,
          reason: '$name 豁免熟练',
        );
      });
    });

    test('英文职业名同样解析', () {
      expect(Dnd5eRules.classSavingThrows('Rogue'), {'dex', 'int'});
      expect(Dnd5eRules.classSavingThrows('Warlock'), {'wis', 'cha'});
      expect(Dnd5eRules.classSavingThrows('Sorcerer'), {'con', 'cha'});
    });

    test('未知职业返回空集合（不猜测）', () {
      expect(Dnd5eRules.classSavingThrows('自定义职业'), isEmpty);
    });
  });

  group('职业资源恢复（2024 休息语义）', () {
    Dnd5eClassResource resource(String id, String recovery, {int maximum = 3}) =>
        Dnd5eClassResource(
          id: id,
          name: id,
          maximum: maximum,
          recovery: recovery,
        );

    test('短休：shortRest 清空、shortRestOne 只回 1 次、longRest 不变', () {
      final resources = [
        resource('a', 'shortRest'),
        resource('b', 'shortRestOne'),
        resource('c', 'longRest'),
      ];
      expect(
        Dnd5eRules.classResourcesAfterRest(
          resources: resources,
          used: const {'a': 2, 'b': 3, 'c': 2},
          longRest: false,
        ),
        {'a': 0, 'b': 2, 'c': 2},
      );
    });

    test('长休：除 none 外全部清空', () {
      final resources = [
        resource('a', 'shortRest'),
        resource('b', 'shortRestOne'),
        resource('c', 'longRest'),
        resource('d', 'none', maximum: 2),
      ];
      expect(
        Dnd5eRules.classResourcesAfterRest(
          resources: resources,
          used: const {'a': 2, 'b': 1, 'c': 3, 'd': 1},
          longRest: true,
        ),
        {'a': 0, 'b': 0, 'c': 0, 'd': 1},
      );
    });

    test('已用次数会被夹到 0..上限', () {
      final resources = [resource('a', 'longRest', maximum: 2)];
      expect(
        Dnd5eRules.classResourcesAfterRest(
          resources: resources,
          used: const {'a': 9},
          longRest: false,
        ),
        {'a': 2},
      );
    });

    test('野蛮人狂暴 / 战士第二气息短休恢复 1 次；动作如潮短休全部恢复', () {
      expect(
        Dnd5eRules.classResources(classSummary: '野蛮人', level: 3).single.recovery,
        'shortRestOne',
      );
      final fighter = Dnd5eRules.classResources(classSummary: '战士', level: 2);
      expect(
        {
          for (final item in fighter) item.id: item.recovery,
        },
        {'second_wind': 'shortRestOne', 'action_surge': 'shortRest'},
        reason: '2024：第二气息短休只回 1 次，动作如潮短休全恢复',
      );
    });
  });
}
