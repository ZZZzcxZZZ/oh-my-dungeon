import 'package:flutter/material.dart';

import '../../../characters/domain/character.dart';
import 'campaign_actor_controller.dart';

/// 把本地角色卡发布为 CampaignActor 的对话框。
/// 玩家模式可见；调用 [CampaignActorController.publishCharacter] 提交到战役。
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
    final success = await widget.controller.publishCharacter(
      widget.character,
      actorType: _actorType,
    );
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
