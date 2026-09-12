// 编辑器「应用规则升级」的再派生幂等：应用后 `_abilityControllers` 已经是**目标
// 等级**的最终值，参照必须换成"最近一次已应用的 build"，否则第二次应用会用
// 升级前的等级去减加值，每次多叠一份 `(旧等级, 目标等级]`。
import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_editor_page.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('连点两次「应用等级规则」：属性值不变，不重复叠加', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final classEntry = ContentEntry.fromJson(<String, Object?>{
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
          },
        ],
      },
    });

    final character = CharacterSheet.local(
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

    await tester.pumpWidget(
      MaterialApp(
        home: CharacterEditorPage(
          initialCharacter: character,
          contentEntries: [classEntry],
          onSubmit: (_) async => true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    String strength() => tester
        .widget<TextField>(find.byKey(const Key('ability-str-field')))
        .controller!
        .text;

    expect(strength(), '16');

    // 把等级字段改成 2 → 出现升级队列与「应用等级规则」。
    await tester.enterText(
      find.byKey(const Key('character-level-field')),
      '2',
    );
    await tester.pumpAndSettle();

    // 升级队列的按钮（页面上另有保存等 FilledButton，必须按文案定位）。
    final applyButton = find.widgetWithText(FilledButton, '应用等级规则');
    expect(applyButton, findsOneWidget);
    await tester.ensureVisible(applyButton);
    await tester.pumpAndSettle();

    await tester.tap(applyButton);
    await tester.pumpAndSettle();
    expect(strength(), '17', reason: '16 + 2 级的 ability 授予 +1');
    // 应用后按钮换成禁用文案；用同一个 finder 的**位置**继续点它。
    final appliedButton = find.widgetWithText(FilledButton, '等级规则已应用');
    expect(appliedButton, findsOneWidget);

    // 第二次点击：按钮在应用后禁用，数值必须原样（旧实现会变成 18）。
    await tester.tap(appliedButton, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(strength(), '17', reason: '重复应用不得再叠一份 (1, 2] 的加值');

    // 第三次点击同样不漂移。
    await tester.tap(appliedButton, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(strength(), '17');
    expect(
      tester.widget<FilledButton>(appliedButton).onPressed,
      isNull,
      reason: '应用后按钮必须禁用（纵深防御之外的显式状态）',
    );
  });
}
