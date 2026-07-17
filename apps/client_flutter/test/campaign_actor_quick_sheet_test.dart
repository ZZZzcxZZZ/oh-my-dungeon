import 'package:dnd_table_client/src/features/campaigns/domain/campaign_actor.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/widgets/campaign_actor_quick_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CampaignActor _actor({
  String name = '艾尔',
  int currentHp = 12,
  int maxHp = 20,
  int ac = 15,
  String actorType = 'player',
}) {
  return CampaignActor(
    id: 'a1',
    campaignId: 'c1',
    ownerUserId: 'u1',
    sourceCharacterId: null,
    actorType: actorType,
    status: 'active',
    sheet: {
      'name': name,
      'currentHp': currentHp,
      'maxHp': maxHp,
      'armorClass': ac,
    },
    revision: 1,
    updatedBy: 'u1',
    createdAt: 't',
    updatedAt: 't',
  );
}

void main() {
  testWidgets('manager sees exact HP numbers', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampaignActorQuickSheet(actor: _actor(), isManager: true),
        ),
      ),
    );

    expect(find.textContaining('12/20'), findsOneWidget);
  });

  testWidgets('non-manager sees health grade word instead of exact HP',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampaignActorQuickSheet(
            actor: _actor(currentHp: 12, maxHp: 20),
            isManager: false,
          ),
        ),
      ),
    );

    expect(find.textContaining('12/20'), findsNothing);
    // 12/20 = 60% > 50% => 健康
    expect(find.text('健康'), findsOneWidget);
  });

  testWidgets('non-manager sees critical grade when HP is low', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampaignActorQuickSheet(
            actor: _actor(currentHp: 3, maxHp: 20),
            isManager: false,
          ),
        ),
      ),
    );

    expect(find.text('危险'), findsOneWidget);
  });

  testWidgets('open sheet button triggers callback', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampaignActorQuickSheet(
            actor: _actor(),
            isManager: true,
            onOpenSheet: () => opened++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开角色卡'));
    await tester.pump();

    expect(opened, 1);
  });
}
