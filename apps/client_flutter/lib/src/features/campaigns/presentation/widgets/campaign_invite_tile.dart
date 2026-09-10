import 'package:flutter/material.dart';

import '../../domain/campaign.dart';
import '../../../../app/theme/app_text_styles.dart';

/// 单个战役邀请码条目：展示邀请码、角色与用量，并提供复制和分享入口。
class CampaignInviteTile extends StatelessWidget {
  const CampaignInviteTile({
    required this.invite,
    required this.onCopy,
    required this.onShare,
    super.key,
  });

  final CampaignInvite invite;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.confirmation_number),
        title: SelectableText(
          invite.code,
          style: AppTextStyles.inviteCodeCompact(Theme.of(context).textTheme),
        ),
        subtitle: Text(
          '角色：${invite.roleOnJoin} | 已用：${invite.usedCount}/${invite.maxUses}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: '复制邀请码',
              icon: const Icon(Icons.copy),
              onPressed: onCopy,
            ),
            IconButton(
              tooltip: '分享邀请码',
              icon: const Icon(Icons.share),
              onPressed: onShare,
            ),
          ],
        ),
      ),
    );
  }
}
