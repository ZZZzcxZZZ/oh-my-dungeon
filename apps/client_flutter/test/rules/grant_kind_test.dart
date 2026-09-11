// 任务 9：规则定义收紧的契约断言。
//
// 1. `progression[].levels`：必填非空、元素 1..20、去重排序；旧的 `level` 键被拒绝。
// 2. `RuleGrantKind` 收敛为 9 项：`resource` / `conditionResistance` / `note` 不再存在。
// 3. `hitPoints` / `ability` 两个 grant **真的**参与派生：HP 进 `maxHp`、
//    属性在派生之前叠加（因此影响法术 DC 等有关派生的数值）。
import 'package:dnd_table_client/src/features/characters/domain/rules_driven_character_builder.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:dnd_table_client/src/features/rules/domain/character_build.dart';
import 'package:dnd_table_client/src/features/rules/domain/character_rule_definition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('progression 只接受 levels 数组，旧的 level 字段被拒绝', () {
    final step = RuleProgressionDefinition.fromJson({
      'levels': [4, 8, 12, 16],
      'grants': [
        {
          'id': 'asi-int',
          'kind': 'ability',
          'label': '智力 +1',
          'target': 'int',
          'value': 1,
        },
      ],
    });
    expect(step.levels, [4, 8, 12, 16]);

    expect(
      () => RuleProgressionDefinition.fromJson({'level': 4}),
      throwsFormatException,
    );
    expect(
      () => RuleProgressionDefinition.fromJson({'levels': [0]}),
      throwsFormatException,
    );
    expect(
      () => RuleProgressionDefinition.fromJson({'levels': [21]}),
      throwsFormatException,
    );
    expect(
      () => RuleProgressionDefinition.fromJson({'levels': []}),
      throwsFormatException,
    );
    expect(
      () => RuleProgressionDefinition.fromJson({'levels': [4, 4]}),
      throwsFormatException,
    );
    expect(
      () => RuleProgressionDefinition.fromJson(const {}),
      throwsFormatException,
    );
  });

  test('levels 去重后按升序规范化', () {
    final step = RuleProgressionDefinition.fromJson({
      'levels': [12, 4, 8],
    });
    expect(step.levels, [4, 8, 12]);
    expect(step.toJson()['levels'], [4, 8, 12]);
    expect(step.toJson().containsKey('level'), isFalse);
  });

  test('grant kind 收敛为 9 项，resource/conditionResistance/note 被拒绝', () {
    expect(RuleGrantKind.values.map((k) => k.name).toSet(), {
      'feature',
      'proficiency',
      'spell',
      'equipment',
      'action',
      'speed',
      'armorClass',
      'hitPoints',
      'ability',
    });
    for (final gone in ['resource', 'conditionResistance', 'note']) {
      expect(() => RuleGrantKind.parse(gone), throwsFormatException, reason: gone);
    }
  });

  test('hitPoints 与 ability grant 参与派生', () {
    // 等级 3、CON 20（调整值 +5）：基础 maxHp = 10 + 5 + 2 ×（5 + 1 + 5）= 37。
    // hitPoints grant 给 `value: 2` 与 `formula: level`（职业等级 3）→ +5 → 42。
    // ability grant 给 `dex` +1（13 → 14）：调整值从 +1 变 +2，因此
    // 先攻（与 AC）必须按 14 结算 —— 只有**先**叠加属性才可能观察到。
    final arcanist = _entry(
      id: 'test:class/arcanist',
      type: 'class',
      name: 'Arcanist',
      structured: const {
        'classRules': {
          'hitDie': 10,
          'savingThrowAbilities': ['str', 'con'],
          'spellcasting': {
            'mode': 'prepared',
            'ability': 'cha',
            'archetype': 'full-caster',
          },
        },
      },
      rules: const {
        'progression': [
          {
            'levels': [1],
            'grants': [
              {
                'id': 'asi-dex',
                'kind': 'ability',
                'label': '敏捷 +1',
                'target': 'dex',
                'value': 1,
              },
            ],
          },
          {
            'levels': [3],
            'grants': [
              {
                'id': 'toughness',
                'kind': 'hitPoints',
                'label': '强健体魄',
                'value': 2,
              },
              {
                'id': 'toughness-scale',
                'kind': 'hitPoints',
                'label': '随等级成长的生命值',
                'formula': 'level',
              },
            ],
          },
        ],
      },
    );
    final builder = RulesDrivenCharacterBuilder(entries: {arcanist.id: arcanist});

    const abilities = {
      'str': 13,
      'dex': 13,
      'con': 20,
      'int': 10,
      'wis': 10,
      'cha': 13,
    };
    final draft = builder.build(
      name: 'Aria',
      build: const CharacterBuild(
        level: 3,
        selections: {'class': 'test:class/arcanist'},
      ),
      abilities: abilities,
    );

    // hitPoints：基础 37 + value 2 + formula `level`（职业等级 3）= 42。
    expect(draft.maxHp, 42, reason: 'hitPoints grant 的 value/formula 必须进 maxHp');
    expect(draft.currentHp, 42);
    // ability：dex 13 → 14，调整值 +1 → +2，因此派生值按 14 结算。
    expect(draft.abilities['dex'], 14);
    expect(
      draft.initiativeBonus,
      2,
      reason: 'ability grant 必须在派生（先攻/AC）之前叠加',
    );
    expect(draft.armorClass, 12);

    // 负向对照：等级 1 时 `levels: [3]` 的生命值步骤不生效，maxHp 只有基础值；
    // 但 `levels: [1]` 的属性步骤仍生效，先攻仍是派生后的 +2。
    final levelOne = builder.build(
      name: 'Aria',
      build: const CharacterBuild(
        level: 1,
        selections: {'class': 'test:class/arcanist'},
      ),
      abilities: abilities,
    );
    expect(levelOne.abilities['dex'], 14);
    expect(levelOne.initiativeBonus, 2);
    // d10 + CON 20（+5）= 15。
    expect(levelOne.maxHp, 15, reason: 'd10 + CON 20（+5）');
  });
}

ContentEntry _entry({
  required String id,
  required String type,
  required String name,
  Map<String, Object?> structured = const {},
  List<Map<String, Object?>> body = const [],
  String summary = '',
  List<String> tags = const [],
  required Map<String, Object?> rules,
}) {
  return ContentEntry.fromJson({
    'id': id,
    'type': type,
    'slug': id.split('/').last,
    'name': name,
    'body': body,
    'revision': 1,
    'structured': structured,
    'summary': summary,
    'tags': tags,
    'rules': rules,
  });
}
