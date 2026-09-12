// 重提取私有包（formatVersion 3）的**金标校验**。
//
// **私有包不存在时不校验**：`private-imports/` 被 Git 忽略，裸检出必须能跑，
// 因此读不到 bundle 时只注册一个显式 skip 占位并 `return`（与
// `test/tooling/private_content_package_validation_test.dart` 的私有路径约定一致）。
//
// oracle 数值全部是**独立字面量**（来自内置档案 / SRD 5.2 官方表，见
// `docs/plans/2026-09-10-rules-contract-core.md` 任务 10b 的 oracle 表），
// **不从生产常量派生**——否则提取器与测试会一起错。
import 'dart:convert';
import 'dart:io';

import 'package:dnd_table_client/src/features/characters/domain/dnd5e_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// 相对 `apps/client_flutter`（`flutter test` 的工作目录）的私有包路径。
const _bundlePath = '../../private-imports/phb-2024-v2-bundle.json';

const _levels = <int>[1, 5, 11, 20];

/// 全施法者原型（诗人 / 牧师 / 德鲁伊 / 术士 / 法师）的法术位。
const _fullCasterSlots = <int, Map<String, int>>{
  1: {'1': 2},
  5: {'1': 4, '2': 3, '3': 2},
  11: {'1': 4, '2': 3, '3': 3, '4': 3, '5': 2, '6': 1},
  20: {
    '1': 4,
    '2': 3,
    '3': 3,
    '4': 3,
    '5': 3,
    '6': 2,
    '7': 2,
    '8': 1,
    '9': 1,
  },
};

/// 半施法者原型（圣武士 / 游侠）的法术位。
const _halfCasterSlots = <int, Map<String, int>>{
  1: {'1': 2},
  5: {'1': 4, '2': 2},
  11: {'1': 4, '2': 3, '3': 3},
  20: {'1': 4, '2': 3, '3': 3, '4': 3, '5': 2},
};

/// 契约魔法（邪术师）：展开后的键是**环阶**（由 `slotLevel` 决定）。
const _pactSlots = <int, Map<String, int>>{
  1: {'1': 1},
  5: {'3': 2},
  11: {'5': 3},
  20: {'5': 4},
};

const _noSlots = <int, Map<String, int>>{1: {}, 5: {}, 11: {}, 20: {}};

const _classSlots = <String, Map<int, Map<String, int>>>{
  'barbarian': _noSlots,
  'fighter': _noSlots,
  'monk': _noSlots,
  'rogue': _noSlots,
  'bard': _fullCasterSlots,
  'cleric': _fullCasterSlots,
  'druid': _fullCasterSlots,
  'sorcerer': _fullCasterSlots,
  'wizard': _fullCasterSlots,
  'paladin': _halfCasterSlots,
  'ranger': _halfCasterSlots,
  'warlock': _pactSlots,
};

const _preparedLimit = <String, Map<int, int?>>{
  'bard': {1: 4, 5: 9, 11: 16, 20: 22},
  'cleric': {1: 4, 5: 9, 11: 16, 20: 22},
  'druid': {1: 4, 5: 9, 11: 16, 20: 22},
  'sorcerer': {1: 2, 5: 9, 11: 16, 20: 22},
  'wizard': {1: 4, 5: 9, 11: 16, 20: 25},
  'warlock': {1: 2, 5: 6, 11: 11, 20: 15},
  'paladin': {1: 2, 5: 6, 11: 10, 20: 15},
  'ranger': {1: 2, 5: 6, 11: 10, 20: 15},
  'barbarian': {1: null, 5: null, 11: null, 20: null},
  'fighter': {1: null, 5: null, 11: null, 20: null},
  'monk': {1: null, 5: null, 11: null, 20: null},
  'rogue': {1: null, 5: null, 11: null, 20: null},
};

const _cantripLimit = <String, Map<int, int?>>{
  'wizard': {1: 3, 5: 4, 11: 5, 20: 5},
  'cleric': {1: 3, 5: 4, 11: 5, 20: 5},
  'sorcerer': {1: 4, 5: 5, 11: 6, 20: 6},
  'bard': {1: 2, 5: 3, 11: 4, 20: 4},
  'druid': {1: 2, 5: 3, 11: 4, 20: 4},
  'warlock': {1: 2, 5: 3, 11: 4, 20: 4},
  // 圣武士 / 游侠显式声明戏法上限 0：是"已声明 0"，不是"未声明"。
  'paladin': {1: 0, 5: 0, 11: 0, 20: 0},
  'ranger': {1: 0, 5: 0, 11: 0, 20: 0},
  'barbarian': {1: null, 5: null, 11: null, 20: null},
  'fighter': {1: null, 5: null, 11: null, 20: null},
  'monk': {1: null, 5: null, 11: null, 20: null},
  'rogue': {1: null, 5: null, 11: null, 20: null},
};

const _maxSpellLevel = <String, Map<int, int?>>{
  'barbarian': {1: null, 5: null, 11: null, 20: null},
  'fighter': {1: null, 5: null, 11: null, 20: null},
  'monk': {1: null, 5: null, 11: null, 20: null},
  'rogue': {1: null, 5: null, 11: null, 20: null},
  'bard': {1: 1, 5: 3, 11: 6, 20: 9},
  'cleric': {1: 1, 5: 3, 11: 6, 20: 9},
  'druid': {1: 1, 5: 3, 11: 6, 20: 9},
  'sorcerer': {1: 1, 5: 3, 11: 6, 20: 9},
  'wizard': {1: 1, 5: 3, 11: 6, 20: 9},
  'paladin': {1: 1, 5: 2, 11: 3, 20: 5},
  'ranger': {1: 1, 5: 2, 11: 3, 20: 5},
  'warlock': {1: 1, 5: 3, 11: 5, 20: 5},
};

