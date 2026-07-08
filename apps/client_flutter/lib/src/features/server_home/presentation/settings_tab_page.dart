import 'package:flutter/material.dart';

import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_page.dart';
import '../../client_mode/domain/client_mode.dart';
import '../../server_profiles/domain/server_profile.dart';

/// Top-level "设置" tab.
///
/// Shows server info, account state (login entry or logged-in user with
/// logout), and the Player/DM mode switch.
class SettingsTabPage extends StatelessWidget {
  const SettingsTabPage({
    required this.profile,
    required this.modeController,
    required this.authController,
    super.key,
  });

  final ServerProfile profile;
  final ClientModeController modeController;
  final AuthController authController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([modeController, authController]),
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('设置')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildServerSection(context),
              const SizedBox(height: 24),
              _buildAccountSection(context),
              const SizedBox(height: 24),
              _buildModeSection(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildServerSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('服务器', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
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
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSection(BuildContext context) {
    if (authController.isLoading) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('账号'),
          SizedBox(height: 8),
          Card(child: ListTile(leading: CircularProgressIndicator())),
        ],
      );
    }

    if (!authController.isLoggedIn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('账号', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('未登录'),
              subtitle: const Text('登录后可管理战役与跑团'),
              trailing: FilledButton(
                onPressed: () => _openAuthPage(context),
                child: const Text('登录'),
              ),
            ),
          ),
        ],
      );
    }

    final user = authController.user!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('账号', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
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
        ),
      ],
    );
  }

  Widget _buildModeSection(BuildContext context) {
    final mode = modeController.mode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('客户端模式', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  onSelectionChanged: (selection) =>
                      modeController.setMode(selection.single),
                ),
                const SizedBox(height: 12),
                Text('当前模式：${mode.label}'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openAuthPage(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => AuthPage(authController: authController),
      ),
    );
  }
}
