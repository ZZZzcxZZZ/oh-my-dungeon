import 'dart:async';
import 'package:flutter/material.dart';

import '../../content/domain/content_entry.dart';
import '../../content/presentation/content_entry_preview_page.dart';
import '../../../core/dice/dice_roller.dart';
import '../../../core/presentation/avatar_image_provider.dart';
import '../domain/character.dart';
import '../domain/character_manual_overrides.dart';
import '../domain/character_override_resolver.dart';
import '../domain/character_profile.dart';
import '../domain/character_quick_edit_service.dart';
import '../domain/character_rule_overrides.dart';
import '../domain/declared_levels.dart';
import '../domain/rule_override_index.dart';
import '../domain/dnd5e_rules.dart';
import '../domain/weapon_attack_derivation.dart';
import '../../rules/domain/rule_field_path.dart';
import '../../rules/domain/rule_override_conflict.dart';
import '../../rules/domain/rule_override_declaration.dart';
import '../../rules/domain/rule_profile.dart';
import 'widgets/character_sheet_shell.dart';
import 'widgets/declared_level_banner.dart';
import 'widgets/rule_source_list.dart';
import '../../../core/presentation/dialog_sizes.dart';
import '../../../core/widgets/empty_state.dart';

part 'character_detail_header_nav.dart';
part 'character_detail_actions_panel.dart';
part 'character_detail_spells_panel.dart';
part 'character_detail_equipment_panel.dart';
part 'character_detail_features_panel.dart';
part 'character_detail_runtime_panel.dart';
part 'character_detail_resources_panel.dart';
part 'character_detail_dialogs.dart';
part 'character_detail_shared_widgets.dart';
typedef CharacterRuntimeUpdate =
    Future<void> Function({
      int? currentHp,
      int? temporaryHp,
      bool? inspiration,
      List<String>? conditions,
      int? deathSaveSuccesses,
      int? deathSaveFailures,
      Map<String, int>? spellSlotsUsed,
      Map<String, int>? classResourcesUsed,
    });

typedef CharacterInventoryUpdate =
    Future<void> Function({
      List<Map<String, Object>>? inventory,
      Map<String, int>? currency,
    });

typedef CharacterRollCallback = void Function(CharacterRollEvent event);
typedef CharacterSaveCallback = Future<bool> Function(CharacterSheet character);
typedef CharacterUpgradeCallback = Future<CharacterSheet?> Function(
  CharacterSheet character,
);
typedef CharacterRulesReapplyCallback =
    Future<CharacterSheet?> Function(CharacterSheet character);

class CharacterRollEvent {
  const CharacterRollEvent({
    required this.label,
    required this.notation,
    required this.total,
    required this.summary,
  });

  final String label;
  final String notation;
  final int total;
  final String summary;
}

/// Task 3.3 — 战役动作接收端抽象.
///
/// 角色卡内的检定/扣血/给予装备等动作通过此接口转发到战役聊天与 Character 同步.
/// `CharacterDetailPage` 在战役上下文中接收一个具体实现 (如 `CharacterRollSink`),
/// 在本地角色卡上下文中保持 null, 仅本地 SnackBar 反馈.
abstract class CampaignActionSink {
  /// 关联的 CampaignCharacter ID (如有). 用于在聊天消息中标记来源 Character.
  String? get campaignCharacterId;

  /// 派发一次检定结果到战役聊天.
  Future<void> dispatchRoll(CharacterRollEvent event);
}

class CharacterDetailPage extends StatefulWidget {
  const CharacterDetailPage({
    required this.character,
    this.onEdit,
    this.onUpdateRuntime,
    this.onUpdateInventory,
    this.onSaveCharacter,
    this.onUpgrade,
    this.contentEntries = const <ContentEntry>[],
    this.diceRoller,
    this.onRoll,
    this.sink,
    this.returnToChatAfterRoll = false,
    this.initialTab = 'overview',
    this.packagePriorities = const <String, int>{},
    this.packageNames = const <String, String>{},
    this.onReapplyRules,
    super.key,
  });

