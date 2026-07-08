import 'package:flutter/material.dart';

import '../../auth/presentation/auth_controller.dart';
import '../../server_profiles/domain/server_profile.dart';
import '../domain/campaign.dart';
import 'campaign_controller.dart';
import 'campaign_detail_page.dart';

/// Top-level "战役" tab.
///
/// Shows a login prompt when the user is not authenticated, otherwise the
/// list of campaigns with create/join entry points.
class CampaignsTabPage extends StatefulWidget {
  const CampaignsTabPage({
    required this.profile,
    required this.authController,
    required this.campaignController,
    super.key,
  });

  final ServerProfile profile;
  final AuthController authController;
  final CampaignController campaignController;

  @override
  State<CampaignsTabPage> createState() => _CampaignsTabPageState();
}

class _CampaignsTabPageState extends State<CampaignsTabPage> {
  @override
  void initState() {
    super.initState();
    _maybeLoadCampaigns();
  }

  void _maybeLoadCampaigns() {
    if (widget.authController.isLoggedIn) {
      widget.campaignController.loadCampaigns();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.authController,
        widget.campaignController,
      ]),
      builder: (context, _) {
        if (!widget.authController.isLoggedIn) {
          return _buildLoginPrompt(context);
        }

        final campaigns = widget.campaignController.campaigns;
        return Scaffold(
          appBar: AppBar(title: const Text('战役')),
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton.extended(
                heroTag: 'create_campaign',
                onPressed: _showCreateDialog,
                icon: const Icon(Icons.add),
                label: const Text('创建战役'),
              ),
              const SizedBox(height: 12),
              FloatingActionButton.extended(
                heroTag: 'join_campaign',
                onPressed: _showJoinDialog,
                icon: const Icon(Icons.login),
                label: const Text('加入战役'),
              ),
            ],
          ),
          body: _buildCampaignList(context, campaigns),
        );
      },
    );
  }

  Widget _buildLoginPrompt(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('战役')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  '登录后管理战役',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  '创建属于你的战役，或使用邀请码加入朋友的团。',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCampaignList(BuildContext context, List<Campaign> campaigns) {
    if (widget.campaignController.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.campaignController.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            widget.campaignController.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (campaigns.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '暂无战役\n点击右下角创建或加入',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: campaigns.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final campaign = campaigns[index];
        final isOwner =
            campaign.ownerId == widget.authController.user?.id;
        return Card(
          child: ListTile(
            leading: const Icon(Icons.castle_outlined),
            title: Text(campaign.name),
            subtitle: Text(campaign.description.isEmpty
                ? campaign.system
                : campaign.description),
            trailing: isOwner
                ? const Chip(label: Text('主持人'))
                : const Chip(label: Text('玩家')),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => CampaignDetailPage(
                    controller: widget.campaignController,
                    campaignId: campaign.id,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showCreateDialog() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    final result = await showDialog<Map<String, String?>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('创建战役'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '战役名称'),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: '描述（可选）'),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop({
                'name': nameController.text.trim(),
                'description': descController.text.trim(),
              }),
              child: const Text('创建'),
            ),
          ],
        );
      },
    );

    if (result == null) return;
    final name = result['name'];
    if (name == null || name.isEmpty) return;

    final success = await widget.campaignController.createCampaign(
      name: name,
      description: result['description']?.isEmpty == true
          ? null
          : result['description'],
    );

    if (!mounted) return;
    if (success) {
      messenger.showSnackBar(const SnackBar(content: Text('战役已创建')));
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '创建失败：${widget.campaignController.error ?? '未知错误'}',
          ),
        ),
      );
    }
  }

  Future<void> _showJoinDialog() async {
    final codeController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    final code = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('加入战役'),
          content: TextField(
            controller: codeController,
            decoration: const InputDecoration(labelText: '邀请码'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(codeController.text.trim()),
              child: const Text('加入'),
            ),
          ],
        );
      },
    );

    if (code == null || code.isEmpty) return;

    final success = await widget.campaignController.joinCampaign(code: code);

    if (!mounted) return;
    if (success) {
      messenger.showSnackBar(const SnackBar(content: Text('已加入战役')));
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '加入失败：${widget.campaignController.error ?? '未知错误'}',
          ),
        ),
      );
    }
  }
}
