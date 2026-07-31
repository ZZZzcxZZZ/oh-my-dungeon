import 'package:dnd_table_client/src/features/characters/domain/monster_template_factory.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds a fully editable character draft from a monster entry', () {
    final draft = MonsterTemplateFactory.fromEntry(
      ContentEntry.fromJson({
        'id': 'private-mm:monster/zombie',
        'type': 'monster',
        'slug': 'zombie',
        'name': '丧尸',
        'revision': 2,
        'body': const <Object?>[],
        'structured': {
          'characterTemplate': {
            'kind': 'monster',
            'templateRef': 'private-mm:monster/zombie',
            'size': 'medium',
            'creatureType': '亡灵',
            'alignment': '中立邪恶',
            'armorClass': 8,
            'initiativeBonus': -2,
            'hitPoints': {'maximum': 15, 'formula': '2d8+6'},
            'speed': {'walk': 20},
            'abilities': {
              'str': 13,
              'dex': 6,
              'con': 16,
              'int': 3,
              'wis': 6,
              'cha': 5,
            },
            'challengeRating': '1/4',
            'proficiencyBonus': 2,
            'description': '腐朽的尸体被死灵能量驱动。',
            'sections': {'特质': '### 不死坚韧\n\n说明', '动作': '### 猛击\n\n命中造成伤害。'},
            'actions': {
              'normal': [
                {
                  'id': 'slam',
                  'name': '猛击',
                  'description': '近战武器攻击。',
                  'damage': {'expression': '1d6+1', 'type': '钝击'},
                },
              ],
              'bonus': <Object?>[],
              'reactions': <Object?>[],
              'legendary': <Object?>[],
              'lair': <Object?>[],
            },
          },
        },
        'source': {'label': '怪物图鉴 2024'},
      }),
    );

    expect(draft.name, '丧尸');
    expect(draft.currentHp, 15);
    expect(draft.maxHp, 15);
    expect(draft.armorClass, 8);
    expect(draft.speed, 20);
    expect(draft.initiativeBonus, -2);
    expect(draft.abilities['con'], 16);
    expect(draft.data['character'], containsPair('kind', 'monster'));
    expect(draft.data['character'], containsPair('hitPointFormula', '2d8+6'));
    expect(draft.data['description'], '腐朽的尸体被死灵能量驱动。');
    expect(draft.notes, isEmpty);
    expect(draft.data['actions'], contains(containsPair('id', 'slam')));
    expect(
      draft.data['markdownSections'],
      containsPair('动作', '### 猛击\n\n命中造成伤害。'),
    );
    expect(draft.contentReferences.single.entryKey, draft.data['templateRef']);
  });

  test('rejects entries without a valid character template', () {
    final entry = ContentEntry.fromJson({
      'id': 'example:item/rope',
      'type': 'item',
      'slug': 'rope',
      'name': '绳索',
      'revision': 1,
      'body': const <Object?>[],
    });

    expect(
      () => MonsterTemplateFactory.fromEntry(entry),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'projects canonical monster groups into editable character sections',
    () {
      final draft = MonsterTemplateFactory.fromEntry(
        ContentEntry.fromJson({
          'id': 'private-mm:monster/night-hag',
          'type': 'monster',
          'slug': 'night-hag',
          'name': '夜鬼婆',
          'revision': 1,
          'body': const <Object?>[],
          'structured': {
            'characterTemplate': {
              'kind': 'monster',
              'description': '在梦境中追猎受害者的邪魔。',
              'creatureType': 'fiend',
              'senses': ['黑暗视觉 120 尺'],
              'languages': ['深渊语', '炼狱语'],
              'challenge': {'rating': '5', 'proficiencyBonus': 3},
              'hitPoints': {'maximum': 112},
              'speed': {'walk': 30},
              'abilities': const <String, int>{},
              'traits': [
                {
                  'id': 'magic-resistance',
                  'name': '魔法抗性',
                  'description': '对抗法术的豁免具有优势。',
                },
              ],
              'actions': [
                {'id': 'claws', 'name': '爪击', 'description': '近战武器攻击。'},
              ],
              'bonusActions': [
                {'id': 'etherealness', 'name': '以太化', 'description': '进入以太位面。'},
              ],
              'reactions': [
                {'id': 'rebuke', 'name': '斥退', 'description': '回应一次命中。'},
              ],
              'legendaryActions': [
                {'id': 'move', 'name': '移动', 'description': '移动至多其速度。'},
              ],
              'spellcasting': [
                {
                  'id': 'innate-spellcasting',
                  'name': '天生施法',
                  'description': '施法属性为魅力。',
                  'ability': 'cha',
                },
              ],
            },
          },
        }),
      );

      final monster = draft.data['monster'] as Map<Object?, Object?>;
      final sections = draft.data['markdownSections'] as Map<Object?, Object?>;
      final actions = draft.data['actions'] as List<Object?>;

      expect(draft.data['description'], '在梦境中追猎受害者的邪魔。');
      expect(monster['traits'], hasLength(1));
      expect(monster['spellcasting'], hasLength(1));
      expect(monster['senses'], ['黑暗视觉 120 尺']);
      expect(monster['languages'], ['深渊语', '炼狱语']);
      expect(monster['challenge'], {'rating': '5', 'proficiencyBonus': 3});
      expect(sections['特性'], contains('### 魔法抗性'));
      expect(sections['动作'], contains('### 爪击'));
      expect(sections['附赠动作'], contains('### 以太化'));
      expect(sections['反应'], contains('### 斥退'));
      expect(sections['传奇动作'], contains('### 移动'));
      expect(sections['施法'], contains('### 天生施法'));
      expect(
        actions,
        contains(
          allOf(
            containsPair('id', 'claws'),
            containsPair('actionType', 'action'),
          ),
        ),
      );
      expect(
        actions,
        contains(
          allOf(
            containsPair('id', 'etherealness'),
            containsPair('actionType', 'bonusAction'),
          ),
        ),
      );
      expect(sections.values.join('\n'), isNot(contains('在梦境中追猎受害者的邪魔。')));
    },
  );
}
