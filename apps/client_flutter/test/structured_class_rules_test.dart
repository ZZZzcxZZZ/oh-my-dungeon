import 'package:dnd_table_client/src/features/characters/domain/dnd5e_rules.dart';
import 'package:dnd_table_client/src/features/characters/domain/structured_class_rules.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:dnd_table_client/src/features/rules/domain/character_rule_definition.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_profile.dart';
import 'package:flutter_test/flutter_test.dart';

/// 任务 8：`savingThrowAbilities` / `hitDie` / `preparedSpellLimit` 三个旧签名
/// 已随过渡 shim 删除（`preparedSpellLimit` 的最后调用方已迁移），规则数值一律经
/// 条目标识走 [Dnd5eRules.resolveClassRules]；准备上限现在读
/// `ResolvedClassRules.preparedLimit`（下方用例覆盖同一语义）。
ResolvedClassRules _rulesFor(ContentEntry? entry) {
  if (entry == null) {
    return Dnd5eRules.resolveClassRules(entryId: null, classSummary: '');
  }
  return Dnd5eRules.resolveClassRules(
    entryId: entry.id,
    classSummary: entry.name,
    structured: entry.structured,
  );
}

void main() {
  test('savingThrowAbilities 与 hitDie 直接读 classRules', () {
    const entry = ContentEntry(
      id: 'test:class/astral',
      type: 'class',
      slug: 'astral',
      name: '星界骑士',
      body: [],
      revision: 1,
      structured: {
        'classRules': {
          'hitDie': 10,
          'savingThrowAbilities': ['wis', 'cha'],
        },
      },
    );

    final rules = _rulesFor(entry);
    expect(rules.savingThrowAbilities, {'wis', 'cha'});
    expect(rules.hitDie, 10);
    expect(rules.preparedLimit(5), isNull, reason: '未声明 prepared 表');
  });

  test('hitDie 未声明时为 null（不再按职业名猜）', () {
    const entry = ContentEntry(
      id: 'test:class/astral',
      type: 'class',
      slug: 'astral',
      name: '星界骑士',
      body: [],
      revision: 1,
      structured: {
        'classRules': {
          'savingThrowAbilities': ['wis'],
        },
      },
    );

    expect(_rulesFor(entry).hitDie, isNull);
  });

  test('中文散文 savingThrows / skills 不再被解析', () {
    const entry = ContentEntry(
      id: 'test:class/legacy',
      type: 'class',
      slug: 'legacy',
      name: '旧写法',
      body: [],
      revision: 1,
      structured: {'savingThrows': '力量与体质', 'skills': '选择2项：运动、察觉'},
    );

    expect(_rulesFor(entry).savingThrowAbilities, isEmpty);
    expect(_rulesFor(entry).hitDie, isNull);
    expect(StructuredClassRules.skillChoice(entry).count, 0);
    expect(StructuredClassRules.skillChoice(entry).options, isEmpty);
  });

  test('skillChoice 改为读 rules.progression[].choices 的 optionType: "skill"', () {
    final entry = ContentEntry(
      id: 'test:class/astral',
      type: 'class',
      slug: 'astral',
      name: '星界骑士',
      body: [],
      revision: 1,
      structured: const {
        'classRules': {'hitDie': 10},
      },
      rules: CharacterRuleDefinition.fromJson({
        'progression': [
          {
            'levels': [1],
            'choices': [
              {
                'id': 'class-skills',
                'label': '选择两项技能熟练',
                'optionType': 'skill',
                'minimum': 2,
                'maximum': 2,
                'options': ['洞悉', '医药', '说服'],
              },
            ],
          },
        ],
      }),
    );

    expect(StructuredClassRules.skillChoice(entry).count, 2);
    expect(StructuredClassRules.skillChoice(entry).options, ['洞悉', '医药', '说服']);
  });

  test('skillChoice 也读 rules.choices，并支持对象元素取 label', () {
    final entry = ContentEntry(
      id: 'test:class/astral',
      type: 'class',
      slug: 'astral',
      name: '星界骑士',
      body: [],
      revision: 1,
      rules: CharacterRuleDefinition.fromJson({
        'choices': [
          {
            'id': 'any-skill',
            'label': '任选三项技能',
            'optionType': 'skill',
            'minimum': 3,
            'maximum': 3,
            'options': [
              '隐匿',
              {'id': 'arcana', 'label': '奥秘'},
            ],
          },
        ],
      }),
    );

    final choice = StructuredClassRules.skillChoice(entry);
    expect(choice.count, 3, reason: 'count 取 minimum');
    expect(choice.options, ['隐匿', '奥秘']);
  });

  test('skillChoice 跳过非 skill 的选择；没有 skill 选择即空', () {
    final entry = ContentEntry(
      id: 'test:class/fighter',
      type: 'class',
      slug: 'fighter',
      name: '战士',
      body: [],
      revision: 1,
      rules: CharacterRuleDefinition.fromJson({
        'progression': [
          {
            'levels': [3],
            'choices': [
              {
                'id': 'subclass-choice',
                'label': '选择子职业',
                'optionType': 'subclass',
                'minimum': 1,
                'maximum': 1,
              },
            ],
          },
        ],
      }),
    );

    expect(StructuredClassRules.skillChoice(entry).count, 0);
    expect(StructuredClassRules.skillChoice(entry).options, isEmpty);
  });

  test('skillChoice 在 rules 为 null 时返回 empty', () {
    const entry = ContentEntry(
      id: 'test:class/fighter',
      type: 'class',
      slug: 'fighter',
      name: '战士',
      body: [],
      revision: 1,
    );

    expect(
      StructuredClassRules.skillChoice(entry),
      same(StructuredSkillChoice.empty),
    );
    expect(
      StructuredClassRules.skillChoice(null),
      same(StructuredSkillChoice.empty),
    );
  });

  // 任务 7：候选 label 的唯一来源是 `RuleChoiceSemantics.candidatesFor`
  // （展示与创建向导的技能网格是同一份候选）。`optionEntryIds` 表达的条目候选
  // 在传入 entries 时也要能取到条目名，不再退化成"候选由条目规则给出"。
  test('skillChoice 的候选 label 经 candidatesFor（含 optionEntryIds 条目候选）', () {
    final entry = ContentEntry(
      id: 'test:class/astral',
      type: 'class',
      slug: 'astral',
      name: '星界骑士',
      body: const [],
      revision: 1,
      rules: CharacterRuleDefinition.fromJson({
        'choices': [
          {
            'id': 'class-skills',
            'label': '选择两项技能熟练',
            'optionType': 'skill',
            'minimum': 2,
            'maximum': 2,
            'optionEntryIds': ['test:skill/stealth'],
          },
        ],
      }),
    );
    final stealth = ContentEntry.fromJson({
      'id': 'test:skill/stealth',
      'type': 'skill',
      'slug': 'stealth',
      'name': '隐匿',
      'body': <Object?>[],
      'revision': 1,
    });

    // 不传 entries：只有内联候选（这里没有）→ 中性文案，不误标"任意技能"。
    expect(StructuredClassRules.skillChoice(entry).options, isEmpty);
    expect(StructuredClassRules.skillChoice(entry).restricted, isTrue);

    // 传 entries：条目候选的 label 来自同一份候选枚举。
    final resolved = StructuredClassRules.skillChoice(
      entry,
      entries: {'test:skill/stealth': stealth},
    );
    expect(resolved.options, ['隐匿']);
    expect(resolved.restricted, isFalse);
  });

  test('preparedLimit 只读职业自身的 prepared 表（含短数组向上沿用）', () {
    const entry = ContentEntry(
      id: 'test:class/astral',
      type: 'class',
      slug: 'astral',
      name: '星界骑士',
      body: [],
      revision: 1,
      structured: {
        'classRules': {
          'hitDie': 10,
          'spellcasting': {
            'mode': 'prepared',
            'ability': 'cha',
            'prepared': [3, 4, 5],
          },
        },
      },
    );

    final rules = _rulesFor(entry);
    expect(rules.preparedLimit(1), 3);
    expect(rules.preparedLimit(5), 5);
    expect(rules.preparedLimit(9), 5, reason: '短数组向上沿用');
  });

  test('preparedLimit 不再看 preparedSpellcasting 开关与散文', () {
    const declared = ContentEntry(
      id: 'test:class/astral',
      type: 'class',
      slug: 'astral',
      name: '星界骑士',
      body: [],
      revision: 1,
      structured: {
        'preparedSpellcasting': true,
        'spellcastingAbility': 'wis',
        'preparedSpells': {'1': 6},
      },
    );

    expect(
      _rulesFor(declared).preparedLimit(1),
      isNull,
      reason: '旧开关与旧显式表都不再参与计算',
    );
  });

  test('preparedLimit 读内置档案的 prepared 表（按 slug 精确对齐）', () {
    const entry = ContentEntry(
      id: 'test:class/cleric',
      type: 'class',
      slug: 'cleric',
      name: '牧师',
      body: [],
      revision: 1,
      structured: {'preparedSpellcasting': true},
    );

    expect(
      _rulesFor(entry).preparedLimit(1),
      4,
      reason: '2024 牧师 1 级准备 4 个，与感知无关',
    );
  });

  group('startingEquipmentChoice', () {
    test('reads maximum from structured field', () {
      const entry = ContentEntry(
        id: 'test:class/fighter',
        type: 'class',
        slug: 'fighter',
        name: '战士',
        body: [],
        revision: 1,
        structured: {
          'startingEquipmentChoice': {'maximum': 5},
        },
      );

      final choice = StructuredClassRules.startingEquipmentChoice(entry);
      expect(choice, isNotNull);
      expect(choice!.maximum, 5);
    });

    test('returns null when field is missing', () {
      const entry = ContentEntry(
        id: 'test/class/fighter',
        type: 'class',
        slug: 'fighter',
        name: '战士',
        body: [],
        revision: 1,
        structured: {},
      );

      expect(StructuredClassRules.startingEquipmentChoice(entry), isNull);
    });
  });
}
