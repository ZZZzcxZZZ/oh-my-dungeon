import 'package:flutter/material.dart';

import '../../../characters/domain/character.dart';
import '../../../characters/presentation/character_detail_page.dart';
import '../../../content/data/local/content_repository.dart';
import '../../../content/domain/content_entry.dart';
import '../../data/sync/campaign_sync_api_client.dart';
import '../../domain/campaign_actor.dart';
import 'campaign_actor_controller.dart';

bool canEditCampaignActor({
  required CampaignActor actor,
  required String currentUserId,
  required bool canEditAnyActor,
}) {
  return canEditAnyActor || actor.ownerUserId == currentUserId;
}

CharacterSheet campaignActorToCharacterSheet(CampaignActor actor) {
  final name = actor.sheet['name']?.toString().trim();
  final level = _positiveInt(actor.sheet['level'], fallback: 1);
  final seed = CharacterSheet.local(
    id: actor.id,
    name: name == null || name.isEmpty ? '未命名角色' : name,
    level: level,
  );
  final json = <String, Object?>{
    ...seed.toJson(),
    ...actor.sheet,
    'id': actor.id,
    'ownerUserId': actor.ownerUserId ?? 'campaign',
    'name': name == null || name.isEmpty ? '未命名角色' : name,
    'system': actor.sheet['system'] is String
        ? actor.sheet['system']
        : 'dnd5e-2024',
    'level': level,
    'classSummary': actor.sheet['classSummary']?.toString() ?? '',
    'raceSummary': actor.sheet['raceSummary']?.toString() ?? '',
    'currentHp': _intValue(actor.sheet['currentHp']),
    'maxHp': _intValue(actor.sheet['maxHp']),
    'armorClass': _intValue(actor.sheet['armorClass'], fallback: 10),
    'speed': _intValue(actor.sheet['speed'], fallback: 30),
    'initiativeBonus': _intValue(actor.sheet['initiativeBonus']),
    'notes': actor.sheet['notes']?.toString() ?? '',
    'createdAt': actor.sheet['createdAt']?.toString().isNotEmpty == true
        ? actor.sheet['createdAt']
        : actor.createdAt,
    'updatedAt': actor.sheet['updatedAt']?.toString().isNotEmpty == true
        ? actor.sheet['updatedAt']
        : actor.updatedAt,
  };
  return CharacterSheet.fromJson(json);
}

Future<void> openCampaignActorSheet({
  required BuildContext context,
  required CampaignActorController controller,
  required CampaignActor actor,
  required bool canEditAnyActor,
  ContentRepository? contentRepository,
}) async {
  final canEdit = canEditCampaignActor(
    actor: actor,
    currentUserId: controller.currentUserId,
    canEditAnyActor: canEditAnyActor,
  );
  final contentEntries = await _loadContentEntries(contentRepository);
  if (!context.mounted) return;

  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (context) => CampaignActorFullSheetPage(
        controller: controller,
        actorId: actor.id,
        canEdit: canEdit,
        contentEntries: contentEntries,
      ),
    ),
  );
}

class CampaignActorFullSheetPage extends StatefulWidget {
  const CampaignActorFullSheetPage({
    required this.controller,
    required this.actorId,
    required this.canEdit,
    required this.contentEntries,
    super.key,
  });

  final CampaignActorController controller;
  final String actorId;
  final bool canEdit;
  final List<ContentEntry> contentEntries;

  @override
  State<CampaignActorFullSheetPage> createState() =>
      _CampaignActorFullSheetPageState();
}

class _CampaignActorFullSheetPageState
    extends State<CampaignActorFullSheetPage> {
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
        key: const Key('actor-conflict-dialog'),
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
    final actor = _latestActor(widget.controller, widget.actorId);
    if (actor == null) {
      return const Scaffold(body: Center(child: Text('角色已不存在')));
    }
    final character = campaignActorToCharacterSheet(actor);
    return CharacterDetailPage(
      key: const Key('campaign-actor-full-sheet'),
      character: character,
      contentEntries: widget.contentEntries,
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
              actorId: widget.actorId,
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
              actorId: widget.actorId,
              inventory: inventory,
              currency: currency,
            )
          : null,
      onSaveCharacter: widget.canEdit
          ? (character) => _saveCharacter(
              controller: widget.controller,
              actorId: widget.actorId,
              character: character,
            )
          : null,
    );
  }
}

Future<List<ContentEntry>> _loadContentEntries(
  ContentRepository? repository,
) async {
  if (repository == null) return const [];
  try {
    return await repository.search(const ContentQuery());
  } catch (_) {
    return const [];
  }
}

CampaignActor? _latestActor(
  CampaignActorController controller,
  String actorId,
) {
  for (final actor in controller.actors) {
    if (actor.id == actorId) return actor;
  }
  return null;
}

Future<bool> _saveCharacter({
  required CampaignActorController controller,
  required String actorId,
  required CharacterSheet character,
}) async {
  final actor = _latestActor(controller, actorId);
  if (actor == null) return false;
  return controller.updateActor(actor, <String, Object?>{
    ...actor.sheet,
    ...character.toJson(),
  });
}

Future<void> _updateRuntime({
  required CampaignActorController controller,
  required String actorId,
  int? currentHp,
  int? temporaryHp,
  bool? inspiration,
  List<String>? conditions,
  int? deathSaveSuccesses,
  int? deathSaveFailures,
  Map<String, int>? spellSlotsUsed,
  Map<String, int>? classResourcesUsed,
}) async {
  final actor = _latestActor(controller, actorId);
  if (actor == null) return;
  final character = campaignActorToCharacterSheet(actor);
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
    actorId: actorId,
    character: character.copyWith(currentHp: currentHp, data: data),
  );
}

Future<void> _updateInventory({
  required CampaignActorController controller,
  required String actorId,
  List<Map<String, Object>>? inventory,
  Map<String, int>? currency,
}) async {
  final actor = _latestActor(controller, actorId);
  if (actor == null) return;
  final character = campaignActorToCharacterSheet(actor);
  await _saveCharacter(
    controller: controller,
    actorId: actorId,
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
