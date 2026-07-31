import 'package:flutter/material.dart';

import '../../../characters/domain/character.dart';
import '../../data/sync/campaign_sync_api_client.dart';
import '../../domain/campaign_character.dart';
import 'campaign_character_controller.dart';

/// 把本地角色卡发布为 CampaignCharacter 的对话框。
/// 玩家模式可见；调用 [CampaignCharacterController.publishCharacter] 提交到战役。
///
/// Spec §头像来源: 战役角色头像由本地角色绑定战役后自动上传。本对话框不再
/// 暴露手动头像选择入口；角色卡已有的 `avatarUrl`（data URL 或 http(s) URL）
/// 随 sheet 一并提交到服务端，无需用户干预。头像维护入口在角色创建/编辑页。
class PublishCharacterSheet extends StatefulWidget {
  const PublishCharacterSheet({
    required this.controller,
    required this.character,
    this.allowDmCharacterTypes = false,
    this.onPublished,
    super.key,
  });

  final CampaignCharacterController controller;
  final CharacterSheet character;
  final bool allowDmCharacterTypes;
  final Future<void> Function(CampaignCharacter character)? onPublished;

  @override
  State<PublishCharacterSheet> createState() => _PublishCharacterSheetState();
}

class _PublishCharacterSheetState extends State<PublishCharacterSheet> {
  String _characterType = 'player';
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('publish-character-sheet'),
      title: const Text('发布到战役'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('将“${widget.character.name}”发布为战役角色，DM 可在战役中查看和编辑。'),
            const SizedBox(height: 12),
            Text('角色概要', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Chip(label: Text('Lv.${widget.character.level}')),
                if (widget.character.classSummary.isNotEmpty)
                  Chip(label: Text(widget.character.classSummary)),
                if (widget.character.raceSummary.isNotEmpty)
                  Chip(label: Text(widget.character.raceSummary)),
                Chip(
                  label: Text(
                    'HP ${widget.character.currentHp}/${widget.character.maxHp}',
                  ),
                ),
                Chip(label: Text('AC ${widget.character.armorClass}')),
              ],
            ),
            if (widget.allowDmCharacterTypes) ...[
              const SizedBox(height: 16),
              Text('角色类型', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    label: const Text('玩家角色'),
                    selected: _characterType == 'player',
                    onSelected: (_) =>
                        setState(() => _characterType = 'player'),
                  ),
                  ChoiceChip(
                    label: const Text('NPC'),
                    selected: _characterType == 'npc',
                    onSelected: (_) => setState(() => _characterType = 'npc'),
                  ),
                  ChoiceChip(
                    label: const Text('怪物'),
                    selected: _characterType == 'monster',
                    onSelected: (_) =>
                        setState(() => _characterType = 'monster'),
                  ),
                  ChoiceChip(
                    label: const Text('同伴'),
                    selected: _characterType == 'companion',
                    onSelected: (_) =>
                        setState(() => _characterType = 'companion'),
                  ),
                ],
              ),
            ],
            if (widget.controller.selectedCampaignId == null) ...[
              const SizedBox(height: 12),
              Text(
                '尚未选择战役。请先在战役页加入或创建战役。',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: const Text('发布'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    // Spec §头像来源: 本地角色头像随发布自动上传。直接使用角色卡上的
    // avatarUrl（data URL 或 http(s) URL），无需用户在发布对话框手动选择。
    final sheet = widget.character.toJson();
    // 玩家角色走 /characters/publish 自发布端点；NPC / 怪物 / 同伴走 /characters
    // DM 创建端点（lifecycle=persistent）。两个端点权限和数据约束不同，
    // 不能混用：服务端会拒绝 player 类型走 createCharacter，也拒绝非 player
    // 类型走 publishCharacter。
    final bool success;
    if (_characterType == 'player') {
      success = await widget.controller.publishCharacter(
        widget.character,
        characterType: _characterType,
        sheetOverride: sheet,
      );
    } else {
      success = await widget.controller.createDmCharacter(
        characterType: _characterType,
        sheet: sheet,
      );
    }
    if (!mounted) return;
    setState(() => _submitting = false);
    if (success) {
      if (_characterType == 'player' && widget.onPublished != null) {
        final published = _publishedPlayerCharacter();
        if (published != null) {
          await widget.onPublished!(published);
          if (!mounted) return;
        }
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已发布到战役')));
      Navigator.of(context).pop();
      return;
    }
    // Spec §双向同步 切片 A: 409 冲突时显示对比对话框，提供"用本地覆盖"
    // （用服务端最新 revision 重试）和"用远端覆盖"（pull 后关闭）。
    final conflict = widget.controller.conflict;
    if (conflict != null && _characterType == 'player') {
      await _showConflictDialog(conflict, sheet);
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(widget.controller.error ?? '发布失败')));
  }

  CampaignCharacter? _publishedPlayerCharacter() {
    for (final character in widget.controller.characters) {
      if (character.sourceCharacterId == widget.character.id &&
          character.characterType == 'player') {
        return character;
      }
    }
    return null;
  }

  Future<void> _showConflictDialog(
    CampaignConflictException conflict,
    Map<String, Object?> sheet,
  ) async {
    final controller = widget.controller;
    final remoteRevision = conflict.current['revision'];
    final remoteRevisionInt = remoteRevision is num
        ? remoteRevision.toInt()
        : null;
    final remoteSheet = conflict.current['sheet'] is Map
        ? Map<String, Object?>.from(conflict.current['sheet'] as Map)
        : <String, Object?>{};
    final remoteName = remoteSheet['name']?.toString() ?? widget.character.name;
    final remoteHp = _asInt(remoteSheet['currentHp']);
    final remoteMaxHp = _asInt(remoteSheet['maxHp']);

    final action = await showDialog<_ConflictAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        key: const Key('publish-conflict-dialog'),
        title: const Text('版本冲突'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$remoteName 已被其他端修改。'),
              const SizedBox(height: 12),
              const Text('服务器最新版本：'),
              const SizedBox(height: 4),
              Text('当前 HP $remoteHp/$remoteMaxHp'),
              if (remoteRevisionInt != null) ...[
                const SizedBox(height: 4),
                Text('版本号 $remoteRevisionInt'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_ConflictAction.cancel),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_ConflictAction.pullRemote),
            child: const Text('用远端覆盖'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_ConflictAction.overrideLocal),
            child: const Text('用本地覆盖'),
          ),
        ],
      ),
    );

    if (action == null || action == _ConflictAction.cancel) return;
    if (!mounted) return;

    if (action == _ConflictAction.pullRemote) {
      await controller.pullUntilCurrent();
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }

    // overrideLocal: 用服务端最新 revision 重试发布。
    setState(() => _submitting = true);
    final retrySuccess = await controller.publishCharacter(
      widget.character,
      characterType: _characterType,
      sheetOverride: sheet,
      baseRevisionOverride: remoteRevisionInt,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (retrySuccess) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已用本地版本覆盖远端')));
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(controller.error ?? '覆盖失败，请重试')));
    }
  }

  int _asInt(Object? value) {
    if (value is num) return value.toInt();
    return 0;
  }
}

enum _ConflictAction { cancel, pullRemote, overrideLocal }
