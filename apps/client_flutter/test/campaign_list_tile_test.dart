import 'package:dnd_table_client/src/features/campaigns/domain/campaign.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/widgets/campaign_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Campaign _campaign({
  String name = '龙之战役',
  int unread = 0,
  String? lastMsg,
  List<CampaignMemberPreview> members = const [],
  String ownerId = 'u-owner',
}) {
  return Campaign(
    id: 'c1',
    name: name,
    description: '',
    system: 'dnd5e',
    ownerId: ownerId,
    status: 'active',
    createdAt: 't',
    updatedAt: 't',
    unreadCount: unread,
    lastMessage: lastMsg == null
        ? null
        : CampaignChatMessage(
            id: 'm1',
            campaignId: 'c1',
            senderId: 'u1',
            campaignActorId: null,
            displayName: '艾尔',
            avatarUrl: null,
            kind: 'say',
            content: lastMsg,
            createdAt: 't',
          ),
    memberPreview: members,
  );
}

void main() {
  testWidgets('shows campaign name and last message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampaignListTile(
            campaign: _campaign(lastMsg: '我攻击哥布林'),
            currentUserId: 'u1',
          ),
        ),
      ),
    );

    expect(find.text('龙之战役'), findsOneWidget);
    expect(find.text('我攻击哥布林'), findsOneWidget);
  });

  testWidgets('shows unread badge when unread > 0', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampaignListTile(
            campaign: _campaign(unread: 3, lastMsg: 'x'),
            currentUserId: 'u1',
          ),
        ),
      ),
    );

    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('hides unread badge when 0', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampaignListTile(
            campaign: _campaign(lastMsg: 'x'),
            currentUserId: 'u1',
          ),
        ),
      ),
    );

    expect(find.text('0'), findsNothing);
  });

  testWidgets('shows host label when current user is owner', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampaignListTile(
            campaign: _campaign(ownerId: 'u-me'),
            currentUserId: 'u-me',
          ),
        ),
      ),
    );

    expect(find.text('主持人'), findsOneWidget);
  });

  testWidgets('shows player label when current user is a player member',
      (tester) async {
    final members = [
      CampaignMemberPreview(userId: 'u-me', displayName: '我', role: 'player'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampaignListTile(
            campaign: _campaign(members: members),
            currentUserId: 'u-me',
          ),
        ),
      ),
    );

    expect(find.text('玩家'), findsOneWidget);
  });

  testWidgets('triggers onTap', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampaignListTile(
            campaign: _campaign(lastMsg: 'x'),
            currentUserId: 'u1',
            onTap: () => tapped++,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(CampaignListTile));
    await tester.pump();

    expect(tapped, 1);
  });
}
