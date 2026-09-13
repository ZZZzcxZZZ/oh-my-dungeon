// S3 任务 13：覆盖 / 勘误场景的**端到端**验收（真实导入器 + 真实解析链 + 真实派生）。
//
// 场景（契约 §3.6 / §3.7 / §3.8 + 决策 D2 / D3 / D4 / D6）：
// - `base` 包：自制职业「星界骑士」（对齐键 `astral-knight`，**不命中内置 12 slug**，
//   因此所有数值只能来自包声明），声明 hitDie / savingThrowAbilities / spellcasting
//   （mode + ability + slots + prepared）/ resources；
// - `errata` 包（manifest priority 40）：同对齐键，**只**声明 `spellcasting.prepared`
//   （`classRules.mode: patch`），其余列一律不动；
// - `errata-b` 包（priority 40）：与 `errata` **同 tier** 抢同一列 → 冲突落库；
// - `errata-full` 包（priority 40，`mode: replace`）：独占职业块，未声明的列一律
//   "未声明"（不回退低 tier），且不登记"replace 未声明列"的冲突。
//
// **为什么角色自身条目（`pc` 包）不声明任何列**：`disabledOriginIds` 按设计**不影响
// 角色自己的条目**（见 `RuleProfileResolver.resolveClassRules`："角色自己的条目不是
// '覆盖'，不受这个开关影响"）。要断言规格第 5 条 H 修复的行为（"同时关掉 base+errata
// 后 spellSlots 为空、spellcastingAbility 为 null"），`base` 就**不能**同时是角色自身
// 的条目——否则它永远关不掉，那半条断言无从成立。因此：角色自身条目只提供身份
// （空 `classRules`），base / errata 都是可关闭的包声明。
//
// 全部构造点都经**真实导入器**（`ContentPackageImporter.previewJson`）；`packagePriorities`
// 直接取导入报告的 `priority`（manifest → 报告 → tier 一条链，不手写第二份）。
// 不 mock 任何合并逻辑：列路径一律经 [RuleFieldPath]，不手拼字面量。
//
// 本场景**只在新文件里做**（规格允许并说明理由）：这里的合成包集合
// （base / errata / errata-b / errata-full）与 `homebrew_class_end_to_end_test.dart`
// 的示例包场景没有共用夹具，塞进同一个文件只会让两套夹具互相污染。
//
// **派生快照的新语义（H 修复后）**："未声明"的表现是**键存在但值为空/null**
// （`spellSlots` = `{}`、`spellcastingAbility` = null、`classResources` = `[]`…）；
// 键是否存在只表示"是否已派生"。因此这里**不**断言 `containsKey(...) isFalse`。
import 'dart:convert';

import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/characters/domain/character_rule_overrides.dart';
import 'package:dnd_table_client/src/features/characters/domain/character_rule_projector.dart';
import 'package:dnd_table_client/src/features/characters/domain/character_upgrade_planner.dart';
import 'package:dnd_table_client/src/features/characters/domain/dnd5e_rules.dart';
import 'package:dnd_table_client/src/features/characters/domain/rules_driven_character_builder.dart';
import 'package:dnd_table_client/src/features/content/data/import/content_package_importer.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:dnd_table_client/src/features/content/domain/content_import_report.dart';
import 'package:dnd_table_client/src/features/rules/domain/character_build.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_field_path.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_override_declaration.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_profile.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/content_test_support.dart';

// ── 列路径：一律经 RuleFieldPath（唯一实现），测试里也不手拼 ──
final _modePath = RuleFieldPath.spellcasting('mode');
final _abilityPath = RuleFieldPath.spellcasting('ability');
final _slotsPath = RuleFieldPath.spellcasting('slots');
final _preparedPath = RuleFieldPath.spellcasting('prepared');
final _surgeMaximumPath = RuleFieldPath.resource('surge', 'maximum');
final _surgeNamePath = RuleFieldPath.resource('surge', 'name');
final _surgeRecoveryPath = RuleFieldPath.resource('surge', 'recovery');

