import 'package:dnd_table_client/src/features/campaigns/domain/campaign.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/widgets/campaign_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Campaign _campaign({
  String name = '龙之战役',
  int unread = 0,
  String? lastMsg,
  String updatedAt = '2026-07-09T00:00:00.000Z',
  String lastMessageAt = '2026-07-09T08:30:00.000Z',
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
    updatedAt: updatedAt,
    unreadCount: unread,
    lastMessage: lastMsg == null
        ? null
        : CampaignChatMessage(
            id: 'm1',
            campaignId: 'c1',
            senderId: 'u1',
            campaignCharacterId: null,
            displayName: '艾尔',
            avatarUrl: null,
            kind: 'say',
            content: lastMsg,
            createdAt: lastMessageAt,
          ),
    memberPreview: members,
  );
}

void main() {
  Widget harness({required Widget child, double width = 400}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, 800)),
        child: Scaffold(body: child),
      ),
    );
  }

  testWidgets('shows campaign name and last message', (tester) async {
    await tester.pumpWidget(
      harness(
        child: CampaignListTile(
          campaign: _campaign(lastMsg: '我攻击哥布林'),
          currentUserId: 'u1',
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

  testWidgets('shows player label when current user is a player member', (
    tester,
  ) async {
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
      harness(
        child: CampaignListTile(
          campaign: _campaign(lastMsg: 'x'),
          currentUserId: 'u1',
          onTap: () => tapped++,
        ),
      ),
    );

    await tester.tap(find.byKey(CampaignListTile.mainChatKey));
    await tester.pump();

    expect(tapped, 1);
  });

  testWidgets('expands groups above direct chats without opening main chat', (
    tester,
  ) async {
    var mainChatTaps = 0;
    String? openedConversationId;
    await tester.pumpWidget(
      harness(
        child: CampaignListTile(
          campaign: _campaign(lastMsg: '主聊天室最后发言'),
          currentUserId: 'u1',
          conversations: const [
            CampaignListConversation(
              id: 'direct-1',
              title: '与艾尔私聊',
              lastMessage: '稍后单独说',
              kind: CampaignConversationKind.direct,
            ),
            CampaignListConversation(
              id: 'group-1',
              title: '侦察小队',
              lastMessage: '从北门进入',
              kind: CampaignConversationKind.group,
            ),
          ],
          onTap: () => mainChatTaps++,
          onConversationTap: (id) => openedConversationId = id,
        ),
      ),
    );

    expect(find.text('侦察小队'), findsNothing);
    await tester.tap(find.byKey(CampaignListTile.expandKey));
    await tester.pumpAndSettle();

    expect(mainChatTaps, 0);
    expect(find.text('小群'), findsOneWidget);
    expect(find.text('私聊'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('侦察小队')).dy,
      lessThan(tester.getTopLeft(find.text('与艾尔私聊')).dy),
    );
    expect(find.text('置顶'), findsNothing);
    expect(find.byIcon(Icons.refresh), findsNothing);

    await tester.tap(find.text('侦察小队'));
    await tester.pump();
    expect(openedConversationId, 'group-1');
  });

  testWidgets('shows activity time and expanded member summary', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        child: CampaignListTile(
          campaign: _campaign(
            lastMsg: '主聊天室最后发言',
            lastMessageAt: '2020-01-02T03:04:00.000Z',
            members: const [
              CampaignMemberPreview(
                userId: 'u-owner',
                displayName: 'DM',
                role: 'owner',
              ),
              CampaignMemberPreview(
                userId: 'u-player',
                displayName: '玩家',
                role: 'player',
              ),
            ],
          ),
          currentUserId: 'u-owner',
        ),
      ),
    );

    expect(find.text('2020/01/02'), findsOneWidget);
    expect(find.text('2 位成员'), findsNothing);

    await tester.tap(find.byKey(CampaignListTile.expandKey));
    await tester.pumpAndSettle();

    expect(find.text('2 位成员'), findsOneWidget);
    expect(find.text('D&D 5E'), findsOneWidget);
  });

  testWidgets('group and direct sections collapse independently', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        child: CampaignListTile(
          campaign: _campaign(lastMsg: '主聊天室最后发言'),
          currentUserId: 'u1',
          conversations: const [
            CampaignListConversation(
              id: 'group-1',
              title: '侦察小队',
              kind: CampaignConversationKind.group,
            ),
            CampaignListConversation(
              id: 'direct-1',
              title: '与艾尔私聊',
              kind: CampaignConversationKind.direct,
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.byKey(CampaignListTile.expandKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(CampaignListTile.groupsToggleKey));
    await tester.pumpAndSettle();

    expect(find.text('侦察小队'), findsNothing);
    expect(find.text('与艾尔私聊'), findsOneWidget);

    await tester.tap(find.byKey(CampaignListTile.directToggleKey));
    await tester.pumpAndSettle();
    expect(find.text('与艾尔私聊'), findsNothing);
  });

  testWidgets('does not overflow at 320 logical pixels', (tester) async {
    await tester.pumpWidget(
      harness(
        width: 320,
        child: CampaignListTile(
          campaign: _campaign(
            name: '一个名称非常长但仍应正确截断的战役',
            lastMsg: '这是一条很长的主聊天室最后消息摘要',
          ),
          currentUserId: 'u-owner',
          conversations: const [
            CampaignListConversation(
              id: 'group-1',
              title: '名称同样非常长的侦察小队聊天室',
              lastMessage: '很长的最后消息',
              kind: CampaignConversationKind.group,
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.byKey(CampaignListTile.expandKey));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
