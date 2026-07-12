import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/characters/domain/character_edit_draft.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_detail_page.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_editor_page.dart';
import 'package:dnd_table_client/src/features/content/domain/content.dart';
import 'package:dnd_table_client/src/features/rooms/domain/dice_roller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('character detail page presents a complete sheet overview', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: CharacterDetailPage(character: _character)),
    );

    expect(find.text('Arannis'), findsWidgets);
    expect(find.text('Elf / Ranger / Lv.3'), findsOneWidget);
    expect(find.text('HP 24/24'), findsOneWidget);
    expect(find.text('AC 15'), findsOneWidget);
    expect(find.text('先攻 +2'), findsOneWidget);
    expect(find.text('属性'), findsWidgets);
    expect(find.text('动作'), findsOneWidget);
    expect(find.text('法术'), findsOneWidget);
    expect(find.text('装备'), findsOneWidget);
    expect(find.text('状态'), findsOneWidget);
    expect(find.text('特性'), findsOneWidget);
    expect(find.text('详情'), findsWidgets);
    expect(find.text('笔记'), findsOneWidget);
    expect(find.text('豁免'), findsOneWidget);
    expect(find.text('技能'), findsOneWidget);

    await tester.tap(find.text('装备'));
    await tester.pumpAndSettle();

    expect(find.text('长弓 x1'), findsOneWidget);
    expect(find.text('gp 10'), findsOneWidget);

    await tester.tap(find.text('状态'));
    await tester.pumpAndSettle();

    expect(find.text('临时 HP 5'), findsOneWidget);
    expect(find.text('灵感'), findsOneWidget);
    expect(find.text('中毒'), findsOneWidget);
    expect(find.text('倒地'), findsOneWidget);
    expect(find.text('死亡豁免 1/2'), findsOneWidget);

    await tester.tap(find.text('笔记'));
    await tester.pumpAndSettle();

    expect(find.text('来自旧林地的游侠。'), findsOneWidget);
  });

  testWidgets('character detail page opens the configured initial tab', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CharacterDetailPage(
          character: _character,
          initialTab: 'equipment',
        ),
      ),
    );

    expect(find.text('长弓 x1'), findsOneWidget);
    expect(find.text('gp 10'), findsOneWidget);
  });

  testWidgets('character detail runtime tab sends quick state updates', (
    tester,
  ) async {
    final updates = <Map<String, Object?>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterDetailPage(
          character: _character,
          onUpdateRuntime:
              ({
                int? currentHp,
                int? temporaryHp,
                bool? inspiration,
                List<String>? conditions,
                int? deathSaveSuccesses,
                int? deathSaveFailures,
                Map<String, int>? spellSlotsUsed,
                Map<String, int>? classResourcesUsed,
              }) async {
                updates.add({
                  'currentHp': currentHp,
                  'temporaryHp': temporaryHp,
                  'inspiration': inspiration,
                  'conditions': conditions,
                  'deathSaveSuccesses': deathSaveSuccesses,
                  'deathSaveFailures': deathSaveFailures,
                });
              },
        ),
      ),
    );

    await tester.tap(find.text('状态'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('+1 临时 HP'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '消耗灵感'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('condition-search-field')),
      '震慑',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ActionChip, '震慑'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, '震慑'));
    await tester.pumpAndSettle();

    expect(updates[0]['temporaryHp'], 6);
    expect(updates[1]['inspiration'], isFalse);
    expect(updates[2]['conditions'], ['中毒', '倒地', '震慑']);
  });

  testWidgets('character detail runtime tab tracks class resources', (
    tester,
  ) async {
    final updates = <Map<String, Object?>>[];
    final character = _character.copyWith(
      classSummary: '战士',
      level: 2,
      data: {
        ..._character.dataMap,
        'classResources': [
          {'id': 'second_wind', 'name': '第二气息', 'maximum': 2},
          {'id': 'action_surge', 'name': '动作如潮', 'maximum': 1},
        ],
        'runtime': {
          ..._character.runtimeMap,
          'classResourcesUsed': {'second_wind': 1, 'action_surge': 0},
        },
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CharacterDetailPage(
          character: character,
          onUpdateRuntime:
              ({
                int? currentHp,
                int? temporaryHp,
                bool? inspiration,
                List<String>? conditions,
                int? deathSaveSuccesses,
                int? deathSaveFailures,
                Map<String, int>? spellSlotsUsed,
                Map<String, int>? classResourcesUsed,
              }) async {
                updates.add({'classResourcesUsed': classResourcesUsed});
              },
        ),
      ),
    );

    await tester.tap(find.text('状态'));
    await tester.pumpAndSettle();

    expect(find.text('第二气息 1/2 已用'), findsOneWidget);
    expect(find.text('动作如潮 0/1 已用'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('消耗第二气息'));
    await tester.tap(find.byTooltip('消耗第二气息'));
    await tester.pumpAndSettle();
    expect(find.text('第二气息 2/2 已用'), findsOneWidget);
    expect(updates.last['classResourcesUsed'], {
      'second_wind': 2,
      'action_surge': 0,
    });

    await tester.ensureVisible(find.byTooltip('恢复第二气息'));
    await tester.tap(find.byTooltip('恢复第二气息'));
    await tester.pumpAndSettle();
    expect(updates.last['classResourcesUsed'], {
      'second_wind': 1,
      'action_surge': 0,
    });
  });

  testWidgets('character detail runtime tab edits current hp and death saves', (
    tester,
  ) async {
    final updates = <Map<String, Object?>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterDetailPage(
          character: _character,
          onUpdateRuntime:
              ({
                int? currentHp,
                int? temporaryHp,
                bool? inspiration,
                List<String>? conditions,
                int? deathSaveSuccesses,
                int? deathSaveFailures,
                Map<String, int>? spellSlotsUsed,
                Map<String, int>? classResourcesUsed,
              }) async {
                updates.add({
                  'currentHp': currentHp,
                  'temporaryHp': temporaryHp,
                  'inspiration': inspiration,
                  'conditions': conditions,
                  'deathSaveSuccesses': deathSaveSuccesses,
                  'deathSaveFailures': deathSaveFailures,
                });
              },
        ),
      ),
    );

    await tester.tap(find.text('状态'));
    await tester.pumpAndSettle();

    expect(find.text('当前 HP 24/24'), findsOneWidget);

    await tester.tap(find.byTooltip('受到 1 点伤害'));
    await tester.pumpAndSettle();
    expect(find.text('当前 HP 23/24'), findsOneWidget);
    expect(updates.last['currentHp'], 23);

    await tester.tap(find.byTooltip('恢复 1 点 HP'));
    await tester.pumpAndSettle();
    expect(find.text('当前 HP 24/24'), findsOneWidget);
    expect(updates.last['currentHp'], 24);

    await tester.tap(find.byTooltip('死亡豁免成功 +1'));
    await tester.pumpAndSettle();
    expect(find.text('死亡豁免 2/2'), findsOneWidget);
    expect(updates.last['deathSaveSuccesses'], 2);

    await tester.tap(find.byTooltip('死亡豁免失败 +1'));
    await tester.pumpAndSettle();
    expect(find.text('死亡豁免 2/3'), findsOneWidget);
    expect(updates.last['deathSaveFailures'], 3);
  });

  testWidgets(
    'character detail runtime tab supports numeric hp changes and rests',
    (tester) async {
      final updates = <Map<String, Object?>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterDetailPage(
            character: _character,
            onUpdateRuntime:
                ({
                  int? currentHp,
                  int? temporaryHp,
                  bool? inspiration,
                  List<String>? conditions,
                  int? deathSaveSuccesses,
                  int? deathSaveFailures,
                  Map<String, int>? spellSlotsUsed,
                  Map<String, int>? classResourcesUsed,
                }) async {
                  updates.add({
                    'currentHp': currentHp,
                    'temporaryHp': temporaryHp,
                    'inspiration': inspiration,
                    'conditions': conditions,
                    'deathSaveSuccesses': deathSaveSuccesses,
                    'deathSaveFailures': deathSaveFailures,
                  });
                },
          ),
        ),
      );

      await tester.tap(find.text('状态'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('hp-delta-field')), '7');
      await tester.tap(find.widgetWithText(FilledButton, '受到伤害'));
      await tester.pumpAndSettle();
      expect(find.text('当前 HP 17/24'), findsOneWidget);
      expect(updates.last['currentHp'], 17);

      await tester.enterText(find.byKey(const Key('hp-delta-field')), '5');
      await tester.tap(find.widgetWithText(FilledButton, '恢复 HP'));
      await tester.pumpAndSettle();
      expect(find.text('当前 HP 22/24'), findsOneWidget);
      expect(updates.last['currentHp'], 22);

      await tester.tap(find.widgetWithText(OutlinedButton, '重置死亡豁免'));
      await tester.pumpAndSettle();
      expect(find.text('死亡豁免 0/0'), findsOneWidget);
      expect(updates.last['deathSaveSuccesses'], 0);
      expect(updates.last['deathSaveFailures'], 0);

      await tester.tap(find.byTooltip('死亡豁免失败 +1'));
      await tester.pumpAndSettle();
      expect(find.text('死亡豁免 0/1'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, '短休'));
      await tester.pumpAndSettle();
      expect(find.text('死亡豁免 0/0'), findsOneWidget);
      expect(updates.last['deathSaveSuccesses'], 0);
      expect(updates.last['deathSaveFailures'], 0);

      await tester.tap(find.widgetWithText(FilledButton, '长休'));
      await tester.pumpAndSettle();
      expect(find.text('当前 HP 24/24'), findsOneWidget);
      expect(find.text('临时 HP 0'), findsOneWidget);
      expect(updates.last['currentHp'], 24);
      expect(updates.last['temporaryHp'], 0);
      expect(updates.last['deathSaveSuccesses'], 0);
      expect(updates.last['deathSaveFailures'], 0);
    },
  );

  testWidgets(
    'character detail runtime tab searches and adds common or custom conditions',
    (tester) async {
      final updates = <Map<String, Object?>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterDetailPage(
            character: _character,
            onUpdateRuntime:
                ({
                  int? currentHp,
                  int? temporaryHp,
                  bool? inspiration,
                  List<String>? conditions,
                  int? deathSaveSuccesses,
                  int? deathSaveFailures,
                  Map<String, int>? spellSlotsUsed,
                  Map<String, int>? classResourcesUsed,
                }) async {
                  updates.add({
                    'currentHp': currentHp,
                    'temporaryHp': temporaryHp,
                    'inspiration': inspiration,
                    'conditions': conditions,
                    'deathSaveSuccesses': deathSaveSuccesses,
                    'deathSaveFailures': deathSaveFailures,
                  });
                },
          ),
        ),
      );

      await tester.tap(find.text('状态'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('condition-search-field')),
        '失明',
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ActionChip, '失明'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, '震慑'), findsNothing);

      await tester.ensureVisible(find.widgetWithText(ActionChip, '失明'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionChip, '失明'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(InputChip, '失明'), findsOneWidget);
      expect(updates.last['conditions'], ['中毒', '倒地', '失明']);

      await tester.enterText(
        find.byKey(const Key('condition-search-field')),
        '被藤蔓束缚',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(FilledButton, '添加自定义状态'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '添加自定义状态'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(InputChip, '被藤蔓束缚'), findsOneWidget);
      expect(updates.last['conditions'], ['中毒', '倒地', '失明', '被藤蔓束缚']);

      await tester.ensureVisible(find.widgetWithText(InputChip, '失明'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(InputChip, '失明'),
          matching: find.byIcon(Icons.cancel),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(InputChip, '失明'), findsNothing);
      expect(updates.last['conditions'], ['中毒', '倒地', '被藤蔓束缚']);
    },
  );

  testWidgets(
    'character detail actions tab shows derived attacks and spell dc',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: CharacterDetailPage(character: _character)),
      );

      await tester.tap(find.text('动作'));
      await tester.pumpAndSettle();

      expect(find.text('攻击动作'), findsOneWidget);
      expect(find.text('长弓'), findsOneWidget);
      expect(find.text('+4 命中'), findsOneWidget);
      expect(find.text('1d8+2 穿刺'), findsOneWidget);
      expect(find.text('施法'), findsOneWidget);
      expect(find.text('法术豁免 DC 12'), findsOneWidget);
      expect(find.text('附赠动作'), findsOneWidget);
      expect(find.text('反应'), findsOneWidget);
    },
  );

  testWidgets('character detail actions tab rolls local checks', (
    tester,
  ) async {
    final rollEvents = <CharacterRollEvent>[];
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterDetailPage(
          character: _character,
          diceRoller: DiceRoller(nextInt: (max) => max - 1),
          onRoll: rollEvents.add,
        ),
      ),
    );

    await tester.tap(find.text('动作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('察觉 +4'));
    await tester.pumpAndSettle();

    expect(find.text('察觉：d20+4 = 24'), findsOneWidget);
    expect(rollEvents.single.label, '察觉');
    expect(rollEvents.single.notation, 'd20+4');
    expect(rollEvents.single.total, 24);
    expect(rollEvents.single.summary, '察觉：d20+4 = 24');
  });

  testWidgets(
    'character detail actions tab supports advantage and disadvantage',
    (tester) async {
      final rolls = [4, 19, 14, 1];
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterDetailPage(
            character: _character,
            diceRoller: DiceRoller(nextInt: (_) => rolls.removeAt(0)),
          ),
        ),
      );

      await tester.tap(find.text('动作'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('优势'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('察觉 +4'));
      await tester.pumpAndSettle();
      expect(find.text('察觉：优势 d20(5, 20)+4 = 24'), findsOneWidget);

      await tester.tap(find.text('劣势'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('察觉 +4'));
      await tester.pumpAndSettle();
      expect(find.text('察觉：劣势 d20(15, 2)+4 = 6'), findsOneWidget);
    },
  );

  testWidgets('character detail actions tab rolls weapon attacks', (
    tester,
  ) async {
    final rollEvents = <CharacterRollEvent>[];
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterDetailPage(
          character: _character,
          diceRoller: DiceRoller(nextInt: (_) => 19),
          onRoll: rollEvents.add,
        ),
      ),
    );

    await tester.tap(find.text('动作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('长弓'));
    await tester.pumpAndSettle();

    expect(find.textContaining('长弓：d20+4 = 24，伤害 1d8+2 ='), findsOneWidget);
    expect(find.textContaining('穿刺'), findsWidgets);
    expect(rollEvents.single.label, '长弓');
    expect(rollEvents.single.notation, 'd20+4 / 1d8+2');
    expect(rollEvents.single.total, greaterThan(24));
    expect(rollEvents.single.summary, contains('长弓：d20+4 = 24，伤害 1d8+2 ='));
  });

  testWidgets('character detail spells tab tracks spell slots and spell refs', (
    tester,
  ) async {
    final updates = <Map<String, Object?>>[];
    final wizard = _character.copyWith(
      classSummary: '法师',
      level: 3,
      abilities: {..._character.abilityMap, 'int': 16},
      data: {
        ..._character.dataMap,
        'runtime': {
          ..._character.runtimeMap,
          'spellSlotsUsed': {'1': 1, '2': 0},
        },
        'contentRefs': {
          'spells': ['魔法飞弹', '护盾术'],
          'items': <String>[],
          'features': <String>[],
        },
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CharacterDetailPage(
          character: wizard,
          initialTab: 'spells',
          onUpdateRuntime:
              ({
                int? currentHp,
                int? temporaryHp,
                bool? inspiration,
                List<String>? conditions,
                int? deathSaveSuccesses,
                int? deathSaveFailures,
                Map<String, int>? spellSlotsUsed,
                Map<String, int>? classResourcesUsed,
              }) async {
                updates.add({'spellSlotsUsed': spellSlotsUsed});
              },
        ),
      ),
    );

    expect(find.text('施法属性 智力'), findsOneWidget);
    expect(find.text('法术豁免 DC 13'), findsOneWidget);
    expect(find.text('一环 1/4 已用'), findsOneWidget);
    expect(find.text('二环 0/2 已用'), findsOneWidget);
    expect(find.text('魔法飞弹'), findsOneWidget);
    expect(find.text('护盾术'), findsOneWidget);

    await tester.tap(find.byTooltip('消耗一环法术位'));
    await tester.pumpAndSettle();
    expect(find.text('一环 2/4 已用'), findsOneWidget);
    expect(updates.last['spellSlotsUsed'], {'1': 2, '2': 0});

    await tester.tap(find.byTooltip('恢复一环法术位'));
    await tester.pumpAndSettle();
    expect(find.text('一环 1/4 已用'), findsOneWidget);
    expect(updates.last['spellSlotsUsed'], {'1': 1, '2': 0});
  });

  testWidgets('character detail equipment tab sends quick inventory updates', (
    tester,
  ) async {
    final updates = <Map<String, Object?>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterDetailPage(
          character: _character,
          onUpdateInventory:
              ({
                List<Map<String, Object>>? inventory,
                Map<String, int>? currency,
              }) async {
                updates.add({'inventory': inventory, 'currency': currency});
              },
        ),
      ),
    );

    await tester.tap(find.text('装备'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('长弓 +1'));
    await tester.pumpAndSettle();
    expect(find.text('长弓 x2'), findsOneWidget);
    expect(updates.last['inventory'], [
      {'name': '长弓', 'quantity': 2},
      {'name': '治疗药水', 'quantity': 2},
    ]);

    await tester.tap(find.widgetWithText(OutlinedButton, '消耗治疗药水'));
    await tester.pumpAndSettle();
    expect(find.text('治疗药水 x1'), findsOneWidget);
    expect(updates.last['inventory'], [
      {'name': '长弓', 'quantity': 2},
      {'name': '治疗药水', 'quantity': 1},
    ]);

    await tester.tap(find.byTooltip('gp +1'));
    await tester.pumpAndSettle();
    expect(find.text('gp 11'), findsOneWidget);
    expect(updates.last['currency'], {'gp': 11});
  });

  testWidgets('character editor submits expanded character sheet fields', (
    tester,
  ) async {
    CharacterEditDraft? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterEditorPage(
          onSubmit: (draft) async {
            submitted = draft;
            return true;
          },
        ),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, '标准创建'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '继续编辑完整角色卡'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('character-name-field')),
      'Mira',
    );
    await tester.enterText(
      find.byKey(const Key('character-class-field')),
      '法师',
    );
    await tester.enterText(find.byKey(const Key('character-race-field')), '人类');
    await tester.enterText(find.byKey(const Key('ability-int-field')), '16');
    await tester.ensureVisible(find.byKey(const Key('save-int-checkbox')));
    await tester.tap(find.byKey(const Key('save-int-checkbox')));
    await tester.ensureVisible(find.byKey(const Key('skill-奥秘-checkbox')));
    await tester.tap(find.byKey(const Key('skill-奥秘-checkbox')));
    await tester.ensureVisible(
      find.byKey(const Key('character-inventory-field')),
    );
    await tester.enterText(
      find.byKey(const Key('character-inventory-field')),
      '法术书 x1\n治疗药水 x2',
    );
    await tester.ensureVisible(find.byKey(const Key('currency-gp-field')));
    await tester.enterText(find.byKey(const Key('currency-gp-field')), '15');
    await tester.ensureVisible(find.byKey(const Key('character-notes-field')));
    await tester.enterText(
      find.byKey(const Key('character-notes-field')),
      '学院出身。',
    );

    await tester.tap(find.widgetWithText(FilledButton, '保存角色'));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.name, 'Mira');
    expect(submitted!.classSummary, '法师');
    expect(submitted!.raceSummary, '人类');
    expect(submitted!.abilities['int'], 16);
    expect(submitted!.saves['int'], isTrue);
    expect(submitted!.skills['奥秘'], isTrue);
    expect(submitted!.inventory, [
      {'name': '法术书', 'quantity': 1},
      {'name': '治疗药水', 'quantity': 2},
    ]);
    expect(submitted!.currency['gp'], 15);
    expect(submitted!.notes, '学院出身。');
  });

  testWidgets('new character editor starts with guided creation choices', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: CharacterEditorPage(onSubmit: (_) async => true)),
    );

    expect(find.text('创建角色'), findsOneWidget);
    expect(find.text('快速创建'), findsWidgets);
    expect(find.text('标准创建'), findsWidgets);
    expect(find.text('导入或复制'), findsOneWidget);
    expect(find.byKey(const Key('character-name-field')), findsNothing);
  });

  testWidgets('new character editor can start from preferred quick build', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterEditorPage(
          defaultCreationMethod: 'quick',
          onSubmit: (_) async => true,
        ),
      ),
    );

    expect(find.text('快速创建角色'), findsOneWidget);
    expect(find.byKey(const Key('quick-character-name-field')), findsOneWidget);
    expect(find.text('选择创建方式'), findsNothing);
  });

  testWidgets('new character editor can start from preferred standard build', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterEditorPage(
          defaultCreationMethod: 'standard',
          onSubmit: (_) async => true,
        ),
      ),
    );

    expect(find.text('标准创建角色'), findsOneWidget);
    expect(
      find.byKey(const Key('standard-character-name-field')),
      findsOneWidget,
    );
    expect(find.text('选择创建方式'), findsNothing);
  });

  testWidgets('quick build submits a playable 2024 character draft', (
    tester,
  ) async {
    CharacterEditDraft? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterEditorPage(
          onSubmit: (draft) async {
            submitted = draft;
            return true;
          },
        ),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, '快速创建'));
    await tester.pumpAndSettle();

    expect(find.text('快速创建角色'), findsOneWidget);
    expect(find.text('D&D 2024'), findsOneWidget);
    expect(find.text('战士'), findsOneWidget);
    expect(find.text('人类'), findsOneWidget);
    expect(find.text('士兵'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('quick-character-name-field')),
      'Kara',
    );
    await tester.tap(find.widgetWithText(FilledButton, '创建角色'));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.name, 'Kara');
    expect(submitted!.classSummary, '战士');
    expect(submitted!.raceSummary, '人类');
    expect(submitted!.level, 1);
    expect(submitted!.maxHp, greaterThan(0));
    expect(submitted!.armorClass, greaterThanOrEqualTo(10));
    expect(submitted!.inventory, isNotEmpty);
    expect(submitted!.notes, contains('D&D 2024'));
  });

  testWidgets('standard build exposes the full guided step outline', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: CharacterEditorPage(onSubmit: (_) async => true)),
    );

    await tester.tap(find.widgetWithText(FilledButton, '标准创建'));
    await tester.pumpAndSettle();

    expect(find.text('标准创建角色'), findsOneWidget);
    for (final step in ['来源', '职业', '起源', '属性', '熟练', '装备', '法术', '详情', '审核']) {
      expect(find.text(step), findsWidgets);
    }
    expect(find.text('完成度'), findsOneWidget);
    expect(find.text('继续编辑完整角色卡'), findsOneWidget);
  });

  testWidgets('standard build review tracks completion and missing fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: CharacterEditorPage(onSubmit: (_) async => true)),
    );

    await tester.tap(find.widgetWithText(FilledButton, '标准创建'));
    await tester.pumpAndSettle();

    expect(find.text('4/5 已完成'), findsOneWidget);
    expect(find.text('缺少角色名'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '创建角色'))
          .onPressed,
      isNull,
    );

    await tester.enterText(
      find.byKey(const Key('standard-character-name-field')),
      'Mira',
    );
    await tester.pumpAndSettle();

    expect(find.text('5/5 已完成'), findsOneWidget);
    expect(find.text('创建前检查通过'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '创建角色'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('standard build edits a draft and submits from review', (
    tester,
  ) async {
    CharacterEditDraft? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterEditorPage(
          onSubmit: (draft) async {
            submitted = draft;
            return true;
          },
        ),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, '标准创建'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('standard-character-name-field')),
      'Mira',
    );
    await tester.tap(
      find.ancestor(of: find.text('法师'), matching: find.byType(ChoiceChip)),
    );
    final elfChip = find.ancestor(
      of: find.text('精灵'),
      matching: find.byType(ChoiceChip),
    );
    await tester.ensureVisible(elfChip);
    await tester.tap(elfChip);
    final sageChip = find.ancestor(
      of: find.text('贤者'),
      matching: find.byType(ChoiceChip),
    );
    await tester.ensureVisible(sageChip);
    await tester.tap(sageChip);
    await tester.pumpAndSettle();

    expect(find.text('审核摘要'), findsOneWidget);
    expect(find.text('Mira / 精灵 / 贤者 / 法师 / Lv.1'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '创建角色'));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.name, 'Mira');
    expect(submitted!.classSummary, '法师');
    expect(submitted!.raceSummary, '精灵');
    expect(submitted!.skills['奥秘'], isTrue);
  });

  testWidgets('standard build edits ability scores and derived stats', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    CharacterEditDraft? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterEditorPage(
          defaultCreationMethod: 'standard',
          onSubmit: (draft) async {
            submitted = draft;
            return true;
          },
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('standard-character-name-field')),
      'Tamsin',
    );
    await tester.enterText(
      find.byKey(const Key('standard-ability-str-field')),
      '15',
    );
    await tester.enterText(
      find.byKey(const Key('standard-ability-dex-field')),
      '12',
    );
    await tester.enterText(
      find.byKey(const Key('standard-ability-con-field')),
      '13',
    );
    await tester.enterText(
      find.byKey(const Key('standard-ability-int-field')),
      '10',
    );
    await tester.enterText(
      find.byKey(const Key('standard-ability-wis-field')),
      '8',
    );
    await tester.enterText(
      find.byKey(const Key('standard-ability-cha-field')),
      '14',
    );
    await tester.pumpAndSettle();

    expect(find.text('属性已完成'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '创建角色'));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.abilities, {
      'str': 15,
      'dex': 12,
      'con': 13,
      'int': 10,
      'wis': 8,
      'cha': 14,
    });
    expect(submitted!.maxHp, 11);
    expect(submitted!.armorClass, 11);
    expect(submitted!.initiativeBonus, 1);
  });

  testWidgets('standard build changes level and previews derived spell slots', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    CharacterEditDraft? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterEditorPage(
          defaultCreationMethod: 'standard',
          onSubmit: (draft) async {
            submitted = draft;
            return true;
          },
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('standard-character-name-field')),
      'Mira',
    );
    await tester.tap(find.text('法师'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('standard-level-increment-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('standard-level-increment-button')));
    await tester.pumpAndSettle();

    expect(find.text('当前等级 3'), findsOneWidget);
    expect(find.text('HP 20'), findsOneWidget);
    expect(find.text('法术位 一环 4 / 二环 2'), findsOneWidget);
    expect(find.text('Mira / 人类 / 士兵 / 法师 / Lv.3'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '创建角色'));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.level, 3);
    expect(submitted!.maxHp, 20);
  });

  testWidgets('standard build edits skill proficiencies', (tester) async {
    tester.view.physicalSize = const Size(1200, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    CharacterEditDraft? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterEditorPage(
          defaultCreationMethod: 'standard',
          onSubmit: (draft) async {
            submitted = draft;
            return true;
          },
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('standard-character-name-field')),
      'Nia',
    );
    await tester.tap(find.byKey(const Key('standard-skill-运动-chip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('standard-skill-察觉-chip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('standard-skill-隐匿-chip')));
    await tester.pumpAndSettle();

    expect(find.text('熟练 3 项'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '创建角色'));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.skills['运动'], isFalse);
    expect(submitted!.skills['威吓'], isTrue);
    expect(submitted!.skills['察觉'], isTrue);
    expect(submitted!.skills['隐匿'], isTrue);
  });

  testWidgets('standard build can use content library choices', (tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    CharacterEditDraft? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterEditorPage(
          defaultCreationMethod: 'standard',
          contentItems: const [
            _fighterContent,
            _aasimarContent,
            _acolyteContent,
          ],
          onSubmit: (draft) async {
            submitted = draft;
            return true;
          },
        ),
      ),
    );

    expect(find.text('战士 / Fighter'), findsOneWidget);
    expect(find.text('阿斯莫 / Aasimar'), findsOneWidget);
    expect(find.text('侍僧 / Acolyte'), findsOneWidget);
    expect(find.text('来自资料库'), findsWidgets);

    await tester.enterText(
      find.byKey(const Key('standard-character-name-field')),
      'Lia',
    );
    final aasimarChip = find.ancestor(
      of: find.text('阿斯莫 / Aasimar'),
      matching: find.byType(ChoiceChip),
    );
    await tester.ensureVisible(aasimarChip);
    await tester.pumpAndSettle();
    await tester.tap(aasimarChip);
    final acolyteChip = find.ancestor(
      of: find.text('侍僧 / Acolyte'),
      matching: find.byType(ChoiceChip),
    );
    await tester.ensureVisible(acolyteChip);
    await tester.pumpAndSettle();
    await tester.tap(acolyteChip);
    await tester.pumpAndSettle();

    expect(
      find.text('Lia / 阿斯莫 / Aasimar / 侍僧 / Acolyte / 战士 / Fighter / Lv.1'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, '创建角色'));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.classSummary, '战士 / Fighter');
    expect(submitted!.raceSummary, '阿斯莫 / Aasimar');
    expect(submitted!.notes, contains('侍僧 / Acolyte'));
  });

  testWidgets('standard build can add library spells and equipment', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    CharacterEditDraft? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterEditorPage(
          defaultCreationMethod: 'standard',
          contentItems: const [
            _fighterContent,
            _aasimarContent,
            _acolyteContent,
            _magicMissileContent,
            _longswordContent,
            _healingPotionContent,
          ],
          onSubmit: (draft) async {
            submitted = draft;
            return true;
          },
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('standard-character-name-field')),
      'Lia',
    );
    await tester.ensureVisible(find.text('魔法飞弹 / Magic Missile'));
    await tester.tap(find.text('魔法飞弹 / Magic Missile'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('长剑 / Longsword'));
    await tester.tap(find.text('长剑 / Longsword'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('治疗药水 / Potion of Healing'));
    await tester.tap(find.text('治疗药水 / Potion of Healing'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '创建角色'));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    final data = submitted!.data;
    expect(data['contentRefs'], {
      'spells': ['魔法飞弹 / Magic Missile'],
      'items': ['长剑 / Longsword', '治疗药水 / Potion of Healing'],
      'features': <String>[],
    });
    expect(
      submitted!.inventory,
      contains(
        predicate<Map<String, Object>>(
          (item) => item['name'] == '长剑 / Longsword' && item['quantity'] == 1,
        ),
      ),
    );
    expect(
      submitted!.inventory,
      contains(
        predicate<Map<String, Object>>(
          (item) =>
              item['name'] == '治疗药水 / Potion of Healing' &&
              item['quantity'] == 1,
        ),
      ),
    );
  });
}

