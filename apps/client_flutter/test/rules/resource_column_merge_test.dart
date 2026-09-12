// test/rules/resource_column_merge_test.dart
//
// S3 任务 3：`resources` 按 `id` 合并、同 id 再按列（契约 §3.4/§3.6 + 决策 D5），
// 以及"补丁资源"（条目可省略 name / maximum，由档案同 id 补齐）。
import 'package:dnd_table_client/src/features/rules/domain/class_rule_set.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_diagnostic.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_field_path.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_profile.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_profile_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

import 'rule_profile_test_support.dart';

const _path = r'$.structured.classRules';
const _entryId = 'errata:class/barbarian';

void main() {
  late RuleProfile profile;
  setUp(() {
    // 与任务 2 共用同一份合成档案（含 barbarian 的 rage）。
    profile = RuleProfileResolver.resolveBuiltin(overrideArchive()).profile!;
  });

  ClassRuleSet entry(List<Object?> resources) {
    final diagnostics = <RuleDiagnostic>[];
    final rules = ClassRuleSet.parse({'resources': resources}, path: _path, diagnostics: diagnostics);
    expect(diagnostics.where((d) => d.severity == RuleSeverity.error), isEmpty, reason: '$diagnostics');
    return rules;
  }

  test('核心验收：同 id 只覆盖 recovery，name / maximum / startsAtLevel 仍来自档案', () {
    final merged = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'barbarian',
      entryRules: entry([
        {'id': 'rage', 'recovery': 'longRest'},
      ]),
      entryId: _entryId,
    );

    expect(merged.resources, hasLength(1));
    final rage = merged.resources.single;
    expect(rage.recoveryAt(1), 'longRest', reason: '条目覆盖的列');
    expect(rage.name, '狂暴', reason: 'name 来自档案');
    expect(
      rage.maximum!.resolve(level: 3, abilities: const {}),
      3,
      reason: 'maximum 来自档案',
    );
    expect(rage.startsAtLevel, 1, reason: 'startsAtLevel 来自档案');

    expect(
      merged.sourceOf(RuleFieldPath.resource('rage', 'recovery'))!.originId,
      _entryId,
    );
    expect(
      merged.sourceOf(RuleFieldPath.resource('rage', 'maximum'))!.originId,
      kBuiltinOriginId,
    );
    expect(
      merged.sourceOf(RuleFieldPath.resource('rage', 'name'))!.originId,
      kBuiltinOriginId,
    );
    expect(
      merged.sourceOf(RuleFieldPath.resource('rage', 'startsAtLevel'))!.originId,
      kBuiltinOriginId,
    );
  });

  test('同 id 覆盖 maximum，档案的 recovery / startsAtLevel 保留', () {
    final merged = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'barbarian',
      entryRules: entry([
        {
          'id': 'rage',
          'maximum': 5,
        },
      ]),
      entryId: _entryId,
    );
    final rage = merged.resources.single;
    expect(rage.maximum!.resolve(level: 12, abilities: const {}), 5);
    expect(rage.recoveryAt(1), 'shortRestOne', reason: 'recovery 来自档案');
    expect(rage.name, '狂暴');
    expect(
      merged.sourceOf(RuleFieldPath.resource('rage', 'maximum'))!.originId,
      _entryId,
    );
  });

  test('D5 逐级回退：同 id 的 maximum.table 只覆盖 20 级，其余等级仍来自档案', () {
    final merged = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'barbarian',
      entryRules: entry([
        {
          'id': 'rage',
          'maximum': {
            'table': {'20': 9},
          },
        },
      ]),
      entryId: _entryId,
    );
    final rage = merged.resources.single;
    expect(rage.maximum!.resolve(level: 1, abilities: const {}), 2, reason: '档案 1 级');
    expect(rage.maximum!.resolve(level: 3, abilities: const {}), 3, reason: '档案 3 级');
    expect(rage.maximum!.resolve(level: 20, abilities: const {}), 9, reason: '条目 20 级');
    expect(rage.recoveryAt(1), 'shortRestOne');
    expect(rage.name, '狂暴');
  });

  test('条目新增档案没有的资源必须自带 name 与 maximum', () {
    final merged = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'barbarian',
      entryRules: entry([
        {'id': 'storm-aura', 'name': '风暴灵光', 'maximum': {'formula': 'level'}},
      ]),
      entryId: _entryId,
    );
    expect(merged.resources, hasLength(2));
    final aura = merged.resources.singleWhere((r) => r.id == 'storm-aura');
    expect(aura.name, '风暴灵光');
    expect(
      merged.sourceOf(RuleFieldPath.resource('storm-aura', 'maximum'))!.originId,
      _entryId,
      reason: '档案里没有这个 id，两列都只能来自条目',
    );
    expect(
      merged.sourceOf(RuleFieldPath.resource('storm-aura', 'name'))!.originId,
      _entryId,
    );
    // 档案同 id 的 rage 不会被"整数组替换"丢掉。
    expect(merged.resources.map((r) => r.id), ['storm-aura', 'rage']);
  });

  test('补丁资源缺 name / maximum 且档案有同 id → 由档案补齐', () {
    final merged = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'barbarian',
      entryRules: entry([
        {'id': 'rage', 'maximum': 6},
      ]),
      entryId: _entryId,
    );
    final rage = merged.resources.single;
    expect(rage.name, '狂暴', reason: 'name 由档案补齐');
    expect(rage.maximum!.resolve(level: 1, abilities: const {}), 6);
    expect(rage.recoveryAt(1), 'shortRestOne');
  });

  test('补丁资源缺 name / maximum 且档案无同 id → 合并后 maximum 为空，运行期跳过', () {
    final merged = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'barbarian',
      entryRules: entry([
        {'id': 'storm-aura', 'recovery': 'longRest'},
      ]),
      entryId: _entryId,
    );
    // 运行期不产出"上限 0"的假资源（导入期已由 incompleteResourcePatch 拦住，
    // 这里的直连解析只是兜底路径）。
    expect(
      merged.resourcesAt(1, const {}).map((r) => r.id),
      isNot(contains('storm-aura')),
    );
  });

  test('resourcesAt 跳过合并后仍无 maximum 的资源，不产出假资源', () {
    final merged = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'barbarian',
      entryRules: entry([
        {'id': 'rage'},
      ]),
      entryId: _entryId,
    );
    // 档案补齐了 maximum，因此正常产出。
    expect(
      merged.resourcesAt(1, const {}).single.maximum,
      2,
    );
  });

  test('显式 0 的 maximum 算已声明，不被档案的表覆盖', () {
    final merged = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'barbarian',
      entryRules: entry([
        {'id': 'rage', 'maximum': 0},
      ]),
      entryId: _entryId,
    );
    final rage = merged.resources.single;
    expect(rage.maximum!.resolve(level: 1, abilities: const {}), 0);
    // 运行期：显式 0 = "存在但上限为 0"，与"未声明"不同。
    expect(merged.resourcesAt(1, const {}).single.maximum, 0);
  });

  test('补丁资源只覆盖 startsAtLevel，maximum 由档案补齐', () {
    final merged = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'barbarian',
      entryRules: entry([
        {'id': 'rage', 'startsAtLevel': 3},
      ]),
      entryId: _entryId,
    );
    final rage = merged.resources.single;
    expect(rage.startsAtLevel, 3);
    expect(rage.maximum!.resolve(level: 3, abilities: const {}), 3);
    expect(
      merged.resourcesAt(2, const {}),
      isEmpty,
      reason: '低于 startsAtLevel 整条跳过',
    );
    expect(merged.resourcesAt(3, const {}).single.maximum, 3);
  });
}
