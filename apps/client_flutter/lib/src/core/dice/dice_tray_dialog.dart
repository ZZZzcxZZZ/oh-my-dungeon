import 'package:flutter/material.dart';

import '../widgets/numeric_input_field.dart';
import 'dice_roller.dart';
import '../../app/theme/app_text_styles.dart';

class DiceTrayCharacterTarget {
  const DiceTrayCharacterTarget({required this.id, required this.name});

  final String id;
  final String name;
}

/// Task 3.2 — 组合式骰子编辑器 (Foundry Dice Tray 风格).
///
/// 支持多组骰子相加, 实时表达式预览, 优势/劣势 (2d20kh1/kl1),
/// DC 检定与用户自定义预设.
/// 调用方通过 [onSend] 回调拿到 [DiceTrayResult] 后再决定如何发送到聊天.
class DiceTrayDialog extends StatefulWidget {
  const DiceTrayDialog({
    required this.diceRoller,
    required this.onSend,
    this.quickPresets = const [],
    this.characterTargets = const [],
    super.key,
  });

  final DiceRoller diceRoller;
  final ValueChanged<DiceTrayResult> onSend;

  /// 用户自定义预设, 来自 AppPreferencesController.quickDicePresets.
  /// 每个字符串是合法骰子表达式, 如 '8d6' / '2d20kh1+3'.
  final List<String> quickPresets;
  final List<DiceTrayCharacterTarget> characterTargets;

  /// 加骰子组按钮的 Key, 便于 widget test 定位.
  static final GlobalKey addGroupKey = GlobalKey(debugLabel: 'dice-tray-add');

  /// 发送按钮的 Key.
  static final GlobalKey sendKey = GlobalKey(debugLabel: 'dice-tray-send');

  /// DC 输入框的 Key.
  static final GlobalKey dcKey = GlobalKey(debugLabel: 'dice-tray-dc');
  static const characterTargetKey = ValueKey('dice-tray-character-target');

  /// 删除某组骰子按钮的 Key.
  static Key removeGroupKey(int index) => ValueKey('dice-tray-remove-$index');

  @override
  State<DiceTrayDialog> createState() => _DiceTrayDialogState();
}

