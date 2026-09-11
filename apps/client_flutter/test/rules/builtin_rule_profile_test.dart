// 内置规则档案（tier 0）资产测试：读资产 JSON，逐项对照 SRD 5.2 官方表核算。
//
// 只校验档案本身的 schema 与数值，不涉及解析器（见任务 2+）。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `flutter test` 的工作目录是包根，因此直接读文件而不用 `rootBundle`。
Map<String, Object?> readArchive() =>
    jsonDecode(File('assets/rules/dnd5e-2024.rules.json').readAsStringSync())
        as Map<String, Object?>;

Map<String, Object?> classRules(Map<String, Object?> classes, String slug) =>
    classes[slug]! as Map<String, Object?>;

/// 资源池里按 id 取一条资源（同职业内 id 唯一）。
Map<String, Object?> resource(
  Map<String, Object?> classes,
  String slug,
  String id,
) {
  final list = classRules(classes, slug)['resources']! as List;
  return list
      .cast<Map<Object?, Object?>>()
      .firstWhere((item) => item['id'] == id,
          orElse: () => fail('缺少资源 $slug.$id'))
      .cast<String, Object?>();
}

/// 单职业期望记录（SRD 5.2 官方表）。
///
/// 新增一个核心职业 = 档案加一段 + 本表加一条；职业键校验、施法模型、
/// prepared/cantrips、资源覆盖都由本表派生，不需要在 6 处同步改。
class ClassExpectation {
  const ClassExpectation({
    required this.hitDie,
    required this.saves,
    required this.resourceIds,
    this.mode,
    this.ability,
    this.archetype,
    this.prepared,
    this.cantrips,
  });

  final int hitDie;

  /// 豁免熟练。数据侧统一按 `abilities` 顺序书写；断言按**集合**比较，
  /// 不把书写顺序当成语义。
  final List<String> saves;

  /// 该职业的资源 id（无资源则为空列表）。
  final List<String> resourceIds;

  /// 非施法者为 null（档案里是 `{"mode": "none"}`）。
  final String? mode;
  final String? ability;
  final String? archetype;

  /// 逐职业的 20 项表；非施法者为 null。
  final List<int>? prepared;
  final List<int>? cantrips;

  bool get isCaster => mode != null;
}

// ---- SRD 5.2 逐职业表（字面量；prepared / cantrips 永远是职业自己的字段） ----

/// 吟游诗人 / 牧师 / 德鲁伊共用同一张“准备法术”表。
const divinePrepared = [
  4, 5, 6, 7, 9, 10, 11, 12, 14, 15, 16, 16, 17, 17, 18, 18, 19, 20, 21, 22,
];

/// 吟游诗人 / 德鲁伊 / 邪术师的戏法表（1 级 2 个）。
const twoStartCantrips = [
  2, 2, 2, 3, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
];

/// 牧师 / 法师的戏法表（1 级 3 个）。
const clericalCantrips = [
  3, 3, 3, 4, 4, 4, 4, 4, 4, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5,
];

/// 术士 1 级只要 2 个准备法术（与牧师/德鲁伊的 4 不同）。
const sorcererPrepared = [
  2, 4, 6, 7, 9, 10, 11, 12, 14, 15, 16, 16, 17, 17, 18, 18, 19, 20, 21, 22,
];

const sorcererCantrips = [
  4, 4, 4, 5, 5, 5, 5, 5, 5, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
];

/// 法师 20 级要 25 个准备法术（原型共用的 22 会静默改数值）。
const wizardPrepared = [
  4, 5, 6, 7, 9, 10, 11, 12, 14, 15, 16, 16, 17, 18, 19, 21, 22, 23, 24, 25,
];

/// 圣武士 / 游侠共用（半施法者）。
const halfCasterPrepared = [
  2, 3, 4, 5, 6, 6, 7, 7, 9, 9, 10, 10, 11, 11, 12, 12, 14, 14, 15, 15,
];

const warlockPrepared = [
  2, 3, 4, 5, 6, 7, 8, 9, 10, 10, 11, 11, 12, 12, 13, 13, 14, 14, 15, 15,
];

/// 半施法者没有戏法（2024 官方表为 0）。
const noCantrips = [
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
];

