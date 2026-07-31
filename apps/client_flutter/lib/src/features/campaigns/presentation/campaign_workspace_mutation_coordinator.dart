class CampaignWorkspaceMutationCoordinator {
  const CampaignWorkspaceMutationCoordinator({
    required this.pullCharacters,
    required this.loadWorkspace,
  });

  final Future<void> Function() pullCharacters;
  final Future<void> Function(String campaignId) loadWorkspace;

  Future<void> refreshAfterCharacterMutation(String campaignId) async {
    await pullCharacters();
    await loadWorkspace(campaignId);
  }
}
