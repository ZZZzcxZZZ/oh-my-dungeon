import 'package:dnd_table_client/src/features/characters/domain/rules_driven_character_builder.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:dnd_table_client/src/features/rules/domain/character_build.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds a traceable character sheet from D&D 2024 content rules', () {
    final fighter = _entry(
      id: 'test:class/fighter',
      type: 'class',
      name: '战士',
      structured: {'hitDie': 'd10'},
      rules: {
        'grants': [
          {
            'id': 'strength-save',
            'kind': 'proficiency',
            'target': 'save:str',
            'label': '力量豁免',
          },
          {
            'id': 'fighter-ac',
            'kind': 'armorClass',
            'value': 1,
            'label': '防御加值',
          },
        ],
        'progression': [
          {
            'level': 1,
            'grants': [
              {
                'id': 'second-wind',
                'kind': 'feature',
                'entryId': 'test:class-feature/second-wind',
                'label': '回气',
              },
            ],
          },
        ],
      },
    );
    final background = _entry(
      id: 'test:background/soldier',
      type: 'background',
      name: '士兵',
      rules: {
        'grants': [
          {
            'id': 'athletics',
            'kind': 'proficiency',
            'target': 'skill:运动',
            'label': '运动熟练',
          },
        ],
      },
    );
    final species = _entry(
      id: 'test:species/human',
      type: 'species',
      name: '人类',
      rules: {
        'grants': [
          {
            'id': 'walking-speed',
            'kind': 'speed',
            'value': 30,
            'label': '步行速度',
          },
        ],
      },
    );
    final feature = _entry(
      id: 'test:class-feature/second-wind',
      type: 'classFeature',
      name: '回气',
      rules: const {},
    );
    final entries = {
      for (final entry in [fighter, background, species, feature])
        entry.id: entry,
    };
    final builder = RulesDrivenCharacterBuilder(entries: entries);

    final draft = builder.build(
      name: '阿兰尼斯',
      build: const CharacterBuild(
        level: 1,
        selections: {
          'class': 'test:class/fighter',
          'background': 'test:background/soldier',
          'species': 'test:species/human',
        },
      ),
      abilities: const {
        'str': 16,
        'dex': 14,
        'con': 14,
        'int': 10,
        'wis': 12,
        'cha': 8,
      },
    );

    expect(draft.classSummary, '战士');
    expect(draft.raceSummary, '人类');
    expect(draft.maxHp, 12);
    expect(draft.armorClass, 13);
    expect(draft.speed, 30);
    expect(draft.saves['str'], isTrue);
    expect(draft.skills['运动'], isTrue);
    expect(
      (draft.data['build'] as Map<String, Object?>)['selections'],
      containsPair('class', 'test:class/fighter'),
    );
    expect(
      (draft.data['contentRefs'] as Map<String, Object?>)['features'],
      contains('test:class-feature/second-wind'),
    );
    expect(
      draft.data['resolvedGrants'],
      contains(containsPair('sourceEntryName', '战士')),
    );

    final character = draft.toLocalCharacter();
    expect(
      character.contentReferences.map((reference) => reference.entryKey),
      containsAll([
        'test:class/fighter',
        'test:background/soldier',
        'test:species/human',
      ]),
    );
  });

  test('uses structured class saves and preserves guided skill choices', () {
    final fighter = _entry(
      id: 'test:class/fighter',
      type: 'class',
      name: '战士',
      structured: const {'hitDie': 'd10', 'savingThrows': '力量与体质'},
      rules: const {
        'progression': [
          {
            'level': 1,
            'grants': [
              {'id': 'second-wind', 'kind': 'feature', 'label': '回气'},
            ],
          },
        ],
      },
    );
    final builder = RulesDrivenCharacterBuilder(entries: {fighter.id: fighter});

    final draft = builder.build(
      name: '莱娅',
      build: const CharacterBuild(
        level: 1,
        selections: {'class': 'test:class/fighter'},
      ),
      abilities: const {
        'str': 15,
        'dex': 13,
        'con': 14,
        'int': 10,
        'wis': 12,
        'cha': 8,
      },
      skillProficiencies: const ['运动', '察觉'],
    );

    expect(draft.saves['str'], isTrue);
    expect(draft.saves['con'], isTrue);
    expect(draft.saves['dex'], isFalse);
    expect(draft.skills['运动'], isTrue);
    expect(draft.skills['察觉'], isTrue);
  });
  test('persists only rule-approved choices and keeps explicit extras', () {
    final mage = _entry(
      id: 'test:class/mage',
      type: 'class',
      name: 'Mage',
      rules: const {
        'choices': [
          {
            'id': 'cantrip',
            'label': 'Cantrip',
            'optionType': 'spell',
            'minimum': 1,
            'maximum': 1,
            'optionTags': ['spell-list:mage'],
          },
        ],
      },
    );
    final invalid = _entry(
      id: 'test:spell/invalid',
      type: 'spell',
      name: 'Invalid',
      tags: const ['spell-list:priest'],
      rules: const {},
    );
    final extraItem = _entry(
      id: 'test:equipment/rope',
      type: 'equipment',
      name: 'Rope',
      rules: const {},
    );
    final builder = RulesDrivenCharacterBuilder(
      entries: {mage.id: mage, invalid.id: invalid, extraItem.id: extraItem},
    );

    final draft = builder.build(
      name: 'Aria',
      build: const CharacterBuild(
        level: 1,
        selections: {'class': 'test:class/mage'},
        choices: {
          'test:class/mage#cantrip': ['test:spell/invalid'],
        },
      ),
      abilities: const {
        'str': 8,
        'dex': 14,
        'con': 14,
        'int': 16,
        'wis': 12,
        'cha': 10,
      },
      extraItemRefs: const ['test:equipment/rope'],
    );

    final refs = draft.data['contentRefs'] as Map<String, Object?>;
    expect(refs['spells'], isEmpty);
    expect(refs['items'], ['test:equipment/rope']);
    final persistedBuild = draft.data['build'] as Map<String, Object?>;
    expect(persistedBuild['choices'], {'test:class/mage#cantrip': <String>[]});
    expect(
      draft.contentReferences.map((reference) => reference.entryKey),
      isNot(contains('test:spell/invalid')),
    );
  });

  test('derives spell slots from resource grants instead of class names', () {
    final classEntry = _entry(
      id: 'test:class/arcanist',
      type: 'class',
      name: 'Arcanist',
      structured: const {'spellcastingAbility': 'int'},
      rules: const {
        'progression': [
          {
            'level': 1,
            'grants': [
              {
                'id': 'first-level-slots',
                'kind': 'resource',
                'label': 'First-level spell slots',
                'target': 'spellSlot:1',
                'value': 2,
              },
              {
                'id': 'arcane-recovery',
                'kind': 'resource',
                'label': 'Arcane Recovery',
                'value': 1,
                'data': {'recovery': 'shortRest'},
              },
            ],
          },
        ],
      },
    );

    final draft =
        RulesDrivenCharacterBuilder(entries: {classEntry.id: classEntry}).build(
          name: 'Aria',
          build: const CharacterBuild(
            level: 1,
            selections: {'class': 'test:class/arcanist'},
          ),
          abilities: const {
            'str': 8,
            'dex': 14,
            'con': 14,
            'int': 16,
            'wis': 12,
            'cha': 10,
          },
        );

    expect(draft.data['spellSlots'], {'1': 2});
    expect(draft.data['spellcastingAbility'], 'int');
    expect(draft.data['classResources'], [
      {
        'id': 'arcane-recovery',
        'name': 'Arcane Recovery',
        'maximum': 1,
        'recovery': 'shortRest',
      },
    ]);
  });
}

ContentEntry _entry({
  required String id,
  required String type,
  required String name,
  Map<String, Object?> structured = const {},
  List<String> tags = const [],
  required Map<String, Object?> rules,
}) {
  return ContentEntry.fromJson({
    'id': id,
    'type': type,
    'slug': id.split('/').last,
    'name': name,
    'body': <Map<String, Object?>>[],
    'revision': 1,
    'structured': structured,
    'tags': tags,
    'rules': rules,
  });
}
