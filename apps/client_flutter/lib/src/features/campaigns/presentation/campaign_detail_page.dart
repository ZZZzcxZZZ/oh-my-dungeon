import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/presentation/auth_controller.dart';
import '../../characters/domain/character.dart';
import '../../characters/presentation/character_controller.dart';
import '../domain/campaign.dart';
import 'campaign_controller.dart';

class CampaignDetailPage extends StatefulWidget {
  const CampaignDetailPage({
    required this.controller,
    required this.characterController,
    required this.campaignId,
    super.key,
  });

  final CampaignController controller;
  final CharacterController characterController;
  final String campaignId;

  @override
  State<CampaignDetailPage> createState() => _CampaignDetailPageState();
}

class _CampaignDetailPageState extends State<CampaignDetailPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.loadCampaignDetail(widget.campaignId);
    widget.characterController.loadCampaignCharacters(widget.campaignId);
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
    if (invite == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '创建邀请码失败：${widget.controller.detailError ?? '未知错误'}',
          ),
        ),
      );
      return;
    }

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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('战役详情')),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          widget.controller,
          widget.characterController,
        ]),
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
              ..._buildCharactersSection(context, campaign),
              const SizedBox(height: 32),
              if (isOwner) ..._buildInviteSection(context),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildCharactersSection(
    BuildContext context,
    Campaign campaign,
  ) {
    final bindings = widget.characterController.campaignCharacters;
    return [
      Text('战役角色', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      if (widget.characterController.isLoading)
        const Center(child: CircularProgressIndicator())
      else if (bindings.isEmpty)
        const Text('暂无绑定角色')
      else
        for (final binding in bindings)
          if (binding.character != null)
            _CampaignCharacterTile(
              character: binding.character!,
              onHpDelta: (delta) => _adjustCampaignCharacterHp(
                campaign.id,
                binding.character!,
                delta,
              ),
            ),
    ];
  }

  Future<void> _adjustCampaignCharacterHp(
    String campaignId,
    CharacterSheet character,
    int delta,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final success = await widget.characterController.adjustCampaignCharacterHp(
      campaignId: campaignId,
      characterId: character.id,
      delta: delta,
    );
    if (!mounted || success) return;
    messenger.showSnackBar(const SnackBar(content: Text('HP 调整失败')));
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

class _CampaignCharacterTile extends StatelessWidget {
  const _CampaignCharacterTile({
    required this.character,
    required this.onHpDelta,
  });

  final CharacterSheet character;
  final ValueChanged<int> onHpDelta;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (character.raceSummary.isNotEmpty) character.raceSummary,
      if (character.classSummary.isNotEmpty) character.classSummary,
      'Lv.${character.level}',
    ].join(' / ');

    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.badge_outlined)),
        title: Text(character.name),
        subtitle: Text(subtitle),
        trailing: Wrap(
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Chip(label: Text('HP ${character.currentHp}/${character.maxHp}')),
            Chip(label: Text('AC ${character.armorClass}')),
            IconButton(
              tooltip: 'HP -1',
              onPressed: () => onHpDelta(-1),
              icon: const Icon(Icons.remove),
            ),
            IconButton(
              tooltip: 'HP +1',
              onPressed: () => onHpDelta(1),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}
