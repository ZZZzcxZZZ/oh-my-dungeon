import 'package:dnd_table_client/src/features/campaigns/domain/campaign.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/center/campaign_records_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec §档案 / §记录: 记录面板条目可点击，点击后展示消息详情（不替换
/// 实时聊天时间线）。本测试覆盖 onTap 行为。
void main() {
  Future<void> pumpPanel(
    WidgetTester tester, {
    required List<CampaignChatMessage> messages,
    required Future<List<CampaignChatMessage>> Function(String) onSearch,
    void Function(CampaignChatMessage)? onTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampaignRecordsPanel(
            messages: messages,
            onSearch: onSearch,
            onMessageTap: onTap,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'records panel entries are tappable and call onMessageTap with the message',
    (tester) async {
      const message = CampaignChatMessage(
        id: 'msg-1',
        campaignId: 'camp-1',
        senderId: 'user-1',
        campaignActorId: null,
        displayName: 'DM',
        avatarUrl: null,
        kind: 'roll',
        content: 'd20+5 = 18',
        createdAt: '2026-07-17T00:00:00.000Z',
      );
      CampaignChatMessage? tapped;

      await pumpPanel(
        tester,
        messages: const [message],
        onSearch: (_) async => const [],
        onTap: (msg) => tapped = msg,
      );

      // The record entry should be displayed.
      expect(find.text('d20+5 = 18'), findsOneWidget);

      // Tap the record entry.
      await tester.tap(find.text('d20+5 = 18'));
      await tester.pumpAndSettle();

      expect(tapped, isNotNull);
      expect(tapped!.id, 'msg-1');
    },
  );

  testWidgets(
    'records panel shows a detail popup with kind and timestamp when tapped without onMessageTap',
    (tester) async {
      const message = CampaignChatMessage(
        id: 'msg-2',
        campaignId: 'camp-1',
        senderId: 'user-1',
        campaignActorId: null,
        displayName: 'DM',
        avatarUrl: null,
        kind: 'system',
        content: 'Arannis 获得长剑',
        createdAt: '2026-07-17T00:00:00.000Z',
      );

      await pumpPanel(
        tester,
        messages: const [message],
        onSearch: (_) async => const [],
      );

      await tester.tap(find.text('Arannis 获得长剑'));
      await tester.pumpAndSettle();

      // Default behavior: detail popup with message kind label.
      expect(find.text('Arannis 获得长剑'), findsWidgets);
      expect(find.textContaining('系统事件'), findsOneWidget);
      expect(find.textContaining('DM'), findsOneWidget);
    },
  );
}
