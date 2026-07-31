import 'package:dnd_table_client/src/features/campaigns/domain/campaign.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/chat/campaign_chat_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CampaignChatMessage _checkRequestMessage() {
  return CampaignChatMessage(
    id: 'msg-check-1',
    campaignId: 'camp-1',
    senderId: 'user-dm',
    campaignCharacterId: null,
    displayName: 'DM',
    avatarUrl: null,
    kind: 'checkRequest',
    content: '请 Mira 进行察觉检定',
    createdAt: '2026-07-19T00:00:00.000Z',
    eventData: const {
      'targetCharacterId': 'character-mira',
      'checkType': 'skill',
      'checkKey': '察觉',
      'label': '察觉检定',
      'dc': 15,
      'rollMode': 'normal',
    },
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: ListView(children: [child])),
  );
}

void main() {
  testWidgets('long narrator text keeps short rules and uses available width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    const content = '风穿过废弃礼拜堂的长廊，远处的钟声连续响了三次，所有人都听见门后传来脚步声。';
    await tester.pumpWidget(
      _wrap(
        CampaignChatBubble(
          message: const CampaignChatMessage(
            id: 'narrator-long',
            campaignId: 'camp-1',
            senderId: 'dm-1',
            campaignCharacterId: null,
            displayName: '旁白',
            avatarUrl: null,
            speakerMode: 'narrator',
            kind: 'say',
            content: content,
            createdAt: '2026-07-29T00:00:00.000Z',
          ),
        ),
      ),
    );

    expect(find.text(content), findsOneWidget);
    expect(find.byKey(const Key('narrator-leading-rule')), findsOneWidget);
    expect(find.byKey(const Key('narrator-trailing-rule')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('checkRequest shows 进行检定 button when player has not responded', (
    tester,
  ) async {
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
  });

  testWidgets('checkRequest shows 已响应 button when player has responded', (
    tester,
  ) async {
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
  });

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
