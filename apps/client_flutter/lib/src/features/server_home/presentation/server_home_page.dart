import 'package:flutter/material.dart';

import '../../auth/data/auth_api_client.dart';
import '../../auth/data/auth_token_store.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_page.dart';
import '../../client_mode/domain/client_mode.dart';
import '../../rooms/data/room_api_client.dart';
import '../../rooms/domain/room.dart';
import '../../rooms/presentation/room_home_page.dart';
import '../../server_profiles/domain/server_profile.dart';

class ServerHomePage extends StatefulWidget {
  const ServerHomePage({
    required this.profile,
    required this.modeController,
    required this.roomClient,
    required this.authTokenStore,
    required this.authClient,
    super.key,
  });

  final ServerProfile profile;
  final ClientModeController modeController;
  final RoomClient roomClient;
  final AuthTokenStore authTokenStore;
  final AuthClient authClient;

  @override
  State<ServerHomePage> createState() => _ServerHomePageState();
}

class _ServerHomePageState extends State<ServerHomePage> {
  late Future<List<Room>> _roomsFuture;
  late final AuthController _authController;

  @override
  void initState() {
    super.initState();
    _roomsFuture = _loadRooms();
    _authController = AuthController(
      tokenStore: widget.authTokenStore,
      authClient: widget.authClient,
      serverProfileId: widget.profile.id,
      apiBaseUrl: widget.profile.apiBaseUrl,
    )..initialize();
  }

  Future<List<Room>> _loadRooms() {
    return widget.roomClient.listRooms(apiBaseUrl: widget.profile.apiBaseUrl);
  }

  void _refreshRooms() {
    setState(() {
      _roomsFuture = _loadRooms();
    });
  }

  Future<void> _showCreateRoomDialog() async {
    final controller = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    final roomName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('创建房间'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: '房间名称'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('创建'),
            ),
          ],
        );
      },
    );

    if (roomName == null || roomName.trim().isEmpty) return;

    try {
      await widget.roomClient.createRoom(
        apiBaseUrl: widget.profile.apiBaseUrl,
        name: roomName.trim(),
      );
      _refreshRooms();
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('创建房间失败：$error')));
    }
  }

  Future<void> _openAuthPage() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => AuthPage(authController: _authController),
      ),
    );
  }

  Future<void> _handleLogout() async {
    await _authController.logout();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.modeController, _authController]),
      builder: (context, _) {
        final mode = widget.modeController.mode;
        return Scaffold(
          appBar: AppBar(title: Text(widget.profile.name)),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                widget.profile.name,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(widget.profile.baseUrl),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Chip(label: Text('当前模式：${mode.label}')),
              ),
              const SizedBox(height: 32),
              Text('账号', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              _buildAuthSection(context),
              const SizedBox(height: 32),
              Text('房间与登录入口', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                mode == ClientMode.dungeonMaster
                    ? 'DM 可以创建房间并邀请玩家加入。'
                    : 'Player 可以等待 DM 邀请，或加入已经开放的房间。',
              ),
              const SizedBox(height: 24),
              if (mode == ClientMode.dungeonMaster)
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: _showCreateRoomDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('创建房间'),
                  ),
                )
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.meeting_room_outlined),
                    label: const Text('等待房间开放'),
                  ),
                ),
              const SizedBox(height: 32),
              FutureBuilder<List<Room>>(
                future: _roomsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const LinearProgressIndicator();
                  }

                  if (snapshot.hasError) {
                    return Text('房间列表加载失败：${snapshot.error}');
                  }

                  final rooms = snapshot.data ?? const <Room>[];
                  if (rooms.isEmpty) {
                    return const Text('暂无开放房间');
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '房间列表',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      for (final room in rooms)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.meeting_room_outlined),
                          title: Text(room.name),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (context) {
                                  return RoomHomePage(
                                    profile: widget.profile,
                                    room: room,
                                    modeController: widget.modeController,
                                    roomClient: widget.roomClient,
                                  );
                                },
                              ),
                            );
                          },
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAuthSection(BuildContext context) {
    if (_authController.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      );
    }

    if (_authController.isLoggedIn) {
      final user = _authController.user!;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.person, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.username,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      user.email,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: _handleLogout,
                child: const Text('退出登录'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.lock_outline, size: 32),
            const SizedBox(width: 16),
            const Expanded(child: Text('未登录')),
            FilledButton(
              onPressed: _openAuthPage,
              child: const Text('登录 / 注册'),
            ),
          ],
        ),
      ),
    );
  }
}