class _DiceTrayDialogState extends State<DiceTrayDialog> {
  late final List<_DiceGroup> _groups = [_DiceGroup.defaults()];
  _RollMode _rollMode = _RollMode.normal;
  /// 可选 DC 检定目标; null 表示不检定.
  int? _dcValue;
  String? _selectedCharacterId;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final notation = _buildNotation();
    final canSend = _groups.every((g) => g.count > 0 && g.sides > 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('组合掷骰', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          for (int i = 0; i < _groups.length; i++)
            _buildGroupRow(i, colorScheme),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: DiceTrayDialog.addGroupKey,
              onPressed: () {
                setState(() => _groups.add(_DiceGroup.defaults()));
              },
              icon: const Icon(Icons.add),
              label: const Text('加骰子组'),
            ),
          ),
          const Divider(),
          _buildRollModeSelector(theme, colorScheme),
          const SizedBox(height: 8),
          _buildDcRow(theme, colorScheme),
          if (widget.characterTargets.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildCharacterTarget(),
          ],
          if (widget.quickPresets.isNotEmpty) ...[
            const Divider(),
            _buildPresets(),
            const SizedBox(height: 12),
          ],
          _buildPreview(theme, colorScheme, notation, canSend),
        ],
      ),
    );
  }

  Widget _buildGroupRow(int index, ColorScheme colorScheme) {
    final group = _groups[index];
    final canRemove = _groups.length > 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              NumericInputField(
                fieldKey: ValueKey('dice-tray-count-$index'),
                value: group.count,
                label: '数量',
                onChanged: (value) => setState(() => group.count = value),
              ),
              const SizedBox(width: 8),
              NumericInputField(
                fieldKey: ValueKey('dice-tray-modifier-$index'),
                value: group.modifier,
                label: '加值',
                allowNegative: true,
                onChanged: (value) => setState(() => group.modifier = value),
              ),
              const Spacer(),
              IconButton(
                key: DiceTrayDialog.removeGroupKey(index),
                tooltip: '删除骰子组',
                onPressed: canRemove
                    ? () => setState(() => _groups.removeAt(index))
                    : null,
                icon: const Icon(Icons.delete_outline),
                color: colorScheme.error,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final sides in const [4, 6, 8, 10, 12, 20, 100])
                ChoiceChip(
                  key: ValueKey('dice-tray-sides-$sides'),
                  selected: group.sides == sides,
                  showCheckmark: false,
                  avatar: const Icon(Icons.casino_outlined, size: 18),
                  label: Text('d$sides'),
                  onSelected: (_) => setState(() => group.sides = sides),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRollModeSelector(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text('优劣势', style: theme.textTheme.labelLarge),
          const SizedBox(width: 12),
          Expanded(
            child: SegmentedButton<_RollMode>(
              segments: const [
                ButtonSegment(value: _RollMode.normal, label: Text('普通')),
                ButtonSegment(value: _RollMode.advantage, label: Text('优势')),
                ButtonSegment(value: _RollMode.disadvantage, label: Text('劣势')),
              ],
              selected: {_rollMode},
              onSelectionChanged: (selection) {
                setState(() => _rollMode = selection.single);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDcRow(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: NumericInputField(
        fieldKey: DiceTrayDialog.dcKey,
        value: _dcValue ?? 0,
        label: 'DC',
        allowEmpty: true,
        width: 96,
        onChanged: (value) => setState(() => _dcValue = value),
        onCleared: () => setState(() => _dcValue = null),
      ),
    );
  }

  Widget _buildCharacterTarget() {
    return DropdownButtonFormField<String?>(
      key: DiceTrayDialog.characterTargetKey,
      initialValue: _selectedCharacterId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: '代骰角色（可选）',
        prefixIcon: Icon(Icons.person_outline),
      ),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('不指定角色')),
        for (final character in widget.characterTargets)
          DropdownMenuItem<String?>(
            value: character.id,
            child: Text(
              character.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (value) => setState(() => _selectedCharacterId = value),
    );
  }

  Widget _buildPresets() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final preset in widget.quickPresets)
          FilledButton.tonalIcon(
            key: ValueKey('dice-tray-preset-$preset'),
            onPressed: () => _applyPreset(preset),
            icon: const Icon(Icons.casino_outlined),
            label: Text(preset),
          ),
      ],
    );
  }

  Widget _buildPreview(
    ThemeData theme,
    ColorScheme colorScheme,
    String notation,
    bool canSend,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '表达式预览',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            notation,
            style: AppTextStyles.diceNotation(theme.textTheme),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 4),
            Text(
              _errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            key: DiceTrayDialog.sendKey,
            onPressed: canSend ? _onSend : null,
            icon: const Icon(Icons.send),
            label: const Text('发送'),
          ),
        ],
      ),
    );
  }

  /// 合成完整表达式, 如 '2d20kh1+5 + 2d6+3'.
  String _buildNotation() {
    final parts = <String>[];
    for (final group in _groups) {
      var part = '${group.count}d${group.sides}';
      // 优劣势只对 d20 生效.
      if (_rollMode != _RollMode.normal && group.sides == 20) {
        part = '2d20${_rollMode == _RollMode.advantage ? 'kh1' : 'kl1'}';
      }
      if (group.modifier > 0) {
        part += '+${group.modifier}';
      } else if (group.modifier < 0) {
        part += '${group.modifier}';
      }
      parts.add(part);
    }
    return parts.join(' + ');
  }

  void _applyPreset(String notation) {
    final parsed = _parsePreset(notation);
    if (parsed == null) return;
    setState(() {
      _groups
        ..clear()
        ..addAll(parsed);
      _rollMode = _RollMode.normal;
    });
  }

  /// 解析预设字符串为骰子组列表. 支持形如 '1d20+5' / '8d6' / '2d20kh1+3'.
  /// 多组用 ' + ' (带空格) 分隔, 避免 '1d20+5' 被误拆. 返回 null 表示格式不可识别.
  List<_DiceGroup>? _parsePreset(String notation) {
    // 只在 ' + ' (前后有空格) 处分割, 保留 '1d20+5' 这样的修正符.
    final tokens = notation.split(RegExp(r'\s+\+\s+'));
    final groups = <_DiceGroup>[];
    for (final token in tokens) {
      final match = RegExp(
        r'^(\d+)d(\d+)(?:kh1|kl1)?([+-]\d+)?$',
      ).firstMatch(token);
      if (match == null) return null;
      final count = int.tryParse(match.group(1)!) ?? 1;
      final sides = int.tryParse(match.group(2)!) ?? 20;
      final modifierStr = match.group(3);
      final modifier = modifierStr == null
          ? 0
          : (int.tryParse(modifierStr) ?? 0);
      groups.add(_DiceGroup(count: count, sides: sides, modifier: modifier));
    }
    return groups.isEmpty ? null : groups;
  }

  void _onSend() {
    final notation = _buildNotation();
    try {
      final roll = widget.diceRoller.rollExpression(notation);
      final dc = _dcValue;
      final success = dc == null ? null : roll.total >= dc;
      widget.onSend(
        DiceTrayResult(
          notation: notation,
          total: roll.total,
          rollMode: _rollMode.name,
          dc: dc,
          success: success,
          characterId: _selectedCharacterId,
          characterName: widget.characterTargets
              .where((character) => character.id == _selectedCharacterId)
              .firstOrNull
              ?.name,
        ),
      );
      setState(() => _errorMessage = null);
    } on DiceRollException catch (error) {
      setState(() => _errorMessage = error.message);
    }
  }
}

enum _RollMode { normal, advantage, disadvantage }

class _DiceGroup {
  _DiceGroup({
    required this.count,
    required this.sides,
    required this.modifier,
  });

  factory _DiceGroup.defaults() => _DiceGroup(count: 1, sides: 20, modifier: 0);

  int count;
  int sides;
  int modifier;
}

/// 组合骰子编辑器发送结果.
class DiceTrayResult {
  const DiceTrayResult({
    required this.notation,
    required this.total,
    required this.rollMode,
    this.dc,
    this.success,
    this.characterId,
    this.characterName,
  });

  /// 完整表达式, 如 '2d20kh1+5 + 2d6+3'.
  final String notation;

  /// 掷骰总和.
  final int total;

  /// 'normal' | 'advantage' | 'disadvantage'.
  final String rollMode;

  /// 可选 DC. 若提供则 [success] 反映是否达标.
  final int? dc;

  /// 仅在 [dc] 提供时有值.
  final bool? success;

  final String? characterId;
  final String? characterName;
}
