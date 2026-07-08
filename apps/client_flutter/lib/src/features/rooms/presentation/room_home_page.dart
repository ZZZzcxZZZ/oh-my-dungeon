import 'package:flutter/material.dart';

import '../../client_mode/domain/client_mode.dart';
import '../../server_profiles/domain/server_profile.dart';
import '../domain/room.dart';

class RoomHomePage extends StatelessWidget {
  const RoomHomePage({
    required this.profile,
    required this.room,
    required this.modeController,
    super.key,
  });

  final ServerProfile profile;
  final Room room;
  final ClientModeController modeController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: modeController,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: Text(room.name)),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                room.name,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(profile.name),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Chip(label: Text('当前模式：${modeController.mode.label}')),
              ),
              const SizedBox(height: 32),
              Text('角色与跑团工具', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: const [
                  _ToolChip(icon: Icons.badge_outlined, label: '角色卡'),
                  _ToolChip(icon: Icons.casino_outlined, label: '掷骰'),
                  _ToolChip(icon: Icons.chat_bubble_outline, label: '房间消息'),
                  _ToolChip(icon: Icons.map_outlined, label: '场景'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ToolChip extends StatelessWidget {
  const _ToolChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ActionChip(avatar: Icon(icon), label: Text(label), onPressed: () {});
  }
}
