// H：关闭覆盖后派生快照必须**真的清空**。
//
// 缺陷：`RulesDrivenCharacterBuilder` 以前只在派生结果非空时才写
// `spellSlots` / `spellcastingAbility` / `preparedSpellLimit` / `classResources` /
// `actions` / `startingEquipmentMaximum`，而 `CharacterRuleProjector` /
// `CharacterUpgradePlanner` 只在 `derivedData.containsKey(key)` 时覆盖 →
// 再派生得到"空"时旧包的数值留在 `data` 里。表现：关闭声明 `spellcasting` 的来源后
// `hitDie` 正确变 null，但 `spellSlots` 还是旧包的数值，而 `classRuleSources`
// 已刷新为"内置档案"——来源与数值自相矛盾（静默数值错误）。
//
// 修法：这 6 个派生快照键**无条件写入**（空表 `{}` / 空列表 `[]` / 无值 `null`），
// 消费方按**是否存在该键**判断"是否已派生"，绝不按"值是否非空"回退。
//
// fixture 设计（关键）：只有**勘误**声明 `spellcasting` / 资源，职业自身条目一个
// 都不声明。关闭勘误后这些列就是"未声明"——若派生结果为空时不显式清空，旧值
// 必然残留（这正是缺陷的触发条件）。
import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/characters/domain/character_rule_overrides.dart';
import 'package:dnd_table_client/src/features/characters/domain/character_rule_projector.dart';
import 'package:dnd_table_client/src/features/characters/domain/character_upgrade_planner.dart';
import 'package:dnd_table_client/src/features/characters/domain/dnd5e_rules.dart';
import 'package:dnd_table_client/src/features/characters/domain/rules_driven_character_builder.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:dnd_table_client/src/features/rules/domain/character_build.dart';
import 'package:flutter_test/flutter_test.dart';

/// 来源 A：职业自身条目。**只声明生命骰**——施法列与资源全留给勘误。
ContentEntry _baseEntry() =>
    _classEntry('base:class/mage', const <String, Object?>{'hitDie': 6});

/// 来源 B：勘误，声明施法列（slots / ability / prepared）与一条职业资源。
ContentEntry _errataEntry() => _classEntry('errata:class/mage', const {
  'spellcasting': {
    'mode': 'prepared',
    'ability': 'wis',
    'slots': {'1': {'1': 2}},
    'prepared': {'1': 9, '2': 11},
  },
  'resources': [
    {'id': 'focus', 'name': '奥能', 'maximum': 5, 'recovery': 'shortRest'},
  ],
});

ContentEntry _classEntry(String id, Map<String, Object?> classRules) =>
    ContentEntry.fromJson(<String, Object?>{
      'id': id,
      'type': 'class',
      'slug': 'mage',
      'name': id,
      'body': <Object?>[],
      'revision': 1,
      'structured': <String, Object?>{'classRules': classRules},
    });

Map<String, ContentEntry> _entries() => <String, ContentEntry>{
  'base:class/mage': _baseEntry(),
  'errata:class/mage': _errataEntry(),
};

const _priorities = <String, int>{'errata': 40};

CharacterSheet _character({Set<String> disabled = const <String>{}}) =>
    CharacterSheet.local(
      id: 'mage',
      name: '快照法师',
      level: 1,
      classSummary: 'mage',
    ).copyWith(
      data: <String, Object?>{
        'build': <String, Object?>{
          'level': 1,
          'selections': <String, Object?>{'class': 'base:class/mage'},
          'choices': <String, Object?>{},
        },
        if (disabled.isNotEmpty)
          'ruleOverrides': <String, Object?>{
            'disabledOriginIds': disabled.toList(),
          },
      },
    );

CharacterRuleProjector _projector() => CharacterRuleProjector(
  entries: _entries(),
  packagePriorities: _priorities,
);

/// 只断言"派生结果为空"的那 6 个派生快照键的形状（H）。
void expectClearedSnapshots(Map<String, Object?> data) {
  expect(data.containsKey('spellSlots'), isTrue, reason: '键必须存在（已派生）');
  expect(data['spellSlots'], isEmpty, reason: '无法术位 = 空表，不得回退旧值');
  expect(
    data.containsKey('spellcastingAbility'),
    isTrue,
    reason: '键必须存在（已派生）',
  );
  expect(data['spellcastingAbility'], isNull, reason: '未声明施法属性');
  expect(
    data.containsKey('preparedSpellLimit'),
    isTrue,
    reason: '键必须存在（已派生）',
  );
  expect(data['preparedSpellLimit'], isNull, reason: '未声明准备上限');
  expect(data.containsKey('classResources'), isTrue);
  expect(data['classResources'], isEmpty);
  expect(data.containsKey('actions'), isTrue);
  expect(data['actions'], isEmpty);
  expect(data.containsKey('startingEquipmentMaximum'), isTrue);
  expect(data['startingEquipmentMaximum'], isNull);
}

