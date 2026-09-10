import 'package:flutter/material.dart';

import '../../domain/campaign.dart';
import '../../domain/campaign_character.dart';
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
    this.characters = const [],
    this.invites = const [],
    this.onCreateInvite,
    this.onOpenCharacter,
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
  final List<CampaignCharacter> characters;
  final List<CampaignInvite> invites;
  final Future<CampaignInvite?> Function()? onCreateInvite;
  final ValueChanged<CampaignCharacter>? onOpenCharacter;
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return KeyedSubtree(
      key: key ?? const Key('campaign-overview-panel'),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Container(
            key: const Key('campaign-overview-header'),
            color: colors.surfaceContainerLow,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  campaign.description.trim().isEmpty
                      ? '尚未填写战役简介'
                      : campaign.description,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      avatar: Icon(
                        canManage
                            ? Icons.shield_outlined
                            : Icons.person_outline,
                        size: 18,
                      ),
                      label: Text(canManage ? '主持人' : '玩家'),
                    ),
                    Chip(
                      avatar: const Icon(Icons.auto_stories_outlined, size: 18),
                      label: Text(campaign.system),
                    ),
                    Chip(
                      avatar: const Icon(Icons.cloud_done_outlined, size: 18),
                      label: Text(
                        campaign.status == 'active' ? '进行中' : campaign.status,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _CampaignSummary(members: members, characters: characters),
          ),
          if (canManage && onCreateInvite != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: _CampaignInviteShare(
                invites: invites,
                onCreateInvite: onCreateInvite!,
                campaignName: campaignName ?? campaign.name,
                serverUrl: serverUrl,
              ),
            ),
          _CampaignMemberList(
            members: members,
            characters: characters,
            onOpenCharacter: onOpenCharacter,
          ),
          // Plan 2026-07-23 Task 1.1: section divider 防止成员列表与下方
          // DM 工具卡/设置区块"黏在一起"。
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(),
          ),
          if (canManage && onOpenDmControl != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _DmControlEntry(onTap: onOpenDmControl!),
            ),
          if (_hasAnySettingEntry)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: _CampaignSettingsSection(
                canManage: canManage,
                onEditDetails: onEditDetails,
                onTransferOwnership: onTransferOwnership,
                onArchiveCampaign: onArchiveCampaign,
                onLeaveCampaign: onLeaveCampaign,
              ),
            ),
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

/// Plan 2026-07-23 Task 1.1: DM 工具卡降权入口。
///
/// 原 `Material(color: surfaceContainerHigh)` 视觉权重过强，与上方成员
/// ListTile 视觉相近导致"黏在一起"。改为 `surfaceContainerLow` 背景 +
/// `outlineVariant` 描边，区分层次。
class _DmControlEntry extends StatelessWidget {
  const _DmControlEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      key: const Key('campaign-overview-dm-control-entry'),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.admin_panel_settings_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('主持工具'),
                      Text(
                        '遭遇、成员状态与 DM 私有工具',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CampaignSummary extends StatelessWidget {
  const _CampaignSummary({required this.members, required this.characters});

  final List<CampaignMemberPreview> members;
  final List<CampaignCharacter> characters;

  @override
  Widget build(BuildContext context) {
    final active = characters
        .where((character) => character.status != 'archived')
        .toList();
    final players = active
        .where((character) => character.characterType == 'player')
        .length;
    final supporting = active.length - players;
    return Container(
      key: const Key('campaign-overview-stats'),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          _CampaignMetric(value: members.length, label: '成员'),
          const VerticalDivider(width: 1),
          _CampaignMetric(value: players, label: '玩家角色'),
          const VerticalDivider(width: 1),
          _CampaignMetric(value: supporting, label: 'NPC / 同伴'),
        ],
      ),
    );
  }
}

