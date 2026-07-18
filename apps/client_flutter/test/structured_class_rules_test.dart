import 'package:dnd_table_client/src/features/characters/domain/structured_class_rules.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads normalized saving throws and skill choice fields', () {
    const entry = ContentEntry(
      id: 'test:class/warden',
      type: 'class',
      slug: 'warden',
      name: '守望者',
      body: [],
      revision: 1,
      structured: {
        'savingThrowAbilities': ['str', 'wis'],
        'skillChoice': {
          'count': 2,
          'options': ['运动', '察觉', '求生'],
        },
      },
    );

    expect(StructuredClassRules.savingThrowAbilities(entry), {'str', 'wis'});
    expect(StructuredClassRules.skillChoice(entry).count, 2);
    expect(StructuredClassRules.skillChoice(entry).options, ['运动', '察觉', '求生']);
  });

  test('supports current PHB package proficiency strings', () {
    const entry = ContentEntry(
      id: 'test:class/fighter',
      type: 'class',
      slug: 'fighter',
      name: '战士',
      body: [],
      revision: 1,
      structured: {
        'savingThrows': '力量与体质',
        'skills': '选择2项：特技、驯兽、运动、历史、洞悉、威吓、游说、察觉、求生',
      },
    );

    expect(StructuredClassRules.savingThrowAbilities(entry), {'str', 'con'});
    expect(StructuredClassRules.skillChoice(entry).count, 2);
    expect(StructuredClassRules.skillChoice(entry).options, contains('运动'));
    expect(StructuredClassRules.skillChoice(entry).options, contains('察觉'));
    expect(StructuredClassRules.skillChoice(entry).options, contains('杂技'));
    expect(StructuredClassRules.skillChoice(entry).options, contains('说服'));
  });

  group('preparedSpellLimit', () {
    test('returns modifier + level for prepared casters', () {
      const entry = ContentEntry(
        id: 'test:class/cleric',
        type: 'class',
        slug: 'cleric',
        name: '牧师',
        body: [],
        revision: 1,
        structured: {
          'spellcastingAbility': 'wis',
          'preparedSpellcasting': true,
        },
      );

      // 感知 16 → 调整值 +3，等级 1 → 上限 4
      expect(
        StructuredClassRules.preparedSpellLimit(
          entry,
          abilities: const {'wis': 16},
          level: 1,
        ),
        4,
      );
      // 等级 5、感知 18 → +4 + 5 = 9
      expect(
        StructuredClassRules.preparedSpellLimit(
          entry,
          abilities: const {'wis': 18},
          level: 5,
        ),
        9,
      );
      // 最低 1
      expect(
        StructuredClassRules.preparedSpellLimit(
          entry,
          abilities: const {'wis': 3},
          level: 1,
        ),
        1,
      );
    });

    test('returns null when preparedSpellcasting is missing or false', () {
      const notPrepared = ContentEntry(
        id: 'test:class/sorcerer',
        type: 'class',
        slug: 'sorcerer',
        name: '术士',
        body: [],
        revision: 1,
        structured: {'spellcastingAbility': 'cha'},
      );
      expect(
        StructuredClassRules.preparedSpellLimit(
          notPrepared,
          abilities: const {'cha': 20},
          level: 10,
        ),
        isNull,
      );

      const explicitlyFalse = ContentEntry(
        id: 'test:class/warlock',
        type: 'class',
        slug: 'warlock',
        name: '邪术师',
        body: [],
        revision: 1,
        structured: {
          'spellcastingAbility': 'cha',
          'preparedSpellcasting': false,
        },
      );
      expect(
        StructuredClassRules.preparedSpellLimit(
          explicitlyFalse,
          abilities: const {'cha': 20},
          level: 10,
        ),
        isNull,
      );
    });

    test('returns null when spellcastingAbility is missing', () {
      const entry = ContentEntry(
        id: 'test:class/fighter',
        type: 'class',
        slug: 'fighter',
        name: '战士',
        body: [],
        revision: 1,
        structured: {'preparedSpellcasting': true},
      );
      expect(
        StructuredClassRules.preparedSpellLimit(
          entry,
          abilities: const {'int': 16},
          level: 3,
        ),
        isNull,
      );
    });
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
