import 'package:flutter/material.dart';

import '../../domain/campaign_character.dart';
import '../widgets/campaign_avatar.dart';

typedef CreateCampaignCharacter =
    Future<String?> Function({
      required String characterType,
      required String displayName,
      required String lifecycle,
      int? maxHp,
    });

typedef CampaignCharacterAction =
    Future<String?> Function({required CampaignCharacter character});

typedef CampaignCharacterVisibilityAction =
    Future<String?> Function({
      required CampaignCharacter character,
      required bool visibleToPlayers,
    });

typedef BatchCampaignCharacterAction =
    Future<String?> Function({required List<String> characterIds});

class CampaignCharactersPanel extends StatefulWidget {
  const CampaignCharactersPanel({
    required this.characters,
    required this.isManager,
    required this.onOpenCharacter,
    this.onCreateCharacter,
    this.onArchiveCharacter,
    this.onRestoreCharacter,
    this.onBatchArchive,
    this.onSetActiveSpeaker,
    this.onSetVisibility,
    this.activeSpeakerCharacterId,
    this.embedded = false,
    this.archivedInitiallyExpanded = false,
    super.key,
  });

  final List<CampaignCharacter> characters;
  final bool isManager;
  final ValueChanged<CampaignCharacter> onOpenCharacter;
  final CreateCampaignCharacter? onCreateCharacter;
  final CampaignCharacterAction? onArchiveCharacter;
  final CampaignCharacterAction? onRestoreCharacter;
  final BatchCampaignCharacterAction? onBatchArchive;
  final CampaignCharacterAction? onSetActiveSpeaker;
  final CampaignCharacterVisibilityAction? onSetVisibility;
  final String? activeSpeakerCharacterId;
  final bool embedded;
  final bool archivedInitiallyExpanded;

  @override
  State<CampaignCharactersPanel> createState() =>
      _CampaignCharactersPanelState();
}

class _CampaignCharactersPanelState extends State<CampaignCharactersPanel> {
  bool _selecting = false;
  late bool _archivedExpanded = widget.archivedInitiallyExpanded;
  final Set<String> _selectedIds = {};

