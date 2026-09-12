// 阻塞项 3（计划任务 6b 后的新语义）：`optionType: "skill"` 的选中值在任务 7
// 之前仍写进草稿 `skills`，但任务 7 起会写进 `build.choices`。升级面**不再**用
// `usesDedicatedOptionUi` 免检：
//   - **上一级**未完成的专门 UI 选择不阻塞升级（只统计本级新增的选择）；
//   - **本级新增**的选择必须由共享组件真的渲染出来（否则是"看不见却阻塞"），
//     未完成就阻塞，完成后即可应用；
//   - 任何情况下都不得再渲染"没有符合条件的资料条目"的红色假错误。
import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_editor_page.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_upgrade_page.dart';
import 'package:dnd_table_client/src/features/characters/presentation/widgets/rule_choice_section.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 选择区里的候选 chip（编辑器页面同时渲染角色卡的技能网格，需按组件限定）。
Finder _choiceChip(String label) => find.descendant(
  of: find.byType(RuleChoiceSection),
  matching: find.widgetWithText(FilterChip, label),
);

void main() {
  testWidgets('编辑器升级队列渲染本级新增的技能选择，完成后可应用（不再免检）', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: CharacterEditorPage(
          initialCharacter: _character(),
          contentEntries: [_classEntry()],
          onSubmit: (_) async => true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 把等级改成 2 → 出现升级队列。
    await tester.enterText(find.byKey(const Key('character-level-field')), '2');
    await tester.pumpAndSettle();

    expect(find.text('升级队列'), findsOneWidget);
    // 本级新增的技能选择**必须可见**（这是修复"看不见却阻塞"的那一半）。
    expect(find.text('选择两项技能熟练'), findsOneWidget);
    expect(find.textContaining('没有符合'), findsNothing);

    final applyButton = find.widgetWithText(FilledButton, '应用等级规则');
    expect(applyButton, findsOneWidget);
    expect(
      tester.widget<FilledButton>(applyButton).onPressed,
      isNull,
      reason: '本级新增的未完成选择必须阻塞，且已在界面上可见',
    );

    // 选中两项技能 → 本级选择完成 → 可应用。
    await tester.tap(_choiceChip('洞悉'));
    await tester.pumpAndSettle();
    await tester.tap(_choiceChip('医药'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<FilledButton>(applyButton).onPressed,
      isNotNull,
      reason: '本级选择完成后必须可应用（无死锁）',
    );
    expect(find.text('请完成本级新增选择，或恢复缺失的资料条目。'), findsNothing);
  });

  testWidgets('独立升级页渲染本级新增的技能选择，完成后可确认', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: CharacterUpgradePage(
          character: _character(),
          contentEntries: [_classEntry()],
          onApply: (_) async => true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 不再渲染"没有符合条件的资料条目"的红色假错误，而是渲染内联候选。
    expect(find.text('没有符合条件的资料条目'), findsNothing);
    expect(find.text('选择两项技能熟练'), findsOneWidget);
    expect(_choiceChip('洞悉'), findsOneWidget);

    final applyButton = find.byKey(const Key('apply-upgrade'));
    expect(
      tester.widget<FilledButton>(applyButton).onPressed,
      isNull,
      reason: '本级新增的未完成选择必须阻塞',
    );

    await tester.tap(_choiceChip('洞悉'));
    await tester.pumpAndSettle();
    await tester.tap(_choiceChip('医药'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<FilledButton>(applyButton).onPressed,
      isNotNull,
      reason: '本级选择完成后必须可确认（无死锁）',
    );
  });
}

ContentEntry _classEntry() => ContentEntry.fromJson(<String, Object?>{
  'id': 'test:class/ascendant',
  'type': 'class',
  'slug': 'ascendant',
  'name': '晋升者',
  'body': <Object?>[],
  'revision': 1,
  'structured': <String, Object?>{
    'classRules': <String, Object?>{'hitDie': 10},
  },
  'rules': <String, Object?>{
    'progression': <Map<String, Object?>>[
      <String, Object?>{
        'levels': <int>[2],
        'grants': <Map<String, Object?>>[
          <String, Object?>{
            'id': 'asi-str',
            'kind': 'ability',
            'target': 'str',
            'value': 1,
            'label': '属性提升：力量 +1',
          },
        ],
        'choices': <Map<String, Object?>>[
          <String, Object?>{
            'id': 'class-skills',
            'label': '选择两项技能熟练',
            'optionType': 'skill',
            'minimum': 2,
            'maximum': 2,
            'builderStep': 'proficiencies',
            'options': <Object?>['洞悉', '医药', '说服'],
          },
        ],
      },
    ],
  },
});

CharacterSheet _character() =>
    CharacterSheet.local(
      id: 'test:character/hero',
      name: '阿雅',
      level: 1,
      classSummary: '晋升者',
    ).copyWith(
      maxHp: 10,
      currentHp: 10,
      abilities: <String, int>{
        'str': 16,
        'dex': 12,
        'con': 14,
        'int': 10,
        'wis': 10,
        'cha': 8,
      },
      data: <String, Object?>{
        'build': <String, Object?>{
          'level': 1,
          'selections': <String, String>{'class': 'test:class/ascendant'},
          'choices': <String, List<String>>{},
        },
      },
    );
