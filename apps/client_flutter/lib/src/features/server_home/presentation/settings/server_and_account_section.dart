import 'package:flutter/material.dart';

import '../../../../core/sync/sync_status_controller.dart';
import '../../../../core/sync/sync_status_tile.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../auth/presentation/auth_page.dart';
import '../../../server_profiles/data/server_profile_store.dart';
import '../../../server_profiles/domain/server_profile.dart';
import '../../../vault/presentation/vault_settings_section.dart';
import '../../../vault/presentation/vault_sync_controller.dart';
import '../../domain/active_server_session.dart';
import 'settings_section.dart';

/// 服务器与账户：服务器信息、切换、登录/退出、同步状态、Vault。
class ServerAndAccountSection extends StatefulWidget {
  const ServerAndAccountSection({
    required this.session,
    required this.authController,
    required this.syncStatusController,
    this.serverProfileStore,
    this.serverProfilesPageBuilder,
    this.onSwitchToProfile,
    this.vaultSyncActions,
    this.compact = false,
    this.onOpenDetails,
    super.key,
  });

  final ActiveServerSession session;
  final AuthController authController;
  final SyncStatusController syncStatusController;
  final ServerProfileStore? serverProfileStore;
  final WidgetBuilder? serverProfilesPageBuilder;
  final ValueChanged<ServerProfile>? onSwitchToProfile;
  final VaultSyncActions? vaultSyncActions;
  final bool compact;
  final VoidCallback? onOpenDetails;

  @override
  State<ServerAndAccountSection> createState() =>
      _ServerAndAccountSectionState();
}

class _ServerAndAccountSectionState extends State<ServerAndAccountSection> {
  List<ServerProfile> _allProfiles = const [];

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final store = widget.serverProfileStore;
    if (store == null) return;
    final profiles = await store.listProfiles();
    if (!mounted) return;
    setState(() => _allProfiles = profiles);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final profile = widget.session.profile;

    if (widget.compact) {
      final accountLabel = widget.authController.isLoading
          ? '正在读取账号'
          : widget.authController.user?.username ?? '未登录';
      return SettingsSection(
        title: '服务器与账户',
        leading: Icon(Icons.cloud_outlined, color: colorScheme.primary),
        children: [
          Card(
            child: ListTile(
              key: const Key('server-account-summary'),
              leading: CircleAvatar(
                backgroundColor: colorScheme.secondaryContainer,
                foregroundColor: colorScheme.onSecondaryContainer,
                child: Icon(
                  profile == null
                      ? Icons.cloud_off_outlined
                      : Icons.cloud_done_outlined,
                ),
              ),
              title: Text(profile?.name ?? '本地模式'),
              subtitle: Text(
                profile == null ? accountLabel : '$accountLabel · 已选择服务器',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: widget.onOpenDetails,
            ),
          ),
        ],
      );
    }

    return SettingsSection(
      title: '服务器与账户',
      leading: Icon(Icons.cloud_outlined, color: colorScheme.primary),
      children: [
        Card(
          child: Column(
            children: [
              if (profile == null) ...[
                ListTile(
                  leading: const Icon(Icons.cloud_off),
                  title: const Text('尚未连接服务器'),
                  subtitle: const Text('离线模式下本地资料、角色和笔记仍可用'),
                ),
                if (widget.serverProfilesPageBuilder != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.tonalIcon(
                        onPressed: () => _openServerProfilesPage(context),
                        icon: const Icon(Icons.add),
                        label: const Text('管理服务器'),
                      ),
                    ),
                  ),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.dns_outlined),
                  title: Text(profile.name),
                  subtitle: Text(profile.baseUrl),
                ),
                ListTile(
                  leading: const Icon(Icons.tag),
                  title: Text('版本 ${profile.lastKnownVersion}'),
                  dense: true,
                ),
                if (widget.serverProfileStore != null &&
                    _allProfiles.length > 1) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('切换服务器', style: theme.textTheme.labelMedium),
                    ),
                  ),
                  for (final p in _allProfiles)
                    ListTile(
                      leading: Icon(
                        p.id == profile.id
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                      ),
                      title: Text(p.name),
                      subtitle: Text(p.baseUrl),
                      // 选中项高亮而非禁用置灰，点击选中项不产生操作。
                      selected: p.id == profile.id,
                      enabled: true,
                      onTap: p.id == profile.id
                          ? null
                          : () => widget.onSwitchToProfile?.call(p),
                    ),
                ],
                if (widget.serverProfilesPageBuilder != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _openServerProfilesPage(context),
                        icon: const Icon(Icons.settings_outlined),
                        label: const Text('管理服务器'),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _AccountCard(
          authController: widget.authController,
          onLogin: () => _openAuthPage(context),
        ),
        const SizedBox(height: 12),
        Card(
          child: SyncStatusTile(
            controller: widget.syncStatusController,
            isLoggedIn: widget.authController.isLoggedIn,
          ),
        ),
        if (widget.vaultSyncActions != null) ...[
          const SizedBox(height: 12),
          VaultSettingsSection(actions: widget.vaultSyncActions!),
        ],
      ],
    );
  }

  void _openServerProfilesPage(BuildContext context) {
    final builder = widget.serverProfilesPageBuilder;
    if (builder == null) return;
    Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: builder));
  }

  Future<void> _openAuthPage(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => AuthPage(authController: widget.authController),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.authController, required this.onLogin});

  final AuthController authController;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    if (authController.isLoading) {
      return const Card(child: ListTile(leading: CircularProgressIndicator()));
    }

    if (!authController.isLoggedIn) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.lock_outline),
          title: const Text('未登录'),
          subtitle: const Text('登录后可管理战役与跑团'),
          trailing: FilledButton(onPressed: onLogin, child: const Text('登录')),
        ),
      );
    }

    final user = authController.user!;
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: Text(user.username),
            subtitle: Text(user.email),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.tonalIcon(
              onPressed: () => authController.logout(),
              icon: const Icon(Icons.logout),
              label: const Text('退出登录'),
            ),
          ),
        ],
      ),
    );
  }
}
