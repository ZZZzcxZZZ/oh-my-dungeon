import 'package:dnd_table_client/src/features/characters/domain/quick_build.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QuickBuildService', () {
    test('builds a playable D&D 2024 fighter draft', () {
      const selection = QuickBuildSelection(
        name: 'Kara',
        className: '战士',
        species: '人类',
        background: '士兵',
        level: 1,
      );

      final draft = QuickBuildService.build(selection);

      expect(draft.name, 'Kara');
      expect(draft.classSummary, '战士');
      expect(draft.raceSummary, '人类');
      expect(draft.level, 1);
      expect(draft.abilities['str'], 16);
      expect(draft.maxHp, 12);
      expect(draft.currentHp, draft.maxHp);
      expect(draft.armorClass, 12);
      expect(draft.saves['str'], isTrue);
      expect(draft.saves['con'], isTrue);
      expect(draft.skills['运动'], isTrue);
      expect(draft.inventory, contains(equals({'name': '长剑', 'quantity': 1})));
      expect(draft.notes, contains('D&D 2024'));
    });

    test('uses class and background presets for casters and scholars', () {
      const selection = QuickBuildSelection(
        name: 'Mira',
        className: '法师',
        species: '精灵',
        background: '贤者',
        level: 3,
      );

      final draft = QuickBuildService.build(selection);

      expect(draft.abilities['int'], 16);
      expect(draft.saves['int'], isTrue);
      expect(draft.skills['奥秘'], isTrue);
      expect(draft.skills['历史'], isTrue);
      expect(draft.inventory, contains(equals({'name': '法术书', 'quantity': 1})));
      expect(draft.maxHp, greaterThan(0));
    });

    test('uses core class presets for bilingual content labels', () {
      const selection = QuickBuildSelection(
        name: 'Mira',
        className: '法师 / Wizard',
        species: '精灵 / Elf',
        background: '贤者 / Sage',
        level: 3,
      );

      final draft = QuickBuildService.build(selection);

      expect(draft.abilities['int'], 16);
      expect(draft.saves['int'], isTrue);
      expect(draft.saves['wis'], isTrue);
      expect(draft.skills['奥秘'], isTrue);
      expect(draft.skills['历史'], isTrue);
      expect(draft.inventory, contains(equals({'name': '法术书', 'quantity': 1})));
      expect(draft.maxHp, 20);
    });

    test('uses custom ability scores and recalculates derived stats', () {
      const selection = QuickBuildSelection(
        name: 'Tamsin',
        className: '战士',
        species: '人类',
        background: '士兵',
        level: 1,
        abilities: {
          'str': 15,
          'dex': 12,
          'con': 13,
          'int': 10,
          'wis': 8,
          'cha': 14,
        },
      );

      final draft = QuickBuildService.build(selection);

      expect(draft.abilities, selection.abilities);
      expect(draft.maxHp, 11);
      expect(draft.currentHp, 11);
      expect(draft.armorClass, 11);
      expect(draft.initiativeBonus, 1);
    });

    test('uses custom skill proficiencies over background defaults', () {
      const selection = QuickBuildSelection(
        name: 'Nia',
        className: '战士',
        species: '人类',
        background: '士兵',
        level: 1,
        skillProficiencies: ['察觉', '隐匿'],
      );

      final draft = QuickBuildService.build(selection);

      expect(draft.skills['运动'], isFalse);
      expect(draft.skills['威吓'], isFalse);
      expect(draft.skills['察觉'], isTrue);
      expect(draft.skills['隐匿'], isTrue);
    });

    test('adds class resources for runtime tracking', () {
      const selection = QuickBuildSelection(
        name: 'Kara',
        className: '战士',
        species: '人类',
        background: '士兵',
        level: 2,
      );

      final draft = QuickBuildService.build(selection);

      expect(draft.data['classResources'], [
        {
          'id': 'second_wind',
          'name': '第二气息',
          'maximum': 2,
          'recovery': 'shortRestOne',
        },
        {
          'id': 'action_surge',
          'name': '动作如潮',
          'maximum': 1,
          'recovery': 'shortRest',
        },
      ]);
      expect(draft.data['runtime'], {
        'classResourcesUsed': {'second_wind': 0, 'action_surge': 0},
      });
    });

    test('preserves rest recovery semantics for every class resource', () {
      const barbarian = QuickBuildSelection(
        name: 'Brun',
        className: '野蛮人',
        species: '半兽人',
        background: '士兵',
        level: 3,
      );

      final draft = QuickBuildService.build(barbarian);

      // 2024：狂暴短休恢复 1 次
      expect(draft.data['classResources'], [
        {
          'id': 'rage',
          'name': '狂暴',
          'maximum': 3,
          'recovery': 'shortRestOne',
        },
      ]);
    });

    test('uses the official 2024 saving throw proficiencies', () {
      const expectations = {
        '野蛮人': ['str', 'con'],
        '吟游诗人': ['dex', 'cha'],
        '牧师': ['wis', 'cha'],
        '德鲁伊': ['int', 'wis'],
        '战士': ['str', 'con'],
        '武僧': ['str', 'dex'],
        '圣武士': ['wis', 'cha'],
        '游侠': ['dex', 'str'],
        '游荡者': ['dex', 'int'],
        '术士': ['con', 'cha'],
        '邪术师': ['wis', 'cha'],
        '法师': ['int', 'wis'],
      };

      expectations.forEach((className, expected) {
        final draft = QuickBuildService.build(
          QuickBuildSelection(
            name: 'Test',
            className: className,
            species: '人类',
            background: '士兵',
            level: 1,
          ),
        );
        for (final ability in const ['str', 'dex', 'con', 'int', 'wis', 'cha']) {
          expect(
            draft.saves[ability],
            expected.contains(ability),
            reason: '$className 的 $ability 豁免',
          );
        }
      });
    });

    test('uses 2024 background skill proficiencies', () {
      final draft = QuickBuildService.build(
        const QuickBuildSelection(
          name: 'Vex',
          className: '游荡者',
          species: '人类',
          background: '罪犯',
          level: 1,
        ),
      );

      // 2024 罪犯背景：巧手 + 隐匿（2014 为欺瞒 + 隐匿）
      expect(draft.skills['巧手'], isTrue);
      expect(draft.skills['隐匿'], isTrue);
      expect(draft.skills['欺瞒'], isFalse);
    });

    test('barbarian hit points use the d12 hit die', () {
      final draft = QuickBuildService.build(
        const QuickBuildSelection(
          name: 'Brun',
          className: '野蛮人',
          species: '半兽人',
          background: '士兵',
          level: 1,
        ),
      );

      // 预设力量型属性 CON 14 → 12 + 2
      expect(draft.maxHp, 14);
    });

    test(
      'stores readable structured story fields without hiding them in notes',
      () {
        const selection = QuickBuildSelection(
          name: 'Aria',
          className: '吟游诗人',
          species: '人类',
          background: '艺人',
          level: 1,
          appearance: '银色短发，旅行斗篷',
          personalityTraits: '遇事先讲一个故事',
          ideals: '自由',
          bonds: '寻找失踪的导师',
          flaws: '过度自信',
          backstory: '在沿海剧团长大。',
          privateNotes: '不向队友公开真实姓氏。',
        );

        final draft = QuickBuildService.build(selection);

        expect(draft.data['story'], {
          'appearance': '银色短发，旅行斗篷',
          'personalityTraits': '遇事先讲一个故事',
          'ideals': '自由',
          'bonds': '寻找失踪的导师',
          'flaws': '过度自信',
          'backstory': '在沿海剧团长大。',
          'privateNotes': '不向队友公开真实姓氏。',
        });
        expect(draft.notes, isNot(contains('不向队友公开真实姓氏')));
      },
    );
  });
}
