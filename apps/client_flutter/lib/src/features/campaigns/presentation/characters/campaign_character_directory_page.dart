import 'package:flutter/material.dart';

import '../../../content/data/local/content_repository.dart';
import '../../domain/campaign_character.dart';
import '../center/campaign_characters_panel.dart';
import 'campaign_character_controller.dart';
import 'campaign_character_sheet_launcher.dart';

class CampaignOption {
  const CampaignOption({required this.id, required this.name});

  final String id;
  final String name;
}

class CampaignCharacterDirectoryPage extends StatelessWidget {
  const CampaignCharacterDirectoryPage({
    required this.controller,
    required this.campaigns,
    this.contentRepository,
    super.key,
  });

  final CampaignCharacterController controller;
  final List<CampaignOption> campaigns;
  final ContentRepository? contentRepository;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Column(
        key: const Key('campaign-character-directory'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (campaigns.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: DropdownMenu<String>(
                initialSelection: controller.selectedCampaignId,
                label: const Text('战役'),
                dropdownMenuEntries: [
                  for (final campaign in campaigns)
                    DropdownMenuEntry(value: campaign.id, label: campaign.name),
                ],
                onSelected: (value) {
                  if (value != null) controller.selectCampaign(value);
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              key: const Key('character-directory-search'),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: '搜索角色名',
              ),
              onChanged: controller.setQuery,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 6,
              children: [
                _filterChip('player', '玩家角色'),
                _filterChip('npc', 'NPC'),
                _filterChip('unclaimed', '未认领'),
                _filterChip('archived', '已归档'),
              ],
            ),
          ),
          Expanded(child: _directoryBody(context)),
        ],
      ),
    );
  }

  Widget _filterChip(String filter, String label) {
    return FilterChip(
      key: Key('filter-chip-$filter'),
      label: Text(label),
      selected: controller.activeFilters.contains(filter),
      onSelected: (_) => controller.toggleFilter(filter),
    );
  }

  Widget _directoryBody(BuildContext context) {
    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.error != null) {
      return Center(child: Text(controller.error!));
    }
    return CampaignCharactersPanel(
      characters: controller.filteredCharacters,
      isManager: false,
      archivedInitiallyExpanded: controller.activeFilters.contains('archived'),
      onOpenCharacter: (character) => _openCharacter(context, character),
    );
  }

  Future<void> _openCharacter(
    BuildContext context,
    CampaignCharacter character,
  ) {
    return openCampaignCharacterSheet(
      context: context,
      controller: controller,
      character: character,
      canEditAnyCharacter: true,
      contentRepository: contentRepository,
    );
  }
}
