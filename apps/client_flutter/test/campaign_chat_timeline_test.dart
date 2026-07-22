import 'package:dnd_table_client/src/features/campaigns/domain/campaign.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/chat/campaign_chat_bubble.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/chat/campaign_chat_timeline.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/chat/campaign_message_grouping.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/widgets/campaign_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CampaignMessagePresentation', () {
    test('groups adjacent ordinary messages from the same speaker', () {
      final first = _message(
        id: '1',
        actorId: 'actor-1',
        createdAt: '2026-07-22T10:00:00Z',
      );
      final second = _message(
        id: '2',
        actorId: 'actor-1',
        createdAt: '2026-07-22T10:03:00Z',
      );

      final presentation = CampaignMessagePresentation.resolve(
        previous: first,
        current: second,
        currentUserId: 'user-1',
      );

      expect(presentation.showIdentity, isFalse);
      expect(presentation.showTimeDivider, isFalse);
      expect(presentation.isOwn, isTrue);
    });

    test('starts a new group when the active actor changes', () {
      final first = _message(
        id: '1',
        actorId: 'actor-1',
        createdAt: '2026-07-22T10:00:00Z',
      );
      final second = _message(
        id: '2',
        actorId: 'actor-2',
        createdAt: '2026-07-22T10:01:00Z',
      );

      final presentation = CampaignMessagePresentation.resolve(
        previous: first,
        current: second,
        currentUserId: 'user-1',
      );

      expect(presentation.showIdentity, isTrue);
      expect(presentation.showTimeDivider, isFalse);
    });

    test('starts a new group and time section after ten minutes', () {
      final first = _message(
        id: '1',
        actorId: 'actor-1',
        createdAt: '2026-07-22T10:00:00Z',
      );
      final second = _message(
        id: '2',
        actorId: 'actor-1',
        createdAt: '2026-07-22T10:10:00Z',
      );

      final presentation = CampaignMessagePresentation.resolve(
        previous: first,
        current: second,
        currentUserId: 'user-2',
      );

      expect(presentation.showIdentity, isTrue);
      expect(presentation.showTimeDivider, isTrue);
      expect(presentation.isOwn, isFalse);
    });

    test('event messages never merge into ordinary speaker groups', () {
      final previous = _message(
        id: '1',
        actorId: 'actor-1',
        createdAt: '2026-07-22T10:00:00Z',
      );
      final event = _message(
        id: '2',
        actorId: 'actor-1',
        kind: 'roll',
        createdAt: '2026-07-22T10:01:00Z',
      );

      final presentation = CampaignMessagePresentation.resolve(
        previous: previous,
        current: event,
        currentUserId: 'user-1',
      );

      expect(presentation.showIdentity, isTrue);
    });
  });

  group('CampaignChatTimeline', () {
    testWidgets('aligns own messages right and other messages left', (
      tester,
    ) async {
      await _pumpTimeline(
        tester,
        messages: [
          _message(
            id: 'other',
            actorId: 'actor-2',
            senderId: 'user-2',
            createdAt: '2026-07-22T10:00:00Z',
          ),
          _message(
            id: 'own',
            actorId: 'actor-1',
            createdAt: '2026-07-22T10:01:00Z',
          ),
        ],
      );

      expect(
        tester
            .widget<Align>(find.byKey(const Key('message-align-other')))
            .alignment,
        Alignment.centerLeft,
      );
      expect(
        tester
            .widget<Align>(find.byKey(const Key('message-align-own')))
            .alignment,
        Alignment.centerRight,
      );
    });

    testWidgets('anchors actor rows to opposite edges on a phone viewport', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpTimeline(
        tester,
        messages: [
          _message(
            id: 'other',
            actorId: 'other-actor',
            senderId: 'user-2',
            createdAt: '2026-07-22T10:00:00Z',
          ),
          _message(
            id: 'own',
            actorId: 'own-actor',
            createdAt: '2026-07-22T10:01:00Z',
          ),
        ],
      );

      final otherAvatar = find.descendant(
        of: find.byKey(const Key('message-align-other')),
        matching: find.byType(CampaignAvatar),
      );
      final ownAvatar = find.descendant(
        of: find.byKey(const Key('message-align-own')),
        matching: find.byType(CampaignAvatar),
      );
      final otherRect = tester.getRect(otherAvatar);
      final ownRect = tester.getRect(ownAvatar);

      expect(otherRect.left, lessThanOrEqualTo(16));
      expect(ownRect.right, greaterThanOrEqualTo(374));
      expect(tester.takeException(), isNull);
    });

    testWidgets('hides repeated identity for an adjacent speaker group', (
      tester,
    ) async {
      await _pumpTimeline(
        tester,
        messages: [
          _message(
            id: 'first',
            actorId: 'actor-1',
            createdAt: '2026-07-22T10:00:00Z',
          ),
          _message(
            id: 'second',
            actorId: 'actor-1',
            createdAt: '2026-07-22T10:01:00Z',
          ),
        ],
      );

      final first = tester.widget<CampaignChatBubble>(
        find.descendant(
          of: find.byKey(const Key('message-align-first')),
          matching: find.byType(CampaignChatBubble),
        ),
      );
      final second = tester.widget<CampaignChatBubble>(
        find.descendant(
          of: find.byKey(const Key('message-align-second')),
          matching: find.byType(CampaignChatBubble),
        ),
      );
      expect(first.showIdentity, isTrue);
      expect(second.showIdentity, isFalse);
      expect(find.byType(CampaignAvatar), findsOneWidget);
    });

    testWidgets('keeps event cards compact on a wide viewport', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 720);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpTimeline(
        tester,
        messages: [
          _message(
            id: 'check',
            actorId: 'actor-1',
            kind: 'checkRequest',
            createdAt: '2026-07-22T10:00:00Z',
          ),
        ],
      );

      expect(
        tester.getSize(find.byKey(const Key('check-request-message'))).width,
        lessThanOrEqualTo(640),
      );
      expect(tester.takeException(), isNull);
    });

    for (final size in const [
      Size(360, 800),
      Size(390, 844),
      Size(1280, 720),
    ]) {
      testWidgets('starts at the latest message at ${size.width}x${size.height}', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await _pumpTimeline(
          tester,
          messages: [
            for (var index = 0; index < 30; index++)
              _message(
                id: index == 29
                    ? 'latest-message'
                    : 'message-$index',
                actorId:
                    '一位拥有非常非常长名称的角色-$index-without-spaces',
                createdAt: '2026-07-22T10:${index.toString().padLeft(2, '0')}:00Z',
              ),
          ],
        );

        expect(find.text('latest-message'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}

Future<void> _pumpTimeline(
  WidgetTester tester, {
  required List<CampaignChatMessage> messages,
}) async {
  final controller = ScrollController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CampaignChatTimeline(
          messages: messages,
          currentUserId: 'user-1',
          scrollController: controller,
          onAvatarTap: (_) => null,
          canRespondToCheck: (_) => false,
          hasRespondedToCheck: (_) => false,
          onRespondToCheck: (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
}

CampaignChatMessage _message({
  required String id,
  required String actorId,
  required String createdAt,
  String kind = 'say',
  String senderId = 'user-1',
}) {
  return CampaignChatMessage(
    id: id,
    campaignId: 'campaign-1',
    senderId: senderId,
    campaignActorId: actorId,
    displayName: actorId,
    avatarUrl: null,
    kind: kind,
    content: id,
    createdAt: createdAt,
  );
}
