import 'package:dnd_table_client/src/features/campaigns/presentation/campaign_workspace_mutation_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'refreshAfterActorMutation refreshes actors before workspace context',
    () async {
      final calls = <String>[];
      final coordinator = CampaignWorkspaceMutationCoordinator(
        pullActors: () async => calls.add('actors'),
        loadWorkspace: (campaignId) async {
          calls.add('workspace:$campaignId');
        },
      );

      await coordinator.refreshAfterActorMutation('campaign-1');

      expect(calls, ['actors', 'workspace:campaign-1']);
    },
  );
}