void main() {
  test('关闭声明 spellcasting 的来源后再派生：派生快照键全部清空（H）', () {
    final withErrata = _projector().project(_character());
    // 关闭之前：勘误的数值真的生效，否则这条用例没有测到目标。
    expect(withErrata.dataMap['spellSlots'], {'1': 2});
    expect(withErrata.dataMap['spellcastingAbility'], 'wis');
    expect(withErrata.dataMap['preparedSpellLimit'], 9);
    expect(withErrata.dataMap['classResources'], isNotEmpty);

    final closed = _projector().project(_character(disabled: {'errata'}));

    expectClearedSnapshots(closed.dataMap);
    // 来源快照同步刷新：这些列现在归职业自身条目（勘误已关闭）。
    final sources = closed.dataMap['classRuleSources']! as Map;
    expect(
      (sources['hitDie']! as Map)['originId'],
      'base:class/mage',
    );
  });

  test('关闭覆盖后**升级**：派生快照同样清空，不残留旧来源数值（H）', () {
    final withErrata = _projector().project(_character());
    expect(withErrata.dataMap['spellSlots'], isNotEmpty);

    final planner = CharacterUpgradePlanner(
      entries: _entries(),
      packagePriorities: _priorities,
      disabledOriginIds: CharacterRuleOverrides.fromCharacter(
        _character(disabled: {'errata'}),
      ).disabledOriginIds,
    );
    final applied = planner.apply(withErrata, planner.plan(withErrata));

    expect(applied.level, 2);
    expectClearedSnapshots(applied.dataMap);
    final sources = applied.dataMap['classRuleSources']! as Map;
    expect((sources['hitDie']! as Map)['originId'], 'base:class/mage');
  });

  test('未关闭时勘误生效（对照组，防止"一律清空"的假修复）', () {
    final derived = RulesDrivenCharacterBuilder(
      entries: _entries(),
      packagePriorities: _priorities,
    ).build(
      name: '快照法师',
      build: const CharacterBuild(
        level: 1,
        selections: {'class': 'base:class/mage'},
      ),
      abilities: Dnd5eRules.defaultAbilities,
    );

    expect(derived.data['spellSlots'], {'1': 2});
    expect(derived.data['spellcastingAbility'], 'wis');
    expect(derived.data['preparedSpellLimit'], 9);
    expect(derived.data['classResources'], isNotEmpty);
  });

  // P0-1：`CharacterSheet.classResources` 的判据必须是"键是否存在"。`replace` 独占
  // 截断档案后 `data.classResources == []`（已派生且为空），按"值非空"判断会回退解析、
  // 把**被截断来源**的资源再算回来（资源面板 / 短休长休按钮 / 列表页同屏矛盾）。
  group('classResources getter 按"键是否存在"判断（P0-1）', () {
    ContentEntry barbarianEntry({required bool replace}) => _classEntry(
      'base:class/barbarian',
      <String, Object?>{
        if (replace) 'mode': 'replace',
        'hitDie': 12,
      },
    );

    CharacterSheet barbarian({required bool replace}) {
      final entry = barbarianEntry(replace: replace);
      final draft = RulesDrivenCharacterBuilder(
        entries: {entry.id: entry},
      ).build(
        name: '野蛮人',
        build: const CharacterBuild(
          level: 1,
          selections: {'class': 'base:class/barbarian'},
        ),
        abilities: Dnd5eRules.defaultAbilities,
      );
      return CharacterSheet.local(
        id: 'barbarian',
        name: '野蛮人',
        level: 1,
        classSummary: 'barbarian',
      ).copyWith(data: draft.data);
    }

    test('未用 replace 时档案的狂暴资源照常派生（对照组，证明夹具有效）', () {
      final character = barbarian(replace: false);
      expect(character.dataMap['classResources'], isNotEmpty);
      expect(character.classResources, isNotEmpty);
      expect(
        character.classResources.map((resource) => resource.id),
        contains('rage'),
      );
    });

    test('replace 截断档案后：data 是空表，getter 也是空（不回退算回被截断的资源）', () {
      final character = barbarian(replace: true);
      expect(
        character.dataMap['classResources'],
        isEmpty,
        reason: 'H：派生快照无条件写入，replace 后就是空表',
      );
      expect(
        character.classResources,
        isEmpty,
        reason: '键已存在（= 已派生）→ 绝不回退把档案的 rage 算回来',
      );
    });
  });
}
