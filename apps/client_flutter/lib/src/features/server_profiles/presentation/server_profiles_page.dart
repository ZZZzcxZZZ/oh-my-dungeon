import 'package:flutter/material.dart';

import '../../auth/data/auth_api_client.dart';
import '../../auth/data/auth_token_store.dart';
import '../../campaigns/data/campaign_api_client.dart';
import '../../characters/data/character_api_client.dart';
import '../../client_mode/domain/client_mode.dart';
import '../../content/data/content_api_client.dart';
import '../../rooms/data/room_api_client.dart';
import '../../server_home/presentation/main_shell.dart';
import '../../sessions/data/session_api_client.dart';
import '../data/server_discovery_client.dart';
import '../data/server_profile_store.dart';
import '../domain/server_profile.dart';

enum _ServerProfileAction { setDefault, editName, delete }

class ServerProfilesPage extends StatefulWidget {
  const ServerProfilesPage({
    required this.store,
    required this.authTokenStore,
    required this.discoveryClient,
    required this.roomClient,
    required this.authClient,
    required this.campaignClient,
    required this.characterClient,
    required this.contentClient,
    required this.sessionClient,
    required this.modeController,
    super.key,
  });

  final ServerProfileStore store;
  final AuthTokenStore authTokenStore;
  final ServerDiscoveryClient discoveryClient;
  final RoomClient roomClient;
  final AuthClient authClient;
  final CampaignClient campaignClient;
  final CharacterClient characterClient;
  final ContentClient contentClient;
  final SessionClient sessionClient;
  final ClientModeController modeController;

  @override
  State<ServerProfilesPage> createState() => _ServerProfilesPageState();
}

class _ServerProfilesPageState extends State<ServerProfilesPage> {
  late Future<_ServerProfilesViewData> _profilesFuture;

  @override
  void initState() {
    super.initState();
    _profilesFuture = _loadProfiles();
  }

  Future<_ServerProfilesViewData> _loadProfiles() async {
    final profiles = await widget.store.listProfiles();
    final defaultProfileId = await widget.store.getDefaultProfileId();
    return _ServerProfilesViewData(
      profiles: profiles,
      defaultProfileId: defaultProfileId,
    );
  }

  void _refreshProfiles() {
    setState(() {
      _profilesFuture = _loadProfiles();
    });
  }

  Future<void> _showSettingsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final mode = widget.modeController.mode;

            return AlertDialog(
              title: const Text('设置'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('客户端模式'),
                  const SizedBox(height: 12),
                  SegmentedButton<ClientMode>(
                    segments: const [
                      ButtonSegment(
                        value: ClientMode.player,
                        icon: Icon(Icons.person_outline),
                        label: Text('Player'),
                      ),
                      ButtonSegment(
                        value: ClientMode.dungeonMaster,
                        icon: Icon(Icons.shield_outlined),
                        label: Text('DM'),
                      ),
                    ],
                    selected: {mode},
                    onSelectionChanged: (selection) async {
                      await widget.modeController.setMode(selection.single);
                      setDialogState(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  Text('当前模式：${widget.modeController.mode.label}'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('关闭'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showAddServerDialog() async {
    final controller = TextEditingController(text: 'http://localhost:3000');
    final messenger = ScaffoldMessenger.of(context);

    final baseUrl = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('添加服务器'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: '服务器地址',
              hintText: 'https://example.com',
            ),
            keyboardType: TextInputType.url,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('测试并保存'),
            ),
          ],
        );
      },
    );

    if (baseUrl == null || baseUrl.trim().isEmpty) return;

    try {
      final metadata = await widget.discoveryClient.discover(baseUrl.trim());
      final profile = ServerProfile.fromMetadata(
        baseUrl: baseUrl.trim(),
        metadata: metadata,
      );
      await widget.store.saveProfile(profile);
      _refreshProfiles();
      messenger.showSnackBar(SnackBar(content: Text('已连接到 ${profile.name}')));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('连接失败：$error')));
    }
  }

  Future<void> _setDefaultProfile(ServerProfile profile) async {
    await widget.store.setDefaultProfileId(profile.id);
    _refreshProfiles();
  }