/// 每职业一条：hitDie / saves / 施法模型 / prepared+cantrips / 资源 id。
const classExpectations = <String, ClassExpectation>{
  'barbarian': ClassExpectation(
    hitDie: 12,
    saves: ['str', 'con'],
    resourceIds: ['rage'],
  ),
  'bard': ClassExpectation(
    hitDie: 8,
    saves: ['dex', 'cha'],
    resourceIds: ['bardic_inspiration'],
    mode: 'prepared',
    ability: 'cha',
    archetype: 'full-caster',
    prepared: divinePrepared,
    cantrips: twoStartCantrips,
  ),
  'cleric': ClassExpectation(
    hitDie: 8,
    saves: ['wis', 'cha'],
    resourceIds: ['channel_divinity'],
    mode: 'prepared',
    ability: 'wis',
    archetype: 'full-caster',
    prepared: divinePrepared,
    cantrips: clericalCantrips,
  ),
  'druid': ClassExpectation(
    hitDie: 8,
    saves: ['int', 'wis'],
    resourceIds: ['wild_shape'],
    mode: 'prepared',
    ability: 'wis',
    archetype: 'full-caster',
    prepared: divinePrepared,
    cantrips: twoStartCantrips,
  ),
  'fighter': ClassExpectation(
    hitDie: 10,
    saves: ['str', 'con'],
    resourceIds: ['second_wind', 'action_surge'],
  ),
  'monk': ClassExpectation(
    hitDie: 8,
    saves: ['dex', 'wis'],
    resourceIds: ['focus_points'],
  ),
  'paladin': ClassExpectation(
    hitDie: 10,
    saves: ['wis', 'cha'],
    resourceIds: ['channel_divinity', 'lay_on_hands'],
    mode: 'prepared',
    ability: 'cha',
    archetype: 'half-caster',
    prepared: halfCasterPrepared,
    cantrips: noCantrips,
  ),
  'ranger': ClassExpectation(
    hitDie: 10,
    saves: ['str', 'dex'],
    resourceIds: ['favored_enemy'],
    mode: 'prepared',
    ability: 'wis',
    archetype: 'half-caster',
    prepared: halfCasterPrepared,
    cantrips: noCantrips,
  ),
  'rogue': ClassExpectation(
    hitDie: 8,
    saves: ['dex', 'int'],
    resourceIds: [],
  ),
  'sorcerer': ClassExpectation(
    hitDie: 6,
    saves: ['con', 'cha'],
    resourceIds: ['sorcery_points', 'innate_sorcery'],
    mode: 'prepared',
    ability: 'cha',
    archetype: 'full-caster',
    prepared: sorcererPrepared,
    cantrips: sorcererCantrips,
  ),
  'warlock': ClassExpectation(
    hitDie: 8,
    saves: ['wis', 'cha'],
    resourceIds: ['magical_cunning'],
    mode: 'prepared',
    ability: 'cha',
    archetype: 'pact',
    prepared: warlockPrepared,
    cantrips: twoStartCantrips,
  ),
  'wizard': ClassExpectation(
    hitDie: 6,
    saves: ['int', 'wis'],
    resourceIds: [],
    mode: 'prepared',
    ability: 'int',
    archetype: 'full-caster',
    prepared: wizardPrepared,
    cantrips: clericalCantrips,
  ),
};

