import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/presentation/auth_controller.dart';
import '../domain/campaign.dart';
import 'campaign_controller.dart';

class CampaignDetailPage extends StatefulWidget {
  const CampaignDetailPage({
    required this.controller,
    required this.campaignId,
    super.key,
  });

  final CampaignController controller;
  final String campaignId;

  @override
  State<CampaignDetailPage> createState() => _CampaignDetailPageState();
}

class _CampaignDetailPageState extends State<CampaignDetailPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.loadCampaignDetail(widget.campaignId);
  }

  bool _isOwner(Campaign campaign, AuthController auth) {
    return campaign.ownerId == auth.user?.id;
  }

  Future<void> _showCreateInviteDialog() async {
    final messenger = ScaffoldMessenger.of(context);
    final campaign = widget.controller.selectedCampaign;
    if (campaign == null) return;

    final invite = await widget.controller.createInvite(
      campaignId: campaign.id,
      roleOnJoin: 'player',
      maxUses: 1,
    );

    if (!mounted) return;
    if (invite != null) {
      await showDialog<void>(
        context: context,
        builder: (context) {
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
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: invite.code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已复制到剪贴板')),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('复制'),
                  ),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('关闭'),
              ),
            ],
          );
        },
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '创建邀请码失败：${widget.controller.detailError ?? '未知错误'}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('战役详情')),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          if (widget.controller.isDetailLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (widget.controller.detailError != null) {
            return Center(
              child: Text(
                widget.controller.detailError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            );
          }

          final campaign = widget.controller.selectedCampaign;
          if (campaign == null) {
            return const Center(child: Text('未找到战役'));
          }

          final isOwner = _isOwner(campaign, widget.controller.authController);

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                campaign.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              if (campaign.description.isNotEmpty)
                Text(campaign.description)
              else
                Text(
                  '暂无描述',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  Chip(label: Text('系统：${campaign.system}')),
                  Chip(label: Text('状态：${campaign.status}')),
                  if (isOwner)
                    const Chip(label: Text('角色：主持人'))
                  else
                    const Chip(label: Text('角色：玩家')),
                ],
              ),
              const SizedBox(height: 32),
              if (isOwner) ..._buildInviteSection(context),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildInviteSection(BuildContext context) {
    final invites = widget.controller.invites;
    return [
      Text('邀请码', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      FilledButton.tonalIcon(
        onPressed: _showCreateInviteDialog,
        icon: const Icon(Icons.add_link),
        label: const Text('创建邀请码'),
      ),
      const SizedBox(height: 16),
      if (invites.isEmpty)
        const Text('暂无邀请码')
      else
        for (final invite in invites)
          Card(
            child: ListTile(
              leading: const Icon(Icons.confirmation_number),
              title: SelectableText(
                invite.code,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              subtitle: Text(
                '角色：${invite.roleOnJoin} | '
                '已用：${invite.usedCount}/${invite.maxUses}',
              ),
            ),
          ),
    ];
  }
}
