import 'dart:convert';
import 'dart:typed_data';

import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/characters/domain/character_edit_draft.dart';
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
    expect(find.text('灵感'), findsOneWidget);
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
      'structured': {'hitDie': 'd10'},
      'rules': {
        'progression': [
          {
            'level': 2,
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
      'structured': {'hitDie': 'd10'},
      'rules': {
        'progression': [
          {
            'level': 2,
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
    expect(build['choices'], {
      'guide:class/guardian#technique': ['guide:class-feature/battle-focus'],
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
    await tester.enterText(find.byKey(const Key('hp-quick-value-field')), '1');
    await tester.tap(find.widgetWithText(FilledButton, '受到伤害'));
    await tester.pumpAndSettle();
    expect(find.text('当前 HP 23/24'), findsOneWidget);
    expect(updates.last['currentHp'], 23);

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
        '7',
      );
      await tester.tap(find.widgetWithText(FilledButton, '受到伤害'));
      await tester.pumpAndSettle();
      expect(find.text('当前 HP 17/24'), findsOneWidget);
      expect(updates.last['currentHp'], 17);

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
    expect(find.text('快速创建'), findsWidgets);
    expect(find.text('标准创建'), findsWidgets);
    expect(find.text('导入或复制'), findsOneWidget);
    expect(find.byKey(const Key('character-name')), findsNothing);
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
    for (final step in ['职业', '背景', '物种', '属性', '熟练', '详情', '审核']) {
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
        'hitDie': 'd10',
        'savingThrows': '力量与体质',
        'skills': '选择2项：特技、驯兽、运动、历史、洞悉、威吓、游说、察觉、求生',
      },
      'rules': {
        'progression': [
          {
            'level': 1,
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
          contentEntries: const [_fighterContent],
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

  testWidgets('standard build details step exposes avatar picker', (
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

    // 跳到"详情"步骤（step 7）。
    await _goToBuilderStep(tester, 7, '详情');
    await tester.pumpAndSettle();

    // 详情步骤出现头像选择器。
    expect(
      find.byKey(const Key('standard-character-avatar-picker')),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(OutlinedButton, '选择图片'));
    await tester.pumpAndSettle();

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
  });
}

const _validPngDataUrl =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC'
    'AAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

final Uint8List _validPngBytes = base64Decode(
  _validPngDataUrl.substring(_validPngDataUrl.indexOf(',') + 1),
);

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
    'hitDie': 'd10',
    'savingThrows': '力量与体质',
    'skills': '选择2项：特技、驯兽、运动、历史、洞悉、威吓、游说、察觉、求生',
    'weaponProficiency': '简易武器与军用武器',
    'armorProficiency': '轻甲、中甲、重甲与盾牌',
    'startingEquipment': '链甲、巨剑、轻弩、20支弩矢、地城套组以及4GP',
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
  structured: {'page': 290},
  tags: ['private-phb-2024-index', 'spell'],
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
