import 'package:dnd_table_client/src/features/campaigns/domain/campaign_character.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/center/campaign_characters_panel.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/widgets/campaign_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/campaign_test_support.dart';

void main() {
  List<CampaignCharacter> characters() => [
    testCampaignCharacter(
      id: 'player-1',
      ownerUserId: 'user-1',
      characterType: 'player',
      sheet: const {'name': '阿兰尼斯', 'currentHp': 9, 'maxHp': 10},
    ),
    testCampaignCharacter(
      id: 'npc-1',
      ownerUserId: null,
      characterType: 'npc',
      visibleToPlayers: false,
      sheet: const {'name': '酒馆老板'},
    ),
    testCampaignCharacter(
      id: 'temp-1',
      ownerUserId: null,
      characterType: 'npc',
      lifecycle: 'temporary',
      sheet: const {'name': '临时守卫'},
    ),
    testCampaignCharacter(
      id: 'archived-1',
      ownerUserId: null,
      characterType: 'monster',
      status: 'archived',
      sheet: const {'name': '旧敌人'},
    ),
  ];

  Widget panel({required bool isManager}) => MaterialApp(
    home: Scaffold(
      body: CampaignCharactersPanel(
        characters: characters(),
        isManager: isManager,
        onOpenCharacter: (_) {},
        onCreateCharacter: isManager
            ? ({
                required characterType,
                required displayName,
                required lifecycle,
                int? maxHp,
              }) async => null
            : null,
      ),
    ),
  );

  testWidgets(
    'groups active characters and keeps archived characters collapsed',
    (tester) async {
      await tester.pumpWidget(panel(isManager: true));

      expect(find.text('玩家角色'), findsWidgets);
      expect(find.text('常驻 NPC'), findsOneWidget);
      expect(find.text('归档角色'), findsOneWidget);
      expect(find.byKey(const Key('character-row-player-1')), findsOneWidget);
      expect(find.byKey(const Key('character-row-npc-1')), findsOneWidget);
      expect(find.byKey(const Key('character-row-archived-1')), findsNothing);

      await tester.tap(find.byKey(const Key('archived-section-toggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('character-row-archived-1')), findsOneWidget);

      await tester.tap(find.byKey(const Key('archived-section-toggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('character-row-archived-1')), findsNothing);
    },
  );

  testWidgets('opens an character by tapping the full row', (tester) async {
    String? openedId;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampaignCharactersPanel(
            characters: characters(),
            isManager: false,
            onOpenCharacter: (character) => openedId = character.id,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('character-row-player-1')));

    expect(openedId, 'player-1');
  });

  testWidgets('uses exact character HP for the avatar progress ring', (
    tester,
  ) async {
    await tester.pumpWidget(panel(isManager: true));

    final paint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byKey(const Key('character-row-player-1')),
        matching: find.byKey(const Key('campaign-avatar-ring-healthy')),
      ),
    );
    final ring = paint.painter! as CampaignHealthRingPainter;
    expect(ring.fraction, 0.9);
  });

  testWidgets('shows character creation only to managers', (tester) async {
    await tester.pumpWidget(panel(isManager: false));
    expect(
      find.byKey(const Key('characters-create-character-button')),
      findsNothing,
    );

    await tester.pumpWidget(panel(isManager: true));
    expect(
      find.byKey(const Key('characters-create-character-button')),
      findsOneWidget,
    );
  });

  testWidgets('manager can reveal a hidden NPC from its action menu', (
    tester,
  ) async {
    CampaignCharacter? changed;
    bool? visible;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampaignCharactersPanel(
            characters: characters(),
            isManager: true,
            onOpenCharacter: (_) {},
            onSetVisibility:
                ({required character, required visibleToPlayers}) async {
                  changed = character;
                  visible = visibleToPlayers;
                  return null;
                },
          ),
        ),
      ),
    );

    expect(find.textContaining('未公开'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('character-row-npc-1')),
        matching: find.byTooltip('角色操作'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('公开给玩家'));
    await tester.pumpAndSettle();

    expect(changed?.id, 'npc-1');
    expect(visible, isTrue);
  });

  testWidgets('manager can restore an archived character', (tester) async {
    String? restoredId;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampaignCharactersPanel(
            characters: characters(),
            isManager: true,
            onOpenCharacter: (_) {},
            onRestoreCharacter: ({required character}) async {
              restoredId = character.id;
              return null;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('archived-section-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('character-row-archived-1')),
        matching: find.byTooltip('角色操作'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('恢复'));
    await tester.pumpAndSettle();

    expect(restoredId, 'archived-1');
  });

  // Plan 2026-07-23 task 2: DM 显示管理动作，玩家只显示自己可用动作；
  // 权限只读已有 capabilities，不根据客户端模式猜测。Panel 是纯展示组件，
  // 所有管理动作都通过 `isManager` 参数门控，由父级从 server capabilities
  // 派生。这里验证玩家看不到批量管理开关与每行操作入口（显示 chevron），
  // DM 则可见批量管理开关且角色行不再显示 chevron（走菜单分支）。
  testWidgets('gates batch management and per-character menu on isManager', (
    tester,
  ) async {
    // Player: no batch toggle, per-character row shows chevron (no menu).
    await tester.pumpWidget(panel(isManager: false));
    expect(find.byKey(const Key('characters-select-toggle')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('character-row-player-1')),
        matching: find.byIcon(Icons.chevron_right),
      ),
      findsOneWidget,
    );

    // DM: batch toggle appears, per-character row no longer shows chevron
    // (management menu branch is taken instead).
    await tester.pumpWidget(panel(isManager: true));
    expect(find.byKey(const Key('characters-select-toggle')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('character-row-player-1')),
        matching: find.byIcon(Icons.chevron_right),
      ),
      findsNothing,
    );
  });
}
