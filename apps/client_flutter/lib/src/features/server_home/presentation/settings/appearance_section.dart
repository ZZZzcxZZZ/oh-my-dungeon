import 'package:flutter/material.dart';

import '../../../app_preferences/presentation/app_preferences_controller.dart';
import 'seed_color_dialog.dart';
import 'settings_section.dart';

/// 外观与体验：主题模式、Material 3 主题色与高对比。
class AppearanceSection extends StatelessWidget {
  const AppearanceSection({required this.controller, super.key});

  final AppPreferencesController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final preferences = controller.preferences;

    return SettingsSection(
      title: '外观与体验',
      leading: Icon(Icons.palette_outlined, color: colorScheme.primary),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('主题模式', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 400;
                    return SegmentedButton<ThemeMode>(
                      expandedInsets: EdgeInsets.zero,
                      segments: [
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: compact
                              ? null
                              : const Icon(Icons.brightness_auto_outlined),
                          label: const Text('系统'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: compact
                              ? null
                              : const Icon(Icons.light_mode_outlined),
                          label: const Text('浅色'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: compact
                              ? null
                              : const Icon(Icons.dark_mode_outlined),
                          label: const Text('深色'),
                        ),
                      ],
                      selected: {preferences.themeMode},
                      onSelectionChanged: (selection) {
                        controller.setThemeMode(selection.single);
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.color_lens_outlined),
                  title: const Text('主题色'),
                  subtitle: const Text('点击选择 Material 3 主题色种子'),
                  trailing: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: preferences.seedColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                  ),
                  onTap: () async {
                    final chosen = await SeedColorDialog.show(
                      context,
                      current: preferences.seedColor,
                    );
                    if (chosen != null) {
                      controller.setSeedColor(chosen);
                    }
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.contrast_outlined),
                  title: const Text('高对比 Material 3'),
                  subtitle: const Text('提高前景与容器色差，适合长时间跑团和投屏。'),
                  value: preferences.highContrastTheme,
                  onChanged: controller.setHighContrastTheme,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
