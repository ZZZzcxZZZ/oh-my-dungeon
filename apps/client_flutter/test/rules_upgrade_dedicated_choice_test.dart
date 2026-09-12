// 阻塞项 3：`optionType: "skill"` 的选择由专门 UI（技能选择器）承担，选中值写进
// 草稿 `skills` 而**永不**进 `build.choices`。升级面若把它计入 `pendingChoices` /
// `canApply`，就会出现「应用等级规则」永久禁用的死锁，并渲染"没有符合条件的资料
// 条目"的红色假错误。专门 UI 选择必须用同一个 `usesDedicatedOptionUi` 判据从升级
// 预览里剔除；降级到条目选项卡片的位置只给中性文案。
import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_editor_page.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_upgrade_page.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('编辑器升级预览不把专门 UI 选择算作待办（无死锁）', (tester) async {
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
    // 专门 UI 选择不出现在升级预览里（它由技能选择器承担）。
    expect(find.text('选择两项技能熟练'), findsNothing);
    expect(find.textContaining('没有符合'), findsNothing);

    // `canApply` 为 true：未选任何东西也能应用等级规则。
    final applyButton = find.widgetWithText(FilledButton, '应用等级规则');
    expect(applyButton, findsOneWidget);
    expect(
      tester.widget<FilledButton>(applyButton).onPressed,
      isNotNull,
      reason: '专门 UI 选择不得堵塞 canApply（升级死锁）',
    );
    expect(find.text('请完成本级新增选择，或恢复缺失的资料条目。'), findsNothing);
  });

  testWidgets('独立升级页对专门 UI 选择给中性文案且不阻断确认', (tester) async {
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

    // 不再渲染"没有符合条件的资料条目"的红色假错误，改为中性文案。
    expect(find.text('没有符合条件的资料条目'), findsNothing);
    expect(find.text('该选择由对应界面选择。'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('apply-upgrade')))
          .onPressed,
      isNotNull,
      reason: '专门 UI 选择不得堵塞升级确认',
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
