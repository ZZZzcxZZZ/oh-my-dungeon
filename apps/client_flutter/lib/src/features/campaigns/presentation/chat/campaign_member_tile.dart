import 'package:flutter/material.dart';

import '../../domain/campaign.dart';
import '../../domain/campaign_character.dart';
import '../widgets/campaign_avatar.dart';
import 'chat_helpers.dart';

/// 成员列表项：把 CampaignMemberPreview 与对应的 CampaignCharacter 配对显示。
class CampaignMemberTile extends StatelessWidget {
  const CampaignMemberTile({required this.member, this.character, super.key});

  final CampaignMemberPreview member;
  final CampaignCharacter? character;

  @override
  Widget build(BuildContext context) {
    final characterName = character?.sheet['name']?.toString().trim();
    final subtitle = [
      if (characterName != null && characterName.isNotEmpty) characterName,
      if (character != null) characterStatusLine(character!),
    ].where((item) => item.isNotEmpty).join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CampaignAvatar(
        initials: characterName == null || characterName.isEmpty
            ? member.displayName
            : characterName,
        imageUrl: character?.sheet['avatarUrl'] as String?,
        health: CampaignAvatar.healthFromHp(
          character?.sheet['currentHp'] as num?,
          character?.sheet['maxHp'] as num?,
        ),
        healthFraction: CampaignAvatar.fractionFromHp(
          character?.sheet['currentHp'] as num?,
          character?.sheet['maxHp'] as num?,
        ),
      ),
      title: Text(member.displayName),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: Chip(label: Text(campaignRoleLabel(member.role))),
    );
  }
}

/// 仅角色无成员预览时的回退显示（例如离线同步的战役角色）。
class CharacterOnlyMemberTile extends StatelessWidget {
  const CharacterOnlyMemberTile({required this.character, super.key});

  final CampaignCharacter character;

  @override
  Widget build(BuildContext context) {
    final name = character.sheet['name']?.toString().trim();
    final displayName = name == null || name.isEmpty ? '未命名角色' : name;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CampaignAvatar(
        initials: displayName,
        imageUrl: character.sheet['avatarUrl'] as String?,
        health: CampaignAvatar.healthFromHp(
          character.sheet['currentHp'] as num?,
          character.sheet['maxHp'] as num?,
        ),
        healthFraction: CampaignAvatar.fractionFromHp(
          character.sheet['currentHp'] as num?,
          character.sheet['maxHp'] as num?,
        ),
      ),
      title: Text(displayName),
      subtitle: Text(characterStatusLine(character)),
      trailing: const Chip(label: Text('角色')),
    );
  }
}
