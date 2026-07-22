import 'package:flutter/material.dart';

import '../../../app_preferences/presentation/app_preferences_controller.dart';
import 'seed_color_dialog.dart';
import 'settings_section.dart';

/// 外观与体验：主题模式、Material 3 主题色、高对比、默认骰子、掷骰确认、
/// 默认角色卡标签。
class AppearanceSection extends StatefulWidget {
  const AppearanceSection({required this.controller, super.key});

  final AppPreferencesController controller;

  @override
  State<AppearanceSection> createState() => _AppearanceSectionState();
}

class _AppearanceSectionState extends State<AppearanceSection> {
  late TextEditingController _diceController;

  @override
  void initState() {
    super.initState();
    _diceController = TextEditingController(
      text: widget.controller.preferences.defaultDice,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncDiceController();
  }

  void _syncDiceController() {
    final current = widget.controller.preferences.defaultDice;
    if (_diceController.text != current) {
      _diceController.value = TextEditingValue(
        text: current,
        selection: TextSelection.collapsed(offset: current.length),
      );
    }
  }

  @override
  void dispose() {
    _diceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final preferences = widget.controller.preferences;

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
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_outlined),
                      label: Text('系统'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_outlined),
                      label: Text('浅色'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_outlined),
                      label: Text('深色'),
                    ),
                  ],
                  selected: {preferences.themeMode},
                  onSelectionChanged: (selection) {
                    widget.controller.setThemeMode(selection.single);
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
                      widget.controller.setSeedColor(chosen);
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
                  onChanged: widget.controller.setHighContrastTheme,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.casino_outlined),
                title: const Text('默认骰子'),
                subtitle: TextField(
                  controller: _diceController,
                  decoration: const InputDecoration(
                    hintText: '1d20',
                    isDense: true,
                  ),
                  onSubmitted: widget.controller.setDefaultDice,
                ),
                trailing: FilledButton.tonal(
                  onPressed: () {
                    widget.controller.setDefaultDice(_diceController.text);
                  },
                  child: const Text('保存'),
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.fact_check_outlined),
                title: const Text('掷骰确认'),
                subtitle: const Text('掷出默认骰子前先确认，避免误触'),
                value: preferences.confirmBeforeRoll,
                onChanged: widget.controller.setConfirmBeforeRoll,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.account_circle_outlined),
                title: const Text('合并连续消息头像'),
                subtitle: const Text('同一角色连续发言时，只在第一条显示头像和名称'),
                value: preferences.groupConsecutiveChatMessages,
                onChanged: widget.controller.setGroupConsecutiveChatMessages,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(child: _CharacterDefaultTabTile(controller: widget.controller)),
      ],
    );
  }
}

class _CharacterDefaultTabTile extends StatelessWidget {
  const _CharacterDefaultTabTile({required this.controller});

  final AppPreferencesController controller;

  @override
  Widget build(BuildContext context) {
    final preferences = controller.preferences;
    final defaultTab = switch (preferences.defaultCharacterTab) {
      'status' => 'overview',
      'details' || 'notes' => 'profile',
      final value => value,
    };
    return ListTile(
      leading: const Icon(Icons.tab_outlined),
      title: const Text('默认角色卡标签'),
      subtitle: const Text('打开角色详情时优先关注的页面'),
      trailing: DropdownButton<String>(
        value: defaultTab,
        items: const [
          DropdownMenuItem(value: 'overview', child: Text('总览')),
          DropdownMenuItem(value: 'actions', child: Text('动作')),
          DropdownMenuItem(value: 'spells', child: Text('法术')),
          DropdownMenuItem(value: 'equipment', child: Text('装备')),
          DropdownMenuItem(value: 'resources', child: Text('资源')),
          DropdownMenuItem(value: 'features', child: Text('特性')),
          DropdownMenuItem(value: 'profile', child: Text('角色资料')),
        ],
        onChanged: (value) {
          if (value != null) {
            controller.setDefaultCharacterTab(value);
          }
        },
      ),
    );
  }
}
