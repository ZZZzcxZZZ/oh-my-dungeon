// 任务 8 的新契约端到端用例：自制职业**只靠 `structured.classRules`** 就能算出
// 生命骰 / 豁免 / 法术位 / 准备上限 / 职业资源；未声明的职业一律不猜。
//
// 数值按 `samples/homebrew-astral-knight/entries.json` 的实际数据核对
// （任务 4.5 收尾第 10 条要求）。
import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/characters/domain/dnd5e_rules.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_profile.dart';
import 'package:flutter_test/flutter_test.dart';

/// 星界骑士的 `structured`（schema 内片段）：d10、感知/魅力豁免、
/// 半施法者 + 自带 slots 与 prepared 表、一个 formula 资源。
final _astralKnightStructured = <String, Object?>{
  'classRules': <String, Object?>{
    'hitDie': 10,
    'savingThrowAbilities': <String>['wis', 'cha'],
    'spellcasting': <String, Object?>{
      'mode': 'prepared',
      'ability': 'cha',
      'archetype': 'half-caster',
      'slots': <String, Object?>{
        '5': <String, Object?>{'1': 4, '2': 2},
      },
      'prepared': <int>[
        3,
        4,
        5,
        6,
        7,
        7,
        8,
        8,
        10,
        10,
        11,
        11,
        12,
        12,
        13,
        13,
        15,
        15,
        16,
        16,
      ],
    },
    'resources': <Map<String, Object?>>[
      <String, Object?>{
        'id': 'surge',
        'name': '星界涌动',
        'recovery': 'shortRestOne',
        'maximum': <String, Object?>{'formula': 'level'},
      },
    ],
  },
};

ResolvedClassRules _resolveAstralKnight() => Dnd5eRules.resolveClassRules(
  entryId: 'my-pack:class/astral-knight',
  classSummary: '星界骑士',
  structured: _astralKnightStructured,
);

void main() {
  group('自制职业：只靠 classRules 算出全部职业数值', () {
    test('生命骰 / 豁免 / 法术位 / 施法属性来自条目声明', () {
      final resolved = _resolveAstralKnight();
      expect(resolved.hitDie, 10);
      expect(resolved.savingThrowAbilities, {'wis', 'cha'});
      // 1 级：自身 slots 表未声明该等级 → 回退半施法者原型。
      expect(resolved.spellSlots(1), {'1': 2});
      // 5 级：自身 slots 表**已声明**该等级 → 整级替换。
      expect(resolved.spellSlots(5), {'1': 4, '2': 2});
      expect(resolved.spellcastingAbility, 'cha');
      expect(resolved.spellcastingMode, 'prepared');
    });

    test('准备上限只看职业自身的 prepared 表', () {
      expect(_resolveAstralKnight().preparedLimit(5), 7);
      // 片段里没有 cantrips 表 → 未声明（不猜、不回退原型）。
      expect(_resolveAstralKnight().cantripLimit(5), isNull);
    });

    test('资源上限按等级与属性结算', () {
      final resources = _resolveAstralKnight().resourcesAt(7, const {
        'cha': 16,
      });
      expect(resources.single.id, 'surge');
      expect(resources.single.name, '星界涌动');
      expect(resources.single.maximum, 7);
      expect(resources.single.recovery, 'shortRestOne');
    });
  });

  test('未知职业不猜：数值为空而非回退到相近职业', () {
    final rules = Dnd5eRules.resolveClassRules(
      entryId: 'my-pack:class/unknown',
      classSummary: '星界游侠',
    );
    expect(rules.hitDie, isNull);
    expect(rules.spellSlots(5), isEmpty);
    expect(rules.preparedLimit(5), isNull);
    expect(rules.savingThrowAbilities, isEmpty);
    expect(rules.spellcastingAbility, isNull, reason: 'mode none 没有施法属性');
    expect(rules.resourcesAt(5, const {'cha': 16}), isEmpty);
  });

  test('展示名 → slug 解析走唯一入口（精确 / 别名+分隔符，禁止裸子串）', () {
    expect(Dnd5eRules.resolveClassSlug(classSummary: '战士'), 'fighter');
    expect(Dnd5eRules.resolveClassSlug(classSummary: 'Fighter'), 'fighter');
    expect(Dnd5eRules.resolveClassSlug(classSummary: '法师 / Wizard'), 'wizard');
    expect(Dnd5eRules.resolveClassSlug(classSummary: '星界游侠'), isEmpty);
    expect(Dnd5eRules.resolveClassSlug(classSummary: '自定义职业'), isEmpty);
    // 条目身份优先于展示名。
    expect(
      Dnd5eRules.resolveClassSlug(
        entryId: 'my-pack:class/astral-knight',
        classSummary: '战士',
      ),
      'astral-knight',
    );
  });

  group('角色卡 classResources：CHA 16 的吟游诗人', () {
    CharacterSheet bard() =>
        CharacterSheet.local(
          id: 'char-bard',
          name: '竖琴手',
          level: 1,
          classSummary: '吟游诗人',
        ).copyWith(
          abilities: const <String, Object?>{
            'str': 8,
            'dex': 14,
            'con': 14,
            'int': 10,
            'wis': 10,
            'cha': 16,
          },
          data: <String, Object?>{
            'classIdentity': <String, Object?>{
              'entryId': 'guide:class/bard',
              'slug': 'bard',
              'name': '吟游诗人',
            },
          },
        );

    test('诗人激励上限 == CHA 调整值（3），不是固定 1', () {
      final resources = bard().classResources;
      expect(resources.single.id, 'bardic_inspiration');
      expect(resources.single.name, '诗人激励');
      expect(resources.single.maximum, 3);
      expect(resources.single.recovery, 'longRest');
    });

    test('能力值会把「诗人激励」上限带到其它职业资源调用点', () {
      // 同一份档案规则，直接走新 API 也必须是 3。
      final rules = Dnd5eRules.resolveClassRules(
        entryId: 'guide:class/bard',
        classSummary: '吟游诗人',
      );
      expect(
        Dnd5eRules.classResourcesFromRules(
          rules: rules,
          level: 1,
          abilities: const {'cha': 16},
        ).single.maximum,
        3,
      );
      // 缺省（未传 abilities）按属性 10 计算，不崩。
      expect(
        Dnd5eRules.classResourcesFromRules(
          rules: rules,
          level: 1,
        ).single.maximum,
        1,
      );
    });
  });
}
