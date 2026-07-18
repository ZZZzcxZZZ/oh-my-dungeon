import 'package:flutter/material.dart';

import '../../domain/campaign.dart';
import '../../domain/campaign_actor.dart';
import '../widgets/campaign_avatar.dart';
import '../widgets/invite_share.dart';

/// Overview panel: shows campaign description, role chip, DM control entry,
/// and the campaign-level settings that used to live in the chat page's
/// "more" menu.
///
/// Plan 3 task 2 — extracted from the legacy `_OverviewTab` so the new
/// `CampaignCenterPage` shell can compose it behind adaptive navigation.
///
/// Spec §概览: "DM 在相同位置额外看到控场摘要、群体检定和遭遇准备入口。"
/// The DM control entry lives here, not in the chat toolbar.
///
/// Spec §全局设置: 战役名称/封面/简介、所有权转移、战役归档都是 owner/dm 才能
/// 使用的低频操作；普通玩家只看到"离开战役"。这些操作原来藏在聊天页右上角
/// 三点菜单里，用户明确要求完全去除三点菜单并整合到战役中心，因此统一搬到
/// 概览面板的"战役设置"区块。
class CampaignOverviewPanel extends StatelessWidget {
  const CampaignOverviewPanel({
    required this.campaign,
    required this.canManage,
    this.members = const [],
    this.actors = const [],
    this.invites = const [],
    this.onCreateInvite,
    this.campaignName,
    this.serverUrl,
    this.onOpenDmControl,
    this.onEditDetails,
    this.onTransferOwnership,
    this.onArchiveCampaign,
    this.onLeaveCampaign,
    super.key,
  });

  final Campaign campaign;
  final bool canManage;
  final List<CampaignMemberPreview> members;
  final List<CampaignActor> actors;
  final List<CampaignInvite> invites;
  final Future<CampaignInvite?> Function()? onCreateInvite;
  final String? campaignName;
  final String? serverUrl;

  /// Spec §概览: DM 控场入口。仅 DM 可见, 点击后由父组件展示控场 sheet。
  final VoidCallback? onOpenDmControl;

  /// Spec §全局设置: 打开战役详情编辑页（名称、封面、简介）。
  /// 仅 `canManage` 为 true 时显示。
  final VoidCallback? onEditDetails;

  /// Spec §全局设置: 所有权转移。仅 `canManage` 为 true 时显示。
  final VoidCallback? onTransferOwnership;

  /// Spec §全局设置: 战役归档。仅 `canManage` 为 true 时显示。
  final VoidCallback? onArchiveCampaign;

  /// Spec §全局设置: 离开战役。所有成员可见。
  final VoidCallback? onLeaveCampaign;

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
          const Divider(),
          _CampaignSummary(members: members, actors: actors),
          const SizedBox(height: 8),
          _CampaignMemberList(members: members, actors: actors),
          if (canManage && onCreateInvite != null) ...[
            const SizedBox(height: 8),
            _CampaignInviteShare(
              invites: invites,
              onCreateInvite: onCreateInvite!,
              campaignName: campaignName ?? campaign.name,
              serverUrl: serverUrl,
            ),
          ],
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
          // Spec §全局设置: 4 项低频操作整合到概览面板。DM 可见全部 4 项,
          // 普通玩家只见"离开战役"。原聊天页三点菜单已删除。
          if (_hasAnySettingEntry) ...[
            const Divider(),
            _CampaignSettingsSection(
              canManage: canManage,
              onEditDetails: onEditDetails,
              onTransferOwnership: onTransferOwnership,
              onArchiveCampaign: onArchiveCampaign,
              onLeaveCampaign: onLeaveCampaign,
            ),
          ],
        ],
      ),
    );
  }

  bool get _hasAnySettingEntry =>
      (canManage &&
          (onEditDetails != null ||
              onTransferOwnership != null ||
              onArchiveCampaign != null)) ||
      onLeaveCampaign != null;
}

class _CampaignSummary extends StatelessWidget {
  const _CampaignSummary({required this.members, required this.actors});

  final List<CampaignMemberPreview> members;
  final List<CampaignActor> actors;

  @override
  Widget build(BuildContext context) {
    final activeActors = actors
        .where((actor) => actor.status != 'archived')
        .length;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Chip(
          avatar: const Icon(Icons.group_outlined, size: 18),
          label: Text('${members.length} 位成员'),
        ),
        Chip(
          avatar: const Icon(Icons.badge_outlined, size: 18),
          label: Text('$activeActors 个角色'),
        ),
      ],
    );
  }
}

class _CampaignMemberList extends StatelessWidget {
  const _CampaignMemberList({required this.members, required this.actors});

