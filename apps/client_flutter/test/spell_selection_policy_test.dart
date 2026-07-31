import 'package:dnd_table_client/src/features/characters/domain/spell_selection_policy.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ContentEntry spell({
    required String id,
    required String name,
    required int level,
    required List<String> tags,
    String school = '防护',
  }) {
    return ContentEntry.fromJson({
      'id': id,
      'type': 'spell',
      'slug': id.split('/').last,
      'name': name,
      'body': <Map<String, Object?>>[],
      'revision': 1,
      'structured': {'level': level, 'school': school},
      'tags': tags,
    });
  }

  ContentEntry customClass() => ContentEntry.fromJson({
    'id': 'test:class/chronomancer',
    'type': 'class',
    'slug': 'chronomancer',
    'name': '时术师',
    'body': <Map<String, Object?>>[],
    'revision': 1,
    'structured': {
      'spellcasting': {
        'mode': 'known',
        'ability': 'int',
        'listTags': ['spell-list:chronomancer'],
        'progression': [
          {
            'level': 1,
            'maximumSpellLevel': 1,
            'maximumCantrips': 2,
            'maximumLeveledSpells': 3,
          },
          {
            'level': 5,
            'maximumSpellLevel': 3,
            'maximumCantrips': 3,
            'maximumLeveledSpells': 8,
          },
        ],
      },
    },
  });

  test('custom class sees only spells allowed by its declarative rules', () {
    final rules = SpellSelectionPolicy.rulesFor(
      classEntry: customClass(),
      characterLevel: 1,
    );
    final options = SpellSelectionPolicy.eligibleSpells(
      entries: [
        spell(
          id: 'test:spell/fire-bolt',
          name: '火焰箭',
          level: 0,
          tags: ['spell-list:chronomancer'],
        ),
        spell(
          id: 'test:spell/alarm',
          name: '警报术',
          level: 1,
          tags: ['spell-list:chronomancer'],
        ),
        spell(
          id: 'test:spell/wish',
          name: '祈愿术',
          level: 9,
          tags: ['spell-list:chronomancer'],
        ),
        spell(
          id: 'test:spell/cure-wounds',
          name: '疗伤术',
          level: 1,
          tags: ['spell-list:divine'],
        ),
      ],
      rules: rules,
    );

    expect(options.map((entry) => entry.name), ['火焰箭', '警报术']);
    expect(rules.maximumCantrips, 2);
    expect(rules.maximumLeveledSpells, 3);
    expect(rules.maximumSpellLevel, 1);
  });

  test('uses the latest progression row at or below the character level', () {
    final rules = SpellSelectionPolicy.rulesFor(
      classEntry: customClass(),
      characterLevel: 7,
    );
    expect(rules.mode, 'known');
    expect(rules.maximumCantrips, 3);
    expect(rules.maximumLeveledSpells, 8);
    expect(rules.maximumSpellLevel, 3);
  });

  test('class without spell rules exposes no automatic spell choices', () {
    final entry = ContentEntry.fromJson({
      'id': 'test:class/manual',
      'type': 'class',
      'slug': 'manual',
      'name': '自定义职业',
      'body': <Map<String, Object?>>[],
      'revision': 1,
    });
    final rules = SpellSelectionPolicy.rulesFor(
      classEntry: entry,
      characterLevel: 20,
    );
    expect(rules.configured, isFalse);
    expect(
      SpellSelectionPolicy.eligibleSpells(entries: const [], rules: rules),
      isEmpty,
    );
  });
}
