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
const _defaultBundlePath = '../../private-imports/phb-2024-v2-bundle.json';

/// 覆盖私有包路径（`flutter test --dart-define=CONTENT_PACKAGE_PATH=...`），
/// 与 `test/tooling/private_content_package_validation_test.dart` 同名同义。
const _bundlePathOverride = String.fromEnvironment('CONTENT_PACKAGE_PATH');

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

/// 战士 / 野蛮人的职业资源上限（§6.2 oracle；数值来自内置档案 / 官方表，不从生产
/// 代码派生）：等级 → {资源 id: 上限}。`startsAtLevel` 之前的等级整条不出现。
const _resources = <String, Map<int, Map<String, int>>>{
  'barbarian': {
    1: {'rage': 2},
    5: {'rage': 3},
    11: {'rage': 4},
    20: {'rage': 6},
  },
  'fighter': {
    1: {'second_wind': 2},
    5: {'second_wind': 3, 'action_surge': 1},
    11: {'second_wind': 4, 'action_surge': 1},
    20: {'second_wind': 4, 'action_surge': 2},
  },
};

/// 战士 / 野蛮人资源的恢复语义（§6.2 oracle）。
const _resourceRecovery = <String, Map<String, String>>{
  'barbarian': {'rage': 'shortRestOne'},
  'fighter': {'second_wind': 'shortRestOne', 'action_surge': 'shortRest'},
};

const _hitDie = <String, int>{'barbarian': 12,
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
  final bundlePath = _bundlePathOverride.isEmpty
      ? _defaultBundlePath
      : _bundlePathOverride;
  final bundleFile = File(bundlePath);
  if (!bundleFile.existsSync()) {
    // `private-imports/` 被 Git 忽略，裸检出必须能跑，所以路径不存在时只注册
    // 显式 skip。但"文件不存在"与"被改名 / 重提取成别的文件名"必须分得开：
    // 目录里只要还有别的 bundle（或用户显式指定了 CONTENT_PACKAGE_PATH），
    // 静默绿就是假绿——直接 fail 说清"预期哪条路径不存在"。
    final overrideProvided = _bundlePathOverride.isNotEmpty;
    final privateImports = Directory('../../private-imports');
    final siblingBundles =
        privateImports.existsSync()
            ? privateImports
                  .listSync()
                  .whereType<File>()
                  .map((file) => file.path)
                  .where((path) => path.endsWith('bundle.json'))
                  .toList(growable: false)
            : const <String>[];
    if (overrideProvided || siblingBundles.isNotEmpty) {
      test('私有重提取 bundle 路径必须精确存在（不得被改名后静默跳过）', () {
        fail(
          '预期路径不存在：$bundlePath'
          '${overrideProvided ? '（来自 CONTENT_PACKAGE_PATH）' : ''}；'
          'private-imports/ 里现有 bundle：'
          '${siblingBundles.isEmpty ? '（无）' : siblingBundles.join('、')}。'
          '请核对文件是否被改名/重提取，或用 '
          '--dart-define=CONTENT_PACKAGE_PATH=<path> 指定正确路径。',
        );
      });
      return;
    }
    test(
      '私有重提取 bundle 不存在，跳过金标校验',
      () {},
      skip: '未找到 $bundlePath（私有包被 Git 忽略）',
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

  test('职业特性用 featureOf 关系挂回宿主（资料库职业页据此列特性）', () {
    // 客户端 `content_detail_page` 按 `relations[].type == 'featureOf'` 过滤职业特性列表；
    // 只写 `structured.featureOf` 这类元数据的话，职业页的特性列表会是空的。
    const deadMetadataKeys = {'featureOf', 'classSlug', 'subclassName', 'levelLabel'};
    for (final entry in entries) {
      final structured = structuredOf(entry);
      expect(
        structured.keys.toSet().intersection(deadMetadataKeys),
        isEmpty,
        reason: '${entry['id']} 仍输出无读者的元数据',
      );
    }

    final entryIds = entries.map((entry) => entry['id']! as String).toSet();
    final features = entries
        .where((entry) => entry['type'] == 'classFeature')
        .toList();
    expect(features, isNotEmpty);

    final linkedTargets = <String>{};
    for (final feature in features) {
      final targets = ((feature['relations'] as List?) ?? const [])
          .cast<Map>()
          .where((relation) => relation['type'] == 'featureOf')
          .map((relation) => relation['targetId']! as String)
          .toList();
      expect(
        targets,
        hasLength(1),
        reason: '${feature['id']} 必须恰好有一条 featureOf 关系，实际 $targets',
      );
      expect(
        entryIds,
        contains(targets.single),
        reason: '${feature['id']} 的 featureOf 目标不存在',
      );
      linkedTargets.add(targets.single);
    }

    final classIds = classes.map((entry) => entry['id']! as String).toSet();
    expect(
      classIds.difference(linkedTargets),
      isEmpty,
      reason: '下列职业没有任何特性挂在它下面',
    );
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

  test('抽样等级的战士 / 野蛮人资源次数与恢复语义命中 oracle（§6.2）', () {
    for (final slug in _resources.keys) {
      final entry = classBySlug[slug]!;
      final rules = Dnd5eRules.resolveClassRules(
        entryId: entry['id']! as String,
        classSummary: entry['name']! as String,
        structured: structuredOf(entry),
      );
      for (final level in _levels) {
        final actual = <String, int>{
          for (final resource in rules.resourcesAt(level, const {}))
            resource.id: resource.maximum,
        };
        expect(actual, _resources[slug]![level], reason: '$slug L$level 资源次数');
      }
      for (final expectation in _resourceRecovery[slug]!.entries) {
        final resource = rules.resources.singleWhere(
          (candidate) => candidate.id == expectation.key,
        );
        expect(
          resource.recoveryAt(5),
          expectation.value,
          reason: '$slug ${expectation.key} 的恢复语义',
        );
      }
    }
  });

  test('真实私包条目上的资源列级合并：勘误只改 recovery 与 20 级上限，其余仍来自档案', () {
    // 以真实 bundle 的 barbarian 条目为底（其 `classRules` 不写 resources，数值全由
    // 内置档案提供），再叠一条"勘误式"资源声明：只写 recovery 与 20 级的 maximum。
    // 1..19 级的上限、name、startsAtLevel 必须原样来自档案，不得整条消失。
    final base = structuredOf(classBySlug['barbarian']!);
    final classRules = Map<String, Object?>.from(base['classRules']! as Map);
    classRules['resources'] = [
      {
        'id': 'rage',
        'recovery': 'longRest',
        'maximum': {
          'table': {'20': 7},
        },
      },
    ];
    final rules = Dnd5eRules.resolveClassRules(
      entryId: classBySlug['barbarian']!['id']! as String,
      classSummary: classBySlug['barbarian']!['name']! as String,
      structured: {...base, 'classRules': classRules},
    );

    expect(rules.resources.map((resource) => resource.id), ['rage']);
    expect(rules.resources.single.name, '狂暴', reason: 'name 由档案补齐');
    expect(rules.resourcesAt(1, const {}).single.maximum, 2, reason: '1 级上限来自档案');
    expect(rules.resourcesAt(5, const {}).single.maximum, 3, reason: '5 级上限来自档案');
    expect(rules.resourcesAt(11, const {}).single.maximum, 4, reason: '11 级上限来自档案');
    expect(
      rules.resourcesAt(20, const {}).single.maximum,
      7,
      reason: '20 级由勘误表负责',
    );
    expect(
      rules.resourcesAt(20, const {}).single.recovery,
      'longRest',
      reason: 'recovery 整列由勘误声明负责',
    );
  });
}
