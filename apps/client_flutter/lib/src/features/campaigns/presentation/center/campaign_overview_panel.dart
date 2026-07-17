import 'package:flutter/material.dart';

import '../../domain/campaign.dart';

/// Overview panel: shows campaign description, role chip, and pinned
/// announcements / quick actions in future revisions.
///
/// Plan 3 task 2 — extracted from the legacy `_OverviewTab` so the new
/// `CampaignCenterPage` shell can compose it behind adaptive navigation.
class CampaignOverviewPanel extends StatelessWidget {
  const CampaignOverviewPanel({
    required this.campaign,
    required this.canManage,
    super.key,
  });

  final Campaign campaign;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: key ?? const Key('campaign-overview-panel'),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            campaign.description.trim().isEmpty
                ? '尚未填写战役简介'
                : campaign.description,
          ),
          const SizedBox(height: 20),
          ListTile(
            leading: Icon(
              canManage ? Icons.shield_outlined : Icons.person_outline,
            ),
            title: Text(canManage ? '地下城主' : '玩家'),
            subtitle: Text('系统：${campaign.system}'),
          ),
        ],
      ),
    );
  }
}
