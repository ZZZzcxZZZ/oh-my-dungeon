import 'package:flutter/material.dart';

import '../../../app_preferences/presentation/app_preferences_controller.dart';
import '../../../client_mode/domain/client_mode.dart';
import 'settings_section.dart';

/// 角色模式：Player/DM 切换 + 默认角色创建方式。
class RoleModeSection extends StatelessWidget {
  const RoleModeSection({
    required this.modeController,
    required this.preferencesController,
    super.key,
  });

  final ClientModeController modeController;
  final AppPreferencesController preferencesController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mode = modeController.mode;
    final preferences = preferencesController.preferences;

    return SettingsSection(
      title: '角色模式',
      leading: Icon(Icons.shield_outlined, color: colorScheme.primary),
      children: [
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
                      label: Text('玩家'),
                    ),
                    ButtonSegment(
                      value: ClientMode.dungeonMaster,
                      icon: Icon(Icons.shield_outlined),
                      label: Text('主持人'),
                    ),
                  ],
                  selected: {mode},
                  onSelectionChanged: (selection) =>
                      modeController.setMode(selection.single),
                ),
                const SizedBox(height: 12),
                Text(
                  mode == ClientMode.dungeonMaster
                      ? '主持人模式会显示战役角色、私有资料和控场工具。'
                      : '玩家模式只显示自己的本地角色和可参与的战役。',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.route_outlined),
            title: const Text('默认创建方式'),
            subtitle: const Text('新建角色时默认推荐的创建路径'),
            trailing: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'quick', label: Text('快速')),
                ButtonSegment(value: 'standard', label: Text('标准')),
              ],
              selected: {preferences.defaultCreationMethod},
              onSelectionChanged: (selection) {
                preferencesController.setDefaultCreationMethod(
                  selection.single,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
