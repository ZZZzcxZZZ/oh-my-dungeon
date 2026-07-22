import 'package:flutter/material.dart';

import '../../domain/campaign_actor.dart';
import '../widgets/campaign_avatar.dart';

typedef CreateCampaignActor =
    Future<String?> Function({
      required String actorType,
      required String displayName,
      required String lifecycle,
      int? maxHp,
    });

typedef CampaignActorAction =
    Future<String?> Function({required CampaignActor actor});

typedef BatchCampaignActorAction =
    Future<String?> Function({required List<String> actorIds});

class CampaignCharactersPanel extends StatefulWidget {
  const CampaignCharactersPanel({
    required this.actors,
    required this.isManager,
    required this.onOpenActor,
    this.onCreateActor,
    this.onConvertToPersistent,
    this.onArchiveActor,
    this.onBatchArchive,
    this.onSetActiveSpeaker,
    this.activeSpeakerActorId,
    super.key,
  });

  final List<CampaignActor> actors;
  final bool isManager;
  final ValueChanged<CampaignActor> onOpenActor;
  final CreateCampaignActor? onCreateActor;
  final CampaignActorAction? onConvertToPersistent;
  final CampaignActorAction? onArchiveActor;
  final BatchCampaignActorAction? onBatchArchive;
  final CampaignActorAction? onSetActiveSpeaker;
  final String? activeSpeakerActorId;

  @override
  State<CampaignCharactersPanel> createState() =>
      _CampaignCharactersPanelState();
}

class _CampaignCharactersPanelState extends State<CampaignCharactersPanel> {
  bool _selecting = false;
  bool _archivedExpanded = false;
  final Set<String> _selectedIds = {};

