// test/rules/class_merge_mode_test.dart
//
// S3 任务 5：`classRules.mode: "patch" | "replace"`（规格 §3.8 推广、决策 D1 / D4）。
//
// - 位置固定在 `structured.classRules.mode`，缺省 `patch`（不写 = 行为不变）；
// - `patch`：只覆盖自己声明过的列 / 等级，未声明的继续回退更低 tier；
// - `replace`：独占——更低 tier（含内置档案）不提供任何列，未声明即未声明；
// - 非法值在解析期报 `invalidMergeMode`（path 精确），并提示 `spellcasting.mode`
//   才是法术选择模型的位置。
import 'package:dnd_table_client/src/features/characters/domain/declared_levels.dart';
import 'package:dnd_table_client/src/features/rules/domain/class_rule_set.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_diagnostic.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_field_path.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_profile.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_profile_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

import 'rule_profile_test_support.dart';

const _path = r'$.structured.classRules';
const _entryId = 'x:class/wizard';

void main() {
  late RuleProfile profile;
  setUp(
    () => profile = RuleProfileResolver.resolveBuiltin(
      overrideArchive(),
    ).profile!,
  );

  ClassRuleSet entry(
    Map<String, Object?> classRules, {
    List<RuleDiagnostic>? out,
  }) => ClassRuleSet.parse(
    classRules,
    path: _path,
    diagnostics: out ?? <RuleDiagnostic>[],
  );

  test('patch（缺省）：条目未声明的列仍回退档案', () {
    final rules = entry({'hitDie': 6});
    expect(rules.mode, ClassMergeMode.patch, reason: '不写 mode 即缺省 patch');

    final merged = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'wizard',
      entryRules: rules,
      entryId: _entryId,
    );
    expect(merged.hitDie, 6);
    expect(merged.savingThrowAbilities, {'int', 'wis'}, reason: '档案补齐');
    expect(merged.preparedLimit(1), 4, reason: '档案补齐 spellcasting 列');
    expect(merged.spellSlots(5), {'1': 4, '2': 3, '3': 2});
    expect(
      merged.sourceOf(RuleFieldPath.savingThrowAbilities)!.originId,
      kBuiltinOriginId,
    );
  });

  test('显式 patch 与缺省逐项等价；同一条目可混用顶层 mode 与 spellcasting.mode', () {
    final defaultMode = entry({'hitDie': 6});
    final explicit = entry({'mode': 'patch', 'hitDie': 6});
    expect(explicit.mode, ClassMergeMode.patch);

    final fromDefault = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'wizard',
      entryRules: defaultMode,
      entryId: _entryId,
    );
    final fromExplicit = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'wizard',
      entryRules: explicit,
      entryId: _entryId,
    );
    expect(fromExplicit.hitDie, fromDefault.hitDie);
    expect(fromExplicit.savingThrowAbilities, fromDefault.savingThrowAbilities);
    expect(fromExplicit.spellSlots(5), fromDefault.spellSlots(5));
    expect(fromExplicit.preparedLimit(1), fromDefault.preparedLimit(1));
    expect(fromExplicit.fieldSources.keys, fromDefault.fieldSources.keys);

    // 顶层 `mode`（合并语义）与 `spellcasting.mode`（法术选择模型）是两个不同的键，
    // 同一条目里共存不冲突，各查各的。
    final mixed = entry({
      'mode': 'patch',
      'spellcasting': {
        'mode': 'prepared',
        'ability': 'int',
        'archetype': 'full-caster',
      },
    });
    expect(mixed.mode, ClassMergeMode.patch);
    expect(mixed.spellcasting!.mode, 'prepared');
    final merged = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'wizard',
      entryRules: mixed,
      entryId: _entryId,
    );
    expect(merged.spellcastingMode, 'prepared');
    expect(merged.spellcastingAbility, 'int');
  });

  test('replace：条目未声明的列一律"未声明"，不回退档案', () {
    final merged = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'wizard',
      entryRules: entry({'mode': 'replace', 'hitDie': 6}),
      entryId: _entryId,
    );
    expect(merged.hitDie, 6);
    expect(merged.savingThrowAbilities, isEmpty, reason: '未声明 → 空，不借用档案');
    expect(merged.spellcasting, isNull, reason: '未声明 → 无 spellcasting');
    expect(merged.resources, isEmpty);
    expect(merged.spellSlots(5), isEmpty);
    expect(merged.sourceOf(RuleFieldPath.hitDie)!.originId, _entryId);
    expect(merged.sourceOf(RuleFieldPath.savingThrowAbilities), isNull);
    expect(
      merged.fieldSources.keys.where((k) => k.startsWith('spellcasting.')),
      isEmpty,
    );
  });

  test('replace 仍回退 archetype（原型是跨职业共享模板，不是 classRules 的列）', () {
    final merged = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'wizard',
      entryRules: entry({
        'mode': 'replace',
        'spellcasting': {
          'mode': 'prepared',
          'ability': 'int',
          'archetype': 'full-caster',
        },
      }),
      entryId: _entryId,
    );
    // 条目自己声明的 archetype 指向档案原型：原型是"跨职业共享模板"，
    // 不是 classRules 的列，replace 不屏蔽它（§3.1）。
    expect(merged.archetype!.name, 'full-caster');
    expect(merged.spellSlots(2), isNotEmpty);
    // 但档案**自身**的列（savingThrowAbilities）在 replace 下不参与。
    expect(merged.savingThrowAbilities, isEmpty);
  });

  test('replace 声明后档案资源不再补：resources 为空且无来源', () {
    final merged = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'barbarian',
      entryRules: entry({'mode': 'replace', 'hitDie': 12}),
      entryId: 'x:class/barbarian',
    );
    expect(merged.resources, isEmpty, reason: '档案的 rage 不得参与');
    expect(
      merged.fieldSources.keys.where((k) => k.startsWith('resources.')),
      isEmpty,
    );
    expect(merged.resourcesAt(1, const {}), isEmpty);
  });

  test('replace：声明范围不含档案（不再显示"声明 1–5 级"而实际无内容）', () {
    final patched = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'wizard',
      entryRules: entry({'hitDie': 6}),
      entryId: _entryId,
    );
    // patch：档案的表仍贡献声明范围（§3.12 规则 3 的"合并后实际生效的范围"）。
    expect(patched.declaredMinLevel, 1);
    expect(patched.declaredMaxLevel, 5, reason: '档案 wizard 的表声明到 5 级');

    final replaced = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'wizard',
      entryRules: entry({'mode': 'replace', 'hitDie': 6}),
      entryId: _entryId,
    );
    expect(replaced.declaredMinLevel, isNull);
    expect(replaced.declaredMaxLevel, isNull);
    expect(
      DeclaredLevels.fromResolvedClassRules(replaced).rangeLabel,
      '该职业未声明任何等级内容',
    );
  });

  test('未知 mode 值 → invalidMergeMode，path 精确', () {
    final diagnostics = <RuleDiagnostic>[];
    entry({'mode': 'merge'}, out: diagnostics);
    final error = diagnostics.singleWhere((d) => d.code == 'invalidMergeMode');
    expect(error.severity, RuleSeverity.error);
    expect(error.path, '$_path.mode');
    expect(error.message, contains('patch'));
    expect(error.message, contains('replace'));
  });

  test('把 spellcasting.mode 写到 classRules.mode 上不静默：报错并提示位置', () {
    final diagnostics = <RuleDiagnostic>[];
    final rules = entry({'mode': 'prepared'}, out: diagnostics);
    final error = diagnostics.singleWhere((d) => d.code == 'invalidMergeMode');
    expect(error.message, contains('spellcasting.mode'));
    // 报错之后形状仍可用：按缺省 patch 继续，不把整块解析废掉。
    expect(rules.mode, ClassMergeMode.patch);
  });
}
