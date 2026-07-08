import 'package:flutter/material.dart';

import '../../client_mode/domain/client_mode.dart';
import '../../rooms/data/room_api_client.dart';
import '../../rooms/domain/room.dart';
import '../../server_profiles/domain/server_profile.dart';

class ServerHomePage extends StatefulWidget {
  const ServerHomePage({
    required this.profile,
    required this.modeController,
    required this.roomClient,
    super.key,
  });

  final ServerProfile profile;
  final ClientModeController modeController;
  final RoomClient roomClient;

  @override
  State<ServerHomePage> createState() => _ServerHomePageState();
}

class _ServerHomePageState extends State<ServerHomePage> {
  final List<Room> _rooms = [];

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
      final room = await widget.roomClient.createRoom(
        apiBaseUrl: widget.profile.apiBaseUrl,
        name: roomName.trim(),
      );
      setState(() {
        _rooms.add(room);
      });
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('创建房间失败：$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.modeController,
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
              if (_rooms.isNotEmpty) ...[
                const SizedBox(height: 32),
                Text('房间列表', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final room in _rooms)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.meeting_room_outlined),
                    title: Text(room.name),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}
