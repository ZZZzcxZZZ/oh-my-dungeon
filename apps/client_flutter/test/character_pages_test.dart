import 'dart:convert';
import 'dart:typed_data';

import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/characters/domain/character_edit_draft.dart';
import 'package:dnd_table_client/src/features/characters/domain/dnd5e_rules.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_detail_page.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_editor_page.dart';
import 'package:dnd_table_client/src/features/content/domain/content_block.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:dnd_table_client/src/core/dice/dice_roller.dart';
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
    expect(find.text('总览'), findsOneWidget);
    expect(find.text('属性'), findsOneWidget);
    expect(find.text('动作'), findsOneWidget);
    expect(find.text('法术'), findsOneWidget);
    expect(find.text('装备'), findsOneWidget);
    expect(find.text('资源'), findsOneWidget);
    expect(find.text('特性'), findsOneWidget);
    expect(find.text('角色资料'), findsOneWidget);
    expect(find.text('豁免'), findsNothing);
    expect(find.text('技能'), findsNothing);

    await tester.tap(find.text('属性'));
    await tester.pumpAndSettle();

    expect(find.text('豁免'), findsOneWidget);
    expect(find.text('技能'), findsOneWidget);

    await tester.tap(find.text('装备'));
    await tester.pumpAndSettle();

    expect(find.text('长弓 x1'), findsOneWidget);
    expect(find.text('gp 10'), findsOneWidget);

    await tester.tap(find.text('总览'));
    await tester.pumpAndSettle();

    expect(find.text('临时 HP 5'), findsOneWidget);
    expect(find.text('激励'), findsOneWidget);
    expect(find.text('中毒'), findsOneWidget);
    expect(find.text('倒地'), findsOneWidget);
    expect(find.text('死亡豁免 1/2'), findsOneWidget);
    expect(find.byKey(const Key('runtime-hp-panel')), findsOneWidget);
    expect(find.byKey(const Key('runtime-temporary-hp-panel')), findsOneWidget);
    expect(find.byKey(const Key('runtime-inspiration-panel')), findsOneWidget);
    expect(find.byKey(const Key('runtime-death-saves-panel')), findsOneWidget);

    await tester.tap(find.text('角色资料'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, '私人笔记'), findsOneWidget);
  });

  // Spec §头像来源: 角色卡头部应优先显示头像图片，无头像时退回首字母。
  testWidgets(
    'character detail header shows avatar image when avatarUrl is set',
    (tester) async {
      final avatarChar = _character.copyWith(
        avatarUrl: Uri.dataFromBytes(
          _validPngBytes,
          mimeType: 'image/png',
        ).toString(),
      );
      await tester.pumpWidget(
        MaterialApp(home: CharacterDetailPage(character: avatarChar)),
      );

      // 头部的 CircleAvatar 应当配置了 backgroundImage（而非首字母 fallback）。
      final avatar = tester.widget<CircleAvatar>(
        find.byKey(const Key('character-detail-avatar')),
      );
      expect(avatar.backgroundImage, isNotNull);
      expect(avatar.child, isNull);
    },
  );

  testWidgets('character detail header falls back to initial when no avatar', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: CharacterDetailPage(character: _character)),
    );

    final avatar = tester.widget<CircleAvatar>(
      find.byKey(const Key('character-detail-avatar')),
    );
    expect(avatar.backgroundImage, isNull);
    expect(avatar.child, isNotNull);
  });

  testWidgets('character resources can be added with a rest recovery rule', (
    tester,
  ) async {
    CharacterSheet? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterDetailPage(
          character: _character,
          onSaveCharacter: (character) async {
            saved = character;
            return true;
          },
        ),
      ),
    );

    await tester.tap(find.text('资源'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('添加资源'));
    await tester.tap(find.text('添加资源'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('resource-name-field')), '幸运点');
    await tester.enterText(
      find.byKey(const Key('resource-maximum-field')),
      '3',
    );
    await tester.tap(find.byKey(const Key('resource-recovery-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('短休恢复').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '添加'));
    await tester.pumpAndSettle();

    expect(find.text('幸运点 3/3'), findsOneWidget);
    final resources = saved!.dataMap['classResources']! as List;
    final luckyPoints = resources.cast<Map>().singleWhere(
      (resource) => resource['name'] == '幸运点',
    );
    expect(luckyPoints['maximum'], 3);
    expect(luckyPoints['recovery'], 'shortRest');
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

  testWidgets('character profile autosaves backstory and private notes', (
    tester,
  ) async {
    CharacterSheet? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterDetailPage(
          character: _character,
          initialTab: 'profile',
          onSaveCharacter: (character) async {
            saved = character;
            return true;
          },
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('character-profile-backstory')),
      '守护边境的游侠。',
    );
    await tester.enterText(
      find.byKey(const Key('character-profile-privateNotes')),
      '寻找失踪的导师。',
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.notes, '寻找失踪的导师。');
    expect((saved!.dataMap['profile'] as Map)['backstory'], '守护边境的游侠。');
  });

  testWidgets('character detail presents rule grants with their source', (
    tester,
  ) async {
    final character = _character.copyWith(
      data: {
        'resolvedGrants': [
          {
            'id': 'second-wind',
            'kind': 'feature',
            'label': '回气',
            'sourceEntryId': 'guide:class/fighter',
            'sourceEntryName': '战士',
            'sourceLevel': 1,
          },
          {
            'id': 'defense-ac',
            'kind': 'armorClass',
            'label': '防御加值',
            'sourceEntryId': 'guide:class-feature/defense',
            'sourceLevel': 1,
            'value': 1,
          },
        ],
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CharacterDetailPage(character: character, initialTab: 'features'),
      ),
    );

    expect(find.text('自动获得的特性'), findsOneWidget);
    expect(find.text('回气'), findsOneWidget);
    expect(find.text('战士 · 1 级获得'), findsOneWidget);
    expect(find.text('防御加值'), findsNothing);
  });

  testWidgets('character actions include rules-driven actions', (tester) async {
    final character = _character.copyWith(
      data: {
        'actions': [
          {
            'id': 'riposte',
            'name': '还击',
            'entryId': 'guide:feature/riposte',
            'formula': '1d8+2',
          },
        ],
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CharacterDetailPage(character: character, initialTab: 'actions'),
      ),
    );

    expect(find.text('资料动作'), findsOneWidget);
    expect(find.text('还击'), findsOneWidget);
    expect(find.text('1d8+2 · guide:feature/riposte'), findsOneWidget);
  });

  testWidgets('editing a level creates and applies a rules upgrade queue', (
    tester,
  ) async {
    CharacterEditDraft? submitted;
    final character = _character.copyWith(
      level: 1,
      classSummary: '战士',
      data: {
        'build': {
          'level': 1,
          'selections': {'class': 'guide:class/fighter'},
          'choices': <String, List<String>>{},
        },
        'runtime': {'temporaryHp': 5},
      },
    );
    final fighter = ContentEntry.fromJson({
      'id': 'guide:class/fighter',
      'type': 'class',
      'slug': 'fighter',
      'name': '战士',
      'body': <Map<String, Object?>>[],
      'revision': 1,
      'rules': {
        'progression': [
          {
            'levels': [2],
            'grants': [
              {'id': 'action-surge', 'kind': 'action', 'label': '动作如潮'},
            ],
          },
        ],
      },
    });

    await tester.pumpWidget(
      MaterialApp(
        home: CharacterEditorPage(
          initialCharacter: character,
          contentEntries: [fighter],
          onSubmit: (draft) async {
            submitted = draft;
            return true;
          },
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('character-level-field')), '2');
    await tester.pumpAndSettle();
    expect(find.text('升级队列'), findsOneWidget);
    expect(find.text('新增：动作如潮'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(FilledButton, '应用等级规则'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '应用等级规则'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '保存角色'));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect((submitted!.data['build'] as Map)['level'], 2);
    expect(submitted!.data['runtime'], {'temporaryHp': 5});
    expect(
      submitted!.data['resolvedGrants'],
      contains(predicate<Map>((grant) => grant['id'] == 'action-surge')),
    );
  });

  testWidgets('level-up queue resolves newly unlocked rule choices', (
    tester,
  ) async {
    CharacterEditDraft? submitted;
    final character = _character.copyWith(
      level: 1,
      classSummary: 'Guardian',
      data: {
        'build': {
          'level': 1,
          'selections': {'class': 'guide:class/guardian'},
          'choices': <String, List<String>>{},
        },
      },
    );
    final guardian = ContentEntry.fromJson({
      'id': 'guide:class/guardian',
      'type': 'class',
      'slug': 'guardian',
      'name': 'Guardian',
      'body': <Map<String, Object?>>[],
      'revision': 1,
      'rules': {
        'progression': [
          {
            'levels': [2],
            'choices': [
              {
                'id': 'technique',
                'label': 'Choose a technique',
                'optionType': 'classFeature',
                'minimum': 1,
                'maximum': 1,
                'optionEntryIds': ['guide:class-feature/battle-focus'],
              },
            ],
          },
        ],
      },
    });
    final technique = ContentEntry.fromJson({
      'id': 'guide:class-feature/battle-focus',
      'type': 'classFeature',
      'slug': 'battle-focus',
      'name': 'Battle Focus',
      'body': <Map<String, Object?>>[],
      'revision': 1,
      'rules': {
        'grants': [
          {'id': 'focus-action', 'kind': 'action', 'label': 'Focus'},
        ],
      },
    });

    await tester.pumpWidget(
      MaterialApp(
        home: CharacterEditorPage(
          initialCharacter: character,
          contentEntries: [guardian, technique],
          onSubmit: (draft) async {
            submitted = draft;
            return true;
          },
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('character-level-field')), '2');
    await tester.pumpAndSettle();
    expect(find.text('Choose a technique'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '应用等级规则'))
          .onPressed,
      isNull,
    );

    await tester.ensureVisible(find.widgetWithText(FilterChip, 'Battle Focus'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Battle Focus'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '应用等级规则'))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.widgetWithText(FilledButton, '应用等级规则'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '保存角色'));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    final build = submitted!.data['build'] as Map<String, Object?>;
    // 选择键带生效等级（§3.5）：每个已达等级是独立的选择实例。
    expect(build['choices'], {
      'guide:class/guardian#technique#2': ['guide:class-feature/battle-focus'],
    });
    expect(
      submitted!.data['resolvedGrants'],
      contains(predicate<Map>((grant) => grant['id'] == 'focus-action')),
    );
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

    await tester.tap(find.byTooltip('+1 临时 HP'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '消耗激励'));
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

    await tester.tap(find.text('资源'));
    await tester.pumpAndSettle();

    expect(find.text('第二气息 1/2'), findsOneWidget);
    expect(find.text('动作如潮 1/1'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('resource-pip-second_wind-1')),
    );
    await tester.tap(find.byKey(const Key('resource-pip-second_wind-1')));
    await tester.pumpAndSettle();
    expect(find.text('第二气息 2/2'), findsOneWidget);
    expect(updates.last['classResourcesUsed'], {
      'second_wind': 0,
      'action_surge': 0,
    });

    await tester.tap(find.byKey(const Key('resource-pip-second_wind-1')));
    await tester.pumpAndSettle();
    expect(updates.last['classResourcesUsed'], {
      'second_wind': 1,
      'action_surge': 0,
    });
  });

  testWidgets('rest changes are visible in the independent resources tab', (
    tester,
  ) async {
    final character = _character.copyWith(
      data: {
        ..._character.dataMap,
        'classResources': [
          {
            'id': 'second_wind',
            'name': '第二气息',
            'maximum': 2,
            'recovery': 'shortRest',
          },
        ],
        'runtime': {
          ..._character.runtimeMap,
          'classResourcesUsed': {'second_wind': 1},
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
              }) async {},
        ),
      ),
    );

    await tester.tap(find.text('资源'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, '恢复短休资源'));
    await tester.tap(find.widgetWithText(FilledButton, '恢复短休资源'));
    await tester.pumpAndSettle();

    expect(find.text('第二气息 2/2'), findsOneWidget);
    expect(find.text('短休恢复'), findsOneWidget);
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

    await tester.tap(find.byKey(const Key('runtime-hp-panel')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('hp-quick-value-field')), '6');
    await tester.tap(find.widgetWithText(FilledButton, '受到伤害'));
    await tester.pumpAndSettle();
    // 2024：5 点临时 HP 先吸收，溢出的 1 点才扣当前 HP。
    expect(find.text('当前 HP 23/24'), findsOneWidget);
    expect(updates.last['currentHp'], 23);
    expect(updates.last['temporaryHp'], 0);

    await tester.tap(find.byKey(const Key('runtime-hp-panel')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('hp-quick-value-field')), '1');
    await tester.tap(find.widgetWithText(FilledButton, '恢复 HP'));
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

      await tester.tap(find.byKey(const Key('runtime-hp-panel')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('hp-quick-value-field')),
        '12',
      );
      await tester.tap(find.widgetWithText(FilledButton, '受到伤害'));
      await tester.pumpAndSettle();
      // 2024：临时 HP 5 先吸收，剩余 7 点扣当前 HP（24 → 17）。
      expect(find.text('当前 HP 17/24'), findsOneWidget);
      expect(updates.last['currentHp'], 17);
      expect(updates.last['temporaryHp'], 0);

      await tester.tap(find.byKey(const Key('runtime-hp-panel')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('hp-quick-value-field')),
        '5',
      );
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

      await tester.ensureVisible(find.widgetWithText(FilledButton, '短休'));
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
        MaterialApp(
          home: CharacterDetailPage(
            character: _characterWithWeaponEntries,
            contentEntries: const [_bowEntry],
          ),
        ),
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

  // Task 3.3: 属性 Tab 中的豁免/技能 _RollChip 应将检定结果转发到 CampaignActionSink,
  // 从而让战役聊天显示检定卡片. 此前属性 Tab 的 _RollChip 不接收 diceRoller/onRoll,
  // 仅本地掷骰 + SnackBar.
  testWidgets(
    'attributes tab roll chip routes to CampaignActionSink (Task 3.3)',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sink = _RecordingSink();
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterDetailPage(
            character: _character,
            diceRoller: DiceRoller(nextInt: (max) => max - 1),
            sink: sink,
          ),
        ),
      );

      await tester.tap(find.text('属性'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('察觉 +4'));
      await tester.pumpAndSettle();

      expect(sink.events, hasLength(1));
      expect(sink.events.single.label, '察觉');
      expect(sink.events.single.notation, 'd20+4');
      expect(sink.events.single.total, 24);
      expect(sink.events.single.summary, '察觉：d20+4 = 24');
    },
  );

  testWidgets(
    'attributes tab roll chip still shows SnackBar without sink (Task 3.3)',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: CharacterDetailPage(
            character: _character,
            diceRoller: DiceRoller(nextInt: (max) => max - 1),
          ),
        ),
      );

      await tester.tap(find.text('属性'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('察觉 +4'));
      await tester.pumpAndSettle();

      expect(find.text('察觉：d20+4 = 24'), findsOneWidget);
    },
  );

  testWidgets('character detail actions tab rolls weapon attacks', (
    tester,
  ) async {
    final rollEvents = <CharacterRollEvent>[];
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterDetailPage(
          character: _characterWithWeaponEntries,
          contentEntries: const [_bowEntry],
          diceRoller: DiceRoller(nextInt: (_) => 19),
          onRoll: rollEvents.add,
        ),
      ),
    );

    await tester.tap(find.text('动作'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('长弓'));
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

  testWidgets('character spell panel prefers rules-derived caster data', (
    tester,
  ) async {
    final arcanist = _character.copyWith(
      classSummary: 'Arcanist',
      level: 1,
      abilities: {..._character.abilityMap, 'int': 16},
      data: {
        ..._character.dataMap,
        'spellcastingAbility': 'int',
        'spellSlots': {'1': 2},
        'contentRefs': {
          'spells': ['test:spell/spark'],
          'items': <String>[],
          'features': <String>[],
        },
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CharacterDetailPage(character: arcanist, initialTab: 'spells'),
      ),
    );

    expect(find.text('施法属性 智力'), findsOneWidget);
    expect(find.text('法术豁免 DC 13'), findsOneWidget);
    expect(find.text('一环 0/2 已用'), findsOneWidget);
    expect(find.text('test:spell/spark'), findsOneWidget);
  });

  testWidgets('character sheet opens referenced spells in a floating reader', (
    tester,
  ) async {
    const spell = ContentEntry(
      id: 'test:spell/spark',
      type: 'spell',
      slug: 'spark',
      name: 'Spark',
      summary: 'A compact rules reference.',
      body: [],
      revision: 1,
      structured: {'level': 1},
    );
    final caster = _character.copyWith(
      classSummary: 'Arcanist',
      data: {
        ..._character.dataMap,
        'spellcastingAbility': 'int',
        'spellSlots': {'1': 2},
        'contentRefs': {
          'spells': ['test:spell/spark'],
          'items': <String>[],
          'features': <String>[],
        },
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CharacterDetailPage(
          character: caster,
          initialTab: 'spells',
          contentEntries: const [spell],
        ),
      ),
    );

    await tester.tap(find.text('Spark'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('A compact rules reference.'), findsOneWidget);
    expect(find.byTooltip('关闭详情'), findsOneWidget);
  });

  testWidgets('spell reader does not repeat a summary copied into the body', (
    tester,
  ) async {
    const repeatedText = 'The spell creates a brief shower of sparks.';
    const spell = ContentEntry(
      id: 'test:spell/spark',
      type: 'spell',
      slug: 'spark',
      name: 'Spark',
      summary: repeatedText,
      body: [ParagraphBlock(text: repeatedText)],
      revision: 1,
      structured: {'level': 1},
    );
    final caster = _character.copyWith(
      data: {
        ..._character.dataMap,
        'contentRefs': {
          'spells': ['test:spell/spark'],
          'items': <String>[],
          'features': <String>[],
        },
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CharacterDetailPage(
          character: caster,
          initialTab: 'spells',
          contentEntries: const [spell],
        ),
      ),
    );

    await tester.tap(find.text('Spark'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text(repeatedText), findsOneWidget);
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

    await tester.ensureVisible(find.widgetWithText(OutlinedButton, '消耗治疗药水'));
    await tester.tap(find.widgetWithText(OutlinedButton, '消耗治疗药水'));
    await tester.pumpAndSettle();
    expect(find.text('治疗药水 x1'), findsOneWidget);
    expect(updates.last['inventory'], [
      {'name': '长弓', 'quantity': 2},
      {'name': '治疗药水', 'quantity': 1},
    ]);

    await tester.ensureVisible(find.byTooltip('gp +1'));
    await tester.pumpAndSettle();
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

    await tester.enterText(find.byKey(const Key('character-name')), 'Mira');
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
    // Task 1.3: "快速创建"卡片已移除, 只保留"标准创建"和"导入或复制"。
    expect(find.text('快速创建'), findsNothing);
    expect(find.text('标准创建'), findsWidgets);
    expect(find.text('导入或复制'), findsOneWidget);
    expect(find.byKey(const Key('character-name')), findsNothing);
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

  testWidgets('standard build exposes the full guided step outline', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: CharacterEditorPage(onSubmit: (_) async => true)),
    );

    await tester.tap(find.widgetWithText(FilledButton, '标准创建'));
    await tester.pumpAndSettle();

    expect(find.text('标准创建角色'), findsOneWidget);
    for (final step in ['职业', '背景', '物种', '属性', '熟练', '故事', '审核']) {
      expect(find.text(step), findsWidgets);
    }
    expect(find.byKey(const Key('builder-step-5')), findsNothing);
    expect(find.byKey(const Key('builder-step-6')), findsNothing);
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

    await _goToBuilderStep(tester, 8, '审核');

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
    await _goToBuilderStep(tester, 2, '物种');
    final elfChip = find.ancestor(
      of: find.text('精灵'),
      matching: find.byType(ChoiceChip),
    );
    await tester.ensureVisible(elfChip);
    await tester.tap(elfChip);
    await _goToBuilderStep(tester, 1, '背景');
    final sageChip = find.ancestor(
      of: find.text('贤者'),
      matching: find.byType(ChoiceChip),
    );
    await tester.ensureVisible(sageChip);
    await tester.tap(sageChip);
    await tester.pumpAndSettle();

    await _goToBuilderStep(tester, 8, '审核');

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
    await _goToBuilderStep(tester, 3, '属性');
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

    await _goToBuilderStep(tester, 8, '审核');
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
    // 未选职业时用档案职业兜底选项的第一个（已改为按档案 `classAliases` 派生并排序，
    // 首个是吟游诗人 d8）：d8 + CON 13（+1）= 9；AC/先攻只看输入的 dex 12。
    expect(submitted!.maxHp, 9);
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

    await _goToBuilderStep(tester, 8, '审核');
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
    await _goToBuilderStep(tester, 4, '熟练');
    await tester.tap(find.byKey(const Key('standard-skill-运动-chip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('standard-skill-察觉-chip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('standard-skill-隐匿-chip')));
    await tester.pumpAndSettle();

    expect(find.text('熟练 3 项'), findsOneWidget);

    await _goToBuilderStep(tester, 8, '审核');
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
          contentEntries: const [
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
    expect(find.text('来自资料库'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('standard-character-name-field')),
      'Lia',
    );
    await _goToBuilderStep(tester, 2, '物种');
    expect(find.text('阿斯莫 / Aasimar'), findsOneWidget);
    expect(find.text('来自资料库'), findsWidgets);
    final aasimarChip = find.ancestor(
      of: find.text('阿斯莫 / Aasimar'),
      matching: find.byType(ChoiceChip),
    );
    await tester.ensureVisible(aasimarChip);
    await tester.pumpAndSettle();
    await tester.tap(aasimarChip);
    await _goToBuilderStep(tester, 1, '背景');
    expect(find.text('侍僧 / Acolyte'), findsOneWidget);
    final acolyteChip = find.ancestor(
      of: find.text('侍僧 / Acolyte'),
      matching: find.byType(ChoiceChip),
    );
    await tester.ensureVisible(acolyteChip);
    await tester.pumpAndSettle();
    await tester.tap(acolyteChip);
    await tester.pumpAndSettle();

    await _goToBuilderStep(tester, 8, '审核');
    expect(
      find.text('Lia / 阿斯莫 / Aasimar / 侍僧 / Acolyte / 战士 / Fighter / Lv.1'),
      findsWidgets,
    );

    await tester.tap(find.widgetWithText(FilledButton, '创建角色'));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.classSummary, '战士 / Fighter');
    expect(submitted!.raceSummary, '阿斯莫 / Aasimar');
    expect(submitted!.notes, contains('侍僧 / Acolyte'));
  });

  testWidgets('standard build persists structured saves and guided skills', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final fighter = ContentEntry.fromJson({
      'id': 'test:class/fighter',
      'type': 'class',
      'slug': 'fighter',
      'name': '战士',
      'body': <Map<String, Object?>>[],
      'revision': 1,
      'structured': {
        // 任务 10：生命骰 / 豁免熟练走 `classRules`（旧散文键已删除）。
        'classRules': {'hitDie': 10, 'savingThrowAbilities': ['str', 'con']},
      },
      'rules': {
        'progression': [
          {
            'levels': [1],
            'grants': [
              {'id': 'second-wind', 'kind': 'feature', 'label': '回气'},
            ],
          },
        ],
      },
    });
    CharacterEditDraft? submitted;

    await tester.pumpWidget(
      MaterialApp(
        home: CharacterEditorPage(
          defaultCreationMethod: 'standard',
          contentEntries: [fighter],
          onSubmit: (draft) async {
            submitted = draft;
            return true;
          },
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('standard-character-name-field')),
      '莱娅',
    );
    await _goToBuilderStep(tester, 4, '熟练');
    await tester.tap(find.byKey(const Key('standard-skill-察觉-chip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('standard-skill-求生-chip')));
    await tester.pumpAndSettle();
    await _goToBuilderStep(tester, 8, '审核');
    await tester.tap(find.widgetWithText(FilledButton, '创建角色'));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.saves['str'], isTrue);
    expect(submitted!.saves['con'], isTrue);
    expect(submitted!.skills['运动'], isTrue);
    expect(submitted!.skills['威吓'], isTrue);
    expect(submitted!.skills['察觉'], isTrue);
    expect(submitted!.skills['求生'], isTrue);
  });

  testWidgets('standard build exposes all three ability generation methods', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: CharacterEditorPage(
          defaultCreationMethod: 'standard',
          onSubmit: (_) async => true,
        ),
      ),
    );
    await _goToBuilderStep(tester, 3, '属性');

    expect(find.byKey(const Key('ability-method-standard')), findsOneWidget);
    expect(find.byKey(const Key('ability-method-point-buy')), findsOneWidget);
    expect(find.byKey(const Key('ability-method-rolled')), findsOneWidget);

    await tester.tap(find.byKey(const Key('ability-method-point-buy')));
    await tester.pumpAndSettle();
    expect(find.text('剩余 0 / 27 点'), findsOneWidget);
    expect(find.byKey(const Key('point-buy-str-decrease')), findsOneWidget);

    await tester.tap(find.byKey(const Key('ability-method-rolled')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reroll-ability-scores')), findsOneWidget);
  });
  testWidgets('standard build opens option references in a floating reader', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: CharacterEditorPage(
          defaultCreationMethod: 'standard',
          contentEntries: const [_fighterContent],
          onSubmit: (_) async => true,
        ),
      ),
    );

    await tester.tap(find.byTooltip('查看 战士 / Fighter'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('战士 / Fighter'), findsWidgets);
  });

  testWidgets('standard build shows structured class rule summaries', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: CharacterEditorPage(
          defaultCreationMethod: 'standard',
          contentEntries: [_fighterRulesContent],
          onSubmit: (_) async => true,
        ),
      ),
    );

    expect(find.text('职业规则摘要'), findsOneWidget);
    expect(find.text('力量或敏捷'), findsOneWidget);
    expect(find.text('d10'), findsOneWidget);

    await _goToBuilderStep(tester, 4, '熟练');
    expect(find.text('力量与体质'), findsOneWidget);
    expect(find.text('简易武器与军用武器'), findsOneWidget);
    expect(find.text('轻甲、中甲、重甲与盾牌'), findsOneWidget);
    expect(find.text('职业技能 0/2 · 背景 2'), findsOneWidget);
    expect(find.byKey(const Key('standard-skill-欺瞒-chip')), findsNothing);

    await tester.tap(find.byKey(const Key('standard-skill-察觉-chip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('standard-skill-求生-chip')));
    await tester.pumpAndSettle();
    expect(find.text('职业技能 2/2 · 背景 2'), findsOneWidget);
    final disabledThirdChoice = tester.widget<FilterChip>(
      find.byKey(const Key('standard-skill-洞悉-chip')),
    );
    expect(disabledThirdChoice.onSelected, isNull);

    await _goToBuilderStep(tester, 5, '装备');
    expect(find.textContaining('链甲、巨剑'), findsOneWidget);
  });

  // M（P0-2.5 区分度版）：向导内头部 HP 预览 / 等级区生命骰 / 法术配额必须走
  // **同一份**带包 priority + 跨包索引的解析结果。夹具刻意让"角色自己那条"的包
  // priority 更高（alpha 50 vs beta 10），因此只有**把 priority 传下去**才会赢；
  // 不带 priority（自身条目落回 tier 100）会让 tier 110 的勘误反过来压过它。
  testWidgets('standard build rides the higher-priority cross-package rules (M/P0-2.5)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // 同一个 slug（`tough`）的两个包：alpha 是角色选中的那条（priority 50），
    // beta 是勘误（priority 10）。alpha 必须赢：hitDie 8 / prepared 3。
    final ownClass = ContentEntry.fromJson(<String, Object?>{
      'id': 'alpha:class/tough',
      'type': 'class',
      'slug': 'tough',
      'name': '磐石骑士',
      'body': <Object?>[],
      'revision': 1,
      'structured': <String, Object?>{
        'classRules': <String, Object?>{
          'hitDie': 8,
          'spellcasting': <String, Object?>{
            'mode': 'prepared',
            'ability': 'int',
            'prepared': <String, Object?>{'1': 3},
          },
        },
      },
      'rules': <String, Object?>{
        'choices': <Object?>[
          <String, Object?>{
            'id': 'spellbook',
            'label': '法术书',
            'optionType': 'spell',
            'minimum': 0,
            'maximum': 5,
            'countsToward': 'prepared',
            'optionTags': <Object?>['spell-list:mage'],
          },
        ],
      },
    });
    final errata = ContentEntry.fromJson(<String, Object?>{
      'id': 'beta:class/tough',
      'type': 'class',
      'slug': 'tough',
      'name': '磐石骑士勘误',
      'body': <Object?>[],
      'revision': 1,
      'structured': <String, Object?>{
        'classRules': <String, Object?>{
          'hitDie': 12,
          'spellcasting': <String, Object?>{
            'mode': 'prepared',
            'prepared': <String, Object?>{'1': 9},
          },
        },
      },
    });

    await tester.pumpWidget(
      MaterialApp(
        home: CharacterEditorPage(
          defaultCreationMethod: 'standard',
          contentEntries: [ownClass, errata],
          packagePriorities: const {'alpha': 50, 'beta': 10},
          onSubmit: (_) async => true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, '磐石骑士'));
    await tester.pumpAndSettle();

    // 先从属性步骤读出向导实际使用的 CON，再算出"alpha(d8)"与"beta(d12)"两个候选
    // 1 级 HP（2024：1 级 = 满骰 + 体质调整值）。两个候选必然不同，否则用例空转。
    await _goToBuilderStep(tester, 3, '属性');
    final conScore = int.parse(
      tester
          .widget<TextField>(
            find.byKey(const Key('standard-ability-con-field')),
          )
          .controller!
          .text,
    );
    final ownHp = Dnd5eRules.averageHitPointsForHitDie(
      hitDie: 8,
      level: 1,
      constitution: conScore,
    );
    final errataHp = Dnd5eRules.averageHitPointsForHitDie(
      hitDie: 12,
      level: 1,
      constitution: conScore,
    );
    expect(ownHp, isNot(errataHp), reason: '两个候选必须不同，用例才有区分度');

    await _goToBuilderStep(tester, 0, '职业');
    // 等级区生命骰（走 `classRules`）。
    expect(
      find.text('HP $ownHp'),
      findsOneWidget,
      reason: '等级区 HP 必须用高 priority 的 alpha（d8），不是 beta 的 d12',
    );
    expect(find.text('HP $errataHp'), findsNothing);
    // 头部 HP 预览（同一个 `classRules`）。
    expect(
      _hpSummaryValue(tester),
      '$ownHp',
      reason: '头部 HP 预览必须与等级区同一口径',
    );

    // 向导法术配额（`RuleChoiceQuota.limitsFor(rules: _resolveClassRules(...))`）：
    // 额度 5 与 prepared 池上限取小 → alpha 的 3（beta 会是 9 → 5）。
    await _goToBuilderStep(tester, 6, '法术');
    expect(
      find.text('已选 0/3'),
      findsOneWidget,
      reason: '法术配额必须用高 priority 的 alpha（prepared 3）',
    );
    expect(find.text('已选 0/5'), findsNothing);
  });

  // M（跨包索引必填）：反向夹具——**勘误包的 priority 更高**时，向导必须以勘误的
  // 数值为准（与 `RulesDrivenCharacterBuilder` 落库结果一致）。不带
  // `overrides:`（看不见别的包的声明）就会退回自身条目的 d8 / prepared 3。
  testWidgets('standard build sees a higher-priority errata from another package (M)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    ContentEntry entry(
      String packageId,
      String name,
      int hitDie,
      int prepared,
    ) => ContentEntry.fromJson(<String, Object?>{
      'id': '$packageId:class/tough',
      'type': 'class',
      'slug': 'tough',
      'name': name,
      'body': <Object?>[],
      'revision': 1,
      'structured': <String, Object?>{
        'classRules': <String, Object?>{
          'hitDie': hitDie,
          'spellcasting': <String, Object?>{
            'mode': 'prepared',
            'ability': 'int',
            'prepared': <String, Object?>{'1': prepared},
          },
        },
      },
      'rules': <String, Object?>{
        'choices': <Object?>[
          <String, Object?>{
            'id': 'spellbook',
            'label': '法术书',
            'optionType': 'spell',
            'minimum': 0,
            'maximum': 5,
            'countsToward': 'prepared',
            'optionTags': <Object?>['spell-list:mage'],
          },
        ],
      },
    });

    await tester.pumpWidget(
      MaterialApp(
        home: CharacterEditorPage(
          defaultCreationMethod: 'standard',
          contentEntries: [
            entry('alpha', '磐石骑士', 8, 3),
            entry('beta', '磐石骑士勘误', 12, 9),
          ],
          // 勘误包 priority 更高 ⇒ beta tier 150 > 自身条目 tier 100。
          packagePriorities: const {'alpha': 0, 'beta': 50},
          onSubmit: (_) async => true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, '磐石骑士'));
    await tester.pumpAndSettle();

    await _goToBuilderStep(tester, 3, '属性');
    final conScore = int.parse(
      tester
          .widget<TextField>(
            find.byKey(const Key('standard-ability-con-field')),
          )
          .controller!
          .text,
    );
    final errataHp = Dnd5eRules.averageHitPointsForHitDie(
      hitDie: 12,
      level: 1,
      constitution: conScore,
    );
    final ownHp = Dnd5eRules.averageHitPointsForHitDie(
      hitDie: 8,
      level: 1,
      constitution: conScore,
    );
    expect(errataHp, isNot(ownHp));

    await _goToBuilderStep(tester, 0, '职业');
    expect(
      find.text('HP $errataHp'),
      findsOneWidget,
      reason: '勘误 priority 更高 ⇒ 等级区 HP 用 errata 的 d12',
    );
    expect(find.text('HP $ownHp'), findsNothing);
    expect(_hpSummaryValue(tester), '$errataHp');

    await _goToBuilderStep(tester, 6, '法术');
    expect(
      find.text('已选 0/5'),
      findsOneWidget,
      reason: '勘误 priority 更高 ⇒ prepared 9 与额度 5 取小 = 5',
    );
    expect(find.text('已选 0/3'), findsNothing);
  });

  // 阻塞项 2：`optionType: "skill"` 的内联选择由专门的技能选择器承担，通用条目
  // 选项卡片不得把它渲染成"资料库中缺少 skill 选项。"的红色假错误；同时技能仍然
  // 可选、仍然写进草稿。
  testWidgets(
    'standard build renders skill choices with the picker, not a missing-option error',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sage = ContentEntry.fromJson({
        'id': 'test:class/battle-sage',
        'type': 'class',
        'slug': 'battle-sage',
        'name': '战贤',
        'body': <Map<String, Object?>>[],
        'revision': 1,
        'structured': {
          'classRules': {
            'hitDie': 10,
            'savingThrowAbilities': ['int', 'wis'],
          },
        },
        'rules': {
          'choices': [
            {
              'id': 'class-skills',
              'label': '选择两项技能熟练',
              'optionType': 'skill',
              'minimum': 2,
              'maximum': 2,
              'builderStep': 'proficiencies',
              'options': <Object?>['洞悉', '医药', '说服', '宗教'],
            },
          ],
        },
      });
      CharacterEditDraft? submitted;

      await tester.pumpWidget(
        MaterialApp(
          home: CharacterEditorPage(
            defaultCreationMethod: 'standard',
            contentEntries: [sage],
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
      await _goToBuilderStep(tester, 4, '熟练');

      expect(find.text('资料库中缺少 skill 选项。'), findsNothing);
      expect(find.byKey(const Key('standard-skill-洞悉-chip')), findsOneWidget);
      expect(find.byKey(const Key('standard-skill-宗教-chip')), findsOneWidget);
      // 技能选择器仍然受 `minimum` 约束（战贤只有这 4 项候选）。
      expect(find.textContaining('职业技能 0/2'), findsOneWidget);

      await tester.tap(find.byKey(const Key('standard-skill-洞悉-chip')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('standard-skill-宗教-chip')));
      await tester.pumpAndSettle();
      expect(find.textContaining('职业技能 2/2'), findsOneWidget);

      await _goToBuilderStep(tester, 8, '审核');
      await tester.tap(find.widgetWithText(FilledButton, '创建角色'));
      await tester.pumpAndSettle();

      expect(submitted, isNotNull);
      expect(submitted!.skills['洞悉'], isTrue);
      expect(submitted!.skills['宗教'], isTrue);
    },
  );
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
          contentEntries: const [
            _wizardContent,
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
    await _goToBuilderStep(tester, 6, '法术');
    await tester.ensureVisible(find.text('魔法飞弹 / Magic Missile'));
    await tester.tap(find.text('魔法飞弹 / Magic Missile'));
    await tester.pumpAndSettle();
    await _goToBuilderStep(tester, 5, '装备');
    await tester.ensureVisible(find.text('长剑 / Longsword'));
    await tester.tap(find.text('长剑 / Longsword'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('治疗药水 / Potion of Healing'));
    await tester.tap(find.text('治疗药水 / Potion of Healing'));
    await tester.pumpAndSettle();

    await _goToBuilderStep(tester, 8, '审核');
    await tester.tap(find.widgetWithText(FilledButton, '创建角色'));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    final data = submitted!.data;
    expect(data['contentRefs'], {
      'spells': ['content-spell-magic-missile'],
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

  // Spec §头像来源: 本地角色头像离线保存在客户端；战役角色头像在绑定战役后自动上传。
  // 头像选择必须出现在角色创建/编辑流程里，而不是发布对话框。
  testWidgets(
    'full sheet character editor exposes avatar picker and saves avatar data url',
    (tester) async {
      CharacterEditDraft? submitted;
      final fakeBytes = _validPngBytes;
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterEditorPage(
            onPickImage: () async => (bytes: fakeBytes, mimeType: 'image/png'),
            onSubmit: (draft) async {
              submitted = draft;
              return true;
            },
          ),
        ),
      );

      // 从标准引导进入完整角色卡。
      await tester.tap(find.widgetWithText(FilledButton, '标准创建'));
      await tester.pumpAndSettle();
      final fullSheetButton = find.widgetWithText(OutlinedButton, '继续编辑完整角色卡');
      await tester.tap(
        fullSheetButton.evaluate().isNotEmpty
            ? fullSheetButton
            : find.byTooltip('继续编辑完整角色卡'),
      );
      await tester.pumpAndSettle();

      // 基础区出现头像选择器。
      final avatarPicker = find.byKey(const Key('character-avatar-picker'));
      expect(avatarPicker, findsOneWidget);

      // 点击选择图片。
      await tester.tap(find.widgetWithText(OutlinedButton, '选择图片'));
      await tester.pumpAndSettle();

      // 填名字后保存。
      await tester.enterText(find.byKey(const Key('character-name')), 'Mira');
      await tester.tap(find.widgetWithText(FilledButton, '保存角色'));
      await tester.pumpAndSettle();

      expect(submitted, isNotNull);
      expect(submitted!.avatarUrl, isNotNull);
      expect(
        submitted!.avatarUrl!.startsWith('data:image/png;base64,'),
        isTrue,
      );
    },
  );

  testWidgets(
    'edit character editor preserves existing avatar url when not changed',
    (tester) async {
      CharacterEditDraft? submitted;
      const existing = CharacterSheet(
        id: 'char-avatar',
        ownerUserId: 'user-1',
        name: 'Elara',
        avatarUrl: _validPngDataUrl,
        system: 'dnd5e',
        level: 1,
        classSummary: '法师',
        raceSummary: '精灵',
        currentHp: 6,
        maxHp: 6,
        armorClass: 10,
        speed: 30,
        initiativeBonus: 0,
        abilities: {
          'str': 10,
          'dex': 14,
          'con': 12,
          'int': 16,
          'wis': 10,
          'cha': 10,
        },
        saves: {'int': true, 'wis': true},
        skills: {'奥秘': true},
        inventory: [],
        currency: {},
        notes: '',
        data: {},
        createdAt: '2026-07-01T00:00:00.000Z',
        updatedAt: '2026-07-01T00:00:00.000Z',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterEditorPage(
            initialCharacter: existing,
            onSubmit: (draft) async {
              submitted = draft;
              return true;
            },
          ),
        ),
      );

      // 编辑模式直接进入 fullSheet。
      expect(find.byKey(const Key('character-avatar-picker')), findsOneWidget);
      expect(find.text('编辑角色'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('character-name')), 'Elara');
      await tester.tap(find.widgetWithText(FilledButton, '保存角色'));
      await tester.pumpAndSettle();

      expect(submitted, isNotNull);
      // 未重新选图时保留原有头像。
      expect(submitted!.avatarUrl, existing.avatarUrl);
    },
  );

  testWidgets('standard build story step captures avatar and story fields', (
    tester,
  ) async {
    final fakeBytes = _validPngBytes;
    CharacterEditDraft? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterEditorPage(
          defaultCreationMethod: 'standard',
          onPickImage: () async => (bytes: fakeBytes, mimeType: 'image/jpeg'),
          onSubmit: (draft) async {
            submitted = draft;
            return true;
          },
        ),
      ),
    );

    expect(find.text('标准创建角色'), findsOneWidget);

    // 跳到“故事”步骤（step 7）。
    await _goToBuilderStep(tester, 7, '故事');
    await tester.pumpAndSettle();

    // 故事步骤提供头像及结构化人物故事字段。
    expect(
      find.byKey(const Key('standard-character-avatar-picker')),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(OutlinedButton, '选择图片'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('character-story-appearance')),
      '银色短发',
    );
    await tester.enterText(
      find.byKey(const Key('character-story-backstory')),
      '在沿海剧团长大。',
    );

    // 回到职业步骤填名字并提交。
    await _goToBuilderStep(tester, 0, '职业');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('standard-character-name-field')),
      'StandardAvatar',
    );
    await _goToBuilderStep(tester, 8, '审核');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '创建角色'));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.avatarUrl, isNotNull);
    expect(submitted!.avatarUrl!.startsWith('data:image/jpeg;base64,'), isTrue);
    expect(
      (submitted!.data['story'] as Map<String, Object?>)['appearance'],
      '银色短发',
    );
    expect(
      (submitted!.data['story'] as Map<String, Object?>)['backstory'],
      '在沿海剧团长大。',
    );
  });

  // Spec §统一业务列表: 动作/法术/装备/资源/特性使用同一紧凑行规范（contentPadding zero）；
  // 条目点击打开已有浮层 reader；列表尾部提供 FilledButton.tonalIcon 添加命令。
  testWidgets(
    'spells panel groups spells by level and opens the reader on tap',
    (tester) async {
      final character = _character.copyWith(
        data: <String, Object?>{
          'runtime': <String, Object?>{'temporaryHp': 5},
          'contentRefs': <String, Object?>{
            'spells': <String>[
              'guide:spell/fire-bolt',
              'guide:spell/magic-missile',
              'guide:spell/shield',
            ],
          },
        },
      );
      final fireBolt = ContentEntry.fromJson({
        'id': 'guide:spell/fire-bolt',
        'type': 'spell',
        'slug': 'fire-bolt',
        'name': '火焰箭',
        'body': <Map<String, Object?>>[],
        'revision': 1,
        'structured': {'level': 0},
      });
      final magicMissile = ContentEntry.fromJson({
        'id': 'guide:spell/magic-missile',
        'type': 'spell',
        'slug': 'magic-missile',
        'name': '魔法飞弹',
        'body': <Map<String, Object?>>[],
        'revision': 1,
        'structured': {'level': 1},
      });
      final shield = ContentEntry.fromJson({
        'id': 'guide:spell/shield',
        'type': 'spell',
        'slug': 'shield',
        'name': '护盾术',
        'body': <Map<String, Object?>>[],
        'revision': 1,
        'structured': {'level': 1},
      });

      await tester.pumpWidget(
        MaterialApp(
          home: CharacterDetailPage(
            character: character,
            contentEntries: [fireBolt, magicMissile, shield],
            initialTab: 'spells',
            onSaveCharacter: (_) async => true,
          ),
        ),
      );

      // 法术按环位分组：戏法在前，一环在后。
      expect(find.text('戏法'), findsOneWidget);
      expect(find.text('一环'), findsOneWidget);
      final cantripIndex = tester.getCenter(find.text('戏法')).dy;
      final leveledIndex = tester.getCenter(find.text('一环')).dy;
      expect(cantripIndex, lessThan(leveledIndex));

      // 紧凑行规范：contentPadding 为 zero。
      final magicMissileTile = tester.widget<ListTile>(
        find.ancestor(of: find.text('魔法飞弹'), matching: find.byType(ListTile)),
      );
      expect(magicMissileTile.contentPadding, EdgeInsets.zero);

      // 列表尾部提供添加命令。
      expect(find.widgetWithText(FilledButton, '添加法术'), findsOneWidget);

      // 点击关联条目打开 reader 浮层。
      await tester.ensureVisible(find.text('魔法飞弹').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('魔法飞弹').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('content-detail-close')), findsOneWidget);
      await tester.tap(find.byKey(const Key('content-detail-close')));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('spells panel renders custom spells and opens their details', (
    tester,
  ) async {
    final character = _character.copyWith(
      data: <String, Object?>{
        'manualOverrides': <String, Object?>{
          'spells': <String, Object?>{
            'custom': <Map<String, Object?>>[
              {
                'id': 'custom-spell-1',
                'name': '星火束',
                'level': 1,
                'school': '塑能',
                'description': '一道只属于这个角色的星光。',
              },
            ],
          },
        },
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CharacterDetailPage(
          character: character,
          contentEntries: const [],
          initialTab: 'spells',
          onSaveCharacter: (_) async => true,
        ),
      ),
    );

    expect(find.text('自定义法术'), findsOneWidget);
    expect(find.text('星火束'), findsOneWidget);
    expect(find.text('一环 · 塑能'), findsOneWidget);

    await tester.tap(find.text('星火束'));
    await tester.pumpAndSettle();
    expect(find.text('一道只属于这个角色的星光。'), findsOneWidget);
  });

  testWidgets(
    'equipment panel places currency above items and opens the reader on tap',
    (tester) async {
      final character = _character.copyWith(
        inventory: <Map<String, Object?>>[
          <String, Object?>{
            'entryId': 'guide:equipment/longbow',
            'name': '长弓',
            'quantity': 1,
          },
        ],
        currency: <String, Object?>{'gp': 10},
      );
      final longbow = ContentEntry.fromJson({
        'id': 'guide:equipment/longbow',
        'type': 'equipment',
        'slug': 'longbow',
        'name': '长弓',
        'body': <Map<String, Object?>>[],
        'revision': 1,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: CharacterDetailPage(
            character: character,
            contentEntries: [longbow],
            initialTab: 'equipment',
            onUpdateInventory: ({inventory, currency}) async {},
          ),
        ),
      );

      // 货币段位于装备与物品段之前。
      final currencyIndex = tester.getCenter(find.text('货币')).dy;
      final itemsIndex = tester.getCenter(find.text('装备与物品')).dy;
      expect(currencyIndex, lessThan(itemsIndex));

      // 列表尾部提供从资料库添加命令。
      expect(find.widgetWithText(FilledButton, '从资料库添加'), findsOneWidget);

      // 装备行使用紧凑行规范。
      final longbowTile = tester.widget<ListTile>(
        find.ancestor(of: find.text('长弓 x1'), matching: find.byType(ListTile)),
      );
      expect(longbowTile.contentPadding, EdgeInsets.zero);
      expect(longbowTile.dense, isTrue);

      // 点击带资料引用的条目打开 reader 浮层。
      await tester.ensureVisible(find.text('长弓 x1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('长弓 x1'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('content-detail-close')), findsOneWidget);
      await tester.tap(find.byKey(const Key('content-detail-close')));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'features panel renders rule grants with compact rows and opens the reader',
    (tester) async {
      final character = _character.copyWith(
        data: <String, Object?>{
          'resolvedGrants': <Map<String, Object?>>[
            <String, Object?>{
              'id': 'second-wind',
              'kind': 'feature',
              'label': '回气',
              'entryId': 'guide:class-feature/second-wind',
              'sourceEntryId': 'guide:class/fighter',
              'sourceEntryName': '战士',
              'sourceLevel': 1,
            },
          ],
        },
      );
      final secondWind = ContentEntry.fromJson({
        'id': 'guide:class-feature/second-wind',
        'type': 'classFeature',
        'slug': 'second-wind',
        'name': '回气',
        'body': <Map<String, Object?>>[],
        'revision': 1,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: CharacterDetailPage(
            character: character,
            contentEntries: [secondWind],
            initialTab: 'features',
            onSaveCharacter: (_) async => true,
          ),
        ),
      );

      expect(find.text('自动获得的特性'), findsOneWidget);
      expect(find.text('回气'), findsOneWidget);

      // 紧凑行规范：dense + contentPadding zero。
      final grantTile = tester.widget<ListTile>(
        find.ancestor(of: find.text('回气'), matching: find.byType(ListTile)),
      );
      expect(grantTile.contentPadding, EdgeInsets.zero);
      expect(grantTile.dense, isTrue);

      // 列表尾部提供从资料库添加命令。
      expect(find.widgetWithText(FilledButton, '从资料库添加'), findsOneWidget);

      // 点击带 entryId 的特性打开 reader 浮层。
      await tester.tap(find.text('回气').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('content-detail-close')), findsOneWidget);
      await tester.tap(find.byKey(const Key('content-detail-close')));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'resources panel adapts columns and shows shortRest/longRest/none labels',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final character = _character.copyWith(
        data: <String, Object?>{
          'runtime': <String, Object?>{'temporaryHp': 5},
          'classResources': <Map<String, Object?>>[
            <String, Object?>{
              'id': 'res-action-surge',
              'name': '动作如潮',
              'maximum': 1,
              'recovery': 'shortRest',
            },
            <String, Object?>{
              'id': 'res-rage',
              'name': '狂暴',
              'maximum': 3,
              'recovery': 'longRest',
            },
            <String, Object?>{
              'id': 'res-heroic',
              'name': '英雄点',
              'maximum': 2,
              'recovery': 'none',
            },
          ],
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CharacterDetailPage(
            character: character,
            initialTab: 'resources',
            onSaveCharacter: (_) async => true,
          ),
        ),
      );

      // 三种恢复标签都应渲染。
      expect(find.text('短休恢复'), findsOneWidget);
      expect(find.text('长休恢复'), findsOneWidget);
      expect(find.text('不自动恢复'), findsOneWidget);

      // 列表尾部提供添加资源命令。
      expect(find.widgetWithText(FilledButton, '添加资源'), findsOneWidget);
    },
  );

  testWidgets('actions panel renders rule actions with compact rows', (
    tester,
  ) async {
    final character = _character.copyWith(
      data: <String, Object?>{
        'actions': <Map<String, Object?>>[
          <String, Object?>{
            'id': 'riposte',
            'name': '还击',
            'entryId': 'guide:feature/riposte',
            'formula': '1d8+2',
          },
        ],
      },
    );
    final riposte = ContentEntry.fromJson({
      'id': 'guide:feature/riposte',
      'type': 'classFeature',
      'slug': 'riposte',
      'name': '还击',
      'body': <Map<String, Object?>>[],
      'revision': 1,
    });

    await tester.pumpWidget(
      MaterialApp(
        home: CharacterDetailPage(
          character: character,
          contentEntries: [riposte],
          initialTab: 'actions',
        ),
      ),
    );

    expect(find.text('资料动作'), findsOneWidget);
    expect(find.text('还击'), findsOneWidget);

    // 紧凑行规范：dense + contentPadding zero。
    final actionTile = tester.widget<ListTile>(
      find.ancestor(of: find.text('还击'), matching: find.byType(ListTile)),
    );
    expect(actionTile.contentPadding, EdgeInsets.zero);
    expect(actionTile.dense, isTrue);
  });

  testWidgets(
    'monster character uses the full sheet and exposes stat-block sections',
    (tester) async {
      final monster = _character.copyWith(
        name: '丧尸',
        level: 1,
        classSummary: '怪物 · CR 1/4',
        raceSummary: '中型亡灵',
        data: const {
          'character': {
            'kind': 'monster',
            'templateRef': 'private-mm2024:monster/zombie',
            'size': 'medium',
            'creatureType': 'undead',
            'alignment': 'neutral-evil',
            'challengeRating': '1/4',
            'proficiencyBonus': 2,
          },
          'markdownSections': {
            '感官与语言': '- 黑暗视觉：60 尺\n- 被动察觉：8',
            '特质': '### 不死坚韧\n\n受到致命伤害时进行体质豁免。',
            '动作': '### 重击\n\n- 命中：+3\n- 伤害：1d8+1 钝击',
          },
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CharacterDetailPage(
            character: monster,
            initialTab: 'character',
          ),
        ),
      );

      expect(find.text('怪物资料'), findsWidgets);
      expect(find.text('CR 1/4'), findsOneWidget);
      expect(find.text('特质'), findsOneWidget);
      expect(find.textContaining('不死坚韧'), findsOneWidget);
      expect(find.text('动作'), findsWidgets);
      expect(find.textContaining('重击'), findsOneWidget);
    },
  );

  testWidgets('full editor preserves and edits monster character sections', (
    tester,
  ) async {
    CharacterEditDraft? saved;
    final monster = _character.copyWith(
      name: '丧尸',
      data: const {
        'character': {
          'kind': 'monster',
          'challengeRating': '1/4',
          'creatureType': 'undead',
        },
        'markdownSections': {'特质': '### 不死坚韧', '动作': '### 重击'},
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CharacterEditorPage(
          initialCharacter: monster,
          onSubmit: (draft) async {
            saved = draft;
            return false;
          },
        ),
      ),
    );

    expect(find.byKey(const Key('character-kind-field')), findsOneWidget);
    expect(find.byKey(const Key('character-section-actions')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('character-section-actions')),
      '### 腐烂重击\n\n- 伤害：2d6',
    );
    await tester.tap(find.widgetWithText(FilledButton, '保存角色'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    final character = saved!.data['character'] as Map<Object?, Object?>;
    final sections = saved!.data['markdownSections'] as Map<Object?, Object?>;
    expect(character['kind'], 'monster');
    expect(sections['动作'], contains('腐烂重击'));
  });
}

const _validPngDataUrl =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC'
    'AAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

final Uint8List _validPngBytes = base64Decode(
  _validPngDataUrl.substring(_validPngDataUrl.indexOf(',') + 1),
);

/// 读头部摘要里 `label == 'HP'` 那个指标的数值。
///
/// `_SummaryMetric` 的 Column 恰好两个 Text（先 value 后 label），因此从最近的
/// 祖先 Column 往外找第一个满足该形状的即可——比按文本猜数字稳。
String _hpSummaryValue(WidgetTester tester) {
  final columns = find.ancestor(
    of: find.text('HP'),
    matching: find.byType(Column),
  );
  for (final candidate in columns.evaluate()) {
    final texts = find
        .descendant(
          of: find.byElementPredicate((element) => element == candidate),
          matching: find.byType(Text),
        )
        .evaluate()
        .map((element) => (element.widget as Text).data)
        .toList();
    if (texts.length == 2 && texts[1] == 'HP') return texts[0]!;
  }
  throw StateError('未找到头部 HP 摘要指标');
}

Future<void> _goToBuilderStep(
  WidgetTester tester,
  int index,
  String label,
) async {
  if (find.byType(NavigationRail).evaluate().isNotEmpty) {
    final destination = find.byKey(Key('builder-step-$index'));
    final selectedDestination = find.byKey(Key('builder-step-$index-selected'));
    await tester.tap(
      destination.evaluate().isNotEmpty ? destination : selectedDestination,
    );
  } else {
    await tester.tap(find.byKey(const Key('builder-mobile-step-selector')));
    await tester.pumpAndSettle();
    final option = find.byWidgetPredicate(
      (widget) => widget is Text && widget.data?.endsWith('. $label') == true,
    );
    await tester.tap(option);
  }
  await tester.pumpAndSettle();
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

/// 与 [_character] 相同，只是长弓带上了资料条目引用（任务 8：武器攻击
/// 只认物品条目自身的声明，没有 `entryId` 就不产出攻击）。
final _characterWithWeaponEntries = _character.copyWith(
  inventory: const <Map<String, Object?>>[
    <String, Object?>{
      'entryId': 'guide:equipment/longbow',
      'name': '长弓',
      'quantity': 1,
    },
    <String, Object?>{'name': '治疗药水', 'quantity': 2},
  ],
);

/// 任务 8：武器攻击改读物品条目自身的 `structured.damage` / `category`，
/// 夹具因此必须给出真实的条目，而不是只靠物品名。
const _bowEntry = ContentEntry(
  id: 'guide:equipment/longbow',
  type: 'equipment',
  slug: 'longbow',
  name: '长弓',
  body: [],
  revision: 1,
  structured: {'category': '远程武器', 'damage': '1d8 穿刺'},
);

/// Task 3.3 — 记录 dispatchRoll 调用, 用于验证角色卡检定转发到战役动作接收端.
class _RecordingSink implements CampaignActionSink {
  final List<CharacterRollEvent> events = [];

  @override
  String? get campaignCharacterId => 'character-rec';

  @override
  Future<void> dispatchRoll(CharacterRollEvent event) async {
    events.add(event);
  }
}

const _fighterContent = ContentEntry(
  id: 'content-class-fighter',
  type: 'class',
  slug: 'class-fighter',
  name: '战士 / Fighter',
  body: [],
  revision: 1,
  structured: {
    'page': 60,
    'primaryAbility': '力量或敏捷',
    'weaponProficiency': '简易武器与军用武器',
    'armorProficiency': '轻甲、中甲、重甲与盾牌',
    'startingEquipment': '链甲、巨剑、轻弩、20支弩矢、地城套组以及4GP',
    // 任务 10：规则值只在 `classRules`，不再有顶层 `hitDie` / `savingThrows` /
    // `skills` 散文副本。
    'classRules': {'hitDie': 10, 'savingThrowAbilities': ['str', 'con']},
  },
  tags: ['private-phb-2024-index', 'class'],
  source: ContentSource(label: 'Private PHB 2024 PDF Index'),
);

/// 与 [_fighterContent] 同样的展示字段，但技能选择改由**新契约**承载：
/// `rules.choices` 里 `optionType: "skill"` 的内联 `options`。
/// 旧的中文散文 `structured.skills` 在夹具里**已经删除**（规则值只在
/// `structured.classRules`）；这个用例覆盖的是"技能选择在规则摘要里照实展示"。
final _fighterRulesContent = ContentEntry.fromJson({
  'id': 'content-class-fighter',
  'type': 'class',
  'slug': 'class-fighter',
  'name': '战士 / Fighter',
  'body': <Map<String, Object?>>[],
  'revision': 1,
  'structured': {
    'page': 60,
    'primaryAbility': '力量或敏捷',
    'weaponProficiency': '简易武器与军用武器',
    'armorProficiency': '轻甲、中甲、重甲与盾牌',
    'startingEquipment': '链甲、巨剑、轻弩、20支弩矢、地城套组以及4GP',
    // 任务 10：生命骰 / 豁免熟练的唯一来源是 `classRules`（旧散文键已删除）。
    'classRules': {
      'hitDie': 10,
      'savingThrowAbilities': ['str', 'con'],
    },
  },
  'rules': {
    'choices': [
      {
        'id': 'class-skills',
        'label': '选择两项技能熟练',
        'optionType': 'skill',
        'minimum': 2,
        'maximum': 2,
        'builderStep': 'proficiencies',
        'options': ['杂技', '驯兽', '运动', '历史', '洞悉', '威吓', '说服', '察觉', '求生'],
      },
    ],
  },
  'tags': ['private-phb-2024-index', 'class'],
  'source': {'label': 'Private PHB 2024 PDF Index'},
});

const _wizardContent = ContentEntry(
  id: 'content-class-wizard',
  type: 'class',
  slug: 'class-wizard',
  name: '法师 / Wizard',
  body: [],
  revision: 1,
  structured: {
    'primaryAbility': '智力',
    'startingEquipment': '法术书、长袍、匕首以及5GP',
    // 任务 8.5：法术选择规则走新契约 `classRules.spellcasting`
    // （逐级表 + 原型），不再有顶层 progression 行数组。
    'classRules': {
      'hitDie': 6,
      'savingThrowAbilities': ['int', 'wis'],
      'spellcasting': {
        'mode': 'prepared',
        'ability': 'int',
        'listTags': ['spell-list:wizard'],
        'maximumSpellLevel': [1],
        'cantrips': [3],
        'prepared': [4],
      },
    },
  },
  tags: ['private-phb-2024-index', 'class'],
  source: ContentSource(label: 'Private PHB 2024 PDF Index'),
);

const _aasimarContent = ContentEntry(
  id: 'content-species-aasimar',
  type: 'species',
  slug: 'species-aasimar',
  name: '阿斯莫 / Aasimar',
  body: [],
  revision: 1,
  structured: {'page': 113},
  tags: ['private-phb-2024-index', 'species'],
  source: ContentSource(label: 'Private PHB 2024 PDF Index'),
);

const _acolyteContent = ContentEntry(
  id: 'content-background-acolyte',
  type: 'background',
  slug: 'background-acolyte',
  name: '侍僧 / Acolyte',
  body: [],
  revision: 1,
  structured: {'page': 111},
  tags: ['private-phb-2024-index', 'background'],
  source: ContentSource(label: 'Private PHB 2024 PDF Index'),
);

const _magicMissileContent = ContentEntry(
  id: 'content-spell-magic-missile',
  type: 'spell',
  slug: 'spell-magic-missile',
  name: '魔法飞弹 / Magic Missile',
  body: [],
  revision: 1,
  structured: {
    'page': 290,
    'level': 1,
    'school': '塑能',
    'classes': ['法师'],
  },
  tags: ['private-phb-2024-index', 'spell', 'spell-list:wizard'],
  source: ContentSource(label: 'Private PHB 2024 PDF Index'),
);

const _longswordContent = ContentEntry(
  id: 'content-equipment-longsword',
  type: 'equipment',
  slug: 'equipment-longsword',
  name: '长剑 / Longsword',
  body: [],
  revision: 1,
  structured: {'page': 215},
  tags: ['private-phb-2024-index', 'equipment'],
  source: ContentSource(label: 'Private PHB 2024 PDF Index'),
);

const _healingPotionContent = ContentEntry(
  id: 'content-item-healing-potion',
  type: 'item',
  slug: 'item-healing-potion',
  name: '治疗药水 / Potion of Healing',
  body: [],
  revision: 1,
  structured: {'page': 228},
  tags: ['private-phb-2024-index', 'item'],
  source: ContentSource(label: 'Private PHB 2024 PDF Index'),
);
