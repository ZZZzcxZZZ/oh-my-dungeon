import 'package:flutter/material.dart';

import '../../../features/auth/presentation/auth_controller.dart';
import '../../../features/campaigns/domain/campaign.dart';
import '../../../features/campaigns/presentation/campaign_controller.dart';
import '../../../features/check_requests/presentation/check_request_controller.dart';
import '../../../features/client_mode/domain/client_mode.dart';
import '../../../features/encounters/domain/encounter.dart';
import '../../../features/encounters/presentation/encounter_controller.dart';
import '../../../features/server_profiles/domain/server_profile.dart';
import '../../../features/sessions/data/session_socket_service.dart';
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
    required this.checkRequestController,
    required this.encounterController,
    required this.socketService,
    required this.modeController,
    super.key,
  });

  final ServerProfile profile;
  final AuthController authController;
  final CampaignController campaignController;
  final SessionController sessionController;
  final CheckRequestController checkRequestController;
  final EncounterController encounterController;
  final SessionSocketService socketService;
  final ClientModeController modeController;

  @override
  State<TableTabPage> createState() => _TableTabPageState();
}

class _TableTabPageState extends State<TableTabPage> {
  bool _requestedCampaignLoad = false;

  @override
  void initState() {
    super.initState();
    _maybeLoadCampaigns();
  }

  void _maybeLoadCampaigns() {
    if (widget.authController.isLoggedIn) {
      _requestedCampaignLoad = true;
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
        widget.encounterController,
        widget.modeController,
      ]),
      builder: (context, _) {
        if (!widget.authController.isLoggedIn) {
          _requestedCampaignLoad = false;
          return _buildLoginPrompt(context);
        }

        final campaigns = widget.campaignController.campaigns;
        if (campaigns.isEmpty &&
            !widget.campaignController.isLoading &&
            !_requestedCampaignLoad) {
          _requestedCampaignLoad = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.campaignController.loadCampaigns();
          });
        }

        if (campaigns.isEmpty) {
          return _buildEmptyCampaigns(context);
        }

        final selectedId = widget.sessionController.selectedCampaignId;
        final effectiveId = selectedId ?? campaigns.first.id;
        if (selectedId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _selectCampaign(effectiveId);
          });
        }

        final isDm = widget.modeController.mode == ClientMode.dungeonMaster;

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
              Expanded(
                child: isDm
                    ? DefaultTabController(
                        length: 2,
                        child: Column(
                          children: [
                            const TabBar(
                              tabs: [
                                Tab(
                                  icon: Icon(Icons.event_note_outlined),
                                  text: '场次',
                                ),
                                Tab(
                                  icon: Icon(Icons.shield_outlined),
                                  text: '控场',
                                ),
                              ],
                            ),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  _buildSessionList(context),
                                  _buildEncounterPanel(context, effectiveId),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    : _buildSessionList(context),
              ),
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
                Text('登录后进入桌面', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                const Text('登录后选择战役，开启或加入一次跑团场次。', textAlign: TextAlign.center),
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
              Text('还没有战役', style: Theme.of(context).textTheme.titleMedium),
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
            DropdownMenuItem(value: campaign.id, child: Text(campaign.name)),
        ],
        onChanged: (value) {
          if (value != null) {
            _selectCampaign(value);
          }
        },
      ),
    );
  }

  void _selectCampaign(String campaignId) {
    widget.sessionController.selectCampaign(campaignId);
    widget.encounterController.loadEncounters(campaignId);
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
          checkRequestController: widget.checkRequestController,
          socketService: widget.socketService,
        ),
      ),
    );
  }

  Widget _buildEncounterPanel(BuildContext context, String campaignId) {
    final controller = widget.encounterController;
    return RefreshIndicator(
      onRefresh: () => controller.loadEncounters(campaignId),
      child: ListView(
        key: const Key('encounter-control-panel'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '遭遇控场',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              FilledButton.icon(
                onPressed: () => _showCreateEncounterDialog(campaignId),
                icon: const Icon(Icons.add),
                label: const Text('新遭遇'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (controller.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                controller.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (controller.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (controller.encounters.isEmpty)
            const _EmptyEncounterHint()
          else
            for (final encounter in controller.encounters) ...[
              _EncounterListTile(
                encounter: encounter,
                selected: controller.activeEncounter?.id == encounter.id,
                onTap: () => controller.loadEncounter(encounter.id),
              ),
              const SizedBox(height: 8),
            ],
          if (controller.activeEncounter != null) ...[
            const SizedBox(height: 12),
            _ActiveEncounterPanel(
              encounter: controller.activeEncounter!,
              controller: controller,
            ),
          ],
        ],
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
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
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
          content: Text('创建失败：${widget.sessionController.error ?? '未知错误'}'),
        ),
      );
    }
  }

  Future<void> _showCreateEncounterDialog(String campaignId) async {
    final controller = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('新遭遇'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: '遭遇名称'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('创建'),
            ),
          ],
        );
      },
    );

    if (name == null || name.isEmpty) return;

    final success = await widget.encounterController.createEncounter(
      campaignId: campaignId,
      name: name,
    );

    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(success ? '遭遇已创建' : '创建遭遇失败')),
    );
  }
}

