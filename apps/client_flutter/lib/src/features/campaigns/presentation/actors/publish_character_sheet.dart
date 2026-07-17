import 'package:flutter/material.dart';

import '../../../characters/domain/character.dart';
import 'campaign_actor_controller.dart';

/// 把本地角色卡发布为 CampaignActor 的对话框。
/// 玩家模式可见；调用 [CampaignActorController.publishCharacter] 提交到战役。
///
/// Spec §头像来源: 战役角色头像由本地角色绑定战役后自动上传。本对话框不再
/// 暴露手动头像选择入口；角色卡已有的 `avatarUrl`（data URL 或 http(s) URL）
/// 随 sheet 一并提交到服务端，无需用户干预。头像维护入口在角色创建/编辑页。
class PublishCharacterSheet extends StatefulWidget {
  const PublishCharacterSheet({
    required this.controller,
    required this.character,
    super.key,
  });

  final CampaignActorController controller;
  final CharacterSheet character;

  @override
  State<PublishCharacterSheet> createState() => _PublishCharacterSheetState();
}

class _PublishCharacterSheetState extends State<PublishCharacterSheet> {
  String _actorType = 'player';
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
            Text(
              '将“${widget.character.name}”发布为战役角色，DM 可在战役中查看和编辑。',
            ),
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
                Chip(label: Text('HP ${widget.character.currentHp}/${widget.character.maxHp}')),
                Chip(label: Text('AC ${widget.character.armorClass}')),
              ],
            ),
            const SizedBox(height: 16),
            Text('角色类型', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  label: const Text('玩家角色'),
                  selected: _actorType == 'player',
                  onSelected: (_) => setState(() => _actorType = 'player'),
                ),
                ChoiceChip(
                  label: const Text('NPC'),
                  selected: _actorType == 'npc',
                  onSelected: (_) => setState(() => _actorType = 'npc'),
                ),
                ChoiceChip(
                  label: const Text('怪物'),
                  selected: _actorType == 'monster',
                  onSelected: (_) => setState(() => _actorType = 'monster'),
                ),
                ChoiceChip(
                  label: const Text('同伴'),
                  selected: _actorType == 'companion',
                  onSelected: (_) => setState(() => _actorType = 'companion'),
                ),
              ],
            ),
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
    // 玩家角色走 /actors/publish 自发布端点；NPC / 怪物 / 同伴走 /actors
    // DM 创建端点（lifecycle=persistent）。两个端点权限和数据约束不同，
    // 不能混用：服务端会拒绝 player 类型走 createActor，也拒绝非 player
    // 类型走 publishActor。
    final bool success;
    if (_actorType == 'player') {
      success = await widget.controller.publishCharacter(
        widget.character,
        actorType: _actorType,
        sheetOverride: sheet,
      );
    } else {
      success = await widget.controller.createDmActor(
        actorType: _actorType,
        sheet: sheet,
      );
    }
    if (!mounted) return;
    setState(() => _submitting = false);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已发布到战役')),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.controller.error ?? '发布失败')),
      );
    }
  }
}