const _hitDie = <String, int>{
  'barbarian': 12,
  'fighter': 10,
  'paladin': 10,
  'ranger': 10,
  'bard': 8,
  'cleric': 8,
  'druid': 8,
  'monk': 8,
  'rogue': 8,
  'warlock': 8,
  'sorcerer': 6,
  'wizard': 6,
};

/// 旧契约的顶层键：新契约下这些一律不得出现在职业条目的 `structured` 里。
const _removedTopLevelKeys = <String>[
  'hitDie',
  'savingThrows',
  'skills',
  'spellcastingAbility',
  'spellcasting',
];

void main() {
  final bundleFile = File(_bundlePath);
  if (!bundleFile.existsSync()) {
    // 私有包不存在时不校验（裸检出必须能跑）：显式 skip 占位，避免"零用例"。
    test(
      '私有重提取 bundle 不存在，跳过金标校验',
      () {},
      skip: '未找到 $_bundlePath（私有包被 Git 忽略）',
    );
    return;
  }

  final bundle =
      jsonDecode(bundleFile.readAsStringSync()) as Map<String, Object?>;
  final entries = (bundle['entries'] as List)
      .cast<Map<String, Object?>>()
      .toList(growable: false);
  final classes = entries
      .where((entry) => entry['type'] == 'class')
      .toList(growable: false);
  final classBySlug = <String, Map<String, Object?>>{
    for (final entry in classes)
      (entry['id']! as String).split('/').last: entry,
  };

  Map<String, Object?> structuredOf(Map<String, Object?> entry) =>
      (entry['structured'] as Map).cast<String, Object?>();

  test('bundle 是 formatVersion 3，12 条职业条目全部是新契约形状', () {
    expect(bundle['formatVersion'], 3);
    expect(classes, hasLength(12));
    // 12 条必须**全部**落到 oracle 覆盖的 slug 上，避免过滤条件写错只验了少数几条。
    expect(classBySlug.keys.toSet(), _hitDie.keys.toSet());

    for (final entry in classes) {
      final id = entry['id']! as String;
      final structured = structuredOf(entry);
      for (final key in _removedTopLevelKeys) {
        expect(
          structured.containsKey(key),
          isFalse,
          reason: '$id 仍带旧顶层键 structured.$key',
        );
      }
      expect(
        structured['classRules'],
        isA<Map>(),
        reason: '$id 缺少 structured.classRules',
      );

      final rules = entry['rules'] as Map?;
      expect(rules, isNotNull, reason: '$id 缺少 rules');
      final progression = (rules!['progression'] as List?) ?? const [];
      expect(progression, isNotEmpty, reason: '$id 缺少 progression');
      for (final step in progression.cast<Map>()) {
        expect(
          step.keys,
          contains('levels'),
          reason: '$id 的 progression 步骤缺少 levels 键',
        );
        expect(
          step.containsKey('level'),
          isFalse,
          reason: '$id 的 progression 步骤仍有单数 level 旧键',
        );
      }
    }
  });

  test('抽样等级 1/5/11/20 的法术位与官方表逐项一致（独立 oracle）', () {
    for (final slug in _hitDie.keys) {
      final entry = classBySlug[slug]!;
      final rules = Dnd5eRules.resolveClassRules(
        entryId: entry['id']! as String,
        classSummary: entry['name']! as String,
        structured: structuredOf(entry),
      );

      for (final level in _levels) {
        expect(
          rules.spellSlots(level),
          _classSlots[slug]![level],
          reason: '$slug L$level 法术位',
        );
        expect(
          rules.preparedLimit(level),
          _preparedLimit[slug]![level],
          reason: '$slug L$level 准备法术上限',
        );
        expect(
          rules.cantripLimit(level),
          _cantripLimit[slug]![level],
          reason: '$slug L$level 戏法上限',
        );
        expect(
          rules.maxSpellLevel(level),
          _maxSpellLevel[slug]![level],
          reason: '$slug L$level 最高环阶',
        );
      }
    }
  });

  test('12 条职业的生命骰与契约魔法判据命中 oracle', () {
    for (final slug in _hitDie.keys) {
      final entry = classBySlug[slug]!;
      final rules = Dnd5eRules.resolveClassRules(
        entryId: entry['id']! as String,
        classSummary: entry['name']! as String,
        structured: structuredOf(entry),
      );
      expect(rules.hitDie, _hitDie[slug], reason: '$slug 生命骰');
      expect(
        rules.usesPactMagic,
        slug == 'warlock',
        reason: '$slug 是否使用契约魔法',
      );
    }
  });

  test('重提取产物的长弓派生攻击属性是 dex', () {
    final longbow = entries.firstWhere(
      (entry) => entry['id'] == 'phb-2024:equipment/longbow',
    );
    expect(
      Dnd5eRules.weaponAbility(structuredOf(longbow)),
      'dex',
      reason: '长弓的 properties 写「弹药（射程 150/600；箭矢）」+ ability: dex',
    );
  });
}
