import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/campaign.dart';
import '../../domain/campaign_actor.dart';
import '../widgets/campaign_avatar.dart';
import '../widgets/campaign_actor_quick_sheet.dart';
import '../widgets/invite_share.dart';

/// Team panel: lists campaign members with their bound actor avatars and
/// opens the quick sheet on tap.
///
/// Spec §队伍: 邀请和管理成员在 `战役中心 → 队伍`，DM 就地操作。
/// 当 `isManager` 为 true 时，面板顶部显示"邀请成员"按钮，点击后
/// 调用 [onCreateInvite] 创建邀请码并弹出分享对话框。
///
/// Plan 3 task 2 — extracted from the legacy `_MembersTab`.
class CampaignTeamPanel extends StatelessWidget {
  const CampaignTeamPanel({
    required this.members,
    required this.actors,
    required this.isManager,
    this.onCreateInvite,
    this.campaignName,
    this.serverUrl,
    super.key,
  });

  final List<CampaignMemberPreview> members;
  final List<CampaignActor> actors;
  final bool isManager;

  /// 创建邀请码的回调。仅 DM 调用；返回邀请码对象或 null（失败时）。
  final Future<CampaignInvite?> Function()? onCreateInvite;

  /// 战役名称，用于格式化分享文本。
  final String? campaignName;

  /// 服务器地址，用于格式化分享文本。
  final String? serverUrl;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: key ?? const Key('campaign-team-panel'),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: members.length + (isManager && onCreateInvite != null ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (isManager && onCreateInvite != null && index == 0) {
            return _InviteButton(
              campaignName: campaignName,
              serverUrl: serverUrl,
              onCreateInvite: onCreateInvite!,
            );
          }
          final memberIndex = isManager && onCreateInvite != null
              ? index - 1
              : index;
          final member = members[memberIndex];
          final actor = actors
              .where((item) => item.ownerUserId == member.userId)
              .firstOrNull;
          final name = actor?.sheet['name']?.toString().trim();
          return ListTile(
            onTap:
                actor == null ? null : () => _showQuickSheet(context, actor),
            leading: CampaignAvatar(
              initials: (name?.isNotEmpty ?? false)
                  ? name!
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
              name?.isNotEmpty ?? false ? name! : _roleLabel(member.role),
            ),
            trailing:
                actor == null ? null : const Icon(Icons.chevron_right),
          );
        },
      ),
    );
  }

  void _showQuickSheet(BuildContext context, CampaignActor actor) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => CampaignActorQuickSheet(
        actor: actor,
        isManager: isManager,
      ),
    );
  }
}

class _InviteButton extends StatelessWidget {
  const _InviteButton({
    required this.campaignName,
    required this.serverUrl,
    required this.onCreateInvite,
  });

  final String? campaignName;
  final String? serverUrl;
  final Future<CampaignInvite?> Function() onCreateInvite;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FilledButton.tonalIcon(
        key: const Key('team-invite-button'),
        onPressed: () => _createAndShowInvite(context),
        icon: const Icon(Icons.person_add),
        label: const Text('邀请成员'),
      ),
    );
  }

  Future<void> _createAndShowInvite(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final invite = await onCreateInvite();
    if (!context.mounted) return;
    if (invite == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('创建邀请码失败')),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('邀请码已创建'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('将以下邀请码分享给玩家：'),
              const SizedBox(height: 16),
              SelectableText(
                invite.code,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: invite.code));
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('邀请码已复制')),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('复制'),
            ),
            FilledButton.icon(
              onPressed: () async {
                await copyInviteToClipboard(
                  code: invite.code,
                  campaignName: campaignName,
                  serverUrl: serverUrl,
                );
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('分享文本已复制，可粘贴到聊天工具')),
                );
              },
              icon: const Icon(Icons.share),
              label: const Text('分享'),
            ),
          ],
        );
      },
    );
  }
}

String _roleLabel(String role) => switch (role) {
      'owner' || 'dm' => '地下城主',
      'spectator' => '旁观者',
      _ => '玩家',
    };