class _EmptyEncounterHint extends StatelessWidget {
  const _EmptyEncounterHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(
            Icons.shield_outlined,
            size: 44,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text('暂无遭遇', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(
            '为当前战役创建遭遇后，可以在这里管理先攻、回合和生命值。',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ],
      ),
    );
  }
}

class _EncounterListTile extends StatelessWidget {
  const _EncounterListTile({
    required this.encounter,
    required this.selected,
    required this.onTap,
  });

  final Encounter encounter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: selected ? colorScheme.secondaryContainer : null,
      child: ListTile(
        leading: const Icon(Icons.shield_outlined),
        title: Text(encounter.name),
        subtitle: Text('Round ${encounter.round} · ${encounter.status}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _ActiveEncounterPanel extends StatelessWidget {
  const _ActiveEncounterPanel({
    required this.encounter,
    required this.controller,
  });

  final Encounter encounter;
  final EncounterController controller;

  @override
  Widget build(BuildContext context) {
    final participants = encounter.participants;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('当前遭遇', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: encounter.status == 'draft'
                  ? controller.startEncounter
                  : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('开始'),
            ),
            FilledButton.tonalIcon(
              onPressed: encounter.status == 'active'
                  ? controller.advanceTurn
                  : null,
              icon: const Icon(Icons.skip_next),
              label: const Text('下一回合'),
            ),
            OutlinedButton.icon(
              onPressed: encounter.status == 'active'
                  ? controller.endEncounter
                  : null,
              icon: const Icon(Icons.stop),
              label: const Text('结束'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (participants.isEmpty)
          const ListTile(
            leading: Icon(Icons.group_outlined),
            title: Text('还没有参战者'),
          )
        else
          for (final participant in participants)
            Card(
              child: ListTile(
                leading: CircleAvatar(child: Text('${participant.initiative}')),
                title: Text(participant.displayName),
                subtitle: Text(
                  'HP ${participant.hpCurrent}/${participant.hpMax} · AC ${participant.armorClass}',
                ),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      tooltip: '减少 HP',
                      onPressed: () => controller.adjustParticipantHp(
                        encounterId: encounter.id,
                        participantId: participant.id,
                        delta: -1,
                      ),
                      icon: const Icon(Icons.remove),
                    ),
                    IconButton(
                      tooltip: '增加 HP',
                      onPressed: () => controller.adjustParticipantHp(
                        encounterId: encounter.id,
                        participantId: participant.id,
                        delta: 1,
                      ),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
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
        trailing: Chip(label: Text(label), backgroundColor: color),
        onTap: onTap,
      ),
    );
  }
}
