import 'package:dnd_table_client/src/features/campaigns/domain/campaign.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/chat/campaign_message_grouping.dart';
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
}

CampaignChatMessage _message({
  required String id,
  required String actorId,
  required String createdAt,
  String kind = 'say',
}) {
  return CampaignChatMessage(
    id: id,
    campaignId: 'campaign-1',
    senderId: 'user-1',
    campaignActorId: actorId,
    displayName: actorId,
    avatarUrl: null,
    kind: kind,
    content: id,
    createdAt: createdAt,
  );
}