// ── 来源 id（对齐键相同、包不同） ──
const _slug = 'astral-knight';
const _pcClassId = 'pc:class/$_slug';
const _baseClassId = 'base:class/$_slug';
const _errataClassId = 'errata:class/$_slug';
const _errataBClassId = 'errata-b:class/$_slug';
const _errataFullClassId = 'errata-full:class/$_slug';

// ── base 声明的数值 ──
const _baseSlotsAt5 = <String, int>{'1': 4, '2': 2};
/// base 的准备上限表（1..20 级，索引 = 等级 − 1）。
const _basePreparedTable = <int>[
  2,
  3,
  4,
  5,
  6,
  7,
  8,
  9,
  10,
  11,
  12,
  13,
  14,
  15,
  16,
  17,
  18,
  19,
  20,
  21,
];

// ── 勘误声明的准备上限（彼此取值不同，否则不构成冲突） ──
const _errataPreparedAt5 = 12;
const _errataBPreparedAt5 = 20;
const _errataFullPreparedAt5 = 8;

const _level = 5;

const _abilities = <String, int>{
  'str': 10,
  'dex': 14,
  'con': 14,
  'int': 12,
  'wis': 12,
  'cha': 16,
};

void main() {
  test('1. base 包声明自制职业：真实导入 + 解析链吃下全部声明列', () async {
    final packages = await _importAll(<_PackageSpec>[
      _pcPackage(),
      _basePackage(),
    ]);
    // 对齐键不命中内置档案：这些数值只可能来自包声明（不是内置 12 slug）。
    expect(
      Dnd5eRules.profile.classRules(_slug),
      isNull,
      reason: '$_slug 不得命中内置档案，否则测不出"包声明真的被解析"',
    );
    // 角色自身条目只提供身份（空 classRules）：导入期只报 warning，不阻断导入。
    expect(packages.reports['pc']!.valid, isTrue);
    expect(packages.reports['pc']!.errors, isEmpty);

    // 导入报告里 base 条目的列级来源就是"这个包 + 内置档案"合并后的结果。
    final declaredByBase = packages.reports['base']!.classRuleSources[_baseClassId]!
        .map((source) => source.field)
        .toSet();
    expect(
      declaredByBase,
      containsAll(<String>[
        RuleFieldPath.hitDie,
        RuleFieldPath.savingThrowAbilities,
        _modePath,
        _abilityPath,
        _slotsPath,
        _preparedPath,
        _surgeNamePath,
        _surgeMaximumPath,
        _surgeRecoveryPath,
      ]),
      reason: 'base 声明的每一列都必须经真实解析链记上来源',
    );

    final data = _buildSheet(packages).dataMap;
    expect(data['hitDie'], 10);
    expect(data['savingThrowAbilities'], unorderedEquals(<String>['wis', 'cha']));
    expect(data['spellSlots'], _baseSlotsAt5);
    expect(data['spellcastingAbility'], 'cha');
    expect(data['preparedSpellLimit'], _basePreparedTable[_level - 1]);
    expect((data['classResources']! as List).single, <String, Object?>{
      'id': 'surge',
      'name': '星界涌动',
      'maximum': _level,
      'recovery': 'shortRestOne',
    });
    expect(_sourceOrigin(data, RuleFieldPath.hitDie), _baseClassId);
    expect(_sourceOrigin(data, _slotsPath), _baseClassId);
    expect(_sourceOrigin(data, _preparedPath), _baseClassId);
    expect(_conflicts(data), isEmpty);
  });

  test('2. errata 只声明 spellcasting.prepared：manifest priority 40 经真实链路生效', () async {
    final packages = await _importAll(<_PackageSpec>[
      _pcPackage(),
      _basePackage(),
      _errataPackage(),
    ]);
    final report = packages.reports['errata']!;
    expect(report.valid, isTrue);
    expect(report.errors, isEmpty, reason: 'warning 不阻断导入，error 才阻断');
    expect(
      report.priority,
      40,
      reason: '包级 priority 必须从 manifest 经真实导入器落进报告',
    );
    expect(packages.priorities['errata'], 40);

    // "只声明 spellcasting.prepared" 的判据：该条目的列级来源**恰好**只有这一列。
    final declared = report.classRuleSources[_errataClassId]!;
    expect(declared.map((source) => source.field).toList(), <String>[
      _preparedPath,
    ]);
    expect(declared.single.originId, _errataClassId);
    expect(
      declared.single.tier,
      kEntryTier + 40,
      reason: 'priority 40 → tier = kEntryTier + 40',
    );
  });

  test('3. 高 tier 勘误只覆盖它声明的列：slots 仍来自 base，且不算冲突', () async {
    final packages = await _importAll(<_PackageSpec>[
      _pcPackage(),
      _basePackage(),
      _errataPackage(),
    ]);
    final data = _buildSheet(packages).dataMap;

    expect(
      data['spellSlots'],
      _baseSlotsAt5,
      reason: '勘误没声明 slots → 该列仍由 base 提供',
    );
    expect(data['preparedSpellLimit'], _errataPreparedAt5);
    expect(data['spellcastingAbility'], 'cha', reason: '勘误没声明 ability');
    expect(_sourceOrigin(data, _preparedPath), _errataClassId);
    expect(_sourceOrigin(data, _slotsPath), _baseClassId);
    expect(
      _conflicts(data),
      isEmpty,
      reason: '不同 tier 是覆盖，不是冲突（D6）',
    );
    expect(
      (data['classResources']! as List),
      hasLength(1),
      reason: '勘误没声明 resources → 资源仍由 base 提供',
    );
  });

  test('4. errata 与 errata-b 同 tier 抢同一列：1 条冲突 + 生效者 = 升序首位', () async {
    final packages = await _importAll(<_PackageSpec>[
      _pcPackage(),
      _basePackage(),
      _errataPackage(),
      _errataBPackage(),
    ]);
    final data = _buildSheet(packages).dataMap;

    final conflicts = _conflicts(data);
    expect(conflicts, hasLength(1));
    final conflict = conflicts.single;
    expect(conflict['field'], _preparedPath);
    expect(conflict['tier'], kEntryTier + 40);
    final originIds = (conflict['originIds']! as List).cast<String>();
    expect(
      originIds,
      <String>[...originIds]..sort(),
      reason: '冲突来源恒按 originId 升序（RuleOverrideOrder.orderedOriginIds）',
    );
    expect(
      originIds,
      <String>[_errataBClassId, _errataClassId],
      reason: '确定性回退：包 id / originId 字典序最小者（errata-b）在前',
    );
    expect(_errataPreparedAt5, isNot(_errataBPreparedAt5));
    expect(
      conflict['effectiveOriginId'],
      originIds.first,
      reason: '无用户选择时生效者 = 排序首位（originId 升序首位）',
    );
    expect(conflict['effectiveOriginId'], _errataBClassId);
    // 每个来源都必须**声明了该列**（0.4 审查项：冲突来源不得凭空出现）。
    for (final originId in originIds) {
      final declared = packages
          .reports[RuleOverrideDeclaration.packageIdOf(originId)]!
          .classRuleSources[originId]!
          .map((source) => source.field)
          .toSet();
      expect(declared, contains(_preparedPath), reason: '$originId 必须声明了冲突列');
    }
    expect(
      data['preparedSpellLimit'],
      _errataBPreparedAt5,
      reason: '生效值取排序首位的 errata-b，而不是 errata 的 $_errataPreparedAt5',
    );
    expect(_sourceOrigin(data, _preparedPath), _errataBClassId);
  });

  test('5. 关闭来源后再派生（含升级路径）：回退 base，快照不残留被关来源旧值（H）', () async {
    final packages = await _importAll(<_PackageSpec>[
      _pcPackage(),
      _basePackage(),
      _errataPackage(),
    ]);
    final built = _buildSheet(packages);
    // 关闭之前：勘误的数值真的生效，否则这条用例没有测到目标。
    expect(built.dataMap['preparedSpellLimit'], _errataPreparedAt5);
    expect(built.dataMap['spellSlots'], _baseSlotsAt5);
    expect(built.dataMap['classResources'], isNotEmpty);

    // 只关 errata（条目 id 命中）→ 覆盖撤回，回退 base。
    final closedErrata = _withOverrides(
      built,
      CharacterRuleOverrides(disabledOriginIds: <String>{_errataClassId}),
    );
    final fallback = _project(closedErrata, packages);
    expect(fallback.dataMap['preparedSpellLimit'], _basePreparedTable[_level - 1]);
    expect(_sourceOrigin(fallback.dataMap, _preparedPath), _baseClassId);
    expect(_sourceOrigin(fallback.dataMap, _slotsPath), _baseClassId);
    expect(fallback.dataMap['spellSlots'], _baseSlotsAt5);
    expect(_conflicts(fallback.dataMap), isEmpty);

    // H：再关掉 base（包 id 命中）→ 所有列都未声明，派生快照必须**显式清空**，
    // 绝不残留被关闭来源的旧数值。
    final closedBoth = _withOverrides(
      built,
      CharacterRuleOverrides(disabledOriginIds: <String>{'base', _errataClassId}),
    );
    final cleared = _project(closedBoth, packages);
    expect(
      cleared.dataMap['spellSlots'],
      isNot(_baseSlotsAt5),
      reason: '被关来源的旧 slots 不得残留',
    );
    _expectClearedDerivedSnapshots(cleared.dataMap);

    // 升级路径：从"关闭前"的角色出发（data 里仍是被关来源的旧数值），
    // 关闭 base+errata 后升级 → 派生快照同样不得残留旧值（H）。
    final closedOverrides = CharacterRuleOverrides.fromCharacter(closedBoth);
    final planner = CharacterUpgradePlanner(
      entries: packages.entries,
      packagePriorities: packages.priorities,
      disabledOriginIds: closedOverrides.disabledOriginIds,
      pinnedOrigins: closedOverrides.pinned,
    );
    final applied = planner.apply(closedBoth, planner.plan(closedBoth));
    expect(applied.level, _level + 1);
    _expectClearedDerivedSnapshots(applied.dataMap);
  });

  test('6. mode: replace 的 errata-full：其余列未声明，且不登记未声明列的冲突', () async {
    // errata-b 额外声明 hitDie：它是与 replace **同 tier** 的反例来源——
    // "replace 未声明的列不登记冲突"（只对 replace 也声明了的列登记）必须靠它测出来。
    final packages = await _importAll(<_PackageSpec>[
      _pcPackage(),
      _basePackage(),
      _errataPackage(),
      _errataBPackage(),
      _errataFullPackage(),
    ]);
    final data = _buildSheet(packages).dataMap;

    // 生效的只有 replace 自己声明的列。
    expect(data['spellcastingAbility'], 'cha');
    expect(data['preparedSpellLimit'], _errataFullPreparedAt5);
    expect(_sourceOrigin(data, _preparedPath), _errataFullClassId);

    // replace 未声明的列一律"未声明"：**键存在**（已派生）+ 值为空 / null，
    // 绝不回退低 tier 的 base / errata（H 修复后的快照语义）。
    expect(data.containsKey('hitDie'), isTrue, reason: '键存在 = 已派生');
    expect(data['hitDie'], isNull, reason: 'replace 未声明 hitDie → null');
    expect(data.containsKey('savingThrowAbilities'), isTrue);
    expect(data['savingThrowAbilities'], isEmpty);
    expect(data.containsKey('spellSlots'), isTrue);
    expect(data['spellSlots'], isEmpty);
    expect(data.containsKey('classResources'), isTrue);
    expect(data['classResources'], isEmpty);
    expect(data.containsKey('actions'), isTrue);
    expect(data['actions'], isEmpty);
    for (final field in <String>[
      RuleFieldPath.hitDie,
      RuleFieldPath.savingThrowAbilities,
      _slotsPath,
      _surgeMaximumPath,
    ]) {
      expect(
        _sourceOrigin(data, field),
        isNull,
        reason: '$field 未被 replace 声明 → 没有任何来源',
      );
    }

    // 冲突只登记"replace 也声明了的列"：hitDie 被同 tier 的 errata-b 声明过，
    // 但 replace 没声明它 → 不得登记；prepared 两边都声明 → 必须登记。
    final conflicts = _conflicts(data);
    expect(
      <Object?>[for (final conflict in conflicts) conflict['field']],
      <Object?>[_preparedPath],
    );
    final conflict = conflicts.single;
    expect(
      conflict['originIds'],
      <String>[_errataBClassId, _errataFullClassId, _errataClassId],
      reason: '同 tier 的被截断来源进冲突；差 tier 的 base 不算冲突（D4）',
    );
    expect(conflict['effectiveOriginId'], _errataFullClassId);
  });

  test('7. 恢复路径：清空 disabledOriginIds 再派生，数值与来源回到第 3 条状态且幂等', () async {
    final packages = await _importAll(<_PackageSpec>[
      _pcPackage(),
      _basePackage(),
      _errataPackage(),
    ]);
    final built = _buildSheet(packages);
    final baseline = built.dataMap;

    final closed = _withOverrides(
      built,
      CharacterRuleOverrides(disabledOriginIds: <String>{_errataClassId}),
    );
    final fallback = _project(closed, packages);
    expect(fallback.dataMap['preparedSpellLimit'], _basePreparedTable[_level - 1]);

    // 恢复：用 CharacterRuleOverrides.enable 撤掉关闭记录（条目 id / 包 id 都认）。
    final restoredOverrides = CharacterRuleOverrides.fromCharacter(
      fallback,
    ).enable(_errataClassId);
    expect(restoredOverrides.disabledOriginIds, isEmpty);
    final restored = _project(_withOverrides(fallback, restoredOverrides), packages);

    expect(restored.dataMap['preparedSpellLimit'], baseline['preparedSpellLimit']);
    expect(restored.dataMap['spellSlots'], baseline['spellSlots']);
    expect(
      restored.dataMap['spellcastingAbility'],
      baseline['spellcastingAbility'],
    );
    expect(_sourceOrigin(restored.dataMap, _preparedPath), _errataClassId);
    expect(_sourceOrigin(restored.dataMap, _slotsPath), _baseClassId);
    expect(_conflicts(restored.dataMap), isEmpty);

    // 幂等：同一份输入再派生一次，派生结果逐字不变。
    final again = _project(restored, packages);
    expect(again.dataMap, restored.dataMap);
  });
}