  @override
  void didUpdateWidget(covariant CampaignCharactersPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.archivedInitiallyExpanded &&
        widget.archivedInitiallyExpanded) {
      _archivedExpanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sections = <(String, String, List<CampaignCharacter>)>[
      ('player', '玩家角色', _charactersFor('player')),
      ('npc', '常驻 NPC', _charactersFor('npc')),
      ('archived', '归档角色', _charactersFor('archived')),
    ].where((section) => section.$3.isNotEmpty).toList(growable: false);

    return KeyedSubtree(
      key: widget.key ?? const Key('campaign-characters-panel'),
      child: ListView(
        shrinkWrap: widget.embedded,
        physics: widget.embedded ? const NeverScrollableScrollPhysics() : null,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          if (widget.isManager) _buildToolbar(context),
          if (sections.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: Text('战役中还没有角色')),
            ),
          for (final section in sections) ...[
            _SectionHeader(
              key: section.$1 == 'archived'
                  ? const Key('archived-section-toggle')
                  : null,
              label: section.$2,
              count: section.$3.length,
              expanded: section.$1 == 'archived' ? _archivedExpanded : null,
              onTap: section.$1 == 'archived'
                  ? () => setState(() => _archivedExpanded = !_archivedExpanded)
                  : null,
            ),
            if (section.$1 != 'archived' || _archivedExpanded)
              for (final character in section.$3)
                _buildCharacterRow(context, character),
          ],
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          if (widget.onCreateCharacter != null)
            FilledButton.tonalIcon(
              key: const Key('characters-create-character-button'),
              onPressed: _showCreateDialog,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('新建角色'),
            ),
          const Spacer(),
          if (_selecting && _selectedIds.isNotEmpty)
            IconButton.filledTonal(
              key: const Key('characters-batch-archive-button'),
              tooltip: '归档所选角色',
              onPressed: _archiveSelected,
              icon: const Icon(Icons.archive_outlined),
            ),
          IconButton(
            key: const Key('characters-select-toggle'),
            tooltip: _selecting ? '退出选择' : '批量管理',
            onPressed: widget.onBatchArchive == null
                ? null
                : () => setState(() {
                    _selecting = !_selecting;
                    if (!_selecting) _selectedIds.clear();
                  }),
            icon: Icon(_selecting ? Icons.close : Icons.checklist_outlined),
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterRow(BuildContext context, CampaignCharacter character) {
    final name = character.sheet['name']?.toString().trim();
    final displayName = name?.isNotEmpty == true ? name! : '未命名角色';
    final selectable = character.status != 'archived';
    final selected = _selectedIds.contains(character.id);
    final active = character.id == widget.activeSpeakerCharacterId;
    return ListTile(
      key: Key('character-row-${character.id}'),
      onTap: _selecting && selectable
          ? () => _toggleSelection(character.id)
          : () => widget.onOpenCharacter(character),
      leading: _selecting && selectable
          ? Checkbox(
              value: selected,
              onChanged: (_) => _toggleSelection(character.id),
            )
          : CampaignAvatar(
              initials: displayName,
              imageUrl: character.sheet['avatarUrl'] as String?,
              health: CampaignAvatar.healthFromHp(
                character.sheet['currentHp'] as num?,
                character.sheet['maxHp'] as num?,
              ),
              healthFraction: CampaignAvatar.fractionFromHp(
                character.sheet['currentHp'] as num?,
                character.sheet['maxHp'] as num?,
              ),
              size: 40,
            ),
      title: Text(displayName),
      subtitle: Text(_characterSubtitle(character, active: active)),
      trailing: _selecting
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (active) const Icon(Icons.record_voice_over, size: 18),
                if (widget.isManager)
                  _CharacterMenu(
                    character: character,
                    canSetActive: widget.onSetActiveSpeaker != null && !active,
                    canArchive:
                        widget.onArchiveCharacter != null &&
                        character.status != 'archived',
                    canRestore:
                        widget.onRestoreCharacter != null &&
                        character.status == 'archived',
                    canSetVisibility:
                        widget.onSetVisibility != null &&
                        character.characterType != 'player',
                    onSelected: (action) =>
                        _runCharacterAction(character, action),
                  )
                else
                  const Icon(Icons.chevron_right),
              ],
            ),
    );
  }

  List<CampaignCharacter> _charactersFor(String section) {
    final result = widget.characters
        .where((character) {
          if (section == 'archived') return character.status == 'archived';
          if (character.status == 'archived') return false;
          // 临时角色已废弃（改用 speakerSnapshot），遗留数据不展示。
          if (character.lifecycle == 'temporary') return false;
          if (section == 'player') return character.characterType == 'player';
          return character.characterType != 'player';
        })
        .toList(growable: false);
    result.sort((left, right) {
      final leftName = left.sheet['name']?.toString() ?? '';
      final rightName = right.sheet['name']?.toString() ?? '';
      return leftName.compareTo(rightName);
    });
    return result;
  }

  String _characterSubtitle(
    CampaignCharacter character, {
    required bool active,
  }) {
    final parts = <String>[_characterTypeLabel(character.characterType)];
    if (character.characterType != 'player') {
      parts.add(character.visibleToPlayers ? '玩家可见' : '未公开');
    }
    if (character.status == 'archived') parts.add('已归档');
    if (active) parts.add('当前发言身份');
    return parts.join(' · ');
  }

  void _toggleSelection(String characterId) {
    setState(() {
      if (!_selectedIds.add(characterId)) _selectedIds.remove(characterId);
    });
  }

  Future<void> _runCharacterAction(
    CampaignCharacter character,
    _CharacterMenuAction action,
  ) async {
    if (action == _CharacterMenuAction.reveal ||
        action == _CharacterMenuAction.hide) {
      final callback = widget.onSetVisibility;
      if (callback == null) return;
      final error = await callback(
        character: character,
        visibleToPlayers: action == _CharacterMenuAction.reveal,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error ?? _successMessage(action))));
      return;
    }
    final callback = switch (action) {
      _CharacterMenuAction.setActive => widget.onSetActiveSpeaker,
      _CharacterMenuAction.archive => widget.onArchiveCharacter,
      _CharacterMenuAction.restore => widget.onRestoreCharacter,
      _CharacterMenuAction.reveal || _CharacterMenuAction.hide => null,
    };
    if (callback == null) return;
    final error = await callback(character: character);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? _successMessage(action))));
  }

  Future<void> _archiveSelected() async {
    final callback = widget.onBatchArchive;
    if (callback == null || _selectedIds.isEmpty) return;
    final ids = _selectedIds.toList(growable: false);
    final error = await callback(characterIds: ids);
    if (!mounted) return;
    if (error == null) {
      setState(() {
        _selectedIds.clear();
        _selecting = false;
      });
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? '已归档 ${ids.length} 个角色')));
  }

  Future<void> _showCreateDialog() async {
    final callback = widget.onCreateCharacter;
    if (callback == null) return;
    final draft = await showDialog<_CharacterDraft>(
      context: context,
      builder: (context) => const _CreateCharacterDialog(),
    );
    if (draft == null || !mounted) return;
    final error = await callback(
      characterType: draft.characterType,
      displayName: draft.displayName,
      lifecycle: draft.lifecycle,
      maxHp: draft.maxHp,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? '角色已创建')));
  }

  String _successMessage(_CharacterMenuAction action) => switch (action) {
    _CharacterMenuAction.setActive => '已切换发言身份',
    _CharacterMenuAction.archive => '角色已归档',
    _CharacterMenuAction.restore => '角色已恢复',
    _CharacterMenuAction.reveal => '已对玩家公开',
    _CharacterMenuAction.hide => '已对玩家隐藏',
  };
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    required this.count,
    this.expanded,
    this.onTap,
    super.key,
  });

  final String label;
  final int count;
  final bool? expanded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      expanded: expanded,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
          child: Row(
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$count',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (expanded != null)
                AnimatedRotation(
                  turns: expanded! ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: const Icon(Icons.expand_more, size: 20),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _CharacterMenuAction { setActive, reveal, hide, archive, restore }

class _CharacterMenu extends StatelessWidget {
  const _CharacterMenu({
    required this.character,
    required this.canSetActive,
    required this.canArchive,
    required this.canRestore,
    required this.canSetVisibility,
    required this.onSelected,
  });

  final CampaignCharacter character;
  final bool canSetActive;
  final bool canArchive;
  final bool canRestore;
  final bool canSetVisibility;
  final ValueChanged<_CharacterMenuAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_CharacterMenuAction>(
      tooltip: '角色操作',
      onSelected: onSelected,
      itemBuilder: (context) => [
        if (canSetActive)
          const PopupMenuItem(
            value: _CharacterMenuAction.setActive,
            child: ListTile(
              leading: Icon(Icons.record_voice_over_outlined),
              title: Text('设为发言身份'),
            ),
          ),
        if (canSetVisibility)
          PopupMenuItem(
            value: character.visibleToPlayers
                ? _CharacterMenuAction.hide
                : _CharacterMenuAction.reveal,
            child: ListTile(
              leading: Icon(
                character.visibleToPlayers
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              title: Text(character.visibleToPlayers ? '对玩家隐藏' : '公开给玩家'),
            ),
          ),
        if (canArchive)
          const PopupMenuItem(
            value: _CharacterMenuAction.archive,
            child: ListTile(
              leading: Icon(Icons.archive_outlined),
              title: Text('归档'),
            ),
          ),
        if (canRestore)
          const PopupMenuItem(
            value: _CharacterMenuAction.restore,
            child: ListTile(
              leading: Icon(Icons.unarchive_outlined),
              title: Text('恢复'),
            ),
          ),
      ],
    );
  }
}

class _CharacterDraft {
  const _CharacterDraft({
    required this.characterType,
    required this.displayName,
    required this.lifecycle,
    required this.maxHp,
  });

  final String characterType;
  final String displayName;
  final String lifecycle;
  final int? maxHp;
}

class _CreateCharacterDialog extends StatefulWidget {
  const _CreateCharacterDialog();

  @override
  State<_CreateCharacterDialog> createState() => _CreateCharacterDialogState();
}

class _CreateCharacterDialogState extends State<_CreateCharacterDialog> {
  final _nameController = TextEditingController();
  final _hpController = TextEditingController();
  String _characterType = 'npc';

  @override
  void dispose() {
    _nameController.dispose();
    _hpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('创建常驻角色'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: '名称'),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'npc', label: Text('NPC')),
                ButtonSegment(value: 'monster', label: Text('怪物')),
                ButtonSegment(value: 'companion', label: Text('同伴')),
              ],
              selected: {_characterType},
              onSelectionChanged: (value) =>
                  setState(() => _characterType = value.single),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _hpController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '最大生命值（可选）'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;
            Navigator.of(context).pop(
              _CharacterDraft(
                characterType: _characterType,
                displayName: name,
                lifecycle: 'persistent',
                maxHp: int.tryParse(_hpController.text.trim()),
              ),
            );
          },
          child: const Text('创建'),
        ),
      ],
    );
  }
}

String _characterTypeLabel(String characterType) => switch (characterType) {
  'player' => '玩家角色',
  'npc' => 'NPC',
  'monster' => '怪物',
  'companion' => '同伴',
  _ => '其他角色',
};
