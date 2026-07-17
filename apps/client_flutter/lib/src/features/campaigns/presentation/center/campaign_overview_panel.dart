import 'package:flutter/material.dart';

import '../../domain/campaign.dart';

/// Overview panel: shows campaign description, role chip, and pinned
/// announcements / quick actions in future revisions.
///
/// Plan 3 task 2 — extracted from the legacy `_OverviewTab` so the new
/// `CampaignCenterPage` shell can compose it behind adaptive navigation.
///
/// Spec §概览: "DM 在相同位置额外看到控场摘要、群体检定和遭遇准备入口。"
/// The DM control entry lives here, not in the chat toolbar.
class CampaignOverviewPanel extends StatelessWidget {
  const CampaignOverviewPanel({
    required this.campaign,
    required this.canManage,
    this.onOpenDmControl,
    super.key,
  });

  final Campaign campaign;
  final bool canManage;

  /// Spec §概览: DM 控场入口。仅 DM 可见, 点击后由父组件展示控场 sheet。
  final VoidCallback? onOpenDmControl;

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
          // Spec §概览: DM 在相同位置额外看到控场摘要、群体检定和遭遇准备入口。
          if (canManage && onOpenDmControl != null) ...[
            const Divider(),
            ListTile(
              key: const Key('campaign-overview-dm-control-entry'),
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: const Text('DM 控场'),
              subtitle: const Text('遭遇、成员状态和 DM 私有工具'),
              trailing: const Icon(Icons.chevron_right),
              onTap: onOpenDmControl,
            ),
          ],
        ],
      ),
    );
  }
}
