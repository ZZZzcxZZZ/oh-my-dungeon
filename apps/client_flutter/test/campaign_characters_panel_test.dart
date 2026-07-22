import 'package:dnd_table_client/src/features/campaigns/domain/campaign_actor.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/center/campaign_characters_panel.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/widgets/campaign_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/campaign_test_support.dart';

void main() {
  List<CampaignActor> actors() => [
    testCampaignActor(
      id: 'player-1',
      ownerUserId: 'user-1',
      actorType: 'player',
      sheet: const {'name': '阿兰尼斯', 'currentHp': 9, 'maxHp': 10},
    ),
    testCampaignActor(
      id: 'npc-1',
      ownerUserId: null,
      actorType: 'npc',
      sheet: const {'name': '酒馆老板'},
    ),
    testCampaignActor(
      id: 'temp-1',
      ownerUserId: null,
      actorType: 'npc',
      lifecycle: 'temporary',
      sheet: const {'name': '临时守卫'},
    ),
    testCampaignActor(
      id: 'archived-1',
      ownerUserId: null,
      actorType: 'monster',
      status: 'archived',
      sheet: const {'name': '旧敌人'},
    ),
  ];

  Widget panel({required bool isManager}) => MaterialApp(
    home: Scaffold(
      body: CampaignCharactersPanel(
        actors: actors(),
        isManager: isManager,
        onOpenActor: (_) {},
        onCreateActor: isManager
            ? ({
                required actorType,
                required displayName,
                required lifecycle,
                int? maxHp,
              }) async => null
            : null,
      ),
    ),
  );

  testWidgets('groups active actors and keeps archived actors collapsed', (
    tester,
  ) async {
    await tester.pumpWidget(panel(isManager: true));

    expect(find.text('玩家角色'), findsWidgets);
    expect(find.text('NPC 与其他角色'), findsOneWidget);
    expect(find.text('临时角色'), findsOneWidget);
    expect(find.text('已归档'), findsOneWidget);
    expect(find.byKey(const Key('actor-row-player-1')), findsOneWidget);
    expect(find.byKey(const Key('actor-row-npc-1')), findsOneWidget);
    expect(find.byKey(const Key('actor-row-temp-1')), findsOneWidget);
    expect(find.byKey(const Key('actor-row-archived-1')), findsNothing);

    await tester.tap(find.byKey(const Key('archived-section-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('actor-row-archived-1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('archived-section-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('actor-row-archived-1')), findsNothing);
  });

  testWidgets('opens an actor by tapping the full row', (tester) async {
    String? openedId;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampaignCharactersPanel(
            actors: actors(),
            isManager: false,
            onOpenActor: (actor) => openedId = actor.id,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('actor-row-player-1')));

    expect(openedId, 'player-1');
  });

  testWidgets('uses exact actor HP for the avatar progress ring', (
    tester,
  ) async {
    await tester.pumpWidget(panel(isManager: true));

    final paint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byKey(const Key('actor-row-player-1')),
        matching: find.byKey(const Key('campaign-avatar-ring-healthy')),
      ),
    );
    final ring = paint.painter! as CampaignHealthRingPainter;
    expect(ring.fraction, 0.9);
  });

  testWidgets('shows actor creation only to managers', (tester) async {
    await tester.pumpWidget(panel(isManager: false));
    expect(
      find.byKey(const Key('characters-create-actor-button')),
      findsNothing,
    );

    await tester.pumpWidget(panel(isManager: true));
    expect(
      find.byKey(const Key('characters-create-actor-button')),
      findsOneWidget,
    );
  });
}
