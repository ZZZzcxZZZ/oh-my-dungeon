import 'dart:async';

import 'package:dnd_table_client/src/features/campaigns/presentation/campaign_refresh_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('coalesces invalidations independently by resource', () async {
    final refreshed = <String>[];
    final coordinator = CampaignRefreshCoordinator.resources(
      refreshers: {
        CampaignRefreshResource.messages: (campaignId, cursor) async {
          refreshed.add('messages:$campaignId:$cursor');
        },
        CampaignRefreshResource.characters: (campaignId, cursor) async {
          refreshed.add('characters:$campaignId:$cursor');
        },
        CampaignRefreshResource.archives: (campaignId, cursor) async {
          refreshed.add('archives:$campaignId:$cursor');
        },
        CampaignRefreshResource.conversations: (campaignId, cursor) async {
          refreshed.add('conversations:$campaignId:$cursor');
        },
      },
      debounceDuration: const Duration(milliseconds: 10),
      fallbackInterval: const Duration(hours: 1),
    );
    coordinator.activate('campaign-1');

    coordinator.invalidateResource(
      CampaignRefreshResource.messages,
      cursor: '10',
    );
    coordinator.invalidateResource(
      CampaignRefreshResource.messages,
      cursor: '10',
    );
    coordinator.invalidateResource(
      CampaignRefreshResource.archives,
      cursor: '4',
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(
      refreshed,
      containsAll(<String>['messages:campaign-1:10', 'archives:campaign-1:4']),
    );
    expect(refreshed, hasLength(2));
    coordinator.dispose();
  });

  test(
    'different resources may refresh while another resource is running',
    () async {
      final messagesGate = Completer<void>();
      final started = <CampaignRefreshResource>[];
      final coordinator = CampaignRefreshCoordinator.resources(
        refreshers: {
          CampaignRefreshResource.messages: (_, _) async {
            started.add(CampaignRefreshResource.messages);
            await messagesGate.future;
          },
          CampaignRefreshResource.characters: (_, _) async {
            started.add(CampaignRefreshResource.characters);
          },
        },
        debounceDuration: Duration.zero,
        fallbackInterval: const Duration(hours: 1),
      );
      coordinator.activate('campaign-1');

      coordinator.invalidateResource(CampaignRefreshResource.messages);
      await Future<void>.delayed(Duration.zero);
      coordinator.invalidateResource(CampaignRefreshResource.characters);
      await Future<void>.delayed(Duration.zero);

      expect(
        started,
        containsAll(<CampaignRefreshResource>[
          CampaignRefreshResource.messages,
          CampaignRefreshResource.characters,
        ]),
      );
      messagesGate.complete();
      await Future<void>.delayed(Duration.zero);
      coordinator.dispose();
    },
  );

  test('same in-flight cursor does not start a duplicate refresh', () async {
    final gate = Completer<void>();
    var refreshCount = 0;
    final coordinator = CampaignRefreshCoordinator.resources(
      refreshers: {
        CampaignRefreshResource.messages: (_, _) async {
          refreshCount += 1;
          await gate.future;
        },
      },
      debounceDuration: Duration.zero,
      fallbackInterval: const Duration(hours: 1),
    );
    coordinator.activate('campaign-1');

    coordinator.invalidateResource(
      CampaignRefreshResource.messages,
      cursor: '20',
    );
    await Future<void>.delayed(Duration.zero);
    coordinator.invalidateResource(
      CampaignRefreshResource.messages,
      cursor: '20',
    );
    gate.complete();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(refreshCount, 1);
    coordinator.dispose();
  });

  test(
    'advanced cursor during a refresh schedules exactly one follow-up',
    () async {
      final firstGate = Completer<void>();
      final cursors = <String?>[];
      final coordinator = CampaignRefreshCoordinator.resources(
        refreshers: {
          CampaignRefreshResource.characters: (_, cursor) async {
            cursors.add(cursor);
            if (cursors.length == 1) await firstGate.future;
          },
        },
        debounceDuration: Duration.zero,
        fallbackInterval: const Duration(hours: 1),
      );
      coordinator.activate('campaign-1');

      coordinator.invalidateResource(
        CampaignRefreshResource.characters,
        cursor: '7',
      );
      await Future<void>.delayed(Duration.zero);
      coordinator.invalidateResource(
        CampaignRefreshResource.characters,
        cursor: '8',
      );
      coordinator.invalidateResource(
        CampaignRefreshResource.characters,
        cursor: '9',
      );
      firstGate.complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(cursors, <String?>['7', '9']);
      coordinator.dispose();
    },
  );

  test('coalesces repeated invalidations for the active campaign', () async {
    final refreshed = <String>[];
    final coordinator = CampaignRefreshCoordinator(
      onRefresh: (campaignId) async => refreshed.add(campaignId),
      debounceDuration: const Duration(milliseconds: 10),
      fallbackInterval: const Duration(hours: 1),
    );
    coordinator.activate('campaign-1');

    coordinator.invalidate();
    coordinator.invalidate();
    coordinator.invalidate();
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(refreshed, ['campaign-1']);
    coordinator.dispose();
  });

  test('ignores invalidation while no campaign is active', () async {
    var refreshCount = 0;
    final coordinator = CampaignRefreshCoordinator(
      onRefresh: (_) async => refreshCount += 1,
      debounceDuration: const Duration(milliseconds: 5),
      fallbackInterval: const Duration(hours: 1),
    );

    coordinator.invalidate();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(refreshCount, 0);
    coordinator.dispose();
  });

  test('foreground resume refreshes the active campaign immediately', () async {
    final refreshed = <String>[];
    final coordinator = CampaignRefreshCoordinator(
      onRefresh: (campaignId) async => refreshed.add(campaignId),
      debounceDuration: const Duration(milliseconds: 5),
      fallbackInterval: const Duration(hours: 1),
    );
    coordinator.activate('campaign-1');

    await coordinator.onForegroundResumed();

    expect(refreshed, ['campaign-1']);
    coordinator.dispose();
  });
}