void main() {
  final archive = readArchive();
  final classes = archive['classes']! as Map<String, Object?>;

  test('档案版本与参照清单完整', () {
    expect(archive['rulebookVersion'], 1);
    expect(archive['system'], 'dnd5e-2024');
    expect(archive['abilities'], hasLength(6));
    expect(archive['skills'], hasLength(18));
  });

  test('属性键与技能参照清单合法', () {
    final abilities = (archive['abilities']! as List).cast<String>();
    expect(abilities.toSet(), {'str', 'dex', 'con', 'int', 'wis', 'cha'});

    final skills = (archive['skills']! as List).cast<Map<String, Object?>>();
    for (final skill in skills) {
      expect(skill['name'], isA<String>(), reason: '$skill');
      expect(abilities, contains(skill['ability']), reason: '$skill');
    }
    // 18 技能名不得重复
    expect(skills.map((skill) => skill['name']).toSet(), hasLength(18));
  });

  test('18 项技能的技能名 → 属性映射对照 SRD 5.2', () {
    // 独立的期望表：不从档案取值再断言（那就是自证循环）。
    const expected = <String, String>{
      '杂技': 'dex',
      '驯兽': 'wis',
      '奥秘': 'int',
      '运动': 'str',
      '欺瞒': 'cha',
      '历史': 'int',
      '洞悉': 'wis',
      '威吓': 'cha',
      '调查': 'int',
      '医药': 'wis',
      '自然': 'int',
      '察觉': 'wis',
      '表演': 'cha',
      '说服': 'cha',
      '宗教': 'int',
      '巧手': 'dex',
      '隐匿': 'dex',
      '求生': 'wis',
    };
    expect(expected, hasLength(18));

    final skills = (archive['skills']! as List).cast<Map<String, Object?>>();
    // 技能名集合恰好是这 18 项（无多无少）
    expect(
      skills.map((skill) => skill['name']).toSet(),
      expected.keys.toSet(),
      reason: '技能名集合应恰好是这 18 项',
    );
    for (final skill in skills) {
      final name = skill['name']! as String;
      expect(skill['ability'], expected[name], reason: '$name 的属性');
    }
  });

  test('12 个核心职业全部存在且字段合法', () {
    expect(classes.keys.toSet(), classExpectations.keys.toSet());
    final abilities = (archive['abilities']! as List).cast<String>();
    for (final slug in classExpectations.keys) {
      final rules = classRules(classes, slug);
      expect(rules['hitDie'], isA<int>(), reason: slug);
      expect(rules['hitDie'] as int, inInclusiveRange(4, 20), reason: slug);
      final saves = rules['savingThrowAbilities']! as List;
      expect(saves, hasLength(2), reason: slug);
      expect(saves.toSet(), hasLength(2), reason: slug);
      for (final ability in saves) {
        expect(abilities, contains(ability), reason: slug);
      }
    }
  });

  test('class 对象只允许契约字段（防止混入散文/多余键）', () {
    const allowed = {'hitDie', 'savingThrowAbilities', 'spellcasting', 'resources'};
    classes.forEach((slug, value) {
      final rules = value! as Map<String, Object?>;
      final extra = rules.keys.toSet().difference(allowed);
      expect(extra, isEmpty, reason: '$slug 出现契约外字段：$extra');
    });
  });

  test('spellcasting 对象只允许契约字段（嵌套层级也要守卫）', () {
    const allowed = {
      'mode',
      'ability',
      'archetype',
      'listTags',
      'slots',
      'slotLevel',
      'prepared',
      'cantrips',
      'maximumSpellLevel',
    };
    classes.forEach((slug, value) {
      final spellcasting =
          (value! as Map<String, Object?>)['spellcasting']! as Map<String, Object?>;
      final extra = spellcasting.keys.toSet().difference(allowed);
      expect(extra, isEmpty, reason: '$slug.spellcasting 出现契约外字段：$extra');
    });
  });

  test('resources 条目只允许契约字段（内置档案不得混入 description）', () {
    const allowed = {'id', 'name', 'maximum', 'recovery', 'startsAtLevel'};
    classes.forEach((slug, value) {
      final rules = value! as Map<String, Object?>;
      final resources = rules['resources'] as List? ?? const [];
      for (final item in resources.cast<Map<String, Object?>>()) {
        final extra = item.keys.toSet().difference(allowed);
        expect(
          extra,
          isEmpty,
          reason: '$slug.${item['id']} 出现契约外字段：$extra（tier 0 只含数值）',
        );
      }
    });
  });

  test('原型不变量：最高环阶与法术位表一致', () {
    final progressions = archive['progressions']! as Map<String, Object?>;
    Map<String, Object?> progression(String name) =>
        progressions[name]! as Map<String, Object?>;

    // full / half / third：最高环阶就是法术位表的环阶个数
    for (final name in ['full-caster', 'half-caster', 'third-caster']) {
      final slots = (progression(name)['slots']! as List).cast<List>();
      final maximum = (progression(name)['maximumSpellLevel']! as List).cast<int>();
      expect(slots, hasLength(20), reason: '$name.slots');
      expect(maximum, hasLength(20), reason: '$name.maximumSpellLevel');
      for (var level = 1; level <= 20; level++) {
        expect(
          maximum[level - 1],
          slots[level - 1].length,
          reason: '$name 等级 $level：最高环阶应等于法术位表的长度',
        );
      }
    }

    // pact：法术位是「单一环阶桶」——档案里 slots[L] 只存该环阶的数量（长度恒为 1），
    // 环阶由 slotLevel[L] 给出。因此「slots[L] 的唯一环阶 == slotLevel[L]」
    // 落实为：只有一个桶 + 最高环阶必须与 slotLevel 逐级绑定（契约魔法没有第二个环阶）。
    final pactSlots = (progression('pact')['slots']! as List).cast<List>();
    final pactSlotLevel = (progression('pact')['slotLevel']! as List).cast<int>();
    final pactMaximum =
        (progression('pact')['maximumSpellLevel']! as List).cast<int>();
    for (var level = 1; level <= 20; level++) {
      final buckets = pactSlots[level - 1];
      expect(
        buckets,
        hasLength(1),
        reason: 'pact 等级 $level：只能有一个环阶桶（唯一环阶）',
      );
      expect(
        buckets.single,
        greaterThan(0),
        reason: 'pact 等级 $level：唯一环阶的位数量必须为正',
      );
      expect(
        pactMaximum[level - 1],
        pactSlotLevel[level - 1],
        reason: 'pact 等级 $level：maximumSpellLevel 必须等于 slotLevel',
      );
    }
  });

  test('原型 minimumLevel 对照 SRD 5.2', () {
    final progressions = archive['progressions']! as Map<String, Object?>;
    Map<String, Object?> progression(String name) =>
        progressions[name]! as Map<String, Object?>;

    expect(progression('full-caster')['minimumLevel'], 1);
    expect(progression('half-caster')['minimumLevel'], 1);
    expect(progression('third-caster')['minimumLevel'], 3,
        reason: '1/3 施法者 3 级起才有法术位');
    expect(progression('pact')['minimumLevel'], 1);
  });

  test('契约书写约定：内置档案默认值一律显式写出', () {
    // 省略默认值会让读者分不清“漏写”还是“取默认”，内置档案一律写全。
    classes.forEach((slug, value) {
      final rules = value! as Map<String, Object?>;
      final resources = rules['resources'] as List? ?? const [];
      for (final item in resources.cast<Map<String, Object?>>()) {
        final id = item['id'];
        expect(item.containsKey('recovery'), isTrue, reason: '$slug.$id 省略了 recovery');
        expect(item.containsKey('startsAtLevel'), isTrue,
            reason: '$slug.$id 省略了 startsAtLevel');
      }
    });
    // `none` 是「无施法」的空原型，自身不承载 minimumLevel。
    for (final name in ['full-caster', 'half-caster', 'third-caster', 'pact']) {
      final p =
          (archive['progressions']! as Map<String, Object?>)[name]! as Map<String, Object?>;
      expect(p.containsKey('minimumLevel'), isTrue, reason: '$name 省略了 minimumLevel');
    }
  });

  test('生命骰与豁免对照 SRD 5.2', () {
    classExpectations.forEach((slug, expected) {
      final rules = classRules(classes, slug);
      expect(rules['hitDie'], expected.hitDie, reason: slug);
      // 豁免是集合：档案的书写顺序不参与语义（数据侧统一按 abilities 顺序书写）。
      expect(
        (rules['savingThrowAbilities']! as List).toSet(),
        expected.saves.toSet(),
        reason: '$slug 豁免（集合比较）',
      );
    });
  });

  test('12 职业施法模型对照 SRD 5.2', () {
    classExpectations.forEach((slug, expected) {
      final spellcasting =
          classRules(classes, slug)['spellcasting']! as Map<String, Object?>;
      if (!expected.isCaster) {
        expect(spellcasting, {'mode': 'none'}, reason: slug);
        return;
      }
      expect(spellcasting['mode'], expected.mode, reason: slug);
      expect(spellcasting['ability'], expected.ability, reason: slug);
      expect(spellcasting['archetype'], expected.archetype, reason: slug);
    });
  });

  test('12 职业资源池的 id 与恢复语义（四种恢复形式都要覆盖）', () {
    // shortRest / shortRestOne / longRest / 随等级变化的表，各至少一例
    expect(resource(classes, 'fighter', 'action_surge')['recovery'], 'shortRest');
    expect(resource(classes, 'barbarian', 'rage')['recovery'], 'shortRestOne');
    expect(
      resource(classes, 'cleric', 'channel_divinity')['recovery'],
      'shortRestOne',
      reason: '牧师引导神力短休只恢复 1 次',
    );
    expect(
      resource(classes, 'druid', 'wild_shape')['recovery'],
      'shortRestOne',
    );
    expect(
      resource(classes, 'sorcerer', 'innate_sorcery')['recovery'],
      'longRest',
      reason: '先天术法是长休恢复',
    );
    expect(resource(classes, 'ranger', 'favored_enemy')['recovery'], 'longRest');
    expect(
      (resource(classes, 'bard', 'bardic_inspiration')['recovery']! as Map)[
          'table'],
      {'1': 'longRest', '5': 'shortRest'},
      reason: '诗人激励 5 级激发灵感后短休也能全恢复',
    );
    expect(resource(classes, 'monk', 'focus_points')['startsAtLevel'], 2);
    expect(resource(classes, 'paladin', 'channel_divinity')['startsAtLevel'], 3);
    // 上限数值不在这里重复断言：见「资源池上限对照 SRD 5.2 官方表」。
  });

  test('资源池上限对照 SRD 5.2 官方表', () {
    const rage = {1: 2, 3: 3, 6: 4, 12: 5, 17: 6};
    const secondWind = {1: 2, 4: 3, 10: 4};
    const actionSurge = {2: 1, 17: 2};
    const channelDivinityCleric = {2: 2, 6: 3, 18: 4};
    const wildShape = {2: 2, 6: 3, 17: 4};
    const favoredEnemy = {1: 2, 5: 3, 9: 4, 13: 5, 17: 6};
    const channelDivinityPaladin = {3: 2, 11: 3};

    void expectTable(String slug, String id, Map<int, int> expected) {
      final maximum = resource(classes, slug, id)['maximum']! as Map;
      final table = (maximum['table']! as Map).cast<String, Object?>();
      // 表必须恰好覆盖这些档位，多写或少写都视为与官方表不符
      expect(
        table.keys.map(int.parse).toSet(),
        expected.keys.toSet(),
        reason: '$slug.$id 档位',
      );
      // 取值为"不超过当前等级的最大已声明档位"，因此 1..20 级逐级核算
      final levels = expected.keys.toList()..sort();
      var effective = levels.first;
      for (var level = 1; level <= 20; level++) {
        if (levels.contains(level)) effective = level;
        expect(
          table['$effective'],
          expected[effective],
          reason: '$slug.$id 等级 $level',
        );
      }
    }

    expectTable('barbarian', 'rage', rage);
    expectTable('fighter', 'second_wind', secondWind);
    expectTable('fighter', 'action_surge', actionSurge);
    expectTable('cleric', 'channel_divinity', channelDivinityCleric);
    expectTable('druid', 'wild_shape', wildShape);
    expectTable('ranger', 'favored_enemy', favoredEnemy);
    expectTable('paladin', 'channel_divinity', channelDivinityPaladin);

    // 公式形态的三种写法
    expect(
      resource(classes, 'bard', 'bardic_inspiration')['maximum'],
      {'formula': 'ability:cha', 'minimum': 1},
      reason: '诗人激励 = 魅力调整值（最低 1）',
    );
    expect(resource(classes, 'monk', 'focus_points')['maximum'], {'formula': 'level'});
    expect(resource(classes, 'sorcerer', 'sorcery_points')['maximum'], {'formula': 'level'});
    expect(
      resource(classes, 'paladin', 'lay_on_hands')['maximum'],
      {'formula': '5*level'},
      reason: '圣疗是 5×等级的治疗池',
    );
    // 常量形态
    expect(resource(classes, 'sorcerer', 'innate_sorcery')['maximum'], 2);
    expect(resource(classes, 'warlock', 'magical_cunning')['maximum'], 1);
  });

  test('资源池覆盖 12 个职业（除游荡者与法师外都有）', () {
    classExpectations.forEach((slug, expected) {
      final resources = classRules(classes, slug)['resources'];
      if (expected.resourceIds.isEmpty) {
        expect(resources, anyOf(isNull, isEmpty), reason: '$slug 不应有资源');
        return;
      }
      final ids = (resources! as List)
          .cast<Map<String, Object?>>()
          .map((item) => item['id'])
          .toList();
      // 比较集合：资源在档案里的书写顺序不参与语义。
      expect(ids.toSet(), expected.resourceIds.toSet(), reason: '$slug 资源 id');
      expect(ids, hasLength(expected.resourceIds.length),
          reason: '$slug 资源数量（id 不得重复）');
    });
  });

  test('每个原型的关键表长度都是 20 或为空', () {
    final progressions = archive['progressions']! as Map<String, Object?>;
    expect(
      progressions.keys.toSet(),
      {'none', 'full-caster', 'half-caster', 'third-caster', 'pact'},
    );
    progressions.forEach((name, raw) {
      final p = raw! as Map<String, Object?>;
      // prepared / cantrips 不在原型里（见下方契约守卫），逐职业表单独核算
      for (final key in ['slots', 'maximumSpellLevel', 'slotLevel']) {
        final value = p[key];
        if (value == null) continue;
        // 原型内部是模板，必须写完整 20 项；`none` 原型的空表是唯一例外
        expect(
          (value as List),
          name == 'none' && key == 'slots' ? isEmpty : hasLength(20),
          reason: '$name.$key',
        );
      }
    });
  });

  test('原型表数值对照 SRD 5.2（1 级 / 5 级 / 20 级抽样）', () {
    final progressions = archive['progressions']! as Map<String, Object?>;
    Map<String, Object?> progression(String name) =>
        progressions[name]! as Map<String, Object?>;

    // 全施法者的法术位表（SRD 5.2 标准施法者表）
    const fullCasterSlots = {
      1: [2],
      5: [4, 3, 2],
      20: [4, 3, 3, 3, 3, 2, 2, 1, 1],
    };
    final fullSlots = (progression('full-caster')['slots']! as List).cast<List>();
    fullCasterSlots.forEach((level, expected) {
      expect(fullSlots[level - 1], expected, reason: 'full-caster 等级 $level 法术位');
    });
    // 半施法者等效等级 = ceil(等级 / 2) 的内部一致性由独立用例覆盖；
    // 这里保留 1 / 5 / 20 级的 SRD 真值锚点。
    final halfSlots = (progression('half-caster')['slots']! as List).cast<List>();
    expect(halfSlots[0], [2], reason: '半施法者 1 级即有法术位（2024）');
    expect(halfSlots[4], [4, 2], reason: '半施法者 5 级等效 3 级');
    expect(halfSlots[19], [4, 3, 3, 3, 2], reason: '半施法者 20 级等效 10 级');
    // 1/3 施法者：3 级起才有法术位
    final thirdSlots = (progression('third-caster')['slots']! as List).cast<List>();
    expect(thirdSlots[0], isEmpty);
    expect(thirdSlots[1], isEmpty);
    expect(thirdSlots[2], [2]);
    expect(thirdSlots[19], [4, 3, 3, 1], reason: '1/3 施法者 20 级等效 7 级');

    // 契约魔法：单一环阶 + 数量
    final pact = progression('pact');
    expect((pact['slots']! as List)[0], [1]);
    expect((pact['slots']! as List)[10], [3]);
    expect((pact['slots']! as List)[16], [4]);
    expect((pact['slotLevel']! as List)[0], 1);
    expect((pact['slotLevel']! as List)[4], 3);
    expect((pact['slotLevel']! as List)[8], 5);
    expect((pact['slotLevel']! as List)[17], 5);

    // 最高环阶
    expect((progression('full-caster')['maximumSpellLevel']! as List)[0], 1);
    expect((progression('full-caster')['maximumSpellLevel']! as List)[8], 5);
    expect((progression('full-caster')['maximumSpellLevel']! as List)[16], 9);
    expect((progression('half-caster')['maximumSpellLevel']! as List)[0], 1);
    expect((progression('half-caster')['maximumSpellLevel']! as List)[16], 5);
    expect((progression('pact')['maximumSpellLevel']! as List)[16], 5);
    // 1/3 施法者的完整最高环阶表（由官方法术位表推导，见契约 §3.1）
    expect(
      progression('third-caster')['maximumSpellLevel'],
      [0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 4, 4],
      reason: '1/3 施法者 3–6 级 1 环 / 7–12 级 2 环 / 13–18 级 3 环 / 19–20 级 4 环',
    );
  });

  test('内部一致性：half-caster = full-caster[ceil(L/2)]', () {
    final progressions = archive['progressions']! as Map<String, Object?>;
    final fullSlots =
        (progressions['full-caster']! as Map<String, Object?>)['slots']! as List;
    final halfSlots =
        (progressions['half-caster']! as Map<String, Object?>)['slots']! as List;
    // 本条只证明两条内置曲线彼此一致（半施法者等效等级 = ceil(等级 / 2)）。
    // SRD 真值由 1 / 5 / 20 级的字面量锚点覆盖（见「原型表数值对照 SRD 5.2」）。
    for (var level = 1; level <= 20; level++) {
      expect(
        halfSlots[level - 1],
        fullSlots[((level + 1) ~/ 2) - 1],
        reason: 'half-caster 等级 $level 法术位',
      );
    }
  });

  test('契约守卫：原型只承载 slots / slotLevel / maximumSpellLevel / minimumLevel', () {
    final progressions = archive['progressions']! as Map<String, Object?>;
    const allowed = {'slots', 'slotLevel', 'maximumSpellLevel', 'minimumLevel'};
    progressions.forEach((name, raw) {
      final p = raw! as Map<String, Object?>;
      // prepared / cantrips 永远是职业自己的字段：2024 官方表这两列逐职业不同，
      // 塞进原型会让法师 20 级准备上限从 25 静默掉到 22、术士 1 级从 2 变 4。
      expect(p.containsKey('prepared'), isFalse, reason: '$name 不得承载 prepared');
      expect(p.containsKey('cantrips'), isFalse, reason: '$name 不得承载 cantrips');
      final unexpected = p.keys.toSet().difference(allowed);
      expect(unexpected, isEmpty, reason: '$name 出现白名单之外的键：$unexpected');
    });
  });

  test('8 个施法职业的 prepared / cantrips 逐职业对照 SRD 5.2（完整 20 项）', () {
    final casters = classExpectations.entries.where((e) => e.value.isCaster);
    expect(casters, hasLength(8), reason: '施法职业应为 8 个');
    for (final entry in casters) {
      final slug = entry.key;
      final expected = entry.value;
      final spellcasting =
          classRules(classes, slug)['spellcasting']! as Map<String, Object?>;
      final prepared = (spellcasting['prepared']! as List).cast<int>();
      final cantrips = (spellcasting['cantrips']! as List).cast<int>();
      expect(prepared, hasLength(20), reason: '$slug.prepared');
      expect(cantrips, hasLength(20), reason: '$slug.cantrips');
      expect(prepared, expected.prepared, reason: '$slug.prepared');
      expect(cantrips, expected.cantrips, reason: '$slug.cantrips');
    }

    // 非施法者保持 {"mode":"none"}，不得凭空多出这两项
    for (final entry in classExpectations.entries.where((e) => !e.value.isCaster)) {
      final spellcasting =
          classRules(classes, entry.key)['spellcasting']! as Map<String, Object?>;
      expect(spellcasting, {'mode': 'none'}, reason: entry.key);
    }
  });

  // 历史缺陷（2026-09 审查）：曾把 prepared / cantrips 塞进原型共用，
  // 会让法师 20 级准备上限从 25 掉到 22、术士 1 级从 2 变 4。
  // 该回归点已由逐职业期望表（classExpectations）与上面的施法表断言完整覆盖；
  // 原先单独一条「缺陷回归点」用例已删除，避免同一个 oracle 维护两处。
}
