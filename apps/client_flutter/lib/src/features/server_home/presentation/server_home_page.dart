import 'package:flutter/material.dart';

import '../../client_mode/domain/client_mode.dart';
import '../../server_profiles/domain/server_profile.dart';

class ServerHomePage extends StatelessWidget {
  const ServerHomePage({
    required this.profile,
    required this.modeController,
    super.key,
  });

  final ServerProfile profile;
  final ClientModeController modeController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: modeController,
      builder: (context, _) {
        final mode = modeController.mode;
        return Scaffold(
          appBar: AppBar(title: Text(profile.name)),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                profile.name,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(profile.baseUrl),
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
                    onPressed: () {},
                    icon: const Icon(Icons.add),
                    label: const Text('创建房间'),
                  ),
                )
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: null,
                    icon: Icon(Icons.meeting_room_outlined),
                    label: Text('等待房间开放'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