// ── 断言辅助 ──

/// "未声明"的新语义（H 修复后）：**键存在**（= 已派生）且值为空 / null。
/// 判定"未声明"用"值为空/null"，判定"是否已派生"用"键存在"。
void _expectClearedDerivedSnapshots(Map<String, Object?> data) {
  expect(data.containsKey('spellSlots'), isTrue, reason: '键存在 = 已派生');
  expect(data['spellSlots'], isEmpty, reason: '未声明法术位 = 空表，不得回退旧值');
  expect(data.containsKey('spellcastingAbility'), isTrue);
  expect(data['spellcastingAbility'], isNull);
  expect(data.containsKey('preparedSpellLimit'), isTrue);
  expect(data['preparedSpellLimit'], isNull);
  expect(data.containsKey('classResources'), isTrue);
  expect(data['classResources'], isEmpty);
  expect(data.containsKey('actions'), isTrue, reason: '键存在 = 已派生');
  expect(data['actions'], isEmpty);
  expect(data['hitDie'], isNull);
  expect(data['savingThrowAbilities'], isEmpty);
  expect(data['classRuleSources'], isEmpty, reason: '没有任何来源生效 → 来源表为空');
  expect(data['classRuleConflicts'], isEmpty);
}

String? _sourceOrigin(Map<String, Object?> data, String field) {
  final sources = data['classRuleSources'];
  final row = sources is Map ? sources[field] : null;
  return row is Map ? '${row['originId']}' : null;
}

