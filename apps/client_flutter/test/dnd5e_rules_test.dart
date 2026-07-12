import 'package:dnd_table_client/src/features/characters/domain/dnd5e_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Dnd5eRules', () {
    test(
      'calculates ability modifiers and formats them for character sheets',
      () {
        expect(Dnd5eRules.abilityModifier(8), -1);
        expect(Dnd5eRules.abilityModifier(10), 0);
        expect(Dnd5eRules.abilityModifier(15), 2);
        expect(Dnd5eRules.formatModifier(2), '+2');
        expect(Dnd5eRules.formatModifier(-1), '-1');
      },
    );

    test('calculates proficiency bonus by level', () {
      expect(Dnd5eRules.proficiencyBonus(1), 2);
      expect(Dnd5eRules.proficiencyBonus(4), 2);
      expect(Dnd5eRules.proficiencyBonus(5), 3);
      expect(Dnd5eRules.proficiencyBonus(17), 6);
    });

    test(
      'calculates saves and skills from abilities and proficiency flags',
      () {
        const abilities = {
          'str': 10,
          'dex': 14,
          'con': 12,
          'int': 8,
          'wis': 16,
          'cha': 13,
        };

        expect(
          Dnd5eRules.saveBonus(
            ability: 'wis',
            abilities: abilities,
            level: 5,
            proficient: true,
          ),
          6,
        );
        expect(
          Dnd5eRules.skillBonus(
            skillName: '察觉',
            abilities: abilities,
            level: 5,
            proficient: true,
          ),
          6,
        );
        expect(
          Dnd5eRules.skillBonus(
            skillName: '调查',
            abilities: abilities,
            level: 5,
            proficient: false,
          ),
          -1,
        );
      },
    );

    test('derives basic combat values for a starter character', () {
      const abilities = {
        'str': 10,
        'dex': 14,
        'con': 12,
        'int': 10,
        'wis': 10,
        'cha': 10,
      };

      expect(Dnd5eRules.baseArmorClass(abilities), 12);
      expect(Dnd5eRules.initiativeBonus(abilities), 2);
      expect(
        Dnd5eRules.averageHitPoints(
          className: '战士',
          level: 3,
          abilities: abilities,
        ),
        25,
      );
    });

    test('derives weapon attacks and spell save dc for sheet actions', () {
      const abilities = {
        'str': 10,
        'dex': 14,
        'con': 12,
        'int': 10,
        'wis': 14,
        'cha': 8,
      };

      final longbow = Dnd5eRules.weaponProfile('长弓');

      expect(longbow?.name, '长弓');
      expect(
        Dnd5eRules.attackBonus(
          abilities: abilities,
          level: 3,
          ability: longbow!.ability,
        ),
        4,
      );
      expect(Dnd5eRules.damageFormula(longbow, abilities), '1d8+2');
      expect(Dnd5eRules.spellcastingAbility('Ranger'), 'wis');
      expect(
        Dnd5eRules.spellSaveDc(
          classSummary: 'Ranger',
          abilities: abilities,
          level: 3,
        ),
        12,
      );
    });

    test('derives class resource maximums for frequent runtime tracking', () {
      final fighterOne = Dnd5eRules.classResourceMaximums(
        classSummary: '战士',
        level: 1,
      );
      final fighterTwo = Dnd5eRules.classResourceMaximums(
        classSummary: 'Fighter',
        level: 2,
      );
      final barbarian = Dnd5eRules.classResourceMaximums(
        classSummary: '野蛮人',
        level: 3,
      );

      expect(fighterOne, {'second_wind': 2});
      expect(fighterTwo, {'second_wind': 2, 'action_surge': 1});
      expect(barbarian, {'rage': 3});
    });
  });
}
