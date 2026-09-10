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

    // 半施法者（圣武士/游侠）：等级 2 起，等效等级 = ceil(level/2)
    const halfCaster = {
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
}
