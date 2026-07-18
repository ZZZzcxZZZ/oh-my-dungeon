import 'package:dnd_table_client/src/features/campaigns/domain/campaign.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/chat/campaign_chat_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CampaignChatMessage _checkRequestMessage() {
  return CampaignChatMessage(
    id: 'msg-check-1',
    campaignId: 'camp-1',
    senderId: 'user-dm',
    campaignActorId: null,
    displayName: 'DM',
    avatarUrl: null,
    kind: 'checkRequest',
    content: '请 Mira 进行察觉检定',
    createdAt: '2026-07-19T00:00:00.000Z',
    eventData: const {
      'targetActorId': 'actor-mira',
      'checkType': 'skill',
      'checkKey': '察觉',
      'label': '察觉检定',
      'dc': 15,
      'rollMode': 'normal',
    },
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: ListView(children: [child])));
}

void main() {
  testWidgets(
    'checkRequest shows 进行检定 button when player has not responded',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          CampaignChatBubble(
            message: _checkRequestMessage(),
            onRespondCheckRequest: () {},
            hasResponded: false,
          ),
        ),
      );

      expect(find.byKey(const Key('respond-check-request')), findsOneWidget);
      expect(find.text('进行检定'), findsOneWidget);
      expect(find.byKey(const Key('responded-check-request')), findsNothing);

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('respond-check-request')),
      );
      expect(button.onPressed, isNotNull);
    },
  );

  testWidgets(
    'checkRequest shows 已响应 button when player has responded',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          CampaignChatBubble(
            message: _checkRequestMessage(),
            onRespondCheckRequest: () {},
            hasResponded: true,
          ),
        ),
      );

      expect(find.byKey(const Key('responded-check-request')), findsOneWidget);
      expect(find.text('已响应'), findsOneWidget);
      expect(find.byKey(const Key('respond-check-request')), findsNothing);

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('responded-check-request')),
      );
      expect(button.onPressed, isNull);
    },
  );

  testWidgets(
    'checkRequest hides action button when onRespondCheckRequest is null',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          CampaignChatBubble(
            message: _checkRequestMessage(),
            onRespondCheckRequest: null,
            hasResponded: false,
          ),
        ),
      );

      expect(find.byKey(const Key('respond-check-request')), findsNothing);
      expect(find.byKey(const Key('responded-check-request')), findsNothing);
    },
  );
}
