import 'package:dnd_table_client/src/features/campaigns/domain/campaign.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign_actor.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/center/campaign_team_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/campaign_test_support.dart';

void main() {
  const members = <CampaignMemberPreview>[
    CampaignMemberPreview(
      userId: 'user-1',
      displayName: 'DM',
      role: 'owner',
    ),
  ];

  // DM-managed actors: one temporary NPC and one persistent monster.
  List<CampaignActor> dmActors() => [
    testCampaignActor(
      id: 'npc-temp',
      ownerUserId: null,
      actorType: 'npc',
      lifecycle: 'temporary',
      sheet: const {'name': 'Innkeeper'},
    ),
    testCampaignActor(
      id: 'monster-persist',
      ownerUserId: null,
      actorType: 'monster',
      lifecycle: 'persistent',
      sheet: const {'name': 'Goblin'},
    ),
  ];

  Widget pumpPanel({
    required bool isManager,
    required List<CampaignActor> actors,
    Future<String?> Function({
      required String actorId,
      required String actorType,
      required String displayName,
      int? maxHp,
      String? avatarUrl,
    })? onConvertToPersistent,
    Future<String?> Function({required List<String> actorIds})? onBatchArchive,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: CampaignTeamPanel(
          members: members,
          actors: actors,
          isManager: isManager,
          onConvertToPersistent: onConvertToPersistent != null
              ? ({required CampaignActor actor}) async {
                  final error = await onConvertToPersistent(
                    actorId: actor.id,
                    actorType: actor.actorType,
                    displayName: actor.sheet['name'].toString(),
                  );
                  return error;
                }
              : null,
          onBatchArchive: onBatchArchive,
        ),
      ),
    );
  }

  group('CampaignTeamPanel DM actor management (spec §完整管理)', () {
    testWidgets(
      'DM sees managed actors section with temporary actor showing convert button',
      (tester) async {
        await tester.pumpWidget(
          pumpPanel(
            isManager: true,
            actors: dmActors(),
            onConvertToPersistent: ({required actorId, required actorType, required displayName, int? maxHp, String? avatarUrl}) async => null,
          ),
        );
        await tester.pump();

        // Section header appears.
        expect(find.text('DM 角色管理'), findsOneWidget);
        // Temporary NPC shows convert-to-persistent button.
        expect(find.byKey(const Key('team-convert-persistent-npc-temp')), findsOneWidget);
        // Persistent monster does NOT show convert button.
        expect(find.byKey(const Key('team-convert-persistent-monster-persist')), findsNothing);
      },
    );

    testWidgets(
      'player does not see managed actors section',
      (tester) async {
        await tester.pumpWidget(
          pumpPanel(
            isManager: false,
            actors: dmActors(),
          ),
        );
        await tester.pump();

        expect(find.text('DM 角色管理'), findsNothing);
        expect(find.byKey(const Key('team-convert-persistent-npc-temp')), findsNothing);
      },
    );

    testWidgets(
      'tapping convert button calls onConvertToPersistent',
      (tester) async {
        String? convertedId;
        await tester.pumpWidget(
          pumpPanel(
            isManager: true,
            actors: dmActors(),
            onConvertToPersistent: ({required actorId, required actorType, required displayName, int? maxHp, String? avatarUrl}) async {
              convertedId = actorId;
              return null;
            },
          ),
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('team-convert-persistent-npc-temp')));
        await tester.pump();

        expect(convertedId, 'npc-temp');
      },
    );

    testWidgets(
      'manage toggle enters multi-select mode and shows batch archive button',
      (tester) async {
        await tester.pumpWidget(
          pumpPanel(
            isManager: true,
            actors: dmActors(),
            onBatchArchive: ({required actorIds}) async => null,
          ),
        );
        await tester.pump();

        // Enter multi-select mode.
        await tester.tap(find.byKey(const Key('team-managed-toggle-select')));
        await tester.pump();

        // Checkboxes appear for each managed actor.
        expect(find.byKey(const Key('team-actor-checkbox-npc-temp')), findsOneWidget);
        expect(find.byKey(const Key('team-actor-checkbox-monster-persist')), findsOneWidget);
        // Batch archive button appears.
        expect(find.byKey(const Key('team-batch-archive-button')), findsOneWidget);
      },
    );

    testWidgets(
      'selecting actors and tapping batch archive calls onBatchArchive with ids',
      (tester) async {
        List<String>? archivedIds;
        await tester.pumpWidget(
          pumpPanel(
            isManager: true,
            actors: dmActors(),
            onBatchArchive: ({required actorIds}) async {
              archivedIds = actorIds;
              return null;
            },
          ),
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('team-managed-toggle-select')));
        await tester.pump();

        // Select the temporary NPC.
        await tester.tap(find.byKey(const Key('team-actor-checkbox-npc-temp')));
        await tester.pump();

        await tester.tap(find.byKey(const Key('team-batch-archive-button')));
        await tester.pump();

        expect(archivedIds, ['npc-temp']);
      },
    );
  });
}
