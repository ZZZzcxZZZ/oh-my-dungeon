// test/rules/rule_override_priority_test.dart
//
// S3 任务 7：声明 / 排序 / 索引值对象（纯新增，决策 D2 / D3 / D6）。
//
// - tier = 0（内置）/ 100 + priority（包声明）；
// - 同 tier：replace 先于 patch → 角色自己的条目优先 → originId 升序
//   （originId 升序就是 D6 的"按包 id 字典序"确定性回退）；
// - `RuleOverrideIndex` 按对齐键（条目 id 末段）分组，排除角色自己那条。
import 'package:dnd_table_client/src/features/characters/domain/rule_override_index.dart';
import 'package:dnd_table_client/src/features/content/domain/content_block.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:dnd_table_client/src/features/rules/domain/class_rule_set.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_diagnostic.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_override_declaration.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_override_priority.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_profile.dart';
import 'package:flutter_test/flutter_test.dart';

const _path = r'$.structured.classRules';

ClassRuleSet rulesOf(Map<String, Object?> raw) => ClassRuleSet.parse(
  raw,
  path: _path,
  diagnostics: <RuleDiagnostic>[],
);

RuleOverrideDeclaration declaration({
  required String originId,
  int priority = 0,
  Map<String, Object?> rules = const {'hitDie': 8},
  String? entryId,
  bool replace = false,
}) => RuleOverrideDeclaration.package(
  originId: originId,
  packageId: RuleOverrideDeclaration.packageIdOf(originId),
  priority: priority,
  entryId: entryId ?? originId,
  rules: rulesOf({if (replace) 'mode': 'replace', ...rules}),
);

