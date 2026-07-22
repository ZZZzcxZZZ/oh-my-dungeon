import 'package:flutter/material.dart';

import '../../../app_preferences/presentation/app_preferences_controller.dart';
import 'settings_section.dart';

/// 游戏与跑团：默认掷骰模式、消息密度、字体缩放、HP 警戒阈值。
///
/// Task 1.3 新增项 — 参考 docs/superpowers/plans/2026-07-23-user-feedback-integration-hardening.md。
/// 快捷骰预设（quickDicePresets）字段已持久化，但 UI 编辑器留待 Wave 3 Task 3.2
/// 「组合式骰子编辑器」统一实现，避免设置页与骰子托盘重复设计。
class GameplaySettingsSection extends StatelessWidget {
  const GameplaySettingsSection({required this.controller, super.key});

  final AppPreferencesController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final preferences = controller.preferences;

    return SettingsSection(
      title: '游戏与跑团',
      leading: Icon(Icons.sports_esports_outlined, color: colorScheme.primary),
      children: [
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.swap_horiz_outlined),
                title: const Text('默认掷骰模式'),
                subtitle: const Text('检定时默认采用的掷骰方式'),
                trailing: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'normal', label: Text('普通')),
                    ButtonSegment(value: 'advantage', label: Text('优势')),
                    ButtonSegment(value: 'disadvantage', label: Text('劣势')),
                  ],
                  selected: {preferences.defaultRollMode},
                  onSelectionChanged: (selection) =>
                      controller.setDefaultRollMode(selection.single),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.density_small_outlined),
                title: const Text('消息密度'),
                subtitle: const Text('聊天消息的间距与字号'),
                trailing: DropdownButton<String>(
                  value: preferences.messageDensity,
                  items: const [
                    DropdownMenuItem(value: 'compact', child: Text('紧凑')),
                    DropdownMenuItem(value: 'standard', child: Text('标准')),
                    DropdownMenuItem(
                      value: 'comfortable',
                      child: Text('宽松'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) controller.setMessageDensity(value);
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.text_fields_outlined),
                title: const Text('字体缩放'),
                subtitle: const Text('列表与正文字号'),
                trailing: DropdownButton<String>(
                  value: preferences.fontScale,
                  items: const [
                    DropdownMenuItem(value: 'system', child: Text('系统')),
                    DropdownMenuItem(value: 'small', child: Text('小')),
                    DropdownMenuItem(value: 'medium', child: Text('中')),
                    DropdownMenuItem(value: 'large', child: Text('大')),
                  ],
                  onChanged: (value) {
                    if (value != null) controller.setFontScale(value);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.favorite_outline, size: 20),
                          const SizedBox(width: 8),
                          Text('HP 警戒阈值', style: theme.textTheme.labelLarge),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '当前 HP 低于最大值 ${(preferences.hpWarningThreshold * 100).round()}% 时, 头像生命环变色',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Slider(
                        value: preferences.hpWarningThreshold,
                        min: 0.0,
                        max: 1.0,
                        divisions: 10,
                        label:
                            '${(preferences.hpWarningThreshold * 100).round()}%',
                        onChanged: controller.setHpWarningThreshold,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
