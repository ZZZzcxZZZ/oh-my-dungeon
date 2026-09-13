import 'package:flutter/material.dart';

import '../../../characters/domain/character.dart';
import '../../../characters/presentation/character_detail_page.dart';
import '../../../content/data/local/content_repository.dart';
import '../../../content/domain/content_entry.dart';
import '../../data/sync/campaign_sync_api_client.dart';
import '../../domain/campaign_character.dart';
import 'campaign_character_controller.dart';
import '../../../../core/widgets/empty_state.dart';

bool canEditCampaignCharacter({
  required CampaignCharacter character,
  required String currentUserId,
  required bool canEditAnyCharacter,
}) {
  return canEditAnyCharacter || character.ownerUserId == currentUserId;
}

CharacterSheet campaignCharacterToCharacterSheet(CampaignCharacter character) {
  final name = character.sheet['name']?.toString().trim();
  final level = _positiveInt(character.sheet['level'], fallback: 1);
  final seed = CharacterSheet.local(
    id: character.id,
    name: name == null || name.isEmpty ? '未命名角色' : name,
    level: level,
  );
  final json = <String, Object?>{
    ...seed.toJson(),
    ...character.sheet,
    'id': character.id,
    'ownerUserId': character.ownerUserId ?? 'campaign',
    'name': name == null || name.isEmpty ? '未命名角色' : name,
    'system': character.sheet['system'] is String
        ? character.sheet['system']
        : 'dnd5e-2024',
    'level': level,
    'classSummary': character.sheet['classSummary']?.toString() ?? '',
    'raceSummary': character.sheet['raceSummary']?.toString() ?? '',
    'currentHp': _intValue(character.sheet['currentHp']),
    'maxHp': _intValue(character.sheet['maxHp']),
    'armorClass': _intValue(character.sheet['armorClass'], fallback: 10),
    'speed': _intValue(character.sheet['speed'], fallback: 30),
    'initiativeBonus': _intValue(character.sheet['initiativeBonus']),
    'notes': character.sheet['notes']?.toString() ?? '',
    'createdAt': character.sheet['createdAt']?.toString().isNotEmpty == true
        ? character.sheet['createdAt']
        : character.createdAt,
    'updatedAt': character.sheet['updatedAt']?.toString().isNotEmpty == true
        ? character.sheet['updatedAt']
        : character.updatedAt,
  };
  return CharacterSheet.fromJson(json);
}

Future<void> openCampaignCharacterSheet({
  required BuildContext context,
  required CampaignCharacterController controller,
  required CampaignCharacter character,
  required bool canEditAnyCharacter,
  ContentRepository? contentRepository,
  CampaignActionSink? sink,
  bool returnToChatAfterRoll = false,
}) async {
  final canEdit = canEditCampaignCharacter(
    character: character,
    currentUserId: controller.currentUserId,
    canEditAnyCharacter: canEditAnyCharacter,
  );
  // 条目与包 priority **一起**加载（同一处 loader）：campaign 视图里的
  // `RuleOverrideIndex` 也要用与本地建档同一份 tier，否则 priority 40 的勘误
  // 压不过自身条目（决策 D2 / 任务 9）。
  final content = await _loadContent(contentRepository);
  if (!context.mounted) return;

  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (context) => CampaignCharacterFullSheetPage(
        controller: controller,
        characterId: character.id,
        canEdit: canEdit,
        contentEntries: content.entries,
        packagePriorities: content.packagePriorities,
        sink: sink,
        returnToChatAfterRoll: returnToChatAfterRoll,
      ),
    ),
  );
}

class CampaignCharacterFullSheetPage extends StatefulWidget {
  const CampaignCharacterFullSheetPage({
    required this.controller,
    required this.characterId,
    required this.canEdit,
    required this.contentEntries,
    this.packagePriorities = const <String, int>{},
    this.sink,
    this.returnToChatAfterRoll = false,
    super.key,
  });

  final CampaignCharacterController controller;
  final String characterId;
  final bool canEdit;
  final List<ContentEntry> contentEntries;

  /// 包 id → priority（决策 D2）：campaign 角色卡的规则解析必须与本地建档
  /// **同一份** tier，否则勘误 / 覆盖在 campaign 视图里失效。
  final Map<String, int> packagePriorities;
  final CampaignActionSink? sink;
  final bool returnToChatAfterRoll;

  @override
  State<CampaignCharacterFullSheetPage> createState() =>
      _CampaignCharacterFullSheetPageState();
}