  final CharacterSheet character;
  final VoidCallback? onEdit;
  final CharacterRuntimeUpdate? onUpdateRuntime;
  final CharacterInventoryUpdate? onUpdateInventory;
  final CharacterSaveCallback? onSaveCharacter;
  final CharacterUpgradeCallback? onUpgrade;
  final List<ContentEntry> contentEntries;
  final DiceRoller? diceRoller;
  final CharacterRollCallback? onRoll;
  final CampaignActionSink? sink;
  final bool returnToChatAfterRoll;
  final String initialTab;

  /// 包 id → priority（来自 `ContentRepository.packagePriorities()`）：关闭覆盖 /
  /// 解决冲突后重新投影响使用与建档**同一份**优先级。
  final Map<String, int> packagePriorities;

  /// 包 id → 展示名，用于把来源 id 翻译成人类可读标签。
  final Map<String, String> packageNames;

  /// 重新派生规则快照（关闭覆盖 / 解决冲突后调用）。回调**接收当前角色**——
  /// 它刚被写过 `data.ruleOverrides`，捕获打开页面时的旧角色会丢掉这次选择。
  final CharacterRulesReapplyCallback? onReapplyRules;

  @override
  State<CharacterDetailPage> createState() => _CharacterDetailPageState();
}

class _CharacterDetailPageState extends State<CharacterDetailPage> {
  late CharacterSheet _character;

  @override
  void initState() {
    super.initState();
    _character = widget.character;
  }

