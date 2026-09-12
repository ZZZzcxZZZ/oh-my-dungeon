import 'package:dnd_table_client/src/features/characters/domain/dnd5e_rules.dart';
import 'package:dnd_table_client/src/features/rules/domain/character_rule_definition.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_choice_quota.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('没有 countsToward：只受 maximum 约束', () {
    expect(
      RuleChoiceQuota.effectiveMaximum(
        countsToward: null,
        maximum: 6,
        poolLimits: const {'prepared': 4},
        usedByOthers: 3,
      ),
      6,
    );
  });

  test('prepared / known 共用同一数值列；spellbook 无独立列 → 无额度（决策 D3）', () {
    expect(
      RuleChoiceQuota.effectiveMaximum(
        countsToward: 'prepared',
        maximum: 6,
        poolLimits: const {'prepared': 4, 'known': 4},
        usedByOthers: 1,
      ),
      3,
    );
    expect(
      RuleChoiceQuota.effectiveMaximum(
        countsToward: 'known',
        maximum: 6,
        poolLimits: const {'prepared': 4, 'known': 4},
        usedByOthers: 0,
      ),
      4,
    );
    expect(
      RuleChoiceQuota.effectiveMaximum(
        countsToward: 'spellbook',
        maximum: 6,
        poolLimits: const {'prepared': 4, 'known': 4},
        usedByOthers: 2,
      ),
      6,
      reason: '法术书容量未建模，不能被 prepared 列反向限制',
    );
  });

  test('池被占满时有效上限为 0（不是负数）', () {
    expect(
      RuleChoiceQuota.effectiveMaximum(
        countsToward: 'prepared',
        maximum: 3,
        poolLimits: const {'prepared': 2},
        usedByOthers: 5,
      ),
      0,
    );
  });

  test('未知池名（程序化构造绕过解析层）按"不占池"处理，不抛异常', () {
    expect(
      RuleChoiceQuota.effectiveMaximum(
        countsToward: 'rituals',
        maximum: 2,
        poolLimits: const {'prepared': 1},
        usedByOthers: 0,
      ),
      2,
    );
  });

  // 内置档案由 `test/flutter_test_config.dart` 在整个 `flutter test` 装配（§4.4），
  // 这里不再重复 `configure`（会触发 "已配置" 的守卫）。
  test('limitsFor：prepared 与 known 取职业 prepared 表，spellbook 不出现', () {
    final wizard = Dnd5eRules.resolveClassRules(
      entryId: 'x:class/wizard',
      classSummary: '法师',
    );

    final limits = RuleChoiceQuota.limitsFor(rules: wizard, level: 1);

    // 法师 1 级 prepared = 4（`assets/rules/dnd5e-2024.rules.json`，
    // 见 `builtin_rule_profile_test.dart` 的同表断言）。
    expect(limits, {'prepared': 4, 'known': 4});
    expect(limits.containsKey('spellbook'), isFalse);
  });

  test('limitsFor：未声明准备上限的职业（非施法者）返回空表', () {
    final fighter = Dnd5eRules.resolveClassRules(
      entryId: 'x:class/fighter',
      classSummary: '战士',
    );

    expect(RuleChoiceQuota.limitsFor(rules: fighter, level: 1), isEmpty);
  });

  test('limitsFor：施法者高等级沿用档案的 prepared 表', () {
    final wizard = Dnd5eRules.resolveClassRules(
      entryId: 'x:class/wizard',
      classSummary: '法师',
    );

    final levelFive = RuleChoiceQuota.limitsFor(rules: wizard, level: 5);
    expect(levelFive['prepared'], greaterThan(4));
    expect(levelFive['known'], levelFive['prepared']);
  });

  test('池名与额度来源一致：kCountsTowardPools = limitsFor 键空间 ∪ 显式无限池', () {
    final wizard = Dnd5eRules.resolveClassRules(
      entryId: 'x:class/wizard',
      classSummary: '法师',
    );
    final declared = <String>{
      ...RuleChoiceQuota.limitsFor(rules: wizard, level: 1).keys,
      ...kUnlimitedCountsTowardPools,
    };

    // 两份清单（合法池名 / 额度来源）将来必须一起改：新增池名要么让 `limitsFor`
    // 给出数值，要么在 `kUnlimitedCountsTowardPools` 里显式标注"不限"；少了任一步
    // 就会静默落到"漏加 = 不限"的默认分支。这里做**双向**相等断言：
    // 既不允许池名没有来源，也不允许来源里有已废弃的池名。
    expect(
      declared,
      kCountsTowardPools,
      reason: '每个合法池名都必须有显式额度来源（数值或"不限"）',
    );
  });
}
