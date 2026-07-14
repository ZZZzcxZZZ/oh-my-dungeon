import 'package:flutter/material.dart';

import '../../domain/campaign_actor.dart';
import 'campaign_actor_controller.dart';
import 'campaign_actor_sheet_page.dart';

/// 战役下拉选项。简化结构以兼容 Dart 3.0 之前的字段类型语法。
class CampaignOption {
  const CampaignOption({required this.id, required this.name});

  final String id;
  final String name;
}

/// DM 模式下的战役角色目录。提供搜索、状态筛选和角色列表。
class CampaignActorDirectoryPage extends StatelessWidget {
  const CampaignActorDirectoryPage({
    required this.controller,
    required this.campaigns,
    this.onPublishCharacter,
    super.key,
  });

  final CampaignActorController controller;
  final List<CampaignOption> campaigns;
  final VoidCallback? onPublishCharacter;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Column(
          key: const Key('campaign-actor-directory'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (campaigns.length > 1) _buildCampaignSelector(context),
            _buildSearchField(context),
            _buildFilterChips(context),
            Expanded(child: _buildActorList(context)),
          ],
        );
      },
    );
  }

  Widget _buildCampaignSelector(BuildContext context) {
    return Padding(
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
    );
  }

  Widget _buildSearchField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        key: const Key('actor-directory-search'),
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          labelText: '搜索角色名',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: controller.setQuery,
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          _filterChip(context, 'player', '玩家角色'),
          _filterChip(context, 'npc', 'NPC'),
          _filterChip(context, 'unclaimed', '未认领'),
          _filterChip(context, 'archived', '已归档'),
        ],
      ),
    );
  }

  Widget _filterChip(BuildContext context, String key, String label) {
    final selected = controller.activeFilters.contains(key);
    return FilterChip(
      key: Key('filter-chip-$key'),
      label: Text(label),
      selected: selected,
      onSelected: (_) => controller.toggleFilter(key),
    );
  }

  Widget _buildActorList(BuildContext context) {
    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            controller.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final actors = controller.filteredActors;
    if (actors.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('暂无角色\n切换筛选或稍后再试', textAlign: TextAlign.center),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: actors.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final actor = actors[index];
        return _ActorCard(
          actor: actor,
          onTap: () => _openSheet(context, actor),
        );
      },
    );
  }

  Future<void> _openSheet(BuildContext context, CampaignActor actor) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => CampaignActorSheetPage(
          controller: controller,
          actorId: actor.id,
        ),
      ),
    );
  }
}

class _ActorCard extends StatelessWidget {
  const _ActorCard({required this.actor, required this.onTap});

  final CampaignActor actor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sheet = actor.sheet;
    final name = sheet['name']?.toString() ?? '(未命名)';
    final currentHp = _asInt(sheet['currentHp']);
    final maxHp = _asInt(sheet['maxHp']);
    final armorClass = _asInt(sheet['armorClass']);
    final speed = _asInt(sheet['speed']);
    final typeLabel = switch (actor.actorType) {
      'player' => '玩家角色',
      'npc' => 'NPC',
      'companion' => '同伴',
      _ => actor.actorType,
    };
    final typeIcon = switch (actor.actorType) {
      'player' => Icons.person,
      'npc' => Icons.smart_toy_outlined,
      'companion' => Icons.pets,
      _ => Icons.help_outline,
    };

    return Card.outlined(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: colorScheme.secondaryContainer,
          foregroundColor: colorScheme.onSecondaryContainer,
          child: Icon(typeIcon),
        ),
        title: Text(name),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Chip(label: Text('HP $currentHp/$maxHp')),
              if (armorClass > 0) Chip(label: Text('AC $armorClass')),
              if (speed > 0) Chip(label: Text('速度 $speed')),
              if (actor.status == 'archived')
                Chip(
                  label: Text(
                    '已归档',
                    style: TextStyle(color: colorScheme.error),
                  ),
                )
              else
                Chip(label: Text(typeLabel)),
            ],
          ),
        ),
        trailing: actor.sourceCharacterId != null
            ? const Icon(Icons.link, color: Colors.transparent)
            : null,
      ),
    );
  }

  int _asInt(Object? value) {
    if (value is num) return value.toInt();
    return 0;
  }
}