  @override
  void didUpdateWidget(covariant CharacterDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.character != widget.character) _character = widget.character;
  }

  /// 来源 id → 展示名（**唯一实现**）：内置档案固定文案；条目 id 用
  /// "包名 · 条目名"；包 id → 包名（[ruleOriginLabel] 会在条目 id 查不到时退回）。
  Map<String, String> _originLabels() {
    final labels = <String, String>{kBuiltinOriginId: '内置档案'};
    for (final entry in widget.contentEntries) {
      final packageId = RuleOverrideDeclaration.packageIdOf(entry.id);
      final packageName = widget.packageNames[packageId];
      labels[entry.id] = packageName == null || packageName.isEmpty
          ? entry.name
          : '$packageName · ${entry.name}';
    }
    for (final entry in widget.packageNames.entries) {
      labels.putIfAbsent(entry.key, () => entry.value);
    }
    return labels;
  }

  /// 列级来源快照（`data.classRuleSources`），未派生时为空（不猜）。
  Map<String, RuleFieldSource> _ruleSources() =>
      RuleFieldSourceMap.fromData(_character.dataMap['classRuleSources']);

  /// 冲突快照（`data.classRuleConflicts`），坏数据降级为空表。
  List<RuleOverrideConflict> _ruleConflicts() =>
      RuleOverrideConflicts.fromData(_character.dataMap['classRuleConflicts']);

  /// 用户已关闭的覆盖来源（`data.ruleOverrides.disabledOriginIds`）：卡片据此渲染
  /// 「已关闭的来源」区并给出恢复入口（C）。读写只在 [CharacterRuleOverrides] 一处。
  Set<String> _disabledOverrideIds() =>
      CharacterRuleOverrides.fromCharacter(_character).disabledOriginIds;

  /// 角色**自己那条**职业条目的 originId（`data.classIdentity.entryId`）。来源是它
  /// 时不是"覆盖"（解析器无条件包含自身条目），因此不显示关闭按钮（C）。
  String? _entryOriginId() {
    final identity = _character.dataMap['classIdentity'];
    final entryId = identity is Map ? identity['entryId'] : null;
    return entryId is String && entryId.trim().isNotEmpty ? entryId : null;
  }

  /// 关闭某条覆盖并**重新派生**（唯一实现）：写 `data.ruleOverrides` → 通知上层
  /// 用 `CharacterRuleProjector` 重算 → 保存。UI 自己不算规则数值。
  Future<void> _disableOverride(String originId) async {
    final overrides = CharacterRuleOverrides.fromCharacter(_character);
    final data = Map<String, Object?>.from(_character.dataMap)
      ..['ruleOverrides'] = overrides.disable(originId).toData();
    setState(() => _character = _character.copyWith(data: data));
    await _reapplyAfterOverrideChange();
  }

  /// 恢复一条被关闭的来源（[CharacterRuleOverrides.enable] 的 UI 入口，C）：
  /// 与 [_disableOverride] 同一条"写 → 再派生 → 保存"链路。
  Future<void> _enableOverride(String originId) async {
    final overrides = CharacterRuleOverrides.fromCharacter(_character);
    final data = Map<String, Object?>.from(_character.dataMap)
      ..['ruleOverrides'] = overrides.enable(originId).toData();
    setState(() => _character = _character.copyWith(data: data));
    await _reapplyAfterOverrideChange();
  }

  /// 冲突选择的结果落库（`pinned`：列路径 → 用户选定的来源），然后重新派生。
  Future<void> _resolveConflicts(
    List<RuleOverrideConflict> conflicts,
  ) async {
    var overrides = CharacterRuleOverrides.fromCharacter(_character);
    for (final conflict in conflicts) {
      overrides = overrides.pin(conflict.field, conflict.effectiveOriginId);
    }
    final data = Map<String, Object?>.from(_character.dataMap)
      ..['ruleOverrides'] = overrides.toData();
    setState(() => _character = _character.copyWith(data: data));
    await _reapplyAfterOverrideChange();
  }

  Future<void> _reapplyAfterOverrideChange() async {
    final callback = widget.onReapplyRules;
    if (callback != null) {
      final reapplied = await callback(_character);
      if (reapplied != null && mounted) {
        setState(() => _character = reapplied);
      }
      return;
    }
    await widget.onSaveCharacter?.call(_character);
  }

  bool get _canEditOverrides =>
      widget.onReapplyRules != null || widget.onSaveCharacter != null;

  @override
  Widget build(BuildContext context) {
    // Task 3.3: 显式 onRoll 优先, 否则回退到 sink.dispatchRoll (Future<void> Function
    // 可赋值给 void Function). 本地角色卡 (sink == null) 退化为纯本地 SnackBar.
    final effectiveRoll =
        widget.onRoll ?? (widget.sink == null ? null : _dispatchCampaignRoll);
    final effectiveContentEntries = _characterContentEntries(
      _character,
      widget.contentEntries,
    );
    // 跨包职业规则声明索引（决策 D3）：与再派生（`CharacterRuleProjector`）用同一份
    // 输入构造，详情页里任何"临时解析一次"的行为路径都看得见勘误包（L）。
    final ruleOverrides = RuleOverrideIndex.fromEntries(
      effectiveContentEntries,
      widget.packagePriorities,
    );
    return CharacterSheetShell(
      title: _character.name,
      header: _CharacterHeader(character: _character),
      initialDestinationId: _initialDestinationId(widget.initialTab),
      actions: [
        if (widget.onUpgrade != null && _character.level < 20)
          IconButton(
            tooltip: '升级角色',
            onPressed: _upgrade,
            icon: const Icon(Icons.upgrade),
          ),
        if (widget.onEdit != null)
          IconButton(
            tooltip: '编辑角色',
            onPressed: widget.onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
      ],
      destinations: [
        CharacterSheetDestination(
          id: 'overview',
          label: '总览',
          icon: Icons.dashboard_outlined,
          child: _SheetTab(
            child: _RuntimePanel(
              character: _character,
              packagePriorities: widget.packagePriorities,
              ruleOverrides: ruleOverrides,
              onUpdateRuntime: widget.onUpdateRuntime == null
                  ? null
                  : _updateRuntime,
            ),
          ),
        ),
        if (_character.isNonPlayerCharacter)
          CharacterSheetDestination(
            id: 'character',
            label: '怪物资料',
            icon: Icons.menu_book_outlined,
            child: _SheetTab(
              child: _CharacterReferencePanel(character: _character),
            ),
          ),
        CharacterSheetDestination(
          id: 'abilities',
          label: '属性',
          icon: Icons.tune_outlined,
          child: _SheetTab(
            child: _AbilityOverview(
              character: _character,
              diceRoller: widget.diceRoller,
              onRoll: effectiveRoll,
            ),
          ),
        ),
        CharacterSheetDestination(
          id: 'actions',
          label: '动作',
          icon: Icons.bolt_outlined,
          child: _SheetTab(
            child: _ActionsPanel(
              character: _character,
              contentEntries: effectiveContentEntries,
              packagePriorities: widget.packagePriorities,
              ruleOverrides: ruleOverrides,
              diceRoller: widget.diceRoller,
              onRoll: effectiveRoll,
              onSaveCharacter: widget.onSaveCharacter == null
                  ? null
                  : _saveCharacter,
            ),
          ),
        ),
        CharacterSheetDestination(
          id: 'spells',
          label: '法术',
          icon: Icons.auto_fix_high_outlined,
          child: _SheetTab(
            child: _SpellsPanel(
              character: _character,
              contentEntries: effectiveContentEntries,
              onUpdateRuntime: widget.onUpdateRuntime == null
                  ? null
                  : _updateRuntime,
              onSaveCharacter: widget.onSaveCharacter == null
                  ? null
                  : _saveCharacter,
              packagePriorities: widget.packagePriorities,
              ruleOverrides: ruleOverrides,
              sources: _ruleSources(),
              conflicts: _ruleConflicts(),
              originLabels: _originLabels(),
              entryOriginId: _entryOriginId(),
              onDisableOverride: _canEditOverrides ? _disableOverride : null,
              onResolveConflicts: _canEditOverrides ? _resolveConflicts : null,
            ),
          ),
        ),
        CharacterSheetDestination(
          id: 'equipment',
          label: '装备',
          icon: Icons.backpack_outlined,
          child: _SheetTab(
            child: _EquipmentPanel(
              character: _character,
              contentEntries: effectiveContentEntries,
              onUpdateInventory: widget.onUpdateInventory,
            ),
          ),
        ),
        CharacterSheetDestination(
          id: 'resources',
          label: '资源',
          icon: Icons.battery_charging_full_outlined,
          child: _SheetTab(
            child: _ResourcesPanel(
              character: _character,
              onUpdateRuntime: widget.onUpdateRuntime == null
                  ? null
                  : _updateRuntime,
              onSaveCharacter: widget.onSaveCharacter == null
                  ? null
                  : _saveCharacter,
              sources: _ruleSources(),
              conflicts: _ruleConflicts(),
              originLabels: _originLabels(),
              entryOriginId: _entryOriginId(),
              onDisableOverride: _canEditOverrides ? _disableOverride : null,
              onResolveConflicts: _canEditOverrides ? _resolveConflicts : null,
            ),
          ),
        ),
        CharacterSheetDestination(
          id: 'features',
          label: '特性',
          icon: Icons.workspace_premium_outlined,
          child: _SheetTab(
            child: _FeaturesPanel(
              character: _character,
              contentEntries: effectiveContentEntries,
              onSaveCharacter: widget.onSaveCharacter == null
                  ? null
                  : _saveCharacter,
            ),
          ),
        ),
        CharacterSheetDestination(
          id: 'profile',
          label: '角色资料',
          icon: Icons.notes_outlined,
          child: _SheetTab(
            child: _ProfilePanel(
              character: _character,
              onSaveCharacter: widget.onSaveCharacter == null
                  ? null
                  : _saveCharacter,
              sources: _ruleSources(),
              originLabels: _originLabels(),
              entryOriginId: _entryOriginId(),
              disabledOriginIds: _disabledOverrideIds(),
              resourceNames: {
                for (final resource in _character.classResources)
                  resource.id: resource.name,
              },
              onDisableOverride: _canEditOverrides ? _disableOverride : null,
              onEnableOverride: _canEditOverrides ? _enableOverride : null,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _dispatchCampaignRoll(CharacterRollEvent event) async {
    await widget.sink!.dispatchRoll(event);
    if (widget.returnToChatAfterRoll && mounted) {
      await Navigator.of(context).maybePop();
    }
  }

  static String _initialDestinationId(String tab) {
    return switch (tab) {
      'abilities' || 'attributes' => 'abilities',
      'actions' => 'actions',
      'spells' => 'spells',
      'equipment' => 'equipment',
      'resources' => 'resources',
      'features' => 'features',
      'character' => 'character',
      'profile' || 'details' || 'notes' => 'profile',
      _ => 'overview',
    };
  }

  Future<void> _updateRuntime({
    int? currentHp,
    int? temporaryHp,
    bool? inspiration,
    List<String>? conditions,
    int? deathSaveSuccesses,
    int? deathSaveFailures,
    Map<String, int>? spellSlotsUsed,
    Map<String, int>? classResourcesUsed,
  }) async {
    final runtime = Map<String, Object?>.from(_character.runtimeMap);
    if (temporaryHp != null) runtime['temporaryHp'] = temporaryHp;
    if (inspiration != null) runtime['inspiration'] = inspiration;
    if (conditions != null) runtime['conditions'] = conditions;
    if (spellSlotsUsed != null) runtime['spellSlotsUsed'] = spellSlotsUsed;
    if (classResourcesUsed != null) {
      runtime['classResourcesUsed'] = classResourcesUsed;
    }
    if (deathSaveSuccesses != null || deathSaveFailures != null) {
      final deathSaves = Map<String, Object?>.from(
        runtime['deathSaves'] is Map
            ? Map<String, Object?>.from(runtime['deathSaves']! as Map)
            : const <String, Object?>{},
      );
      if (deathSaveSuccesses != null) {
        deathSaves['successes'] = deathSaveSuccesses;
      }
      if (deathSaveFailures != null) deathSaves['failures'] = deathSaveFailures;
      runtime['deathSaves'] = deathSaves;
    }
    final data = Map<String, Object?>.from(_character.dataMap)
      ..['runtime'] = runtime;
    final updated = _character.copyWith(currentHp: currentHp, data: data);
    if (mounted) setState(() => _character = updated);
    await widget.onUpdateRuntime?.call(
      currentHp: currentHp,
      temporaryHp: temporaryHp,
      inspiration: inspiration,
      conditions: conditions,
      deathSaveSuccesses: deathSaveSuccesses,
      deathSaveFailures: deathSaveFailures,
      spellSlotsUsed: spellSlotsUsed,
      classResourcesUsed: classResourcesUsed,
    );
  }

  Future<bool> _saveCharacter(CharacterSheet character) async {
    final callback = widget.onSaveCharacter;
    if (callback == null) return false;
    final success = await callback(character);
    if (!mounted) return success;
    if (success) {
      setState(() => _character = character);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存失败，请稍后重试')));
    }
    return success;
  }

  /// 打开升级页。**必须把当前角色传上去**（A）：`onUpgrade` 若捕获打开详情页时的
  /// 旧快照，用户在详情页刚做出的选择（关闭来源 / pin 某列，写在
  /// `data.ruleOverrides`）会在升级再派生时被静默还原——升级走的是角色数据里的
  /// `data.ruleOverrides`，不是闭包捕获的那份。
  Future<void> _upgrade() async {
    final upgraded = await widget.onUpgrade?.call(_character);
    if (mounted && upgraded != null) setState(() => _character = upgraded);
  }
}
