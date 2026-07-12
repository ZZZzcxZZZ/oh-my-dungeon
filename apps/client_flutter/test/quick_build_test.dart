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
        {'id': 'second_wind', 'name': '第二气息', 'maximum': 2},
        {'id': 'action_surge', 'name': '动作如潮', 'maximum': 1},
      ]);
      expect(draft.data['runtime'], {
        'classResourcesUsed': {'second_wind': 0, 'action_surge': 0},
      });
    });
  });
}
