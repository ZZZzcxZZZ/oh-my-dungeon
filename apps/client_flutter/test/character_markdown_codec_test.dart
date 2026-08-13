import 'package:dnd_table_client/src/features/characters/data/character_markdown_codec.dart';
import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const codec = CharacterMarkdownCodec();

  final character = CharacterSheet(
    id: 'char-1',
    ownerUserId: 'user-1',
    name: '阿兰尼斯',
    avatarUrl: null,
    system: 'dnd5e-2024',
    level: 5,
    classSummary: '游侠',
    raceSummary: '精灵',
    currentHp: 24,
    maxHp: 35,
    armorClass: 16,
    speed: 30,
    initiativeBonus: 3,
    abilities: const {
      'str': 10,
      'dex': 16,
      'con': 14,
      'int': 10,
      'wis': 15,
      'cha': 8,
    },
    saves: const {'str': true, 'dex': false},
    skills: const {'察觉': true, '隐匿': true},
    inventory: const [
      {'id': 'item-longbow', 'name': '长弓', 'quantity': 1, 'equipped': true},
    ],
    currency: const {'gp': 42, 'sp': 7},
    notes: '来自北方森林。\n正在寻找失踪的导师。',
    data: const {
      'characterState': {
        'schemaVersion': 2,
        'hitPoints': {'current': 24, 'maximum': 35, 'temporary': 3},
        'resources': [
          {
            'id': 'favored-foe',
            'name': '宿敌标记',
            'current': 2,
            'maximum': 3,
            'restoreOn': 'longRest',
            'custom': true,
          },
        ],
        'conditions': [
          {'id': 'poisoned', 'type': '中毒', 'remaining': 2},
        ],
        'items': [
          {'id': 'item-longbow', 'name': '长弓', 'quantity': 1, 'equipped': true},
        ],
        'extensions': {
          'homebrew.reputation': {'harpers': 2},
        },
      },
    },
    createdAt: '2026-07-01T00:00:00.000Z',
    updatedAt: '2026-07-26T00:00:00.000Z',
  );

  test('exports a readable Chinese character sheet with stable references', () {
    final markdown = codec.encode(
      character,
      mode: CharacterMarkdownMode.campaignSnapshot,
    );

    expect(markdown, startsWith('---\n'));
    expect(markdown, contains('format: dnd-table-character/v2'));
    expect(markdown, contains('revision: 1'));
    expect(markdown, contains(RegExp(r'contentHash: sha256:[0-9a-f]{64}')));
    expect(markdown, contains('generatedAt: 2026-07-26T00:00:00.000Z'));
    expect(markdown, contains('kind: player'));
    expect(markdown, contains('# 阿兰尼斯'));
    expect(markdown, contains('## 战斗'));
    expect(markdown, contains('| 当前 HP | 24 |'));
    expect(markdown, contains('<!-- dnd:id=poisoned -->'));
    expect(markdown, contains('<!-- dnd:id=item-longbow -->'));
    expect(markdown, contains('来自北方森林。'));
    expect(markdown, isNot(contains('"currentHp"')));
  });

  test('round trips standard fields, state, and namespaced extensions', () {
    final decoded = codec.decode(codec.encode(character));

    expect(decoded.mode, CharacterMarkdownMode.profile);
    expect(decoded.character.name, character.name);
    expect(decoded.character.level, 5);
    expect(decoded.character.abilityMap['dex'], 16);
    expect(decoded.character.saveMap['str'], isTrue);
    expect(decoded.character.saveMap['dex'], isFalse);
    expect(decoded.character.skillMap['察觉'], isTrue);
    expect(decoded.character.skillMap['隐匿'], isTrue);
    expect(decoded.character.currencyMap, {'gp': 42, 'sp': 7});
    expect(decoded.character.notes, character.notes);
    expect(decoded.state.hitPoints.temporary, 3);
    expect(decoded.state.resources.single.id, 'favored-foe');
    expect(decoded.state.conditions.single.type, '中毒');
    expect(decoded.state.items.single.name, '长弓');
    expect(decoded.state.extensions['homebrew.reputation'], {'harpers': 2});
  });

  test('round trips embedded rule snapshots without a content library', () {
    final withRules = character.copyWith(
      data: {
        ...character.dataMap,
        'contentRefs': {
          'features': ['core:feature/second-wind'],
          'spells': ['core:spell/shield'],
          'items': <String>[],
        },
        'ruleSnapshots': {
          'core:feature/second-wind': {
            'id': 'core:feature/second-wind',
            'type': 'classFeature',
            'name': '回气',
            'summary': '恢复生命值。',
            'body': [
              {'type': 'paragraph', 'text': '以附赠动作恢复生命值。'},
            ],
            'revision': 1,
          },
          'core:spell/shield': {
            'id': 'core:spell/shield',
            'type': 'spell',
            'name': '护盾术',
            'summary': '反应施放，AC 暂时提高。',
            'body': <Object?>[],
            'revision': 1,
          },
        },
      },
    );

    final markdown = codec.encode(withRules);
    final decoded = codec.decode(markdown).character;

    expect(markdown, contains('## 规则特性'));
    expect(markdown, contains('### 回气'));
    expect(markdown, contains('## 法术'));
    expect(markdown, contains('### 护盾术'));
    expect(
      decoded.dataMap['ruleSnapshots'],
      withRules.dataMap['ruleSnapshots'],
    );
    expect(decoded.dataMap['contentRefs'], withRules.dataMap['contentRefs']);
  });

  test('exports the supplied local revision in Markdown v2', () {
    final markdown = codec.encode(character, revision: 42);

    expect(markdown, contains('format: dnd-table-character/v2'));
    expect(markdown, contains('revision: 42'));
  });

  test('accepts harmless blank-line and heading spacing edits', () {
    final markdown = codec
        .encode(character)
        .replaceFirst('## 属性', '##   属性   ')
        .replaceFirst('| 力量', '\n\n| 力量');

    final decoded = codec.decode(markdown);

    expect(decoded.character.abilityMap['str'], 10);
    expect(decoded.character.name, '阿兰尼斯');
  });

  test('rejects invalid numeric fields with a readable error', () {
    final markdown = codec
        .encode(character)
        .replaceFirst('| 等级 | 5 |', '| 等级 | 五 |');

    expect(
      () => codec.decode(markdown),
      throwsA(
        isA<CharacterMarkdownFormatException>().having(
          (error) => error.message,
          'message',
          contains('等级'),
        ),
      ),
    );
  });

  test('preserves unknown user sections for later export', () {
    final markdown =
        '${codec.encode(character)}\n'
        '## 我的团规备注\n\n'
        '在月光下进行感知检定时获得优势。\n';

    final decoded = codec.decode(markdown);
    final sections =
        decoded.character.dataMap['markdownSections'] as Map<Object?, Object?>;

    expect(sections['我的团规备注'], contains('月光'));
    expect(codec.encode(decoded.character), contains('## 我的团规备注'));
  });

  test('does not invent an empty notes section', () {
    final markdown = codec.encode(character.copyWith(notes: ''));

    expect(markdown, isNot(contains('## 笔记')));
  });

  test('continues to import legacy v1 character files', () {
    final legacy = codec
        .encode(character)
        .replaceFirst(
          'format: dnd-table-character/v2',
          'format: dnd-table-character/v1',
        );

    expect(codec.decode(legacy).character.name, '阿兰尼斯');
  });

  test(
    'imports a Monster Manual style character card as an editable character',
    () {
      const markdown = '''
---
format: dnd-table-character/v1
kind: monster
name: 丧尸
system: dnd5e-2024
templateRef: private-mm2024:monster/zombie
size: medium
creatureType: undead
alignment: neutral-evil
armorClass: 8
hitPoints:
  current: 15
  maximum: 15
  formula: 2d8+6
speed:
  walk: 20
abilities:
  str: 13
  dex: 6
  con: 16
  int: 3
  wis: 6
  cha: 5
challengeRating: 1/4
proficiencyBonus: 2
---

# 丧尸

中型亡灵，通常为中立邪恶

## 感官与语言

- 黑暗视觉：60 尺
- 被动察觉：8
- 语言：理解生前语言但无法说话

## 特质

### 不死坚韧

受到致命伤害时进行体质豁免。

## 动作

### 重击

- 类型：近战武器攻击
- 命中：+3
- 触及：5 尺
- 伤害：1d8+1 钝击
''';

      final decoded = codec.decode(markdown);

      expect(decoded.character.name, '丧尸');
      expect(decoded.character.currentHp, 15);
      expect(decoded.character.maxHp, 15);
      expect(decoded.character.armorClass, 8);
      expect(decoded.character.speed, 20);
      expect(decoded.character.abilityMap['con'], 16);
      expect(
        decoded.character.dataMap['character'],
        containsPair('kind', 'monster'),
      );
      expect(
        decoded.character.dataMap['character'],
        containsPair('templateRef', 'private-mm2024:monster/zombie'),
      );
      final sections =
          decoded.character.dataMap['markdownSections']
              as Map<Object?, Object?>;
      expect(sections['特质'], contains('不死坚韧'));
      expect(sections['动作'], contains('重击'));
      final exported = codec.encode(decoded.character);
      expect(exported, contains('### 不死坚韧'));
      expect(exported, contains('- 伤害：1d8+1 钝击'));
    },
  );

  test('re-exports imported monster data and readable action sections', () {
    final monster = character.copyWith(
      name: '枯骨卫士',
      classSummary: '怪物 · CR 1',
      raceSummary: '中型亡灵',
      data: {
        ...character.dataMap,
        'description': '一名沉默守卫，盔甲上刻着旧王徽记。',
        'character': {
          'kind': 'monster',
          'templateRef': 'private-mm2024:monster/skeleton',
          'size': 'medium',
          'creatureType': 'undead',
          'alignment': 'lawful-evil',
          'challengeRating': '1',
          'proficiencyBonus': 2,
          'hitPointFormula': '2d8+4',
          'speed': {'walk': 30},
        },
        'markdownSections': {
          '特质': '### 不死本质\n\n无需进食或呼吸。',
          '动作': '### 短剑\n\n- 命中：+4\n- 伤害：1d6+2 穿刺',
        },
      },
    );

    final markdown = codec.encode(monster);
    final decoded = codec.decode(markdown);

    expect(markdown, contains('kind: monster'));
    expect(markdown, contains('## 描述'));
    expect(markdown, contains('一名沉默守卫，盔甲上刻着旧王徽记。'));
    expect(decoded.character.dataMap['description'], '一名沉默守卫，盔甲上刻着旧王徽记。');
    expect(
      markdown,
      contains("templateRef: 'private-mm2024:monster/skeleton'"),
    );
    expect(markdown, contains('## 特质'));
    expect(markdown, contains('### 短剑'));
    expect(
      decoded.character.dataMap['character'],
      containsPair('kind', 'monster'),
    );
    expect(decoded.character.dataMap['markdownSections'], contains('动作'));
  });

  test('round trips structured monster groups through readable Markdown', () {
    final monster = character.copyWith(
      name: '暮影龙',
      data: {
        ...character.dataMap,
        'description': '一条盘踞在失落钟楼中的幼龙。',
        'character': {
          'kind': 'monster',
          'creatureType': 'dragon',
          'challengeRating': '5',
        },
        'monster': {
          'senses': ['黑暗视觉 120 尺', '被动察觉 16'],
          'languages': ['通用语', '龙语'],
          'challenge': {'rating': '5', 'proficiencyBonus': 3},
          'traits': [
            {
              'id': 'shadow-step',
              'name': '踏影',
              'description': '处于微光或黑暗中时可以穿过生物。',
              'uses': {'maximum': 1, 'restoreOn': 'longRest'},
            },
          ],
          'actions': [
            {
              'id': 'bite',
              'name': '啃咬',
              'description': '近战武器攻击。',
              'attack': {'bonus': 7, 'reach': '10 尺'},
              'damage': {'expression': '2d10+4', 'type': '穿刺'},
            },
          ],
          'bonusActions': [
            {'id': 'wing-shift', 'name': '振翼移位', 'description': '移动至多 15 尺。'},
          ],
          'reactions': [
            {'id': 'tail-guard', 'name': '尾部格挡', 'description': '使一次攻击检定受到劣势。'},
          ],
          'legendaryActions': [
            {
              'id': 'detect',
              'name': '侦测',
              'description': '进行一次感知检定。',
              'cost': 2,
            },
          ],
          'spellcasting': [
            {
              'id': 'innate-spellcasting',
              'name': '天生施法',
              'description': '施法属性为魅力。',
              'ability': 'cha',
              'saveDc': 15,
              'attackBonus': 7,
              'spells': ['黑暗术', '隐形术'],
            },
          ],
        },
      },
    );

    final markdown = codec.encode(monster);
    final decoded = codec.decode(markdown);
    final structured =
        decoded.character.dataMap['monster'] as Map<Object?, Object?>;

    expect(markdown, contains('## 特性'));
    expect(markdown, contains('## 动作'));
    expect(markdown, contains('## 附赠动作'));
    expect(markdown, contains('## 反应'));
    expect(markdown, contains('## 传奇动作'));
    expect(markdown, contains('## 施法'));
    expect(markdown, contains('## 怪物资料'));
    expect(markdown, contains('黑暗视觉 120 尺'));
    expect(markdown, contains('**命中加值：** +7'));
    expect(markdown, contains('**伤害：** `2d10+4` 穿刺'));
    expect(markdown, contains('**次数：** 1'));
    expect(markdown, contains('**恢复：** longRest'));
    expect(markdown, contains('**法术：** 黑暗术、隐形术'));
    expect(
      structured['traits'],
      equals((monster.dataMap['monster'] as Map)['traits']),
    );
    expect(
      structured['actions'],
      equals((monster.dataMap['monster'] as Map)['actions']),
    );
    expect(
      structured['bonusActions'],
      equals((monster.dataMap['monster'] as Map)['bonusActions']),
    );
    expect(
      structured['reactions'],
      equals((monster.dataMap['monster'] as Map)['reactions']),
    );
    expect(
      structured['legendaryActions'],
      equals((monster.dataMap['monster'] as Map)['legendaryActions']),
    );
    expect(
      structured['spellcasting'],
      equals((monster.dataMap['monster'] as Map)['spellcasting']),
    );
    expect(
      structured['senses'],
      equals((monster.dataMap['monster'] as Map)['senses']),
    );
    expect(
      structured['languages'],
      equals((monster.dataMap['monster'] as Map)['languages']),
    );
    expect(
      structured['challenge'],
      equals((monster.dataMap['monster'] as Map)['challenge']),
    );
  });

  test('uses human-edited monster entry text instead of stale metadata', () {
    final monster = character.copyWith(
      data: {
        ...character.dataMap,
        'character': {'kind': 'monster'},
        'monster': {
          'actions': [
            {
              'id': 'bolt',
              'name': '暗影箭',
              'description': '远程法术攻击。',
              'attack': {'bonus': 5},
              'damage': {'expression': '2d8', 'type': '黯蚀'},
            },
          ],
        },
      },
    );
    final edited = codec
        .encode(monster)
        .replaceFirst('远程法术攻击。', '射出一支寒冷的暗影箭。')
        .replaceFirst('**命中加值：** +5', '**命中加值：** +8')
        .replaceFirst('`2d8` 黯蚀', '`3d8+2` 冷冻');

    final decoded = codec.decode(edited);
    final action =
        ((decoded.character.dataMap['monster'] as Map)['actions'] as List)
                .single
            as Map;

    expect(action['description'], '射出一支寒冷的暗影箭。');
    expect(action['attack'], {'bonus': 8});
    expect(action['damage'], {'expression': '3d8+2', 'type': '冷冻'});
  });
}
