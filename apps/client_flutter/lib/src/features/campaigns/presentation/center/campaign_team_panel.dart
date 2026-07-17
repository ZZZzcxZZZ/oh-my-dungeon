import 'package:flutter/material.dart';

import '../../domain/campaign.dart';
import '../../domain/campaign_actor.dart';
import '../widgets/campaign_avatar.dart';
import '../widgets/campaign_actor_quick_sheet.dart';

/// Team panel: lists campaign members with their bound actor avatars and
/// opens the quick sheet on tap. DM management affordances are integrated
/// here in future revisions (actor lifecycle: persistent / temporary /
/// archived).
///
/// Plan 3 task 2 — extracted from the legacy `_MembersTab`.
class CampaignTeamPanel extends StatelessWidget {
  const CampaignTeamPanel({
    required this.members,
    required this.actors,
    required this.isManager,
    super.key,
  });

  final List<CampaignMemberPreview> members;
  final List<CampaignActor> actors;
  final bool isManager;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: key ?? const Key('campaign-team-panel'),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: members.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final member = members[index];
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

String _roleLabel(String role) => switch (role) {
      'owner' || 'dm' => '地下城主',
      'spectator' => '旁观者',
      _ => '玩家',
    };