  final List<CampaignMemberPreview> members;
  final List<CampaignActor> actors;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('campaign-member-list'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text('成员', style: Theme.of(context).textTheme.titleSmall),
        ),
        if (members.isEmpty)
          const ListTile(
            leading: Icon(Icons.group_outlined),
            title: Text('成员信息尚未同步'),
          )
        else
          for (final member in members) _memberTile(member),
      ],
    );
  }

  Widget _memberTile(CampaignMemberPreview member) {
    final actor = actors
        .where(
          (candidate) =>
              candidate.ownerUserId == member.userId &&
              candidate.actorType == 'player' &&
              candidate.status != 'archived',
        )
        .firstOrNull;
    final actorName = actor?.sheet['name']?.toString().trim();
    return ListTile(
      leading: CampaignAvatar(
        initials: actorName?.isNotEmpty == true
            ? actorName!
            : member.displayName,
        imageUrl: actor?.sheet['avatarUrl'] as String?,
        health: CampaignAvatar.healthFromHp(
          actor?.sheet['currentHp'] as num?,
          actor?.sheet['maxHp'] as num?,
        ),
        size: 40,
      ),
      title: Text(member.displayName),
      subtitle: Text(
        actorName?.isNotEmpty == true
            ? '$actorName · ${_roleLabel(member.role)}'
            : '${_roleLabel(member.role)} · 未绑定角色',
      ),
    );
  }
}

class _CampaignInviteShare extends StatelessWidget {
  const _CampaignInviteShare({
    required this.invites,
    required this.onCreateInvite,
    required this.campaignName,
    required this.serverUrl,
  });

  final List<CampaignInvite> invites;
  final Future<CampaignInvite?> Function() onCreateInvite;
  final String campaignName;
  final String? serverUrl;

  @override
  Widget build(BuildContext context) {
    final current = invites
        .where((invite) => invite.usedCount < invite.maxUses)
        .firstOrNull;
    return ListTile(
      key: const Key('campaign-invite-share'),
      leading: const Icon(Icons.person_add_alt_1_outlined),
      title: Text(current == null ? '创建邀请码' : '分享邀请码'),
      subtitle: Text(current?.code ?? '邀请玩家加入这个战役'),
      trailing: const Icon(Icons.ios_share_outlined),
      onTap: () => _share(context, current),
    );
  }

  Future<void> _share(BuildContext context, CampaignInvite? invite) async {
    final resolved = invite ?? await onCreateInvite();
    if (resolved == null || !context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(invite == null ? '邀请码已创建' : '分享邀请码'),
        content: SelectableText(
          formatInviteShareText(
            code: resolved.code,
            campaignName: campaignName,
            serverUrl: serverUrl,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await copyInviteToClipboard(
                code: resolved.code,
                campaignName: campaignName,
                serverUrl: serverUrl,
              );
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            icon: const Icon(Icons.copy_outlined),
            label: const Text('复制'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('完成'),
          ),
        ],
      ),
    );
  }
}

String _roleLabel(String role) => switch (role) {
  'owner' => '主持人',
  'dm' => '协同主持人',
  'player' => '玩家',
  _ => role,
};

/// "战役设置" 区块: 4 项低频操作以 ListTile 列出。
class _CampaignSettingsSection extends StatelessWidget {
  const _CampaignSettingsSection({
    required this.canManage,
    required this.onEditDetails,
    required this.onTransferOwnership,
    required this.onArchiveCampaign,
    required this.onLeaveCampaign,
  });

  final bool canManage;
  final VoidCallback? onEditDetails;
  final VoidCallback? onTransferOwnership;
  final VoidCallback? onArchiveCampaign;
  final VoidCallback? onLeaveCampaign;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            '战役设置',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (canManage && onEditDetails != null)
          ListTile(
            key: const Key('campaign-overview-edit-details'),
            leading: const Icon(Icons.edit_outlined),
            title: const Text('战役名称、封面和简介'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onEditDetails,
          ),
        if (canManage && onTransferOwnership != null)
          ListTile(
            key: const Key('campaign-overview-transfer-ownership'),
            leading: const Icon(Icons.swap_horiz_outlined),
            title: const Text('所有权转移'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onTransferOwnership,
          ),
        if (canManage && onArchiveCampaign != null)
          ListTile(
            key: const Key('campaign-overview-archive-campaign'),
            leading: const Icon(Icons.archive_outlined),
            title: const Text('战役归档'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onArchiveCampaign,
          ),
        if (onLeaveCampaign != null)
          ListTile(
            key: const Key('campaign-overview-leave-campaign'),
            leading: const Icon(Icons.logout_outlined),
            title: const Text('离开战役'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onLeaveCampaign,
          ),
      ],
    );
  }
}