class _CampaignCharacterFullSheetPageState
    extends State<CampaignCharacterFullSheetPage> {
  bool _conflictDialogOpen = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
    final conflict = widget.controller.conflict;
    if (conflict != null && !_conflictDialogOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_conflictDialogOpen) _showConflictDialog(conflict);
      });
    }
  }

  Future<void> _showConflictDialog(CampaignConflictException conflict) async {
    _conflictDialogOpen = true;
    final current = conflict.current;
    final sheet = _objectMap(current['sheet']);
    final name = sheet['name']?.toString() ?? '此角色';
    final currentHp = _intValue(sheet['currentHp']);
    final maxHp = _intValue(sheet['maxHp']);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        key: const Key('character-conflict-dialog'),
        title: const Text('版本冲突'),
        content: Text('$name 已被其他主持人修改。\n服务器当前 HP $currentHp/$maxHp'),
        actions: [
          TextButton(
            onPressed: () {
              widget.controller.clearConflict();
              Navigator.of(dialogContext).pop();
            },
            child: const Text('保留本地'),
          ),
          FilledButton(
            onPressed: () {
              widget.controller.clearConflict();
              Navigator.of(dialogContext).pop();
              widget.controller.pullUntilCurrent();
            },
            child: const Text('重新加载'),
          ),
        ],
      ),
    );
    _conflictDialogOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    final campaignCharacter = _latestCharacter(
      widget.controller,
      widget.characterId,
    );
    if (campaignCharacter == null) {
      return const Scaffold(
        body: EmptyState(icon: Icons.person_off_outlined, title: '角色已不存在'),
      );
    }
    final character = campaignCharacterToCharacterSheet(campaignCharacter);
    return CharacterDetailPage(
      key: const Key('campaign-character-full-sheet'),
      character: character,
      contentEntries: widget.contentEntries,
      packagePriorities: widget.packagePriorities,
      sink: widget.sink,
      returnToChatAfterRoll: widget.returnToChatAfterRoll,
      onUpdateRuntime: widget.canEdit
          ? ({
              currentHp,
              temporaryHp,
              inspiration,
              conditions,
              deathSaveSuccesses,
              deathSaveFailures,
              spellSlotsUsed,
              classResourcesUsed,
            }) => _updateRuntime(
              controller: widget.controller,
              characterId: widget.characterId,
              currentHp: currentHp,
              temporaryHp: temporaryHp,
              inspiration: inspiration,
              conditions: conditions,
              deathSaveSuccesses: deathSaveSuccesses,
              deathSaveFailures: deathSaveFailures,
              spellSlotsUsed: spellSlotsUsed,
              classResourcesUsed: classResourcesUsed,
            )
          : null,
      onUpdateInventory: widget.canEdit
          ? ({inventory, currency}) => _updateInventory(
              controller: widget.controller,
              characterId: widget.characterId,
              inventory: inventory,
              currency: currency,
            )
          : null,
      onSaveCharacter: widget.canEdit
          ? (character) => _saveCharacter(
              controller: widget.controller,
              characterId: widget.characterId,
              character: character,
            )
          : null,
    );
  }
}

/// 一次加载 campaign 角色卡需要的**全部**内容侧输入：条目与包 priority。
///
/// **唯一 loader**：条目与 priority 必须成对加载（调用方不许各自再查一次），否则
/// 两处会读到不一致的 tier（决策 D2）。
Future<({List<ContentEntry> entries, Map<String, int> packagePriorities})>
_loadContent(ContentRepository? repository) async {
  if (repository == null) {
    return (
      entries: const <ContentEntry>[],
      packagePriorities: const <String, int>{},
    );
  }
  try {
    return (
      entries: await repository.search(const ContentQuery()),
      packagePriorities: await repository.packagePriorities(),
    );
  } catch (_) {
    return (
      entries: const <ContentEntry>[],
      packagePriorities: const <String, int>{},
    );
  }
}

CampaignCharacter? _latestCharacter(
  CampaignCharacterController controller,
  String characterId,
) {
  for (final character in controller.characters) {
    if (character.id == characterId) return character;
  }
  return null;
}

Future<bool> _saveCharacter({
  required CampaignCharacterController controller,
  required String characterId,
  required CharacterSheet character,
}) async {
  final campaignCharacter = _latestCharacter(controller, characterId);
  if (campaignCharacter == null) return false;
  return controller.updateCharacter(campaignCharacter, <String, Object?>{
    ...campaignCharacter.sheet,
    ...character.toJson(),
  });
}

Future<void> _updateRuntime({
  required CampaignCharacterController controller,
  required String characterId,
  int? currentHp,
  int? temporaryHp,
  bool? inspiration,
  List<String>? conditions,
  int? deathSaveSuccesses,
  int? deathSaveFailures,
  Map<String, int>? spellSlotsUsed,
  Map<String, int>? classResourcesUsed,
}) async {
  final campaignCharacter = _latestCharacter(controller, characterId);
  if (campaignCharacter == null) return;
  final character = campaignCharacterToCharacterSheet(campaignCharacter);
  final runtime = Map<String, Object?>.from(character.runtimeMap);
  if (temporaryHp != null) runtime['temporaryHp'] = temporaryHp;
  if (inspiration != null) runtime['inspiration'] = inspiration;
  if (conditions != null) runtime['conditions'] = conditions;
  if (spellSlotsUsed != null) runtime['spellSlotsUsed'] = spellSlotsUsed;
  if (classResourcesUsed != null) {
    runtime['classResourcesUsed'] = classResourcesUsed;
  }
  if (deathSaveSuccesses != null || deathSaveFailures != null) {
    runtime['deathSaves'] = <String, Object?>{
      ..._objectMap(runtime['deathSaves']),
      'successes': ?deathSaveSuccesses,
      'failures': ?deathSaveFailures,
    };
  }
  final data = <String, Object?>{...character.dataMap, 'runtime': runtime};
  await _saveCharacter(
    controller: controller,
    characterId: characterId,
    character: character.copyWith(currentHp: currentHp, data: data),
  );
}

Future<void> _updateInventory({
  required CampaignCharacterController controller,
  required String characterId,
  List<Map<String, Object>>? inventory,
  Map<String, int>? currency,
}) async {
  final campaignCharacter = _latestCharacter(controller, characterId);
  if (campaignCharacter == null) return;
  final character = campaignCharacterToCharacterSheet(campaignCharacter);
  await _saveCharacter(
    controller: controller,
    characterId: characterId,
    character: character.copyWith(inventory: inventory, currency: currency),
  );
}

Map<String, Object?> _objectMap(Object? value) =>
    value is Map ? Map<String, Object?>.from(value) : const <String, Object?>{};

int _positiveInt(Object? value, {required int fallback}) {
  final parsed = _intValue(value, fallback: fallback);
  return parsed > 0 ? parsed : fallback;
}

int _intValue(Object? value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? fallback;
}
