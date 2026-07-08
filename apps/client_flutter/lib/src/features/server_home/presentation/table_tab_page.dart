import 'package:flutter/material.dart';

import '../../../features/auth/presentation/auth_controller.dart';
import '../../../features/campaigns/domain/campaign.dart';
import '../../../features/campaigns/presentation/campaign_controller.dart';
import '../../../features/server_profiles/domain/server_profile.dart';
import '../../../features/sessions/domain/session.dart';
import '../../../features/sessions/presentation/session_controller.dart';
import '../../../features/sessions/presentation/session_detail_page.dart';

/// Top-level "桌面" tab.
///
/// Shows the live play surface: pick a campaign, then create or enter a
/// Session. Replaces the frozen rooms prototype.
class TableTabPage extends StatefulWidget {
  const TableTabPage({
    required this.profile,
    required this.authController,
    required this.campaignController,
    required this.sessionController,
    super.key,
  });

  final ServerProfile profile;
  final AuthController authController;
  final CampaignController campaignController;
  final SessionController sessionController;

  @override
  State<TableTabPage> createState() => _TableTabPageState();
}

class _TableTabPageState extends State<TableTabPage> {
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
        widget.sessionController,
      ]),
      builder: (context, _) {
        if (!widget.authController.isLoggedIn) {
          return _buildLoginPrompt(context);
        }

        final campaigns = widget.campaignController.campaigns;
        if (campaigns.isEmpty) {
          return _buildEmptyCampaigns(context);
        }

        final selectedId = widget.sessionController.selectedCampaignId;
        final effectiveId = selectedId ?? campaigns.first.id;
        if (selectedId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.sessionController.selectCampaign(effectiveId);
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('桌面'),
            actions: [
              if (widget.sessionController.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'create_session',
            onPressed: _showCreateSessionDialog,
            icon: const Icon(Icons.add),
            label: const Text('新场次'),
          ),
          body: Column(
            children: [
              _buildCampaignSelector(context, campaigns, effectiveId),
              Expanded(child: _buildSessionList(context)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoginPrompt(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('桌面')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.table_restaurant_outlined,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  '登录后进入桌面',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  '登录后选择战役，开启或加入一次跑团场次。',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyCampaigns(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('桌面')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.castle_outlined, size: 48),
              const SizedBox(height: 12),
              Text(
                '还没有战役',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                '先到「战役」标签创建或加入一个战役，再回到这里开局。',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCampaignSelector(
    BuildContext context,
    List<Campaign> campaigns,
    String effectiveId,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: DropdownButtonFormField<String>(
        initialValue: effectiveId,
        decoration: const InputDecoration(
          labelText: '战役',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.castle_outlined),
        ),
        items: [
          for (final campaign in campaigns)
            DropdownMenuItem(
              value: campaign.id,
              child: Text(campaign.name),
            ),
        ],
        onChanged: (value) {
          if (value != null) {
            widget.sessionController.selectCampaign(value);
          }
        },
      ),
    );
  }

  Widget _buildSessionList(BuildContext context) {
    if (widget.sessionController.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            widget.sessionController.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final sessions = widget.sessionController.sessions;
    if (sessions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '该战役暂无场次\n点击右下角「新场次」开局',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: sessions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final session = sessions[index];
        return _SessionCard(
          session: session,
          onTap: () => _openSession(session),
        );
      },
    );
  }

  Future<void> _openSession(Session session) async {
    final navigator = Navigator.of(context);
    await widget.sessionController.openSession(session.id);
    if (!mounted) return;
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (context) => SessionDetailPage(
          profile: widget.profile,
          authController: widget.authController,
          sessionController: widget.sessionController,
        ),
      ),
    );
  }

  Future<void> _showCreateSessionDialog() async {
    final controller = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('新场次'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: '场次名称'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('创建'),
            ),
          ],
        );
      },
    );

    if (name == null || name.isEmpty) return;

    final success = await widget.sessionController.createSession(name: name);

    if (!mounted) return;
    if (success) {
      messenger.showSnackBar(const SnackBar(content: Text('场次已创建')));
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '创建失败：${widget.sessionController.error ?? '未知错误'}',
          ),
        ),
      );
    }
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.onTap});

  final Session session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (label, color) = switch (session.status) {
      'active' => ('进行中', colorScheme.primaryContainer),
      'scheduled' => ('待开始', colorScheme.surfaceContainerHighest),
      'ended' => ('已结束', colorScheme.secondaryContainer),
      _ => (session.status, colorScheme.surfaceContainerHighest),
    };

    return Card(
      child: ListTile(
        leading: const Icon(Icons.table_restaurant_outlined),
        title: Text(session.name),
        subtitle: Text(session.createdAt.split('T').first),
        trailing: Chip(
          label: Text(label),
          backgroundColor: color,
        ),
        onTap: onTap,
      ),
    );
  }
}
