import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../characters/domain/character.dart';
import '../widgets/avatar_picker.dart';
import 'campaign_actor_controller.dart';

/// 把本地角色卡发布为 CampaignActor 的对话框。
/// 玩家模式可见；调用 [CampaignActorController.publishCharacter] 提交到战役。
///
/// 图片选择调用通过 [onPickImage] 注入，便于测试时替换为内存 fake，无需触及
/// file_picker 原生插件。
class PublishCharacterSheet extends StatefulWidget {
  const PublishCharacterSheet({
    required this.controller,
    required this.character,
    required this.onPickImage,
    super.key,
  });

  final CampaignActorController controller;
  final CharacterSheet character;

  /// 选择图片的回调。返回 `(bytes, mimeType)` 或 `null`（用户取消）。
  final Future<({Uint8List bytes, String mimeType})?> Function() onPickImage;

  @override
  State<PublishCharacterSheet> createState() => _PublishCharacterSheetState();
}

class _PublishCharacterSheetState extends State<PublishCharacterSheet> {
  String _actorType = 'player';
  bool _submitting = false;
  bool _picking = false;
  String? _pickError;
  Uint8List? _avatarBytes;
  String? _avatarMimeType;

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
            AvatarPicker(
              currentAvatarUrl: widget.character.avatarUrl,
              previewBytes: _avatarBytes,
              isUploading: _picking,
              error: _pickError,
              onPick: _pickImage,
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

  Future<void> _pickImage() async {
    setState(() {
      _picking = true;
      _pickError = null;
    });
    try {
      final result = await widget.onPickImage();
      if (!mounted) return;
      if (result == null) {
        setState(() => _picking = false);
        return;
      }
      if (result.bytes.length > 2 * 1024 * 1024) {
        setState(() {
          _picking = false;
          _pickError = '头像图片不能超过 2 MB';
        });
        return;
      }
      setState(() {
        _avatarBytes = result.bytes;
        _avatarMimeType = result.mimeType;
        _picking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _picking = false;
        _pickError = '选择图片失败';
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final sheet = Map<String, Object?>.from(widget.character.toJson());
    final bytes = _avatarBytes;
    final mimeType = _avatarMimeType;
    if (bytes != null && mimeType != null) {
      sheet['avatarUrl'] = 'data:$mimeType;base64,${base64Encode(bytes)}';
    } else {
      // 没有选择头像时显式移除 null 占位，避免污染服务端字段。
      sheet.remove('avatarUrl');
    }
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