const _character = CharacterSheet(
  id: 'char-1',
  ownerUserId: 'user-1',
  name: 'Arannis',
  avatarUrl: null,
  system: 'dnd5e',
  level: 3,
  classSummary: 'Ranger',
  raceSummary: 'Elf',
  currentHp: 24,
  maxHp: 24,
  armorClass: 15,
  speed: 30,
  initiativeBonus: 2,
  abilities: {'str': 10, 'dex': 14, 'con': 12, 'int': 10, 'wis': 14, 'cha': 8},
  saves: {'dex': true, 'wis': true},
  skills: {'察觉': true, '隐匿': true},
  inventory: [
    {'name': '长弓', 'quantity': 1},
    {'name': '治疗药水', 'quantity': 2},
  ],
  currency: {'gp': 10},
  notes: '来自旧林地的游侠。',
  data: {
    'runtime': {
      'temporaryHp': 5,
      'inspiration': true,
      'conditions': ['中毒', '倒地'],
      'deathSaves': {'successes': 1, 'failures': 2},
    },
  },
  createdAt: '2026-07-09T00:00:00.000Z',
  updatedAt: '2026-07-09T00:00:00.000Z',
);

const _fighterContent = ContentItem(
  id: 'content-class-fighter',
  packageId: 'pkg-phb',
  type: 'class',
  slug: 'class-fighter',
  name: '战士 / Fighter',
  description: '',
  structured: {'page': 60},
  tags: ['private-phb-2024-index', 'class'],
  sourceLabel: 'Private PHB 2024 PDF Index',
  schemaVersion: 1,
  createdAt: '2026-07-09T00:00:00.000Z',
  updatedAt: '2026-07-09T00:00:00.000Z',
);