  Future<void> _showEditProfileDialog(ServerProfile profile) async {
    final controller = TextEditingController(text: profile.name);

    final nextName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('编辑名称'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: '服务器名称'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (nextName == null || nextName.trim().isEmpty) return;

    await widget.store.saveProfile(profile.copyWith(name: nextName.trim()));
    _refreshProfiles();
  }

  Future<void> _showDeleteProfileDialog(ServerProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除服务器'),
          content: Text('确认删除 ${profile.name}？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确认删除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await widget.store.deleteProfile(profile.id);
    _refreshProfiles();
  }

  Future<void> _handleProfileAction({
    required ServerProfile profile,
    required _ServerProfileAction action,
  }) async {
    switch (action) {
      case _ServerProfileAction.setDefault:
        await _setDefaultProfile(profile);
      case _ServerProfileAction.editName:
        await _showEditProfileDialog(profile);
      case _ServerProfileAction.delete:
        await _showDeleteProfileDialog(profile);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.modeController,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('D&D Table Tool'),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Center(
                  child: Text('当前模式：${widget.modeController.mode.label}'),
                ),
              ),
              IconButton(
                tooltip: '设置',
                onPressed: _showSettingsDialog,
                icon: const Icon(Icons.settings_outlined),
              ),
              IconButton(
                tooltip: '添加服务器',
                onPressed: _showAddServerDialog,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          body: FutureBuilder<_ServerProfilesViewData>(
            future: _profilesFuture,
            builder: (context, snapshot) {
              final data = snapshot.data ?? _ServerProfilesViewData.empty;
              if (data.profiles.isEmpty) {
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.dns_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '连接你的跑团服务器',
                            style: Theme.of(context).textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '添加自托管服务器后，可以登录、切换 Player/DM 模式并进入战役。',
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: _showAddServerDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('添加服务器'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return ListView.separated(
                itemCount: data.profiles.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final profile = data.profiles[index];
                  final isDefault = profile.id == data.defaultProfileId;
                  return ListTile(
                    leading: const Icon(Icons.dns_outlined),
                    title: Text(profile.name),
                    subtitle: Text(profile.baseUrl),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) {
                            return MainShell(
                              profile: profile,
                              modeController: widget.modeController,
                              roomClient: widget.roomClient,
                              authTokenStore: widget.authTokenStore,
                              authClient: widget.authClient,
                              campaignClient: widget.campaignClient,
                              characterClient: widget.characterClient,
                              contentClient: widget.contentClient,
                              sessionClient: widget.sessionClient,
                            );
                          },
                        ),
                      );
                    },
                    trailing: _ServerProfileTrailing(
                      profile: profile,
                      isDefault: isDefault,
                      onSelected: (action) => _handleProfileAction(
                        profile: profile,
                        action: action,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _ServerProfileTrailing extends StatelessWidget {
  const _ServerProfileTrailing({
    required this.profile,
    required this.isDefault,
    required this.onSelected,
  });

  final ServerProfile profile;
  final bool isDefault;
  final ValueChanged<_ServerProfileAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isDefault) ...[
          const Chip(label: Text('默认')),
          const SizedBox(width: 8),
        ],
        Text(profile.lastKnownVersion),
        PopupMenuButton<_ServerProfileAction>(
          tooltip: '服务器操作',
          onSelected: onSelected,
          itemBuilder: (context) {
            return [
              if (!isDefault)
                const PopupMenuItem(
                  value: _ServerProfileAction.setDefault,
                  child: Text('设为默认'),
                ),
              const PopupMenuItem(
                value: _ServerProfileAction.editName,
                child: Text('编辑名称'),
              ),
              const PopupMenuItem(
                value: _ServerProfileAction.delete,
                child: Text('删除'),
              ),
            ];
          },
        ),
      ],
    );
  }
}

class _ServerProfilesViewData {
  const _ServerProfilesViewData({
    required this.profiles,
    required this.defaultProfileId,
  });

  static const empty = _ServerProfilesViewData(
    profiles: [],
    defaultProfileId: null,
  );

  final List<ServerProfile> profiles;
  final String? defaultProfileId;
}
