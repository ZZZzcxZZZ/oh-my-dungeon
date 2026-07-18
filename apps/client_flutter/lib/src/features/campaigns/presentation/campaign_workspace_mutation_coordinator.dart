class CampaignWorkspaceMutationCoordinator {
  const CampaignWorkspaceMutationCoordinator({
    required this.pullActors,
    required this.loadWorkspace,
  });

  final Future<void> Function() pullActors;
  final Future<void> Function(String campaignId) loadWorkspace;

  Future<void> refreshAfterActorMutation(String campaignId) async {
    await pullActors();
    await loadWorkspace(campaignId);
  }
}
