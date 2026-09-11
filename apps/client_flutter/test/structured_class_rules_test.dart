import 'package:dnd_table_client/src/features/characters/domain/structured_class_rules.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:dnd_table_client/src/features/rules/domain/character_rule_definition.dart';
import 'package:flutter_test/flutter_test.dart';

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

    expect(StructuredClassRules.savingThrowAbilities(entry), {'wis', 'cha'});
    expect(StructuredClassRules.hitDie(entry), 10);
    expect(
      StructuredClassRules.preparedSpellLimit(
        entry,
        abilities: const {},
        level: 5,
      ),
      isNull,
      reason: '未声明 prepared 表',
    );
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

    expect(StructuredClassRules.hitDie(entry), isNull);
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

    expect(StructuredClassRules.savingThrowAbilities(entry), isEmpty);
    expect(StructuredClassRules.hitDie(entry), isNull);
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
            'level': 1,
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
            'level': 3,
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

  test('preparedSpellLimit 只读职业自身的 prepared 表（含短数组向上沿用）', () {
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

    expect(
      StructuredClassRules.preparedSpellLimit(
        entry,
        abilities: const {'cha': 20},
        level: 1,
      ),
      3,
    );
    expect(
      StructuredClassRules.preparedSpellLimit(
        entry,
        abilities: const {'cha': 20},
        level: 5,
      ),
      5,
    );
    expect(
      StructuredClassRules.preparedSpellLimit(
        entry,
        abilities: const {'cha': 20},
        level: 9,
      ),
      5,
      reason: '短数组向上沿用',
    );
    expect(
      StructuredClassRules.preparedSpellLimit(
        entry,
        abilities: const {'cha': 3},
        level: 9,
      ),
      5,
      reason: '准备上限是职业级表，与属性无关',
    );
  });

  test('preparedSpellLimit 不再看 preparedSpellcasting 开关与散文', () {
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
      StructuredClassRules.preparedSpellLimit(
        declared,
        abilities: const {'wis': 20},
        level: 1,
      ),
      isNull,
      reason: '旧开关与旧显式表都不再参与计算',
    );
  });

  test('preparedSpellLimit 读内置档案的 prepared 表（按 slug 精确对齐）', () {
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
      StructuredClassRules.preparedSpellLimit(
        entry,
        abilities: const {'wis': 3},
        level: 1,
      ),
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