List<Map<String, Object?>> _conflicts(Map<String, Object?> data) => <Map<String, Object?>>[
  for (final row in (data['classRuleConflicts'] as List? ?? const <Object?>[]))
    Map<String, Object?>.from(row as Map),
];

/// 用真实 [RulesDrivenCharacterBuilder] 建角色（构造点与生产同口径：三项状态全传）。
CharacterSheet _buildSheet(_ImportedPackages packages, {int level = _level}) {
  final draft = RulesDrivenCharacterBuilder(
    entries: packages.entries,
    packagePriorities: packages.priorities,
    disabledOriginIds: const <String>{},
    pinnedOrigins: const <String, String>{},
  ).build(
    name: '星界试炼者',
    build: CharacterBuild(
      level: level,
      selections: const <String, String>{'class': _pcClassId},
    ),
    abilities: _abilities,
  );
  return draft.toLocalCharacter();
}

/// 写回用户的覆盖选择：形状归一化的唯一实现是 [CharacterRuleOverrides.toData]。
CharacterSheet _withOverrides(
  CharacterSheet character,
  CharacterRuleOverrides overrides,
) => character.copyWith(
  data: <String, Object?>{...character.dataMap, 'ruleOverrides': overrides.toData()},
);

/// 再派生：[CharacterRuleProjector] 的 `disabledOriginIds` / `pinned` 按生产口径
/// **从角色数据读**（构造点只收 `entries` + `packagePriorities`）。
CharacterSheet _project(CharacterSheet character, _ImportedPackages packages) =>
    CharacterRuleProjector(
      entries: packages.entries,
      packagePriorities: packages.priorities,
    ).project(character);

