import 'package:flutter/material.dart';

import '../../auth/presentation/auth_controller.dart';
import '../../campaigns/presentation/campaign_controller.dart';
import '../../characters/presentation/character_controller.dart';
import '../../client_mode/domain/client_mode.dart';
import '../../sessions/presentation/session_controller.dart';
import '../domain/active_server_session.dart';

class HomeDashboardPage extends StatefulWidget {
  const HomeDashboardPage({
    required this.session,
    required this.modeController,
    required this.authController,
    required this.campaignController,
    required this.characterController,
    required this.sessionController,
    required this.onNavigateToTab,
    super.key,
  });

  final ActiveServerSession session;
  final ClientModeController modeController;
  final AuthController authController;
  final CampaignController campaignController;
  final CharacterController characterController;
  final SessionController sessionController;
  final ValueChanged<int> onNavigateToTab;

  @override
  State<HomeDashboardPage> createState() => _HomeDashboardPageState();
}

class _HomeDashboardPageState extends State<HomeDashboardPage> {
  String? _loadedForToken;

  @override
  void initState() {
    super.initState();
    widget.authController.addListener(_onAuthChanged);
    _maybeLoad();
  }

  @override
  void dispose() {
    widget.authController.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (!widget.authController.isLoggedIn) {
      _loadedForToken = null;
      return;
    }
    _maybeLoad();
  }

  void _maybeLoad() {
    final token = widget.authController.accessToken;
    if (!widget.authController.isLoggedIn ||
        token == null ||
        token == _loadedForToken) {
      return;
    }
    _loadedForToken = token;
    widget.campaignController.loadCampaigns();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.modeController,
        widget.authController,
        widget.campaignController,
        widget.characterController,
        widget.sessionController,
      ]),
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('首页'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Chip(
                  avatar: Icon(
                    widget.modeController.mode == ClientMode.dungeonMaster
                        ? Icons.shield_outlined
                        : Icons.person_outline,
                    size: 18,
                  ),
                  label: Text(widget.modeController.mode.label),
                ),
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: _buildOverview(context)),
                              const SizedBox(width: 16),
                              Expanded(flex: 2, child: _buildSideRail(context)),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildOverview(context),
                              const SizedBox(height: 16),
                              _buildSideRail(context),
                            ],
                          ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildOverview(BuildContext context) {
    final theme = Theme.of(context);
    final signedIn = widget.authController.isLoggedIn;
    final profile = widget.session.profile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('跑团总览', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        Card.filled(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 28,
                      child: Text(
                        profile?.name.characters.first ?? '本',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile?.name ?? '本地模式',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profile?.baseUrl ?? '未连接服务器，离线使用中',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (!signedIn) ...[
                  const _InfoLine(
                    icon: Icons.lock_outline,
                    title: '登录后同步战役、角色和跑团状态',
                    subtitle: '服务器资料、角色卡和跑团日志会按当前服务器隔离保存。',
                  ),
                ] else ...[
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _MetricChip(
                        icon: Icons.castle_outlined,
                        label: '战役',
                        value: '${widget.campaignController.campaigns.length}',
                      ),
                      _MetricChip(
                        icon: Icons.badge_outlined,
                        label: '角色',
                        value:
                            '${widget.characterController.characters.length}',
                      ),
                      _MetricChip(
                        icon: Icons.table_restaurant_outlined,
                        label: '场次',
                        value: '${widget.sessionController.sessions.length}',
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildQuickActions(context),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        FilledButton.tonalIcon(
          onPressed: () => widget.onNavigateToTab(1),
          icon: const Icon(Icons.castle_outlined),
          label: const Text('打开战役'),
        ),
        FilledButton.tonalIcon(
          onPressed: () => widget.onNavigateToTab(2),
          icon: const Icon(Icons.badge_outlined),
          label: const Text('打开角色'),
        ),
        FilledButton.tonalIcon(
          onPressed: () => widget.onNavigateToTab(1),
          icon: const Icon(Icons.forum_outlined),
          label: const Text('进入战役聊天室'),
        ),
      ],
    );
  }

  Widget _buildSideRail(BuildContext context) {
    final activeSession = widget.sessionController.activeSession;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ActionCard(
          icon: Icons.menu_book_outlined,
          title: '内容索引',
          subtitle: '查法术、装备、怪物和战役启用内容。',
          onTap: () => widget.onNavigateToTab(3),
        ),
        const SizedBox(height: 12),
        _ActionCard(
          icon: Icons.forum_outlined,
          title: activeSession == null ? '战役聊天室' : activeSession.name,
          subtitle: activeSession == null
              ? '进入战役后可聊天、掷骰、检定和打开 DM 控场。'
              : '继续当前跑团上下文。',
          onTap: () => widget.onNavigateToTab(1),
        ),
        const SizedBox(height: 12),
        _ActionCard(
          icon: Icons.settings_outlined,
          title: '应用设置',
          subtitle: '服务器、模式、外观和跑团偏好。',
          onTap: () => widget.onNavigateToTab(4),
        ),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 18), label: Text('$label $value'));
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(subtitle),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
