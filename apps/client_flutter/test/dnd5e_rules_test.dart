import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/characters/domain/dnd5e_rules.dart';
import 'package:dnd_table_client/src/features/characters/domain/weapon_attack_derivation.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
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

      // 任务 8：武器数值来自物品条目自身的声明，物品名映射表已删除。
      final longbow = _weaponEntry(
        id: 'guide:equipment/longbow',
        name: '长弓',
        structured: const {'category': '远程武器', 'damage': '1d8 穿刺'},
      );
      final ability = Dnd5eRules.weaponAbility(longbow.structured)!;

      expect(longbow.name, '长弓');
      expect(ability, 'dex');
      expect(
        Dnd5eRules.attackBonus(
          abilities: abilities,
          level: 3,
          ability: ability,
        ),
        4,
      );
      expect(
        Dnd5eRules.damageFormula(
          Dnd5eWeaponProfile(
            name: longbow.name,
            ability: ability,
            damageDie: '1d8',
            damageType: '穿刺',
          ),
          abilities,
        ),
        '1d8+2',
      );
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

    test('weaponAbility 只读条目声明，不按物品名猜', () {
      // ability 显式声明优先。
      expect(
        Dnd5eRules.weaponAbility(const {'ability': 'dex', 'category': '军用武器'}),
        'dex',
      );
      // 灵巧（finesse 或 properties 里的「灵巧」）→ dex。
      expect(Dnd5eRules.weaponAbility(const {'finesse': true}), 'dex');
      expect(
        Dnd5eRules.weaponAbility(const {
          'category': '军用武器',
          'properties': '灵巧，轻型',
        }),
        'dex',
      );
      // 远程类别 → dex；近战默认 str。
      expect(Dnd5eRules.weaponAbility(const {'category': '远程武器'}), 'dex');
      expect(Dnd5eRules.weaponAbility(const {'category': '军用武器'}), 'str');
      expect(Dnd5eRules.weaponAbility(null), isNull);
    });
  });

  group('WeaponAttackDerivation（物品条目声明驱动）', () {
    final character =
        CharacterSheet.local(
          id: 'char-1',
          name: 'Arannis',
          level: 3,
          classSummary: 'Ranger',
        ).copyWith(
          abilities: const <String, Object?>{
            'str': 10,
            'dex': 14,
            'con': 12,
            'int': 10,
            'wis': 14,
            'cha': 8,
          },
          inventory: const <Map<String, Object?>>[
            <String, Object?>{
              'entryId': 'guide:equipment/longbow',
              'name': '长弓',
              'quantity': 1,
            },
            <String, Object?>{
              'entryId': 'guide:equipment/longsword',
              'name': '长剑',
              'quantity': 1,
            },
            <String, Object?>{
              'entryId': 'guide:equipment/rope',
              'name': '麻绳',
              'quantity': 1,
            },
            <String, Object?>{'name': '无名物品', 'quantity': 1},
          ],
        );

    final entries = <ContentEntry>[
      _weaponEntry(
        id: 'guide:equipment/longbow',
        name: '长弓',
        structured: const {'category': '远程武器', 'damage': '1d8 穿刺'},
      ),
      _weaponEntry(
        id: 'guide:equipment/longsword',
        name: '长剑',
        structured: const {'category': '军用武器', 'damage': '1d8 挥砍'},
      ),
      _weaponEntry(
        id: 'guide:equipment/rope',
        name: '麻绳',
        structured: const {'category': '冒险装备'},
      ),
    ];

    test('按 structured.damage / category 派生攻击', () {
      final attacks = WeaponAttackDerivation.derive(
        character: character,
        contentEntries: entries,
      );

      expect(attacks, hasLength(2));
      final longbow = attacks.first;
      expect(longbow.name, '长弓');
      expect(longbow.bonus, 4);
      expect(longbow.toHit, '+4 命中');
      expect(longbow.damageFormula, '1d8+2');
      expect(longbow.damage, '1d8+2 穿刺');
      expect(longbow.damageType, '穿刺');

      // 近战军用武器 → 力量（STR 10 → +0）。
      final longsword = attacks.last;
      expect(longsword.name, '长剑');
      expect(longsword.bonus, 2, reason: '力量 +0，熟练 +2');
      expect(longsword.damageFormula, '1d8');
      expect(longsword.damage, '1d8 挥砍');
      expect(longsword.damageType, '挥砍');
    });

    test('未声明伤害的物品不产出攻击（不猜）', () {
      final attacks = WeaponAttackDerivation.derive(
        character: character,
        contentEntries: entries,
      );
      expect(attacks.map((attack) => attack.name), isNot(contains('麻绳')));
      expect(attacks, hasLength(2));
    });

    test('灵巧武器在 str / dex 中取较高者', () {
      final finesseCharacter = character.copyWith(
        abilities: const <String, Object?>{
          'str': 8,
          'dex': 16,
          'con': 12,
          'int': 10,
          'wis': 14,
          'cha': 8,
        },
        inventory: const <Map<String, Object?>>[
          <String, Object?>{
            'entryId': 'guide:equipment/dagger',
            'name': '匕首',
            'quantity': 1,
          },
        ],
      );
      final attacks = WeaponAttackDerivation.derive(
        character: finesseCharacter,
        contentEntries: <ContentEntry>[
          _weaponEntry(
            id: 'guide:equipment/dagger',
            name: '匕首',
            // 真实 PHB 数据把"灵巧"写在 properties 里，而不是布尔字段。
            structured: const {
              'category': '简易武器',
              'damage': '1d4 穿刺',
              'properties': '灵巧，轻型，投掷（射程 20/60）',
            },
          ),
        ],
      );

      expect(attacks.single.bonus, 5, reason: 'DEX 16 → +3，熟练 +2');
      expect(attacks.single.damageFormula, '1d4+3');
    });

    test('条目不在资料库（或物品名相同但没有 entryId）时不产出攻击', () {
      final orphan = character.copyWith(
        inventory: const <Map<String, Object?>>[
          <String, Object?>{'name': '长弓', 'quantity': 1},
        ],
      );
      expect(
        WeaponAttackDerivation.derive(
          character: orphan,
          contentEntries: entries,
        ),
        isEmpty,
      );
    });
  });
}

ContentEntry _weaponEntry({
  required String id,
  required String name,
  required Map<String, Object?> structured,
}) {
  return ContentEntry.fromJson({
    'id': id,
    'type': 'equipment',
    'slug': id.split('/').last,
    'name': name,
    'body': <Map<String, Object?>>[],
    'revision': 1,
    'structured': structured,
  });
}