// ── 真实导入器夹具 ──

typedef _PackageSpec =
    ({String id, int priority, List<Map<String, Object?>> entries});

class _ImportedPackages {
  _ImportedPackages({
    required this.entries,
    required this.priorities,
    required this.reports,
  });

  final Map<String, ContentEntry> entries;

  /// 包 id → priority，直接取导入报告的 `priority`（manifest → 报告 → tier）。
  final Map<String, int> priorities;

  /// 包 id → 导入报告（列级来源与 warning/error 都从真实导入链路来）。
  final Map<String, ContentImportReport> reports;
}

Future<_ImportedPackages> _importAll(List<_PackageSpec> packages) async {
  final entries = <String, ContentEntry>{};
  final priorities = <String, int>{};
  final reports = <String, ContentImportReport>{};
  for (final package in packages) {
    final report = await ContentPackageImporter(MemoryContentRepository())
        .previewJson(
          jsonEncode(<String, Object?>{
            'formatVersion': 3,
            'id': package.id,
            'name': package.id,
            'version': '1.0.0',
            'locale': 'zh-CN',
            'system': 'dnd5e-2024',
            'priority': package.priority,
            'entryCount': package.entries.length,
            'entries': package.entries,
          }),
        );
    expect(
      report.valid,
      isTrue,
      reason: [
        for (final error in report.errors) '${error.path}: ${error.message}',
      ].join('; '),
    );
    expect(report.errors, isEmpty);
    expect(report.priority, package.priority);
    entries.addAll(<String, ContentEntry>{
      for (final entry in report.entries) entry.id: entry,
    });
    priorities[package.id] = report.priority;
    reports[package.id] = report;
  }
  return _ImportedPackages(
    entries: entries,
    priorities: priorities,
    reports: reports,
  );
}

