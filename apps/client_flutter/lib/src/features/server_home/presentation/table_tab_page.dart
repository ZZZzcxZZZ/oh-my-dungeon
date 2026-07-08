import 'package:flutter/material.dart';

import '../../../features/auth/presentation/auth_controller.dart';
import '../../../features/client_mode/domain/client_mode.dart';
import '../../../features/rooms/data/room_api_client.dart';
import '../../../features/rooms/domain/room.dart';
import '../../../features/rooms/presentation/room_home_page.dart';
import '../../../features/server_profiles/domain/server_profile.dart';

/// Top-level "桌面" tab.
///
/// Placeholder for the v0.4 Session desktop. For now it shows the legacy
/// rooms prototype (clearly marked) so the feature remains reachable while
/// the formal Session/DiceRoll model is being built.
class TableTabPage extends StatefulWidget {
  const TableTabPage({
    required this.profile,
    required this.modeController,
    required this.roomClient,
    required this.authController,
    super.key,
  });

  final ServerProfile profile;
  final ClientModeController modeController;
  final RoomClient roomClient;
  final AuthController authController;

  @override
  State<TableTabPage> createState() => _TableTabPageState();
}

class _TableTabPageState extends State<TableTabPage> {
  late Future<List<Room>> _roomsFuture;

  @override
  void initState() {
    super.initState();
    _roomsFuture = widget.roomClient.listRooms(
      apiBaseUrl: widget.profile.apiBaseUrl,
    );
  }

  void _refreshRooms() {
    setState(() {
      _roomsFuture = widget.roomClient.listRooms(
        apiBaseUrl: widget.profile.apiBaseUrl,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('桌面')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.info_outline),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Session 桌面开发中。下方房间列表为早期原型，仅用于演示掷骰，将在 v0.4 正式替换。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildRoomsSection(context),
        ],
      ),
    );
  }

  Widget _buildRoomsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '房间原型',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            if (widget.modeController.mode == ClientMode.dungeonMaster)
              FilledButton.tonalIcon(
                onPressed: _showCreateRoomDialog,
                icon: const Icon(Icons.add),
                label: const Text('创建房间'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<Room>>(
          future: _roomsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            if (snapshot.hasError) {
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.error_outline),
                  title: const Text('房间列表加载失败'),
                  subtitle: Text('${snapshot.error}'),
                ),
              );
            }

            final rooms = snapshot.data ?? const <Room>[];
            if (rooms.isEmpty) {
              return const Card(
                child: ListTile(
                  leading: Icon(Icons.meeting_room_outlined),
                  title: Text('暂无开放房间'),
                ),
              );
            }

            return Card(
              child: Column(
                children: [
                  for (final room in rooms)
                    ListTile(
                      leading: const Icon(Icons.meeting_room_outlined),
                      title: Text(room.name),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) => RoomHomePage(
                              profile: widget.profile,
                              room: room,
                              modeController: widget.modeController,
                              roomClient: widget.roomClient,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
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
}
