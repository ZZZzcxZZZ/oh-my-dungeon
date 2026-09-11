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
      .firstWhere((item) => item['id'] == id)
      .cast<String, Object?>();
}

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

  test('12 个核心职业全部存在且字段合法', () {
    const slugs = [
      'barbarian', 'bard', 'cleric', 'druid', 'fighter', 'monk',
      'paladin', 'ranger', 'rogue', 'sorcerer', 'warlock', 'wizard',
    ];
    expect(classes.keys.toSet(), slugs.toSet());
    final abilities = (archive['abilities']! as List).cast<String>();
    for (final slug in slugs) {
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

  test('生命骰与豁免对照 SRD 5.2', () {
    const expected = {
      'barbarian': [12, ['str', 'con']],
      'bard': [8, ['dex', 'cha']],
      'cleric': [8, ['wis', 'cha']],
      'druid': [8, ['int', 'wis']],
      'fighter': [10, ['str', 'con']],
      'monk': [8, ['dex', 'wis']],
      'paladin': [10, ['wis', 'cha']],
      'ranger': [10, ['dex', 'str']],
      'rogue': [8, ['dex', 'int']],
      'sorcerer': [6, ['con', 'cha']],
      'warlock': [8, ['wis', 'cha']],
      'wizard': [6, ['int', 'wis']],
    };
    expected.forEach((slug, value) {
      final rules = classRules(classes, slug);
      expect(rules['hitDie'], value[0], reason: slug);
      expect(rules['savingThrowAbilities'], value[1], reason: slug);
    });
  });

  test('12 职业施法模型对照 SRD 5.2', () {
    const expected = {
      'barbarian': null,
      'bard': ['prepared', 'cha', 'full-caster'],
      'cleric': ['prepared', 'wis', 'full-caster'],
      'druid': ['prepared', 'wis', 'full-caster'],
      'fighter': null,
      'monk': null,
      'paladin': ['prepared', 'cha', 'half-caster'],
      'ranger': ['prepared', 'wis', 'half-caster'],
      'rogue': null,
      'sorcerer': ['prepared', 'cha', 'full-caster'],
      'warlock': ['prepared', 'cha', 'pact'],
      'wizard': ['prepared', 'int', 'full-caster'],
    };
    expected.forEach((slug, value) {
      final spellcasting =
          classRules(classes, slug)['spellcasting']! as Map<String, Object?>;
      if (value == null) {
        expect(spellcasting, {'mode': 'none'}, reason: slug);
        return;
      }
      expect(spellcasting['mode'], value[0], reason: slug);
      expect(spellcasting['ability'], value[1], reason: slug);
      expect(spellcasting['archetype'], value[2], reason: slug);
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
    expect(resource(classes, 'warlock', 'magical_cunning')['maximum'], 1);
    expect(
      resource(classes, 'paladin', 'lay_on_hands')['maximum'],
      {'formula': '5*level'},
    );
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
    const withResources = [
      'barbarian', 'bard', 'cleric', 'druid', 'fighter', 'monk',
      'paladin', 'ranger', 'sorcerer', 'warlock',
    ];
    for (final slug in withResources) {
      expect((classRules(classes, slug)['resources']! as List), isNotEmpty,
          reason: slug);
    }
    for (final slug in ['rogue', 'wizard']) {
      expect(classRules(classes, slug)['resources'], anyOf(isNull, isEmpty),
          reason: slug);
    }
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
    // 半施法者逐级引用同一张标准表：等效等级 = ceil(等级 / 2)
    final halfSlots = (progression('half-caster')['slots']! as List).cast<List>();
    for (var level = 1; level <= 20; level++) {
      expect(
        halfSlots[level - 1],
        fullSlots[((level + 1) ~/ 2) - 1],
        reason: 'half-caster 等级 $level 法术位',
      );
    }
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
    // 吟游诗人 / 牧师 / 德鲁伊共用同一张"准备法术"表
    const divinePrepared = [
      4, 5, 6, 7, 9, 10, 11, 12, 14, 15, 16, 16, 17, 17, 18, 18, 19, 20, 21, 22,
    ];
    // 吟游诗人 / 德鲁伊 / 邪术师的戏法表（1 级 2 个）
    const twoStartCantrips = [
      2, 2, 2, 3, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
    ];
    const clericCantrips = [
      3, 3, 3, 4, 4, 4, 4, 4, 4, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5,
    ];
    const wizardCantrips = clericCantrips;
    const sorcererPrepared = [
      2, 4, 6, 7, 9, 10, 11, 12, 14, 15, 16, 16, 17, 17, 18, 18, 19, 20, 21, 22,
    ];
    const sorcererCantrips = [
      4, 4, 4, 5, 5, 5, 5, 5, 5, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
    ];
    const wizardPrepared = [
      4, 5, 6, 7, 9, 10, 11, 12, 14, 15, 16, 16, 17, 18, 19, 21, 22, 23, 24, 25,
    ];
    const halfCasterPrepared = [
      2, 3, 4, 5, 6, 6, 7, 7, 9, 9, 10, 10, 11, 11, 12, 12, 14, 14, 15, 15,
    ];
    const warlockPrepared = [
      2, 3, 4, 5, 6, 7, 8, 9, 10, 10, 11, 11, 12, 12, 13, 13, 14, 14, 15, 15,
    ];
    const noCantrips = [
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    ];

    const expected = <String, List<List<int>>>{
      'bard': [divinePrepared, twoStartCantrips],
      'cleric': [divinePrepared, clericCantrips],
      'druid': [divinePrepared, twoStartCantrips],
      'sorcerer': [sorcererPrepared, sorcererCantrips],
      'wizard': [wizardPrepared, wizardCantrips],
      'paladin': [halfCasterPrepared, noCantrips],
      'ranger': [halfCasterPrepared, noCantrips],
      'warlock': [warlockPrepared, twoStartCantrips],
    };

    expected.forEach((slug, tables) {
      final spellcasting =
          classRules(classes, slug)['spellcasting']! as Map<String, Object?>;
      final prepared = (spellcasting['prepared']! as List).cast<int>();
      final cantrips = (spellcasting['cantrips']! as List).cast<int>();
      expect(prepared, hasLength(20), reason: '$slug.prepared');
      expect(cantrips, hasLength(20), reason: '$slug.cantrips');
      expect(prepared, tables[0], reason: '$slug.prepared');
      expect(cantrips, tables[1], reason: '$slug.cantrips');
    });

    // 非施法者保持 {"mode":"none"}，不得凭空多出这两项
    for (final slug in ['barbarian', 'fighter', 'monk', 'rogue']) {
      final spellcasting =
          classRules(classes, slug)['spellcasting']! as Map<String, Object?>;
      expect(spellcasting, {'mode': 'none'}, reason: slug);
    }
  });

  test('缺陷回归：职业差异不得被原型抹平（法师 25 / 术士 1 级 2 等）', () {
    List<int> table(String slug, String key) =>
        ((classRules(classes, slug)['spellcasting']! as Map<String, Object?>)[key]!
                as List)
            .cast<int>();

    final wizard = table('wizard', 'prepared');
    expect(wizard[19], 25, reason: '法师 20 级准备上限 25，不是原型共用的 22');
    expect(wizard[0], 4, reason: '法师 1 级准备 4');

    final sorcerer = table('sorcerer', 'prepared');
    expect(sorcerer[0], 2, reason: '术士 1 级只要 2 个准备法术，不是原型的 4');
    expect(sorcerer[19], 22);

    expect(table('druid', 'cantrips')[0], 2, reason: '德鲁伊 1 级戏法 2');
    expect(table('sorcerer', 'cantrips')[0], 4, reason: '术士 1 级戏法 4');
    expect(table('cleric', 'cantrips')[0], 3, reason: '牧师 1 级戏法 3');

    for (final slug in ['paladin', 'ranger']) {
      expect(table(slug, 'cantrips'), everyElement(0), reason: '$slug 没有戏法');
    }

    final warlock = table('warlock', 'prepared');
    expect(warlock[0], 2, reason: '邪术师 1 级准备 2');
    expect(warlock[19], 15);
  });
}
