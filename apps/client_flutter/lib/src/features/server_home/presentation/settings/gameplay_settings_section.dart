import 'package:flutter/material.dart';

import '../../../app_preferences/presentation/app_preferences_controller.dart';
import 'settings_section.dart';

/// 游戏与跑团：默认掷骰模式、消息密度、字体缩放、HP 警戒阈值、快捷骰预设.
///
/// Task 1.3 新增项 — 参考 docs/superpowers/plans/2026-07-23-user-feedback-integration-hardening.md。
/// Task 3.2: 快捷骰预设编辑器 (quickDicePresets) 与组合式骰子编辑器联动.
class GameplaySettingsSection extends StatefulWidget {
  const GameplaySettingsSection({required this.controller, super.key});

  final AppPreferencesController controller;

  @override
  State<GameplaySettingsSection> createState() =>
      _GameplaySettingsSectionState();

  static String? validatePreset(String input) {
    if (input.isEmpty) return '不能为空';
    final tokens = input.split(RegExp(r'\s+\+\s+'));
    for (final token in tokens) {
      final match = RegExp(
        r'^(\d+)d(\d+)(?:kh1|kl1)?([+-]\d+)?$',
      ).firstMatch(token);
      if (match == null) {
        return '格式无效, 请使用如 1d20+5 或 2d6+3 的表达式';
      }
    }
    return null;
  }
}

class _GameplaySettingsSectionState extends State<GameplaySettingsSection> {
  late final TextEditingController _diceController;

  AppPreferencesController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _diceController = TextEditingController(
      text: controller.preferences.defaultDice,
    );
  }

  @override
  void didUpdateWidget(covariant GameplaySettingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = controller.preferences.defaultDice;
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
    final preferences = controller.preferences;

    return SettingsSection(
      title: '游戏与跑团',
      leading: Icon(Icons.sports_esports_outlined, color: colorScheme.primary),
      children: [
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
                  onSubmitted: controller.setDefaultDice,
                ),
                trailing: IconButton.filledTonal(
                  tooltip: '保存默认骰子',
                  onPressed: () =>
                      controller.setDefaultDice(_diceController.text),
                  icon: const Icon(Icons.save_outlined),
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.fact_check_outlined),
                title: const Text('掷骰前确认'),
                subtitle: const Text('掷出默认骰子前先确认，避免误触'),
                value: preferences.confirmBeforeRoll,
                onChanged: controller.setConfirmBeforeRoll,
              ),
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
                    DropdownMenuItem(value: 'comfortable', child: Text('宽松')),
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
              SwitchListTile(
                secondary: const Icon(Icons.account_circle_outlined),
                title: const Text('连续消息合并头像'),
                subtitle: const Text('同一角色连续发言时，只在第一条显示头像和名称'),
                value: preferences.groupConsecutiveChatMessages,
                onChanged: controller.setGroupConsecutiveChatMessages,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.keyboard_return_outlined),
                title: const Text('检定后返回聊天室'),
                subtitle: const Text('从战役角色卡掷骰后自动回到聊天'),
                value: preferences.returnToChatAfterRoll,
                onChanged: controller.setReturnToChatAfterRoll,
              ),
              _CharacterDefaultTabTile(controller: controller),
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
        const SizedBox(height: 12),
        _buildQuickDicePresetsCard(context, theme, colorScheme),
      ],
    );
  }

  /// Task 3.2: 快捷骰预设编辑器. 最多 6 个, 支持添加/删除.
  Widget _buildQuickDicePresetsCard(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final presets = controller.preferences.quickDicePresets;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.casino_outlined, size: 20),
                const SizedBox(width: 8),
                Text('快捷骰预设', style: theme.textTheme.labelLarge),
                const Spacer(),
                Text(
                  '${presets.length}/6',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '在掷骰面板中一键填入的常用表达式, 如 1d20+5 或 2d6+3',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            if (presets.isEmpty)
              Text(
                '还没有自定义预设',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.outline,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (int i = 0; i < presets.length; i++)
                    Chip(
                      key: ValueKey('quick-dice-preset-$i'),
                      label: Text(presets[i]),
                      onDeleted: () {
                        final next = List<String>.of(presets)..removeAt(i);
                        controller.setQuickDicePresets(next);
                      },
                    ),
                ],
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('quick-dice-preset-add'),
                onPressed: presets.length >= 6
                    ? null
                    : () => _showAddPresetDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('添加预设'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddPresetDialog(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => const _PresetEditorDialog(),
    );
    if (result == null) return;
    final current = List<String>.of(controller.preferences.quickDicePresets);
    current.add(result);
    await controller.setQuickDicePresets(current);
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

/// 添加快捷骰预设对话框. 独立 StatefulWidget 以正确管理 TextEditingController 生命周期.
class _PresetEditorDialog extends StatefulWidget {
  const _PresetEditorDialog();

  @override
  State<_PresetEditorDialog> createState() => _PresetEditorDialogState();
}

class _PresetEditorDialogState extends State<_PresetEditorDialog> {
  final _inputController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _submit() {
    final trimmed = _inputController.text.trim();
    final validation = GameplaySettingsSection.validatePreset(trimmed);
    if (validation == null) {
      Navigator.of(context).pop(trimmed);
    } else {
      setState(() => _errorText = validation);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加快捷骰预设'),
      content: TextField(
        key: const Key('quick-dice-preset-input'),
        controller: _inputController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: '例如 1d20+5 或 2d6+3',
          errorText: _errorText,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('quick-dice-preset-confirm'),
          onPressed: _submit,
          child: const Text('添加'),
        ),
      ],
    );
  }
}
