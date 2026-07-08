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
              Chip(label: Text('当前模式：${modeController.mode.label}')),
              const SizedBox(height: 32),
              Text('房间与登录入口', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('这里将接入账号登录、房间列表，以及 DM 创建房间流程。'),
            ],
          ),
        );
      },
    );
  }
}
