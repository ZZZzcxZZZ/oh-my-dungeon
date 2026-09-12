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
import '../domain/declared_levels.dart';
import '../domain/dnd5e_rules.dart';
import '../domain/weapon_attack_derivation.dart';
import 'widgets/character_sheet_shell.dart';
import 'widgets/declared_level_banner.dart';
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
typedef CharacterUpgradeCallback = Future<CharacterSheet?> Function();

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

  Future<void> _upgrade() async {
    final upgraded = await widget.onUpgrade?.call();
    if (mounted && upgraded != null) setState(() => _character = upgraded);
  }
}
