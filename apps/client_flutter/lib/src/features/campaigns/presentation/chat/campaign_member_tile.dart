import 'package:flutter/material.dart';

import '../../domain/campaign.dart';
import '../../domain/campaign_actor.dart';
import '../widgets/campaign_avatar.dart';
import 'chat_helpers.dart';

/// 成员列表项：把 CampaignMemberPreview 与对应的 CampaignActor 配对显示。
class CampaignMemberTile extends StatelessWidget {
  const CampaignMemberTile({required this.member, this.actor, super.key});

  final CampaignMemberPreview member;
  final CampaignActor? actor;

  @override
  Widget build(BuildContext context) {
    final actorName = actor?.sheet['name']?.toString().trim();
    final subtitle = [
      if (actorName != null && actorName.isNotEmpty) actorName,
      if (actor != null) actorStatusLine(actor!),
    ].where((item) => item.isNotEmpty).join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CampaignAvatar(
        initials: actorName == null || actorName.isEmpty
            ? member.displayName
            : actorName,
        imageUrl: actor?.sheet['avatarUrl'] as String?,
        health: CampaignAvatar.healthFromHp(
          actor?.sheet['currentHp'] as num?,
          actor?.sheet['maxHp'] as num?,
        ),
        healthFraction: CampaignAvatar.fractionFromHp(
          actor?.sheet['currentHp'] as num?,
          actor?.sheet['maxHp'] as num?,
        ),
      ),
      title: Text(member.displayName),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: Chip(label: Text(campaignRoleLabel(member.role))),
    );
  }
}

/// 仅角色无成员预览时的回退显示（例如离线同步的战役角色）。
class ActorOnlyMemberTile extends StatelessWidget {
  const ActorOnlyMemberTile({required this.actor, super.key});

  final CampaignActor actor;

  @override
  Widget build(BuildContext context) {
    final name = actor.sheet['name']?.toString().trim();
    final displayName = name == null || name.isEmpty ? '未命名角色' : name;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CampaignAvatar(
        initials: displayName,
        imageUrl: actor.sheet['avatarUrl'] as String?,
        health: CampaignAvatar.healthFromHp(
          actor.sheet['currentHp'] as num?,
          actor.sheet['maxHp'] as num?,
        ),
        healthFraction: CampaignAvatar.fractionFromHp(
          actor.sheet['currentHp'] as num?,
          actor.sheet['maxHp'] as num?,
        ),
      ),
      title: Text(displayName),
      subtitle: Text(actorStatusLine(actor)),
      trailing: const Chip(label: Text('角色')),
    );
  }
}
