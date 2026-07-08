import 'package:flutter/material.dart';

import 'campaign_controller.dart';
import 'campaign_detail_page.dart';

class CampaignListPage extends StatefulWidget {
  const CampaignListPage({
    required this.controller,
    super.key,
  });

  final CampaignController controller;

  @override
  State<CampaignListPage> createState() => _CampaignListPageState();
}

class _CampaignListPageState extends State<CampaignListPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.loadCampaigns();
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

    final success = await widget.controller.createCampaign(
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
        SnackBar(content: Text('创建失败：${widget.controller.error ?? '未知错误'}')),
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

    final success = await widget.controller.joinCampaign(code: code);

    if (!mounted) return;
    if (success) {
      messenger.showSnackBar(const SnackBar(content: Text('已加入战役')));
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text('加入失败：${widget.controller.error ?? '未知错误'}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('战役')),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          if (widget.controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final campaigns = widget.controller.campaigns;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _showCreateDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('创建战役'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _showJoinDialog,
                    icon: const Icon(Icons.login),
                    label: const Text('加入战役'),
                  ),
                ],
              ),
              if (widget.controller.error != null) ...[
                const SizedBox(height: 16),
                Text(
                  widget.controller.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              if (campaigns.isEmpty)
                const Text('暂无战役，创建一个或使用邀请码加入。')
              else ...[
                Text(
                  '我的战役',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final campaign in campaigns)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.castle),
                      title: Text(campaign.name),
                      subtitle: Text(campaign.description.isEmpty
                          ? campaign.system
                          : campaign.description),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) => CampaignDetailPage(
                              controller: widget.controller,
                              campaignId: campaign.id,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
