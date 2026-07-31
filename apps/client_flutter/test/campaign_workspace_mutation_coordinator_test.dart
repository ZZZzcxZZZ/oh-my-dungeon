import 'package:dnd_table_client/src/features/campaigns/presentation/campaign_workspace_mutation_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'refreshAfterCharacterMutation refreshes characters before workspace context',
    () async {
      final calls = <String>[];
      final coordinator = CampaignWorkspaceMutationCoordinator(
        pullCharacters: () async => calls.add('characters'),
        loadWorkspace: (campaignId) async {
          calls.add('workspace:$campaignId');
        },
      );

      await coordinator.refreshAfterCharacterMutation('campaign-1');

      expect(calls, ['characters', 'workspace:campaign-1']);
    },
  );
}
