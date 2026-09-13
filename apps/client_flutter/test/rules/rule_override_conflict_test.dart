// test/rules/rule_override_conflict_test.dart
//
// S3 任务 8：多声明列级合并 + 同 tier 冲突登记（决策 D5 / D6）。
//
// - `resolveClassRules` 接受按优先级排好的跨包声明，tier 降序合并；
// - 同 tier 多来源抢**同一列**（标量列 / 表列 / 资源 maximum）→ 记一条
//   `RuleOverrideConflict`：生效值取排序首位（可复现 = 包 id 字典序最小 /
//   角色自身条目优先），但其余来源必须如实记录，不许静默丢弃；
// - 不同 tier 只是覆盖，不算冲突；
// - 角色自己的条目通过 `entryPriority` 参与**同一套** tier 排序。
import 'package:dnd_table_client/src/features/characters/domain/rule_override_index.dart';
import 'package:dnd_table_client/src/features/rules/domain/class_rule_set.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_diagnostic.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_field_path.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_override_conflict.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_override_declaration.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_override_priority.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_profile.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_profile_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

import 'rule_profile_test_support.dart';

const _path = r'$.structured.classRules';

ClassRuleSet rulesOf(Map<String, Object?> raw) => ClassRuleSet.parse(
  raw,
  path: _path,
  diagnostics: <RuleDiagnostic>[],
);

RuleOverrideDeclaration declaration(
  String originId,
  Map<String, Object?> raw, {
  int priority = 0,
}) => RuleOverrideDeclaration.package(
  originId: originId,
  packageId: RuleOverrideDeclaration.packageIdOf(originId),
  priority: priority,
  entryId: originId,
  rules: rulesOf(raw),
);