Map<String, Object?> _classEntryJson({
  required String packageId,
  Map<String, Object?> classRules = const <String, Object?>{},
  Map<String, Object?>? rules,
}) {
  final json = <String, Object?>{
    'id': '$packageId:class/$_slug',
    'type': 'class',
    'slug': _slug,
    'name': '星界骑士（$packageId）',
    'body': <Object?>[],
    'revision': 1,
    'structured': <String, Object?>{'classRules': classRules},
  };
  if (rules != null) json['rules'] = rules;
  return json;
}

/// 角色自身条目：**只提供身份**，不声明任何列（见文件头的理由）。
_PackageSpec _pcPackage() => (
  id: 'pc',
  priority: 0,
  entries: <Map<String, Object?>>[_classEntryJson(packageId: 'pc')],
);

_PackageSpec _basePackage() => (
  id: 'base',
  priority: 0,
  entries: <Map<String, Object?>>[
    _classEntryJson(packageId: 'base', classRules: _baseClassRules()),
  ],
);

/// base 的职业规则：生命骰 / 豁免 / 施法（mode + ability + slots + prepared）/ 资源。
Map<String, Object?> _baseClassRules() => <String, Object?>{
  'hitDie': 10,
  'savingThrowAbilities': <String>['wis', 'cha'],
  'spellcasting': <String, Object?>{
    'mode': 'prepared',
    'ability': 'cha',
    'slots': <String, Object?>{'$_level': _baseSlotsAt5},
    'prepared': _basePreparedTable,
  },
  'resources': <Map<String, Object?>>[
    <String, Object?>{
      'id': 'surge',
      'name': '星界涌动',
      'recovery': 'shortRestOne',
      'maximum': <String, Object?>{'formula': 'level'},
    },
  ],
};