const _aasimarContent = ContentItem(
  id: 'content-species-aasimar',
  packageId: 'pkg-phb',
  type: 'species',
  slug: 'species-aasimar',
  name: '阿斯莫 / Aasimar',
  description: '',
  structured: {'page': 113},
  tags: ['private-phb-2024-index', 'species'],
  sourceLabel: 'Private PHB 2024 PDF Index',
  schemaVersion: 1,
  createdAt: '2026-07-09T00:00:00.000Z',
  updatedAt: '2026-07-09T00:00:00.000Z',
);

const _acolyteContent = ContentItem(
  id: 'content-background-acolyte',
  packageId: 'pkg-phb',
  type: 'background',
  slug: 'background-acolyte',
  name: '侍僧 / Acolyte',
  description: '',
  structured: {'page': 111},
  tags: ['private-phb-2024-index', 'background'],
  sourceLabel: 'Private PHB 2024 PDF Index',
  schemaVersion: 1,
  createdAt: '2026-07-09T00:00:00.000Z',
  updatedAt: '2026-07-09T00:00:00.000Z',
);

const _magicMissileContent = ContentItem(
  id: 'content-spell-magic-missile',
  packageId: 'pkg-phb',
  type: 'spell',
  slug: 'spell-magic-missile',
  name: '魔法飞弹 / Magic Missile',
  description: '',
  structured: {'page': 290},
  tags: ['private-phb-2024-index', 'spell'],
  sourceLabel: 'Private PHB 2024 PDF Index',
  schemaVersion: 1,
  createdAt: '2026-07-09T00:00:00.000Z',
  updatedAt: '2026-07-09T00:00:00.000Z',
);

const _longswordContent = ContentItem(
  id: 'content-equipment-longsword',
  packageId: 'pkg-phb',
  type: 'equipment',
  slug: 'equipment-longsword',
  name: '长剑 / Longsword',
  description: '',
  structured: {'page': 215},
  tags: ['private-phb-2024-index', 'equipment'],
  sourceLabel: 'Private PHB 2024 PDF Index',
  schemaVersion: 1,
  createdAt: '2026-07-09T00:00:00.000Z',
  updatedAt: '2026-07-09T00:00:00.000Z',
);

const _healingPotionContent = ContentItem(
  id: 'content-item-healing-potion',
  packageId: 'pkg-phb',
  type: 'item',
  slug: 'item-healing-potion',
  name: '治疗药水 / Potion of Healing',
  description: '',
  structured: {'page': 228},
  tags: ['private-phb-2024-index', 'item'],
  sourceLabel: 'Private PHB 2024 PDF Index',
  schemaVersion: 1,
  createdAt: '2026-07-09T00:00:00.000Z',
  updatedAt: '2026-07-09T00:00:00.000Z',
);
