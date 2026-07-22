import 'package:flutter/material.dart';

import '../../../client_mode/domain/client_mode.dart';
import 'settings_section.dart';

/// 角色模式：Player/DM 切换。
class RoleModeSection extends StatelessWidget {
  const RoleModeSection({
    required this.modeController,
    super.key,
  });

  final ClientModeController modeController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mode = modeController.mode;

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
      ],
    );
  }
}