class _CampaignMetric extends StatelessWidget {
  const _CampaignMetric({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$value', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _CampaignMemberList extends StatelessWidget {
  const _CampaignMemberList({
    required this.members,
    required this.characters,
    required this.onOpenCharacter,
  });

  final List<CampaignMemberPreview> members;
  final List<CampaignCharacter> characters;
  final ValueChanged<CampaignCharacter>? onOpenCharacter;

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
    // 成员栏展示的是“绑定关系”：成员通过 boundCharacterId 绑定战役角色。
    // 不能用 ownerUserId 匹配——发布者不一定是绑定者（如 DM 代发或历史
    // 数据中发布者与绑定者不一致），否则会把角色错误挂到他人名下。
    final character = member.boundCharacterId == null
        ? null
        : characters
            .where(
              (candidate) =>
                  candidate.id == member.boundCharacterId &&
                  candidate.status != 'archived',
            )
            .firstOrNull;
    final characterName = character?.sheet['name']?.toString().trim();
    return ListTile(
      leading: CampaignAvatar(
        initials: characterName?.isNotEmpty == true
            ? characterName!
            : member.displayName,
        imageUrl: character?.sheet['avatarUrl'] as String?,
        health: CampaignAvatar.healthFromHp(
          character?.sheet['currentHp'] as num?,
          character?.sheet['maxHp'] as num?,
        ),
        healthFraction: CampaignAvatar.fractionFromHp(
          character?.sheet['currentHp'] as num?,
          character?.sheet['maxHp'] as num?,
        ),
        size: 40,
      ),
      title: Text(member.displayName),
      subtitle: Text(
        characterName?.isNotEmpty == true
            ? '$characterName · ${_roleLabel(member.role)}'
            : '${_roleLabel(member.role)} · 未绑定角色',
      ),
      trailing: character == null ? null : const Icon(Icons.chevron_right),
      onTap: character == null || onOpenCharacter == null
          ? null
          : () => onOpenCharacter!(character),
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
    final colors = Theme.of(context).colorScheme;
    return Material(
      key: const Key('campaign-invite-share'),
      color: colors.secondaryContainer,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _share(context, current),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          // Icons and text sit on a secondaryContainer surface, so they must
          // use the matching on-* role (E2).
          child: IconTheme.merge(
            data: IconThemeData(color: colors.onSecondaryContainer),
            child: DefaultTextStyle(
              style: TextStyle(color: colors.onSecondaryContainer),
              child: Row(
                children: [
                  const Icon(Icons.person_add_alt_1_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('邀请玩家'),
                        Text(
                          current == null
                              ? '创建邀请码并分享服务器信息'
                              : '邀请码  ${current.code}',
                          style: current == null
                              ? Theme.of(context).textTheme.bodySmall
                              : Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    current == null
                        ? Icons.add_link_outlined
                        : Icons.ios_share_outlined,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
    return ExpansionTile(
      key: const Key('campaign-overview-settings'),
      leading: const Icon(Icons.settings_outlined),
      title: const Text('战役设置'),
      subtitle: const Text('低频管理与退出操作'),
      children: [
        if (canManage && onEditDetails != null)
          ListTile(
            key: const Key('campaign-overview-edit-details'),
            leading: const Icon(Icons.edit_outlined),
            title: const Text('名称、封面和简介'),
            onTap: onEditDetails,
          ),
        if (canManage && onTransferOwnership != null)
          ListTile(
            key: const Key('campaign-overview-transfer-ownership'),
            leading: const Icon(Icons.swap_horiz_outlined),
            title: const Text('转移所有权'),
            onTap: onTransferOwnership,
          ),
        if (canManage && onArchiveCampaign != null)
          ListTile(
            key: const Key('campaign-overview-archive-campaign'),
            leading: const Icon(Icons.archive_outlined),
            title: const Text('归档战役'),
            onTap: onArchiveCampaign,
          ),
        if (onLeaveCampaign != null)
          ListTile(
            key: const Key('campaign-overview-leave-campaign'),
            leading: Icon(
              Icons.logout_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              '离开战役',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
            onTap: onLeaveCampaign,
          ),
      ],
    );
  }
}