void main() {
  group('RuleOverrideOrder.ordered', () {
    test('tier 降序：priority 高的包排在前面', () {
      final ordered = RuleOverrideOrder.ordered([
        declaration(originId: 'low:class/wizard', priority: 0),
        declaration(originId: 'high:class/wizard', priority: 50),
      ]);
      expect(ordered.map((d) => d.originId), [
        'high:class/wizard',
        'low:class/wizard',
      ]);
      expect(ordered.first.tier, kEntryTier + 50);
      expect(ordered.last.tier, kEntryTier);
    });

    test('同 tier：replace 排在 patch 之前', () {
      final ordered = RuleOverrideOrder.ordered([
        declaration(originId: 'a:class/wizard'),
        declaration(originId: 'b:class/wizard', replace: true),
      ]);
      expect(ordered.first.originId, 'b:class/wizard');
      expect(ordered.last.originId, 'a:class/wizard');
    });

    test('同 tier 同 mode：角色自己的条目排在别的包之前', () {
      final ordered = RuleOverrideOrder.ordered([
        declaration(originId: 'other:class/wizard'),
        declaration(originId: 'mine:class/wizard'),
      ], characterEntryId: 'mine:class/wizard');
      expect(ordered.first.originId, 'mine:class/wizard');
    });

    test('其余同 tier 按 originId 升序（= 包 id 字典序，结果可复现）', () {
      final ordered = RuleOverrideOrder.ordered([
        declaration(originId: 'zeta:class/wizard'),
        declaration(originId: 'alpha:class/wizard'),
      ]);
      expect(ordered.map((d) => d.originId), [
        'alpha:class/wizard',
        'zeta:class/wizard',
      ]);
      // 同样输入换个传入顺序，结果必须一致（不依赖 Map / 列表迭代序）。
      final reversed = RuleOverrideOrder.ordered([
        declaration(originId: 'alpha:class/wizard'),
        declaration(originId: 'zeta:class/wizard'),
      ]);
      expect(reversed.map((d) => d.originId), ordered.map((d) => d.originId));
    });

    test('默认 priority 0 的声明 tier 就是 100（行为不变）', () {
      expect(declaration(originId: 'x:class/wizard').tier, kEntryTier);
    });

    test('内置档案 tier 0 永远最后，priority 字段为负数只是可读', () {
      final builtin = RuleOverrideDeclaration.builtin(rulesOf(const {}));
      expect(builtin.tier, kBuiltinTier);
      expect(builtin.originId, kBuiltinOriginId);
      expect(builtin.packageId, isEmpty);
      final ordered = RuleOverrideOrder.ordered([
        builtin,
        declaration(originId: 'x:class/wizard'),
      ]);
      expect(ordered.first.originId, 'x:class/wizard');
      expect(ordered.last.originId, kBuiltinOriginId);
    });
  });

  group('RuleOverrideOrder.effective（D4 截断）', () {
    test('第一条 replace 之后的声明全部丢弃（低 tier 不再提供任何列）', () {
      final effective = RuleOverrideOrder.effective([
        RuleOverrideDeclaration.builtin(rulesOf(const {'hitDie': 6})),
        declaration(originId: 'mid:class/wizard', priority: 5, replace: true),
        declaration(originId: 'low:class/wizard'),
      ]);
      expect(effective.map((d) => d.originId), [
        'mid:class/wizard',
        // 更低 tier（含内置）被截断。
      ]);
    });

    test('没有 replace 时原样保留全部声明', () {
      final effective = RuleOverrideOrder.effective([
        RuleOverrideDeclaration.builtin(rulesOf(const {'hitDie': 6})),
        declaration(originId: 'mid:class/wizard'),
      ]);
      expect(effective, hasLength(2));
    });
  });

  group('RuleOverrideIndex', () {
    ContentEntry classEntry(String id, String name) => ContentEntry(
      id: id,
      type: 'class',
      slug: name.toLowerCase(),
      name: name,
      body: const <ContentBlock>[],
      revision: 1,
      structured: const {
        'classRules': {'hitDie': 8},
      },
    );

    test('按对齐键（条目 id 末段）分组，排除角色自己那条', () {
      final index = RuleOverrideIndex.fromEntries([
        classEntry('base:class/wizard', 'Wizard'),
        classEntry('errata:class/wizard', 'Wizard Errata'),
        classEntry('other:class/fighter', 'Fighter'),
      ], const {'errata': 40});

      final wizard = index.declarationsFor(
        'wizard',
        excludeEntryId: 'base:class/wizard',
      );
      expect(wizard, hasLength(1));
      expect(wizard.single.originId, 'errata:class/wizard');
      expect(wizard.single.tier, kEntryTier + 40);
      expect(wizard.single.packageId, 'errata');
      expect(index.declarationsFor('fighter'), hasLength(1));
      expect(index.declarationsFor('barbarian'), isEmpty);
    });

    test('包优先级缺省 0；declare 与 exclude 的键都做 trim/lowercase', () {
      final index = RuleOverrideIndex.fromEntries([
        classEntry('base:class/wizard', 'Wizard'),
        classEntry('errata:class/wizard', 'Wizard Errata'),
      ], const {});
      final wizard = index.declarationsFor(
        '  Wizard  ',
        excludeEntryId: 'base:class/wizard',
      );
      expect(wizard.single.tier, kEntryTier, reason: '未配置的包 priority = 0');
    });

    test('非 class 条目与未声明 classRules 的条目不参与', () {
      final index = RuleOverrideIndex.fromEntries([
        ContentEntry(
          id: 'p:spell/fireball',
          type: 'spell',
          slug: 'fireball',
          name: 'F',
          body: const <ContentBlock>[],
          revision: 1,
        ),
        ContentEntry(
          id: 'p:class/naked',
          type: 'class',
          slug: 'naked',
          name: 'N',
          body: const <ContentBlock>[],
          revision: 1,
        ),
      ], const {});
      expect(index.declarationsFor('naked'), isEmpty);
      expect(index.declarationsFor('fireball'), isEmpty);
    });

    test('packageIdOf 取 id 前缀（缺失时返回空串）', () {
      expect(
        RuleOverrideDeclaration.packageIdOf('phb-2024:class/wizard'),
        'phb-2024',
      );
      expect(RuleOverrideDeclaration.packageIdOf('wizard'), '');
      expect(RuleOverrideDeclaration.packageIdOf(':class/wizard'), '');
    });
  });
}
