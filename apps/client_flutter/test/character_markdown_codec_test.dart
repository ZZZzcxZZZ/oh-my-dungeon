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
}
