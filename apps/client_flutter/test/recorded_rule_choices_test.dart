import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/characters/domain/recorded_rule_choices.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/character_test_support.dart';

ContentEntry _entry({
  required String id,
  required String type,
  required String name,
  Map<String, Object?> rules = const <String, Object?>{},
}) => ContentEntry.fromJson(<String, Object?>{
  'id': id,
  'type': type,
  'slug': id.split('/').last,
  'name': name,
  'body': <Object?>[],
  'revision': 1,
  'rules': rules,
});

void main() {
  final classEntry = _entry(
    id: 'demo:class/starweaver',
    type: 'class',
    name: '织星者',
    rules: <String, Object?>{
      'progression': <Object?>[
        <String, Object?>{
          'levels': <int>[1],
          'choices': <Object?>[
            <String, Object?>{
              'id': 'skills',
              'label': '选择两项技能熟练',
              'optionType': 'skill',
              'minimum': 2,
              'maximum': 2,
              'options': <String>['奥秘', '历史'],
            },
            <String, Object?>{
              'id': 'style',
              'label': '选择一项战斗风格',
              'optionType': 'feat',
              'minimum': 1,
              'maximum': 1,
              'options': <Object?>[
                <String, Object?>{
                  'id': 'poise',
                  'label': '星界之势',
                  'description': '示例说明。',
                },
              ],
            },
            <String, Object?>{
              'id': 'spells-1',
              'label': '戏法',
              'optionType': 'spell',
              'minimum': 1,
              'maximum': 1,
              'optionTags': <String>['spell-list:starweaver'],
            },
          ],
        },
      ],
    },
  );
  final spellEntry = _entry(
    id: 'demo:spell/star-spark',
    type: 'spell',
    name: '星火',
  );
  final entries = <ContentEntry>[classEntry, spellEntry];

  CharacterSheet characterWith(Map<String, Object?> choices) =>
      testCharacter(name: '测试').copyWith(
        classSummary: '织星者',
        data: <String, Object?>{'choices': choices},
      );

  test('读取 data[\'choices\']：内联选项 / 技能名 / 条目名的标签解析', () {
    final recorded = recordedRuleChoices(
      character: characterWith(<String, Object?>{
        'demo:class/starweaver#skills#1': <String>['奥秘', '历史'],
        'demo:class/starweaver#style#1': <String>['poise'],
        'demo:class/starweaver#spells-1#1': <String>['demo:spell/star-spark'],
      }),
      entries: entries,
    );

    // 展示顺序 = 条目里的声明顺序（与创建向导的步骤顺序一致），不是 id 字典序。
    expect(recorded.map((choice) => choice.choiceLabel).toList(), <String>[
      '选择两项技能熟练',
      '选择一项战斗风格',
      '戏法',
    ]);
    final byId = {
      for (final choice in recorded) choice.choiceId: choice.optionLabels,
    };
    expect(byId['skills'], <String>['奥秘', '历史'], reason: '技能选项的 id 就是技能名');
    expect(byId['style'], <String>['星界之势'], reason: '内联 options[].label');
    expect(
      byId['spells-1'],
      <String>['星火'],
      reason: '引用条目时用条目的 name（不是裸 id）',
    );
    expect(recorded.first.summary, '织星者 · 选择两项技能熟练（1 级）：奥秘、历史');
  });

  test('定义缺失 / 条目缺失时退回 id，绝不臆造标签', () {
    final recorded = recordedRuleChoices(
      character: characterWith(<String, Object?>{
        'ghost:class/unknown#mystery#3': <String>['whatever-id'],
      }),
      entries: entries,
    );
    expect(recorded.single.choiceLabel, 'mystery');
    expect(recorded.single.sourceName, isNull);
    expect(recorded.single.optionLabels, <String>['whatever-id']);
    expect(recorded.single.summary, 'ghost:class/unknown · mystery（3 级）：whatever-id');
  });

  test('没有 choices 键 / 空值 → 空列表（不抛）', () {
    expect(
      recordedRuleChoices(
        character: characterWith(const <String, Object?>{}),
        entries: entries,
      ),
      isEmpty,
    );
  });
}