  @override
  Widget build(BuildContext context) {
    final sections = <(String, String, List<CampaignActor>)>[
      ('player', '玩家角色', _actorsFor('player')),
      ('npc', 'NPC 与其他角色', _actorsFor('npc')),
      ('temporary', '临时角色', _actorsFor('temporary')),
      ('archived', '已归档', _actorsFor('archived')),
    ].where((section) => section.$3.isNotEmpty).toList(growable: false);

    return KeyedSubtree(
      key: widget.key ?? const Key('campaign-characters-panel'),
      child: ListView(
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
              for (final actor in section.$3) _buildActorRow(context, actor),
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
          if (widget.onCreateActor != null)
            FilledButton.tonalIcon(
              key: const Key('characters-create-actor-button'),
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

  Widget _buildActorRow(BuildContext context, CampaignActor actor) {
    final name = actor.sheet['name']?.toString().trim();
    final displayName = name?.isNotEmpty == true ? name! : '未命名角色';
    final selectable = actor.status != 'archived';
    final selected = _selectedIds.contains(actor.id);
    final active = actor.id == widget.activeSpeakerActorId;
    return ListTile(
      key: Key('actor-row-${actor.id}'),
      onTap: _selecting && selectable
          ? () => _toggleSelection(actor.id)
          : () => widget.onOpenActor(actor),
      leading: _selecting && selectable
          ? Checkbox(
              value: selected,
              onChanged: (_) => _toggleSelection(actor.id),
            )
          : CampaignAvatar(
              initials: displayName,
              imageUrl: actor.sheet['avatarUrl'] as String?,
              health: CampaignAvatar.healthFromHp(
                actor.sheet['currentHp'] as num?,
                actor.sheet['maxHp'] as num?,
              ),
              healthFraction: CampaignAvatar.fractionFromHp(
                actor.sheet['currentHp'] as num?,
                actor.sheet['maxHp'] as num?,
              ),
              size: 40,
            ),
      title: Text(displayName),
      subtitle: Text(_actorSubtitle(actor, active: active)),
      trailing: _selecting
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (active) const Icon(Icons.record_voice_over, size: 18),
                if (widget.isManager && actor.status != 'archived')
                  _ActorMenu(
                    actor: actor,
                    canSetActive: widget.onSetActiveSpeaker != null && !active,
                    canConvert:
                        widget.onConvertToPersistent != null &&
                        actor.lifecycle == 'temporary',
                    canArchive: widget.onArchiveActor != null,
                    onSelected: (action) => _runActorAction(actor, action),
                  )
                else
                  const Icon(Icons.chevron_right),
              ],
            ),
    );
  }

  List<CampaignActor> _actorsFor(String section) {
    final result = widget.actors
        .where((actor) {
          if (section == 'archived') return actor.status == 'archived';
          if (actor.status == 'archived') return false;
          if (section == 'temporary') return actor.lifecycle == 'temporary';
          if (actor.lifecycle == 'temporary') return false;
          if (section == 'player') return actor.actorType == 'player';
          return actor.actorType != 'player';
        })
        .toList(growable: false);
    result.sort((left, right) {
      final leftName = left.sheet['name']?.toString() ?? '';
      final rightName = right.sheet['name']?.toString() ?? '';
      return leftName.compareTo(rightName);
    });
    return result;
  }

  String _actorSubtitle(CampaignActor actor, {required bool active}) {
    final parts = <String>[_actorTypeLabel(actor.actorType)];
    if (actor.lifecycle == 'temporary') parts.add('临时');
    if (actor.status == 'archived') parts.add('已归档');
    if (active) parts.add('当前发言身份');
    return parts.join(' · ');
  }

  void _toggleSelection(String actorId) {
    setState(() {
      if (!_selectedIds.add(actorId)) _selectedIds.remove(actorId);
    });
  }

  Future<void> _runActorAction(
    CampaignActor actor,
    _ActorMenuAction action,
  ) async {
    final callback = switch (action) {
      _ActorMenuAction.setActive => widget.onSetActiveSpeaker,
      _ActorMenuAction.convert => widget.onConvertToPersistent,
      _ActorMenuAction.archive => widget.onArchiveActor,
    };
    if (callback == null) return;
    final error = await callback(actor: actor);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? _successMessage(action))));
  }

  Future<void> _archiveSelected() async {
    final callback = widget.onBatchArchive;
    if (callback == null || _selectedIds.isEmpty) return;
    final ids = _selectedIds.toList(growable: false);
    final error = await callback(actorIds: ids);
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
    final callback = widget.onCreateActor;
    if (callback == null) return;
    final draft = await showDialog<_ActorDraft>(
      context: context,
      builder: (context) => const _CreateActorDialog(),
    );
    if (draft == null || !mounted) return;
    final error = await callback(
      actorType: draft.actorType,
      displayName: draft.displayName,
      lifecycle: draft.lifecycle,
      maxHp: draft.maxHp,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? '角色已创建')));
  }

  String _successMessage(_ActorMenuAction action) => switch (action) {
    _ActorMenuAction.setActive => '已切换发言身份',
    _ActorMenuAction.convert => '已转为常驻角色',
    _ActorMenuAction.archive => '角色已归档',
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

enum _ActorMenuAction { setActive, convert, archive }

class _ActorMenu extends StatelessWidget {
  const _ActorMenu({
    required this.actor,
    required this.canSetActive,
    required this.canConvert,
    required this.canArchive,
    required this.onSelected,
  });

  final CampaignActor actor;
  final bool canSetActive;
  final bool canConvert;
  final bool canArchive;
  final ValueChanged<_ActorMenuAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ActorMenuAction>(
      tooltip: '角色操作',
      onSelected: onSelected,
      itemBuilder: (context) => [
        if (canSetActive)
          const PopupMenuItem(
            value: _ActorMenuAction.setActive,
            child: ListTile(
              leading: Icon(Icons.record_voice_over_outlined),
              title: Text('设为发言身份'),
            ),
          ),
        if (canConvert)
          const PopupMenuItem(
            value: _ActorMenuAction.convert,
            child: ListTile(
              leading: Icon(Icons.push_pin_outlined),
              title: Text('转为常驻角色'),
            ),
          ),
        if (canArchive)
          const PopupMenuItem(
            value: _ActorMenuAction.archive,
            child: ListTile(
              leading: Icon(Icons.archive_outlined),
              title: Text('归档'),
            ),
          ),
      ],
    );
  }
}

class _ActorDraft {
  const _ActorDraft({
    required this.actorType,
    required this.displayName,
    required this.lifecycle,
    required this.maxHp,
  });

  final String actorType;
  final String displayName;
  final String lifecycle;
  final int? maxHp;
}

class _CreateActorDialog extends StatefulWidget {
  const _CreateActorDialog();

  @override
  State<_CreateActorDialog> createState() => _CreateActorDialogState();
}

class _CreateActorDialogState extends State<_CreateActorDialog> {
  final _nameController = TextEditingController();
  final _hpController = TextEditingController();
  String _actorType = 'npc';
  bool _temporary = false;

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
              selected: {_actorType},
              onSelectionChanged: (value) =>
                  setState(() => _actorType = value.single),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _hpController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '最大生命值（可选）'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('临时角色'),
              value: _temporary,
              onChanged: (value) => setState(() => _temporary = value),
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
              _ActorDraft(
                actorType: _actorType,
                displayName: name,
                lifecycle: _temporary ? 'temporary' : 'persistent',
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

String _actorTypeLabel(String actorType) => switch (actorType) {
  'player' => '玩家角色',
  'npc' => 'NPC',
  'monster' => '怪物',
  'companion' => '同伴',
  _ => '其他角色',
};
