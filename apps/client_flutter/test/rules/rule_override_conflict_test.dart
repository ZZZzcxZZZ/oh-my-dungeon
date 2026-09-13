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
import 'package:dnd_table_client/src/features/rules/domain/rule_override_conflict.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_override_declaration.dart';
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
    test('被同 tier replace 丢弃的 patch：每一列都有一条可见冲突', () {
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

      // replace 独占：patch 的列一个都不生效。
      expect(merged.hitDie, 10);
      expect(merged.preparedLimit(5), isNull);
      // 但被丢弃这件事可见：patch 声明过的每一列都有冲突记录，生效者 = replace。
      final fields = merged.conflicts.map((c) => c.field).toList();
      expect(fields, contains('hitDie'));
      expect(fields, contains('spellcasting.prepared'));
      for (final conflict in merged.conflicts) {
        expect(conflict.effectiveOriginId, 'replacer:class/wizard');
        expect(conflict.originIds, contains('patch:class/wizard'));
      }
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
}
