// test/rules/spellcasting_column_merge_test.dart
//
// S3 任务 2：`spellcasting` 列级合并（契约 §3.3/§3.6/§3.7 + 决策 D5）。
//
// 核心验收：条目只声明 `spellcasting.prepared` 的稀疏表时，`slots` / `mode` /
// `ability` / `cantrips` / `maximumSpellLevel` 仍按列回退内置档案；表列在 `patch`
// 语义下**按每个等级**独立回退（D5），所以条目只写 20 级时 1..19 级仍是档案值。
import 'package:dnd_table_client/src/features/rules/domain/class_rule_set.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_diagnostic.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_field_path.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_profile.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_profile_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

import 'rule_profile_test_support.dart';

const _path = r'$.structured.classRules';
const _entryId = 'errata:class/wizard';

ClassRuleSet entry(Map<String, Object?> classRules) {
  final diagnostics = <RuleDiagnostic>[];
  final rules = ClassRuleSet.parse(
    classRules,
    path: _path,
    diagnostics: diagnostics,
  );
  expect(
    diagnostics.where((d) => d.severity == RuleSeverity.error),
    isEmpty,
    reason: '$diagnostics',
  );
  return rules;
}

void main() {
  late RuleProfile profile;
  setUp(() {
    profile = RuleProfileResolver.resolveBuiltin(overrideArchive()).profile!;
  });

  test('核心验收：条目只覆盖 prepared，档案的 slots / mode / ability 仍然生效', () {
    final merged = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'wizard',
      entryRules: entry({
        'spellcasting': {
          'prepared': {'5': 9},
        },
      }),
      entryId: _entryId,
    );

    expect(merged.preparedLimit(5), 9, reason: '条目覆盖的等级生效');
    expect(
      merged.preparedLimit(1),
      4,
      reason: 'D5 逐级回退：条目没声明 1 级，用档案的 4',
    );
    expect(
      merged.preparedLimit(4),
      7,
      reason: 'D5 逐级回退：1..4 级都来自档案',
    );
    expect(
      merged.spellSlots(5),
      {'1': 4, '2': 3, '3': 2},
      reason: 'slots 列条目没声明，整列来自档案',
    );
    expect(merged.spellcastingMode, 'prepared', reason: 'mode 仍来自档案');
    expect(merged.spellcastingAbility, 'int', reason: 'ability 仍来自档案');
    expect(merged.cantripLimit(1), 3, reason: 'cantrips 仍来自档案');
    expect(merged.maxSpellLevel(3), 2, reason: 'maximumSpellLevel 仍来自档案');

    expect(
      merged.sourceOf(RuleFieldPath.spellcasting('prepared'))!.originId,
      _entryId,
    );
    expect(
      merged.sourceOf(RuleFieldPath.spellcasting('slots'))!.originId,
      kBuiltinOriginId,
    );
    expect(
      merged.sourceOf(RuleFieldPath.spellcasting('mode'))!.originId,
      kBuiltinOriginId,
    );
    expect(
      merged.sourceOf(RuleFieldPath.hitDie)!.originId,
      kBuiltinOriginId,
    );
  });

  test('D5 逐级回退：条目只声明 20 级时，1..19 级仍是档案值', () {
    final merged = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'wizard',
      entryRules: entry({
        'spellcasting': {
          'prepared': {'20': 24},
        },
      }),
      entryId: _entryId,
    );

    expect(merged.preparedLimit(1), 4, reason: '档案 1 级');
    expect(merged.preparedLimit(5), 9, reason: '档案 5 级（最后声明等级）');
    expect(merged.preparedLimit(19), 9, reason: '档案：高于最后声明等级沿用');
    expect(merged.preparedLimit(20), 24, reason: '条目 20 级');
    // 列级来源仍是条目（该列的最高 tier 声明者），逐级来源细节不在本批次。
    expect(
      merged.sourceOf(RuleFieldPath.spellcasting('prepared'))!.originId,
      _entryId,
    );
    // 没有被碰过的列不受影响。
    expect(merged.spellSlots(5), {'1': 4, '2': 3, '3': 2});
    expect(merged.cantripLimit(1), 3);
  });

  test('D5 逐级回退：条目只声明 slots 的 3 级，其余等级仍按档案/原型', () {
    final merged = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'wizard',
      entryRules: entry({
        'spellcasting': {
          'slots': {
            '3': {'1': 3},
          },
        },
      }),
      entryId: _entryId,
    );

    expect(merged.spellSlots(3), {'1': 3}, reason: '条目声明的等级');
    expect(
      merged.spellSlots(1),
      {'1': 2},
      reason: '条目与档案都没声明 1 级 → 回退 archetype（full-caster 1 级）',
    );
    expect(
      merged.spellSlots(2),
      {'1': 3},
      reason: '条目/档案都没声明 2 级 → archetype',
    );
    expect(
      merged.spellSlots(5),
      {'1': 3},
      reason: '条目表高于最后声明等级沿用 3 级的值，压过档案 5 级',
    );
    expect(
      merged.sourceOf(RuleFieldPath.spellcasting('slots'))!.originId,
      _entryId,
    );
  });

  test('条目声明 mode: none 时短路整个施法（slots 为空、能力为 null）', () {
    final merged = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'wizard',
      entryRules: entry({
        'spellcasting': {'mode': 'none'},
      }),
      entryId: _entryId,
    );
    expect(merged.spellcastingMode, 'none');
    expect(merged.spellcastingAbility, isNull);
    expect(merged.spellSlots(5), isEmpty);
    expect(merged.preparedLimit(5), isNull);
    expect(
      merged.sourceOf(RuleFieldPath.spellcasting('mode'))!.originId,
      _entryId,
    );
    expect(
      merged.sourceOf(RuleFieldPath.spellcasting('slots'))!.originId,
      kBuiltinOriginId,
      reason: 'slots 列仍然来自档案——只是被 mode: none 短路',
    );
  });

  test('条目写全 8 列时全部来源都是条目', () {
    final merged = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'astral-knight',
      entryRules: entry({
        'spellcasting': {
          'mode': 'known',
          'ability': 'cha',
          'listTags': ['spell-list:astral'],
          'slots': {'5': {'1': 4, '2': 2}},
          'prepared': {'5': 6},
          'cantrips': {'5': 3},
          'maximumSpellLevel': {'5': 3},
        },
      }),
      entryId: _entryId,
    );
    for (final column in RuleFieldPath.spellcastingColumns) {
      final source = merged.sourceOf(RuleFieldPath.spellcasting(column));
      if (column == 'archetype' || column == 'slotLevel') {
        expect(source, isNull, reason: '$column 未声明 → 无来源');
        continue;
      }
      expect(source!.originId, _entryId, reason: column);
      expect(source.tier, kEntryTier, reason: column);
    }
    expect(merged.archetype, isNull, reason: '未声明 archetype，档案也没有 astral-knight');
    expect(merged.preparedLimit(5), 6);
    expect(merged.cantripLimit(5), 3);
    expect(merged.maxSpellLevel(5), 3);
    expect(merged.spellSlots(5), {'1': 4, '2': 2});
  });

  test('显式 null 的 archetype 清空档案的列', () {
    final merged = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'wizard',
      entryRules: entry({
        'spellcasting': {'archetype': null},
      }),
      entryId: _entryId,
    );
    expect(merged.archetype, isNull);
    expect(
      merged.sourceOf(RuleFieldPath.spellcasting('archetype'))!.originId,
      _entryId,
      reason: '显式 null 是"清空该列"，来源仍是条目',
    );
    // prepared / cantrips 是职业自己的列，与 archetype 无关，仍来自档案。
    expect(merged.preparedLimit(1), 4);
  });

  test('双方都没声明 spellcasting 时不产生 spellcasting 来源', () {
    final merged = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'astral-knight',
      entryRules: entry({'hitDie': 10}),
      entryId: _entryId,
    );
    expect(merged.spellcasting, isNull);
    expect(
      merged.fieldSources.keys.where((k) => k.startsWith('spellcasting.')),
      isEmpty,
    );
  });

  test('显式 0 / 显式空表算已声明，不被当成"未声明"', () {
    final merged = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'wizard',
      entryRules: entry({
        'spellcasting': {
          'prepared': {'1': 0},
          'cantrips': {'1': 0},
          'slots': {
            '1': <String, Object?>{},
          },
        },
      }),
      entryId: _entryId,
    );
    expect(merged.preparedLimit(1), 0, reason: '显式 0 是"存在但为 0"');
    // 高于最后声明等级沿用 0，不落回档案。
    expect(merged.preparedLimit(5), 0);
    expect(merged.cantripLimit(1), 0);
    expect(merged.spellSlots(1), isEmpty, reason: '显式空表');
    expect(merged.spellSlots(5), isEmpty, reason: '沿用显式空表');
    expect(
      merged.sourceOf(RuleFieldPath.spellcasting('prepared'))!.originId,
      _entryId,
    );
    expect(
      merged.sourceOf(RuleFieldPath.spellcasting('slots'))!.originId,
      _entryId,
    );
  });
}