void main() {
  late RuleProfile profile;
  setUp(
    () => profile = RuleProfileResolver.resolveBuiltin(
      overrideArchive(),
    ).profile!,
  );

  group('多声明合并 + 冲突登记（D5/D6）', () {
    test('高 priority 的勘误覆盖角色自己条目声明的列', () {
      final merged = RuleProfileResolver.resolveClassRules(
        profile: profile,
        slug: 'wizard',
        entryRules: rulesOf({
          'hitDie': 6,
          'spellcasting': {
            'prepared': {'5': 7},
          },
        }),
        entryId: 'base:class/wizard',
        declarations: [
          declaration('errata:class/wizard', {
            'spellcasting': {
              'prepared': {'5': 9},
            },
          }, priority: 40),
        ],
      );
      expect(merged.preparedLimit(5), 9);
      expect(
        merged.sourceOf('spellcasting.prepared')!.originId,
        'errata:class/wizard',
      );
      expect(merged.sourceOf('spellcasting.prepared')!.tier, kEntryTier + 40);
      expect(merged.sourceOf('hitDie')!.originId, 'base:class/wizard');
      expect(merged.conflicts, isEmpty, reason: '不同 tier 只是覆盖');
    });

    test('低 priority 的勘误不生效，但来源里看得见谁赢', () {
      final merged = RuleProfileResolver.resolveClassRules(
        profile: profile,
        slug: 'wizard',
        entryRules: rulesOf({
          'spellcasting': {
            'mode': 'prepared',
            'prepared': {'5': 7},
          },
        }),
        entryId: 'base:class/wizard',
        declarations: [
          declaration('errata:class/wizard', {
            'spellcasting': {
              'prepared': {'5': 9},
            },
          }),
        ],
      );
      // 同 tier（都是 100）；角色自己的条目优先，因此 7 生效。
      expect(merged.preparedLimit(5), 7);
      expect(
        merged.sourceOf('spellcasting.prepared')!.originId,
        'base:class/wizard',
      );
    });

    test('同 tier 两个外部包抢同一表列 → 记一条冲突，取 originId 升序首位', () {
      final merged = RuleProfileResolver.resolveClassRules(
        profile: profile,
        slug: 'wizard',
        entryRules: rulesOf({'hitDie': 6}),
        entryId: 'base:class/wizard',
        declarations: [
          declaration('alpha:class/wizard', {
            'spellcasting': {
              'mode': 'prepared',
              'prepared': {'5': 9},
            },
          }, priority: 10),
          declaration('zeta:class/wizard', {
            'spellcasting': {
              'prepared': {'5': 11},
            },
          }, priority: 10),
        ],
      );
      expect(merged.preparedLimit(5), 9, reason: 'alpha 在 originId 升序里先');
      expect(merged.conflicts, hasLength(1));
      final conflict = merged.conflicts.single;
      expect(conflict.field, 'spellcasting.prepared');
      expect(conflict.tier, kEntryTier + 10);
      expect(conflict.originIds, ['alpha:class/wizard', 'zeta:class/wizard']);
      expect(conflict.effectiveOriginId, 'alpha:class/wizard');
      // 冲突是"附加信息"：来源仍如实记在生效者上。
      expect(
        merged.sourceOf('spellcasting.prepared')!.originId,
        'alpha:class/wizard',
      );
    });

    test('同 tier 两个外部包抢同一标量列（hitDie）→ 冲突登记', () {
      final merged = RuleProfileResolver.resolveClassRules(
        profile: profile,
        slug: 'wizard',
        entryRules: null,
        entryId: null,
        declarations: [
          declaration('alpha:class/wizard', {'hitDie': 8}, priority: 5),
          declaration('zeta:class/wizard', {'hitDie': 10}, priority: 5),
        ],
      );
      expect(merged.hitDie, 8, reason: 'alpha 确定性胜出');
      expect(merged.conflicts, hasLength(1));
      final conflict = merged.conflicts.single;
      expect(conflict.field, 'hitDie');
      expect(conflict.tier, kEntryTier + 5);
      expect(conflict.originIds, ['alpha:class/wizard', 'zeta:class/wizard']);
      expect(conflict.effectiveOriginId, 'alpha:class/wizard');
    });

    test('同 tier 两个外部包抢资源 maximum → 冲突登记（分层回退仍生效）', () {
      final merged = RuleProfileResolver.resolveClassRules(
        profile: profile,
        slug: 'barbarian',
        entryRules: null,
        entryId: null,
        declarations: [
          declaration('alpha:class/barbarian', {
            'resources': [
              {'id': 'x', 'name': 'X', 'maximum': 2},
            ],
          }, priority: 0),
          declaration('zeta:class/barbarian', {
            'resources': [
              {'id': 'x', 'maximum': 3},
            ],
          }, priority: 0),
        ],
      );
      final x = merged.resourcesAt(
        1,
        const {},
      ).singleWhere((resource) => resource.id == 'x');
      expect(x.maximum, 2, reason: 'alpha 的 MaxSpec 是分层链的生效层');
      final fields = merged.conflicts.map((c) => c.field).toList();
      expect(fields, contains('resources.x.maximum'));
    });

    test('声明不同列的两个包同一 tier 不算冲突（互补）', () {
      final merged = RuleProfileResolver.resolveClassRules(
        profile: profile,
        slug: 'wizard',
        entryRules: rulesOf({
          'spellcasting': {'mode': 'prepared'},
        }),
        entryId: 'base:class/wizard',
        declarations: [
          declaration('alpha:class/wizard', {
            'spellcasting': {
              'prepared': {'5': 9},
            },
          }, priority: 10),
          declaration('beta:class/wizard', {
            'spellcasting': {
              'cantrips': {'5': 5},
            },
          }, priority: 10),
        ],
      );
      expect(merged.preparedLimit(5), 9);
      expect(merged.cantripLimit(5), 5);
      expect(merged.conflicts, isEmpty);
    });

    test('高 tier 覆盖低 tier 不算冲突（只是覆盖）', () {
      final merged = RuleProfileResolver.resolveClassRules(
        profile: profile,
        slug: 'wizard',
        entryRules: rulesOf({
          'spellcasting': {'mode': 'prepared'},
        }),
        entryId: 'base:class/wizard',
        declarations: [
          declaration('errata:class/wizard', {
            'spellcasting': {
              'prepared': {'5': 9},
            },
          }, priority: 40),
          declaration('other:class/wizard', {
            'spellcasting': {
              'prepared': {'5': 11},
            },
          }, priority: 10),
        ],
      );
      expect(merged.preparedLimit(5), 9);
      expect(merged.conflicts, isEmpty);
    });

    test('priority 不同的两个包都参与合并：各自声明的列都生效', () {
      final merged = RuleProfileResolver.resolveClassRules(
        profile: profile,
        slug: 'wizard',
        entryRules: null,
        entryId: null,
        declarations: [
          declaration('alpha:class/wizard', {
            'spellcasting': {
              'mode': 'prepared',
              'prepared': {'5': 9},
            },
          }, priority: 40),
          declaration('zeta:class/wizard', {
            'spellcasting': {
              'cantrips': {'5': 5},
            },
          }, priority: 10),
        ],
      );
      expect(merged.preparedLimit(5), 9);
      expect(merged.cantripLimit(5), 5, reason: '低 priority 声明的是另一列，仍然生效');
      expect(merged.spellSlots(5), {'1': 4, '2': 3, '3': 2}, reason: '档案补齐');
      expect(merged.conflicts, isEmpty);
    });

    test('档案与包声明不同 tier，永不算冲突', () {
      final merged = RuleProfileResolver.resolveClassRules(
        profile: profile,
        slug: 'wizard',
        entryRules: null,
        entryId: null,
        declarations: [
          declaration('alpha:class/wizard', {
            'spellcasting': {
              'prepared': {'5': 9},
            },
          }),
        ],
      );
      expect(merged.preparedLimit(5), 9);
      expect(merged.conflicts, isEmpty);
    });
  });

  group('角色自身条目参与同一优先级排序（entryPriority）', () {
    test('entryPriority 更高时，角色自己的条目压过高 priority 的勘误', () {
      final merged = RuleProfileResolver.resolveClassRules(
        profile: profile,
        slug: 'wizard',
        entryRules: rulesOf({
          'hitDie': 6,
          'spellcasting': {
            'prepared': {'5': 7},
          },
        }),
        entryId: 'base:class/wizard',
        // 角色自己那条的包 priority 50 > 勘误包 priority 40。
        entryPriority: 50,
        declarations: [
          declaration('errata:class/wizard', {
            'spellcasting': {
              'prepared': {'5': 9},
            },
          }, priority: 40),
        ],
      );
      expect(merged.preparedLimit(5), 7);
      expect(
        merged.sourceOf('spellcasting.prepared')!.originId,
        'base:class/wizard',
      );
      expect(merged.sourceOf('spellcasting.prepared')!.tier, kEntryTier + 50);
      expect(merged.conflicts, isEmpty);
    });

    test('同 tier 时角色自身条目优先，即使包 id 字典序更大', () {
      // 包 id 升序里 `alpha-pack` 在 `zown-pack` 之前；只有"角色自己的条目优先"
      // 这条 tie-break 才能让 zown 胜出（旧实现把该参数滤成死参，永远不触发）。
      final merged = RuleProfileResolver.resolveClassRules(
        profile: profile,
        slug: 'wizard',
        entryRules: rulesOf({
          'spellcasting': {
            'mode': 'prepared',
            'prepared': {'5': 7},
          },
        }),
        entryId: 'zown-pack:class/wizard',
        declarations: [
          declaration('alpha-pack:class/wizard', {
            'spellcasting': {
              'prepared': {'5': 9},
            },
          }),
        ],
      );
      expect(merged.preparedLimit(5), 7);
      expect(
        merged.sourceOf('spellcasting.prepared')!.originId,
        'zown-pack:class/wizard',
      );
    });
  });

  group('RuleOverrideIndex.declarationsFor 返回值（任务 8 接口调整）', () {
    ClassRuleSet rules(Map<String, Object?> raw) => rulesOf(raw);

    test('返回未截断的 ordered()：截断由解析器合入档案后统一做', () {
      final index = RuleOverrideIndex(
        <String, List<RuleOverrideDeclaration>>{
          'wizard': [
            declaration('patch:class/wizard', {'hitDie': 8}, priority: 0),
            RuleOverrideDeclaration.package(
              originId: 'replacer:class/wizard',
              packageId: 'replacer',
              priority: 50,
              entryId: 'replacer:class/wizard',
              rules: rules({'mode': 'replace', 'hitDie': 10}),
            ),
          ],
        },
      );
      final declarations = index.declarationsFor('wizard');
      // 未截断：replace 更高 tier 排前面，但 patch 声明**不被这里丢掉**
      // （否则"更高 tier 的 replace 截断"无法与"合入档案"一起统一处理）。
      expect(declarations.map((d) => d.originId), [
        'replacer:class/wizard',
        'patch:class/wizard',
      ]);
      expect(declarations.first.rules.mode, ClassMergeMode.replace);
    });

    test('排除角色自己那条：同一来源不重复参与', () {
      final index = RuleOverrideIndex(
        <String, List<RuleOverrideDeclaration>>{
          'wizard': [
            declaration('base:class/wizard', {'hitDie': 8}),
            declaration('errata:class/wizard', {'hitDie': 10}),
          ],
        },
      );
      final declarations = index.declarationsFor(
        'wizard',
        excludeEntryId: 'base:class/wizard',
      );
      expect(declarations.single.originId, 'errata:class/wizard');
    });
  });

  group('RuleOverrideConflict 持久化（唯一实现）', () {
    test('toJson / fromJson 往返；坏数据降级为"没有冲突"', () {
      const conflict = RuleOverrideConflict(
        field: 'spellcasting.prepared',
        tier: 110,
        originIds: ['alpha:class/wizard', 'zeta:class/wizard'],
        effectiveOriginId: 'alpha:class/wizard',
      );
      final restored = RuleOverrideConflict.fromJson(conflict.toJson())!;
      expect(restored.field, conflict.field);
      expect(restored.tier, conflict.tier);
      expect(restored.originIds, conflict.originIds);
      expect(restored.effectiveOriginId, conflict.effectiveOriginId);
      expect(restored.label, '准备法术上限');

      // 坏数据：形状不对 / 少于两个来源 / tier 非整数 → null（不猜）。
      expect(RuleOverrideConflict.fromJson(null), isNull);
      expect(RuleOverrideConflict.fromJson(<String, Object?>{}), isNull);
      expect(
        RuleOverrideConflict.fromJson(<String, Object?>{
          'field': 'hitDie',
          'tier': 100,
          'originIds': ['only:class/wizard'],
          'effectiveOriginId': 'only:class/wizard',
        }),
        isNull,
      );
      expect(
        RuleOverrideConflict.fromJson(<String, Object?>{
          'field': 'hitDie',
          'tier': '100',
          'originIds': ['a', 'b'],
          'effectiveOriginId': 'a',
        }),
        isNull,
      );

      // 表级持久化：非 List 输入 → 空表。
      expect(RuleOverrideConflicts.fromData(null), isEmpty);
      expect(RuleOverrideConflicts.fromData('nope'), isEmpty);
      expect(
        RuleOverrideConflicts.fromData(RuleOverrideConflicts.toData([conflict])),
        hasLength(1),
      );
    });

    test('effectiveOriginId 不在 originIds 里 → 降级为"没有冲突"', () {
      expect(
        RuleOverrideConflict.fromJson(<String, Object?>{
          'field': 'hitDie',
          'tier': 100,
          'originIds': ['alpha:class/wizard', 'zeta:class/wizard'],
          'effectiveOriginId': 'ghost:class/wizard',
        }),
        isNull,
        reason: '界面绝不能把"生效来源"显示成没参与该列竞争的名字',
      );
      // originIds 恒升序，但 effectiveOriginId 由排序首位决定（角色自身条目优先时
      // 可以不是首个元素）——因此判据是 contains，而不是 == first。
      final conflict = RuleOverrideConflict.fromJson(<String, Object?>{
        'field': 'hitDie',
        'tier': 100,
        'originIds': ['alpha-pack:class/wizard', 'zown-pack:class/wizard'],
        'effectiveOriginId': 'zown-pack:class/wizard',
      });
      expect(conflict, isNotNull);
      expect(conflict!.originIds.first, 'alpha-pack:class/wizard');
    });
  });

  group('用户 pin 只影响被 pin 的那一列（0.1 阻塞项）', () {
    test('pin prepared 不改变同一来源声明的 hitDie', () {
      final merged = RuleProfileResolver.resolveClassRules(
        profile: profile,
        slug: 'wizard',
        entryRules: null,
        entryId: null,
        declarations: [
          declaration('alpha:class/wizard', {
            'hitDie': 8,
            'spellcasting': {
              'prepared': {'5': 9},
            },
          }, priority: 40),
          declaration('zeta:class/wizard', {
            'hitDie': 10,
            'spellcasting': {
              'prepared': {'5': 11},
            },
          }, priority: 40),
        ],
        pinnedOrigins: const {'spellcasting.prepared': 'zeta:class/wizard'},
      );

      // 被 pin 的列生效值来自被 pin 的来源。
      expect(merged.preparedLimit(5), 11);
      expect(
        merged.sourceOf('spellcasting.prepared')!.originId,
        'zeta:class/wizard',
      );
      // pin 一列**不得**连带该来源声明的其它列：hitDie 仍由 alpha 胜出。
      expect(merged.hitDie, 8);
      expect(merged.sourceOf('hitDie')!.originId, 'alpha:class/wizard');
    });

    test('pin 一列不会在未 pin 的列上制造冲突', () {
      final merged = RuleProfileResolver.resolveClassRules(
        profile: profile,
        slug: 'wizard',
        entryRules: null,
        entryId: null,
        declarations: [
          declaration('alpha:class/wizard', {
            'hitDie': 8,
            'spellcasting': {
              'prepared': {'5': 9},
            },
          }, priority: 40),
          declaration('zeta:class/wizard', {
            'hitDie': 10,
            'spellcasting': {
              'prepared': {'5': 11},
            },
          }, priority: 40),
        ],
        pinnedOrigins: const {'spellcasting.prepared': 'zeta:class/wizard'},
      );

      // hitDie 仍是真正的同 tier 冲突（8 vs 10），与 pin 无关。
      expect(merged.conflicts.map((c) => c.field), ['hitDie']);
      // prepared 已由用户 pin 解决，不再提示冲突。
      expect(
        merged.conflicts.where((c) => c.field == 'spellcasting.prepared'),
        isEmpty,
      );
    });

    test('pin 豁免 disabled：被关闭的来源只要被 pin 仍在该列生效', () {
      final merged = RuleProfileResolver.resolveClassRules(
        profile: profile,
        slug: 'wizard',
        entryRules: null,
        entryId: null,
        declarations: [
          declaration('zeta:class/wizard', {
            'spellcasting': {
              'prepared': {'5': 11},
            },
          }, priority: 40),
        ],
        disabledOriginIds: const {'zeta'},
        pinnedOrigins: const {'spellcasting.prepared': 'zeta:class/wizard'},
      );
      expect(merged.preparedLimit(5), 11, reason: 'pin 是比 disabled 更晚的用户选择');
      expect(
        merged.sourceOf('spellcasting.prepared')!.originId,
        'zeta:class/wizard',
      );

      // 没有 pin 时 disabled 生效：回退档案（5 级 9）。
      final disabledOnly = RuleProfileResolver.resolveClassRules(
        profile: profile,
        slug: 'wizard',
        entryRules: null,
        entryId: null,
        declarations: [
          declaration('zeta:class/wizard', {
            'spellcasting': {
              'prepared': {'5': 11},
            },
          }, priority: 40),
        ],
        disabledOriginIds: const {'zeta'},
      );
      expect(disabledOnly.preparedLimit(5), 9);
      expect(
        disabledOnly.sourceOf('spellcasting.prepared')!.originId,
        kBuiltinOriginId,
      );
    });
  });

  group('冲突判定收紧为"同 tier + 同列 + 区间有交集 + 取值不同"（0.3）', () {
    test('同值不登记', () {
      final merged = RuleProfileResolver.resolveClassRules(
        profile: profile,
        slug: 'wizard',
        entryRules: null,
        entryId: null,
        declarations: [
          declaration('alpha:class/wizard', {
            'spellcasting': {
              'prepared': {'5': 9},
            },
          }, priority: 10),
          declaration('zeta:class/wizard', {
            'spellcasting': {
              'prepared': {'5': 9},
            },
          }, priority: 10),
        ],
      );
      expect(merged.preparedLimit(5), 9);
      expect(merged.conflicts, isEmpty, reason: '同值不是冲突');
    });

    test('只改不同等级（声明区间不相交）不登记', () {
      // 更高排序位的那条声明 10 级、低排序位的声明 5 级：两条区间 [10,10] 与
      // [5,5] 不相交，D5 逐级合并后 5 级来自后者、10 级来自前者，互补生效。
      final merged = RuleProfileResolver.resolveClassRules(
        profile: profile,
        slug: 'wizard',
        entryRules: null,
        entryId: null,
        declarations: [
          declaration('alpha:class/wizard', {
            'spellcasting': {
              'prepared': {'10': 11},
            },
          }, priority: 10),
          declaration('zeta:class/wizard', {
            'spellcasting': {
              'prepared': {'5': 9},
            },
          }, priority: 10),
        ],
      );
      expect(merged.preparedLimit(5), 9);
      expect(merged.preparedLimit(10), 11, reason: '两级互补，D5 逐级合并');
      expect(merged.conflicts, isEmpty, reason: '[10,10] 与 [5,5] 不相交');
    });

    test('同 tier 同列且区间相交、取值不同 → 登记（来源恒升序）', () {
      final merged = RuleProfileResolver.resolveClassRules(
        profile: profile,
        slug: 'wizard',
        entryRules: null,
        entryId: null,
        declarations: [
          declaration('alpha:class/wizard', {
            'spellcasting': {
              'prepared': {'5': 9, '10': 10},
            },
          }, priority: 10),
          declaration('zeta:class/wizard', {
            'spellcasting': {
              'prepared': {'5': 11},
            },
          }, priority: 10),
        ],
      );
      expect(merged.conflicts, hasLength(1));
      final conflict = merged.conflicts.single;
      expect(conflict.field, 'spellcasting.prepared');
      expect(conflict.originIds, [
        'alpha:class/wizard',
        'zeta:class/wizard',
      ]);
      expect(conflict.effectiveOriginId, 'alpha:class/wizard');
    });

    test('同 tier 标量列同值不登记、不同值登记', () {
      String fieldOf(Map<String, Object?> a, Map<String, Object?> b) {
        final merged = RuleProfileResolver.resolveClassRules(
          profile: profile,
          slug: 'wizard',
          entryRules: null,
          entryId: null,
          declarations: [
            declaration('alpha:class/wizard', a, priority: 3),
            declaration('zeta:class/wizard', b, priority: 3),
          ],
        );
        return merged.conflicts.map((c) => c.field).join(',');
      }

      expect(
        fieldOf({
          'savingThrowAbilities': ['int', 'wis'],
        }, {
          'savingThrowAbilities': ['wis', 'int'],
        }),
        isEmpty,
        reason: 'Set 内容相同不算冲突（内建 == 只看引用，必须走内容比较）',
      );
      expect(
        fieldOf({'hitDie': 6}, {'hitDie': 8}),
        'hitDie',
      );
    });
  });

  group('originIds 恒升序（0.4-3）', () {
    test('同 tier 角色自身条目优先时，effectiveOriginId 仍 ∈ originIds', () {
      final merged = RuleProfileResolver.resolveClassRules(
        profile: profile,
        slug: 'wizard',
        entryRules: rulesOf({
          'spellcasting': {
            'mode': 'prepared',
            'prepared': {'5': 7},
          },
        }),
        entryId: 'zown-pack:class/wizard',
        declarations: [
          declaration('alpha-pack:class/wizard', {
            'spellcasting': {
              'prepared': {'5': 9},
            },
          }),
        ],
      );
      final conflict = merged.conflicts.single;
      expect(conflict.originIds, [
        'alpha-pack:class/wizard',
        'zown-pack:class/wizard',
      ], reason: 'originIds 恒按 originId 升序');
      expect(conflict.effectiveOriginId, 'zown-pack:class/wizard');
      expect(conflict.originIds, contains(conflict.effectiveOriginId));
      expect(conflict.effectiveOriginId, isNot(conflict.originIds.first));
    });
  });

  group('replace 截掉同 tier patch 不静默（0.4-4）', () {
    test('被同 tier replace 丢弃的 patch：replace 也声明的列才有冲突', () {
      final merged = RuleProfileResolver.resolveClassRules(
        profile: profile,
        slug: 'wizard',
        entryRules: null,
        entryId: null,
        declarations: [
          // replace 声明 hitDie 与 spellcasting.prepared 两列。
          RuleOverrideDeclaration.package(
            originId: 'replacer:class/wizard',
            packageId: 'replacer',
            priority: 50,
            entryId: 'replacer:class/wizard',
            rules: rulesOf({
              'mode': 'replace',
              'hitDie': 10,
              'spellcasting': {
                'mode': 'prepared',
                'prepared': {'5': 7},
              },
            }),
          ),
          declaration('patch:class/wizard', {
            'hitDie': 8,
            'spellcasting': {
              'prepared': {'5': 9},
            },
          }, priority: 50),
        ],
      );

      // replace 独占：patch 的列一个都不生效。
      expect(merged.hitDie, 10);
      expect(merged.preparedLimit(5), 7, reason: 'replace 自己声明了该列');
      // 被丢弃这件事可见：**replace 也声明过**的每一列都有冲突记录。
      final fields = merged.conflicts.map((c) => c.field).toList();
      expect(fields, contains('hitDie'));
      expect(fields, contains('spellcasting.prepared'));
      for (final conflict in merged.conflicts) {
        expect(conflict.effectiveOriginId, 'replacer:class/wizard');
        expect(conflict.originIds, contains('patch:class/wizard'));
        expect(conflict.originIds, contains('replacer:class/wizard'));
      }
    });

    test('replace 未声明的列不登记冲突（D4：未声明即未声明）', () {
      final merged = RuleProfileResolver.resolveClassRules(
        profile: profile,
        slug: 'wizard',
        entryRules: null,
        entryId: null,
        declarations: [
          RuleOverrideDeclaration.package(
            originId: 'replacer:class/wizard',
            packageId: 'replacer',
            priority: 50,
            entryId: 'replacer:class/wizard',
            rules: rulesOf({'mode': 'replace', 'hitDie': 10}),
          ),
          declaration('patch:class/wizard', {
            'hitDie': 8,
            'spellcasting': {
              'prepared': {'5': 9},
            },
          }, priority: 50),
        ],
      );

      expect(merged.hitDie, 10);
      expect(
        merged.preparedLimit(5),
        isNull,
        reason: 'replace 未声明 spellcasting.prepared：该列就是未声明',
      );
      final fields = merged.conflicts.map((c) => c.field).toList();
      expect(fields, contains('hitDie'));
      expect(
        fields,
        isNot(contains('spellcasting.prepared')),
        reason: 'replace 未声明的列不登记冲突（不变量：冲突来源必须声明该列）',
      );
    });

    test('pin 到被 replace 丢弃的同 tier patch：该列按 patch 取值、冲突消失', () {
      final declarations = <RuleOverrideDeclaration>[
        RuleOverrideDeclaration.package(
          originId: 'replacer:class/wizard',
          packageId: 'replacer',
          priority: 50,
          entryId: 'replacer:class/wizard',
          rules: rulesOf({
            'mode': 'replace',
            'hitDie': 10,
            'spellcasting': {
              'mode': 'prepared',
              'prepared': {'5': 7},
            },
          }),
        ),
        declaration('patch:class/wizard', {
          'hitDie': 8,
          'spellcasting': {
            'prepared': {'5': 9},
          },
        }, priority: 50),
      ];

      final merged = RuleProfileResolver.resolveClassRules(
        profile: profile,
        slug: 'wizard',
        entryRules: null,
        entryId: null,
        declarations: declarations,
        pinnedOrigins: const {'spellcasting.prepared': 'patch:class/wizard'},
      );

      expect(merged.preparedLimit(5), 9, reason: 'pin 只作用于该列');
      expect(
        merged.sourceOf('spellcasting.prepared')!.originId,
        'patch:class/wizard',
      );
      expect(
        merged.conflicts.map((c) => c.field),
        isNot(contains('spellcasting.prepared')),
        reason: 'pin 就是用户对该列的答案，冲突消失',
      );
      // pin 一列**不得**连带该来源声明的其它列：hitDie 仍由 replace 独占。
      expect(merged.hitDie, 10);
      expect(merged.conflicts.map((c) => c.field), contains('hitDie'));
    });

    test('更低 tier 被 replace 截断是 D4 设计语义，不记冲突', () {
      final merged = RuleProfileResolver.resolveClassRules(
        profile: profile,
        slug: 'wizard',
        entryRules: null,
        entryId: null,
        declarations: [
          RuleOverrideDeclaration.package(
            originId: 'replacer:class/wizard',
            packageId: 'replacer',
            priority: 50,
            entryId: 'replacer:class/wizard',
            rules: rulesOf({'mode': 'replace', 'hitDie': 10}),
          ),
          declaration('low:class/wizard', {'hitDie': 8}, priority: 0),
        ],
      );
      expect(merged.hitDie, 10);
      expect(merged.conflicts, isEmpty);
    });
  });

  // 新增不变量（B）：**每条冲突的每个 `originId` 都必须声明了该列，
  // `effectiveOriginId` 必须是其中之一。** 判据与 `_declaredColumnPaths` 同源：
  // `RuleFieldPath` 解析列路径 + `ClassRuleSet.declares`。
  group('不变量：冲突来源必须声明该列（B）', () {
    /// `field` 路径 → "该规则块是否声明了这一列" 的判据（唯一实现）。
    bool declaresField(ClassRuleSet rules, String field) {
      if (field == RuleFieldPath.hitDie) return rules.declares('hitDie');
      if (field == RuleFieldPath.savingThrowAbilities) {
        return rules.declares('savingThrowAbilities');
      }
      if (field.startsWith(RuleFieldPath.spellcastingPrefix)) {
        final column = field.substring(RuleFieldPath.spellcastingPrefix.length);
        if (!RuleFieldPath.spellcastingColumns.contains(column)) return false;
        return rules.spellcasting?.declares(column) ?? false;
      }
      final resource = RuleFieldPath.parseResource(field);
      if (resource == null ||
          !RuleFieldPath.resourceColumns.contains(resource.column)) {
        return false;
      }
      for (final rule in rules.resources) {
        if (rule.id == resource.id && rule.declares(resource.column)) {
          return true;
        }
      }
      return false;
    }

    /// 该 fixture 里**每个**冲突都对全部来源断言不变量。
    void expectInvariant(
      ResolvedClassRules merged,
      Map<String, ClassRuleSet> rulesByOrigin,
    ) {
      for (final conflict in merged.conflicts) {
        expect(
          conflict.originIds,
          contains(conflict.effectiveOriginId),
          reason: '${conflict.field}: 生效来源必须参与该列竞争',
        );
        for (final originId in conflict.originIds) {
          final rules = rulesByOrigin[originId];
          expect(rules, isNotNull, reason: '未知来源 $originId');
          expect(
            declaresField(rules!, conflict.field),
            isTrue,
            reason: '${conflict.field}: 来源 $originId 并没有声明该列（不变量违反）',
          );
        }
      }
    }

    /// `resolveClassRules`（`entryRules` 走 `entryId` 同一个 originId）。
    ResolvedClassRules resolve({
      required String slug,
      ClassRuleSet? entryRules,
      String? entryId,
      required List<RuleOverrideDeclaration> declarations,
      Map<String, String> pinnedOrigins = const <String, String>{},
    }) => RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: slug,
      entryRules: entryRules,
      entryId: entryId,
      declarations: declarations,
      pinnedOrigins: pinnedOrigins,
    );

    test('同 tier 抢同一列（标量 / 表 / 资源 maximum）', () {
      final alpha = declaration('alpha:class/wizard', {
        'hitDie': 8,
        'spellcasting': {
          'mode': 'prepared',
          'prepared': {'5': 9},
        },
        'resources': [
          {'id': 'x', 'name': 'X', 'maximum': {'table': {'1': 2}}},
        ],
      }, priority: 7);
      final zeta = declaration('zeta:class/wizard', {
        'hitDie': 10,
        'spellcasting': {
          'prepared': {'5': 11},
        },
        'resources': [
          {'id': 'x', 'maximum': 3},
        ],
      }, priority: 7);
      final merged = resolve(
        slug: 'wizard',
        declarations: [alpha, zeta],
      );
      expect(merged.conflicts, isNotEmpty, reason: 'fixture 必须真的产生冲突');
      expectInvariant(merged, {
        alpha.originId: alpha.rules,
        zeta.originId: zeta.rules,
      });
    });

    test('角色自身条目 + 同 tier 包声明', () {
      final own = rulesOf({
        'hitDie': 6,
        'spellcasting': {
          'mode': 'prepared',
          'prepared': {'5': 7},
        },
      });
      final other = declaration('alpha:class/wizard', {
        'hitDie': 8,
        'spellcasting': {
          'prepared': {'5': 9},
        },
      });
      final merged = resolve(
        slug: 'wizard',
        entryRules: own,
        entryId: 'zown-pack:class/wizard',
        declarations: [other],
      );
      expect(merged.conflicts, isNotEmpty, reason: 'fixture 必须真的产生冲突');
      expectInvariant(merged, {
        'zown-pack:class/wizard': own,
        other.originId: other.rules,
      });
    });

    test('replace 截掉同 tier patch（含 pin 到被丢弃 patch 的情况）', () {
      final replacer = RuleOverrideDeclaration.package(
        originId: 'replacer:class/wizard',
        packageId: 'replacer',
        priority: 50,
        entryId: 'replacer:class/wizard',
        rules: rulesOf({
          'mode': 'replace',
          'hitDie': 10,
          'spellcasting': {
            'mode': 'prepared',
            'prepared': {'5': 7},
          },
        }),
      );
      final patch = declaration('patch:class/wizard', {
        'hitDie': 8,
        'spellcasting': {
          'prepared': {'5': 9},
        },
      }, priority: 50);
      final rulesByOrigin = <String, ClassRuleSet>{
        replacer.originId: replacer.rules,
        patch.originId: patch.rules,
      };

      for (final pinned in const <Map<String, String>>[
        <String, String>{},
        <String, String>{'spellcasting.prepared': 'patch:class/wizard'},
        <String, String>{'hitDie': 'patch:class/wizard'},
      ]) {
        final merged = resolve(
          slug: 'wizard',
          declarations: [replacer, patch],
          pinnedOrigins: pinned,
        );
        expectInvariant(merged, rulesByOrigin);
      }
    });

    test('多个被丢弃 patch 声明同一列：合并成一条冲突、来源取并集（K）', () {
      final replacer = RuleOverrideDeclaration.package(
        originId: 'replacer:class/wizard',
        packageId: 'replacer',
        priority: 50,
        entryId: 'replacer:class/wizard',
        rules: rulesOf({
          'mode': 'replace',
          'hitDie': 10,
          'spellcasting': {
            'mode': 'prepared',
            'prepared': {'5': 7},
          },
        }),
      );
      final merged = resolve(
        slug: 'wizard',
        declarations: [
          replacer,
          declaration('beta:class/wizard', {
            'spellcasting': {
              'prepared': {'5': 11},
            },
          }, priority: 50),
          declaration('alpha:class/wizard', {
            'spellcasting': {
              'prepared': {'5': 13},
            },
          }, priority: 50),
        ],
      );
      final prepared = merged.conflicts.singleWhere(
        (conflict) => conflict.field == 'spellcasting.prepared',
      );
      expect(
        prepared.originIds,
        [
          'alpha:class/wizard',
          'beta:class/wizard',
          'replacer:class/wizard',
        ],
        reason: '同一列只登记一条冲突，来源取并集且恒升序（不丢来源）',
      );
      expect(prepared.effectiveOriginId, 'replacer:class/wizard');
    });
  });

  // D：`maximum` 的常量按数值参与比较——"常量 2"与"整表都是 2"不再误报冲突。
  group('maximum 跨形态比较（D）', () {
    String conflictFieldsOf(Object? left, Object? right) {
      final merged = RuleProfileResolver.resolveClassRules(
        profile: profile,
        slug: 'wizard',
        entryRules: null,
        entryId: null,
        declarations: [
          declaration('alpha:class/wizard', {
            'resources': [
              {'id': 'x', 'name': 'X', 'maximum': left},
            ],
          }, priority: 0),
          declaration('zeta:class/wizard', {
            'resources': [
              {'id': 'x', 'maximum': right},
            ],
          }, priority: 0),
        ],
      );
      return merged.conflicts.map((c) => c.field).join(',');
    }

    test('"常量 2"与"1..20 全为 2 的表"逐级同值 → 不登记冲突', () {
      expect(
        conflictFieldsOf(2, {
          'table': {for (var level = 1; level <= 20; level++) '$level': 2},
        }),
        isEmpty,
        reason: '同值不因形态不同而误报冲突',
      );
    });

    test('"常量 2"与"常量 3"取值不同 → 登记冲突', () {
      expect(conflictFieldsOf(2, 3), 'resources.x.maximum');
    });
  });

  // J：`disabled` 的两种写法（条目 id / 包 id）必须得到同一结果。
  group('disable 的两种写法行为一致（J）', () {
    final rules = rulesOf({
      'spellcasting': {
        'mode': 'prepared',
        'prepared': {'5': 11},
      },
    });

    ResolvedClassRules disabledAs(String disabled) =>
        RuleProfileResolver.resolveClassRules(
          profile: profile,
          slug: 'wizard',
          entryRules: null,
          entryId: null,
          declarations: [
            declaration('zeta:class/wizard', {
              'spellcasting': {
                'mode': 'prepared',
                'prepared': {'5': 11},
              },
            }, priority: 40),
          ],
          disabledOriginIds: {disabled},
        );

    test('disable 条目 id 与 disable 包 id 解析结果完全相同', () {
      final byEntryId = disabledAs('zeta:class/wizard');
      final byPackageId = disabledAs('zeta');
      expect(byEntryId.preparedLimit(5), byPackageId.preparedLimit(5));
      expect(
        byEntryId.preparedLimit(5),
        9,
        reason: '回退内置档案（5 级 9），不是被关闭来源的 11',
      );
      expect(
        byEntryId.sourceOf('spellcasting.prepared')!.originId,
        byPackageId.sourceOf('spellcasting.prepared')!.originId,
      );
      // 三向匹配的唯一实现：包 id 查询条目 id 的禁用记录也为 true。
      expect(
        RuleOverrideOrder.isDisabled({'zeta:class/wizard'}, 'zeta'),
        isTrue,
      );
      expect(RuleOverrideOrder.isDisabled({'zeta'}, 'zeta:class/wizard'), isTrue);
      expect(
        RuleOverrideOrder.isDisabled({'other'}, 'zeta:class/wizard'),
        isFalse,
      );
    });

    test('规则块本身确实声明了该列（fixture 有效性）', () {
      expect(rules.spellcasting?.declares('prepared'), isTrue);
    });
  });

  // P0-2.2：`_sameTierDropped` 的 **tier 过滤**——只有被 replace 丢弃的**同 tier**
  // 声明才作为 pin 的候选保留。更低 tier 被截断是 D4 的设计语义（"不提供任何列"），
  // pin 也不许把它复活。
  group('被 replace 丢弃的声明只有同 tier 才能被 pin 复活（P0-2.2）', () {
    RuleOverrideDeclaration replacer({int priority = 50}) =>
        RuleOverrideDeclaration.package(
          originId: 'replacer:class/wizard',
          packageId: 'replacer',
          priority: priority,
          entryId: 'replacer:class/wizard',
          rules: rulesOf({
            'mode': 'replace',
            'hitDie': 10,
            'spellcasting': {
              'mode': 'prepared',
              'prepared': {'5': 7},
            },
          }),
        );

    ResolvedClassRules resolve({
      required int patchPriority,
      Map<String, String> pinnedOrigins = const <String, String>{},
    }) => RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'wizard',
      entryRules: null,
      entryId: null,
      declarations: [
        replacer(),
        declaration('patch:class/wizard', {
          'hitDie': 8,
          'spellcasting': {
            'prepared': {'5': 9},
          },
        }, priority: patchPriority),
      ],
      pinnedOrigins: pinnedOrigins,
    );

    test('同 tier patch 被 pin 后生效（对照组）', () {
      final merged = resolve(
        patchPriority: 50,
        pinnedOrigins: const {'spellcasting.prepared': 'patch:class/wizard'},
      );
      expect(merged.preparedLimit(5), 9);
      expect(
        merged.sourceOf('spellcasting.prepared')!.originId,
        'patch:class/wizard',
      );
    });

    test('**更低 tier** patch 即使被 pin 也不生效（D4：更低 tier 不提供任何列）', () {
      final merged = resolve(
        patchPriority: 0,
        pinnedOrigins: const {'spellcasting.prepared': 'patch:class/wizard'},
      );
      expect(
        merged.preparedLimit(5),
        7,
        reason: 'pin 救不回被更高 tier replace 截断的更低 tier 声明',
      );
      expect(
        merged.sourceOf('spellcasting.prepared')!.originId,
        'replacer:class/wizard',
      );
    });
  });

  // P0-2.3：`_PinContext.targetFor` 的 fallback 分支必须带 `declares` 守卫——
  // pin 指向"被 disabled 剔除但**不声明该列**"的来源时，该列取不到它（回退正常链），
  // 且**不抑制**该列的冲突。
  group('pin 的 fallback 只认声明了该列的来源（P0-2.3）', () {
    test('pin 指向不声明该列的 disabled 来源：回退正常链且冲突照旧提示', () {
      final merged = RuleProfileResolver.resolveClassRules(
        profile: profile,
        slug: 'wizard',
        entryRules: null,
        entryId: null,
        declarations: [
          // 同 tier 真冲突：alpha vs zeta 抢 spellcasting.prepared。
          declaration('alpha:class/wizard', {
            'spellcasting': {
              'mode': 'prepared',
              'prepared': {'5': 9},
            },
          }, priority: 10),
          declaration('zeta:class/wizard', {
            'spellcasting': {
              'prepared': {'5': 11},
            },
          }, priority: 10),
          // disabled 且只声明 hitDie：被 pin 到 prepared 时不能顶替。
          declaration('broken:class/wizard', {'hitDie': 12}, priority: 10),
        ],
        disabledOriginIds: const {'broken'},
        pinnedOrigins: const {'spellcasting.prepared': 'broken:class/wizard'},
      );

      expect(
        merged.preparedLimit(5),
        9,
        reason: 'pin 目标不声明该列 → 落回正常链（alpha 升序首位）',
      );
      expect(
        merged.sourceOf('spellcasting.prepared')!.originId,
        'alpha:class/wizard',
      );
      expect(
        merged.conflicts.map((c) => c.field),
        contains('spellcasting.prepared'),
        reason: 'pin 没解决该列（目标不声明它）→ 冲突必须照旧提示',
      );
    });

    test('pin 指向声明了该列的 disabled 来源：该列取到它且冲突消失（对照组）', () {
      final merged = RuleProfileResolver.resolveClassRules(
        profile: profile,
        slug: 'wizard',
        entryRules: null,
        entryId: null,
        declarations: [
          declaration('alpha:class/wizard', {
            'spellcasting': {
              'mode': 'prepared',
              'prepared': {'5': 9},
            },
          }, priority: 10),
          declaration('zeta:class/wizard', {
            'spellcasting': {
              'prepared': {'5': 13},
            },
          }, priority: 10),
        ],
        disabledOriginIds: const {'zeta'},
        pinnedOrigins: const {'spellcasting.prepared': 'zeta:class/wizard'},
      );
      expect(merged.preparedLimit(5), 13);
      expect(
        merged.sourceOf('spellcasting.prepared')!.originId,
        'zeta:class/wizard',
      );
      expect(
        merged.conflicts.where((c) => c.field == 'spellcasting.prepared'),
        isEmpty,
      );
    });
  });

  // P0-2.4：`RuleOverrideOrder.orderedConflicts` 的**首条优先**（同 field 只留先登记
  // 的那条）。夹具让同一 field 同时出现"真实同 tier 冲突"（更高 tier 的两个包）与
  // "replace 丢弃冲突"（同 tier 的 replace vs 被丢弃 patch）。
  group('同 field 的真实冲突与 replace-drop 冲突：保留先登记的一条（P0-2.4）', () {
    test('真实冲突（更高 tier）先登记 → 保留它，丢弃 replace-drop 那条', () {
      final merged = RuleProfileResolver.resolveClassRules(
        profile: profile,
        slug: 'wizard',
        entryRules: null,
        entryId: null,
        declarations: [
          // tier 200：两个包真冲突，各自声明 spellcasting.prepared。
          declaration('alpha:class/wizard', {
            'spellcasting': {
              'mode': 'prepared',
              'prepared': {'5': 9},
            },
          }, priority: 100),
          declaration('zeta:class/wizard', {
            'spellcasting': {
              'prepared': {'5': 11},
            },
          }, priority: 100),
          // tier 150：replace 独占 + 同 tier patch 被丢弃（也会为同一列登记 drop 冲突）。
          RuleOverrideDeclaration.package(
            originId: 'replacer:class/wizard',
            packageId: 'replacer',
            priority: 50,
            entryId: 'replacer:class/wizard',
            rules: rulesOf({
              'mode': 'replace',
              'spellcasting': {
                'mode': 'prepared',
                'prepared': {'5': 7},
              },
            }),
          ),
          declaration('patch:class/wizard', {
            'spellcasting': {
              'prepared': {'5': 15},
            },
          }, priority: 50),
        ],
      );

      final prepared = merged.conflicts.singleWhere(
        (conflict) => conflict.field == 'spellcasting.prepared',
      );
      expect(
        prepared.tier,
        kEntryTier + 100,
        reason: '真实同 tier 冲突（tier 200）在合并阶段先登记，drop 冲突被去重丢弃',
      );
      expect(prepared.effectiveOriginId, 'alpha:class/wizard');
      expect(prepared.originIds, [
        'alpha:class/wizard',
        'zeta:class/wizard',
      ]);
      // drop 冲突那条确实被生成过（否则本用例测不到"首条优先"）：它若被保留，
      // tier 会是 150 且 originIds 含 patch。
      expect(
        merged.conflicts.where(
          (conflict) => conflict.originIds.contains('patch:class/wizard'),
        ),
        isEmpty,
        reason: '同 field 只留首条：drop 冲突被丢弃',
      );
    });
  });

  // 建议 8：读入侧把 `originIds` 排序 + 去重 + 丢空串（写入侧恒升序的承诺对旧数据
  // 也要成立，且 UI 不该出现空标签）。
  group('RuleOverrideConflict.fromJson 归一化 originIds（建议 8）', () {
    test('乱序 / 重复 / 空串 → 排序 + 去重 + 丢掉空串', () {
      final conflict = RuleOverrideConflict.fromJson(<String, Object?>{
        'field': 'hitDie',
        'tier': 100,
        'originIds': <Object?>['zeta:class/wizard', 'alpha:class/wizard', '', '  ', 'zeta:class/wizard'],
        'effectiveOriginId': 'alpha:class/wizard',
      });
      expect(conflict, isNotNull);
      expect(conflict!.originIds, [
        'alpha:class/wizard',
        'zeta:class/wizard',
      ]);
    });

    test('归一化后不足两个来源 → 降级为"没有冲突"', () {
      expect(
        RuleOverrideConflict.fromJson(<String, Object?>{
          'field': 'hitDie',
          'tier': 100,
          'originIds': <Object?>['alpha:class/wizard', '', 'alpha:class/wizard'],
          'effectiveOriginId': 'alpha:class/wizard',
        }),
        isNull,
        reason: '去重后只剩一个来源，不是冲突',
      );
    });

    test('effectiveOriginId 仍在归一化后的集合里 → 保留（含首尾空白）', () {
      final conflict = RuleOverrideConflict.fromJson(<String, Object?>{
        'field': 'hitDie',
        'tier': 100,
        'originIds': <Object?>[' zeta:class/wizard ', 'alpha:class/wizard'],
        'effectiveOriginId': '  zeta:class/wizard  ',
      });
      expect(conflict, isNotNull);
      expect(conflict!.originIds, [
        'alpha:class/wizard',
        'zeta:class/wizard',
      ]);
      expect(conflict.effectiveOriginId, 'zeta:class/wizard');
    });
  });
}