/// `errata`：只声明 `spellcasting.prepared` 的补丁条目（缺省 merge mode 就是 patch，
/// 这里显式写出来，避免"抄错位置写成 spellcasting.mode"的歧义）。
_PackageSpec _errataPackage() => (
  id: 'errata',
  priority: 40,
  entries: <Map<String, Object?>>[
    _classEntryJson(
      packageId: 'errata',
      classRules: <String, Object?>{
        'mode': 'patch',
        'spellcasting': <String, Object?>{
          'prepared': <String, Object?>{'$_level': _errataPreparedAt5},
        },
      },
    ),
  ],
);

/// `errata-b`：与 `errata` 同 priority 40、抢同一列 `spellcasting.prepared`。
///
/// 额外声明 `hitDie` 是**故意的**：第 6 条要测"replace 未声明列的冲突不登记"，
/// 需要一个与 replace **同 tier**、且声明了 replace **未声明列**的反例来源。
_PackageSpec _errataBPackage() => (
  id: 'errata-b',
  priority: 40,
  entries: <Map<String, Object?>>[
    _classEntryJson(
      packageId: 'errata-b',
      classRules: <String, Object?>{
        'mode': 'patch',
        'hitDie': 12,
        'spellcasting': <String, Object?>{
          'prepared': <String, Object?>{'$_level': _errataBPreparedAt5},
        },
      },
    ),
  ],
);

/// `errata-full`：`mode: replace` 独占职业块。
///
/// 它必须同时声明 `spellcasting.mode` + `ability`——`mode` 未声明会落成 `none`，
/// 而 `ResolvedClassRules.preparedLimit` 在 `mode == none` 时一律返回 null
/// （§3.3）：那样 `prepared` 这一列就算声明了也永远不生效，测不到 replace 的语义。
_PackageSpec _errataFullPackage() => (
  id: 'errata-full',
  priority: 40,
  entries: <Map<String, Object?>>[
    _classEntryJson(
      packageId: 'errata-full',
      classRules: <String, Object?>{
        'mode': 'replace',
        'spellcasting': <String, Object?>{
          'mode': 'prepared',
          'ability': 'cha',
          'prepared': <String, Object?>{'$_level': _errataFullPreparedAt5},
        },
      },
    ),
  ],
);
