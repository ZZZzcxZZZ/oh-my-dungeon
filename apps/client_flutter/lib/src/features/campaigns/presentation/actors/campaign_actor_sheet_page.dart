import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../data/sync/campaign_sync_api_client.dart';
import '../../domain/campaign_actor.dart';
import 'campaign_actor_controller.dart';

/// 战役角色详情页。DM 可编辑 HP/AC/速度/状态/备注等字段；每次成功更新都会
/// 通过 [CampaignActorController] 提交到服务器并写回本地缓存。
class CampaignActorSheetPage extends StatefulWidget {
  const CampaignActorSheetPage({
    required this.controller,
    required this.actorId,
    super.key,
  });

  final CampaignActorController controller;
  final String actorId;

  @override
  State<CampaignActorSheetPage> createState() => _CampaignActorSheetPageState();
}

class _CampaignActorSheetPageState extends State<CampaignActorSheetPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.loadActorAudits(widget.actorId);
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
    final conflict = widget.controller.conflict;
    if (conflict != null && _conflictDialogOpen == false) {
      _showConflictDialog(conflict);
    }
  }

  bool _conflictDialogOpen = false;

  Future<void> _showConflictDialog(CampaignConflictException conflict) async {
    _conflictDialogOpen = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _ActorConflictDialog(
          conflict: conflict,
          onReload: () {
            widget.controller.clearConflict();
            Navigator.of(dialogContext).pop();
            widget.controller.pullUntilCurrent();
          },
          onKeepLocal: () {
            widget.controller.clearConflict();
            Navigator.of(dialogContext).pop();
          },
        );
      },
    );
    _conflictDialogOpen = false;
  }

  CampaignActor? get _actor {
    return widget.controller.actors
        .where((actor) => actor.id == widget.actorId)
        .firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final actor = _actor;
    if (actor == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('角色')),
        body: const Center(child: Text('角色已不存在')),
      );
    }
    final sheet = Map<String, Object?>.from(actor.sheet);
    return Scaffold(
      key: const Key('campaign-actor-sheet'),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 180,
            title: Text(sheet['name']?.toString() ?? '(未命名)'),
            actions: [
              IconButton(
                tooltip: '归档',
                icon: const Icon(Icons.archive_outlined),
                onPressed: () => _confirmArchive(actor),
              ),
            ],
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              _buildSummaryCard(context, actor, sheet),
              _buildRuntimeSection(context, sheet),
              _buildRuleLedgerSection(context, sheet),
              _buildHpSection(context, actor, sheet),
              _buildBuildFields(context, actor, sheet),
              _buildNotesSection(context, actor, sheet),
              _buildAuditSection(context, actor),
              const SizedBox(height: 32),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    CampaignActor actor,
    Map<String, Object?> sheet,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentHp = _asInt(sheet['currentHp']);
    final maxHp = _asInt(sheet['maxHp']);
    final armorClass = _asInt(sheet['armorClass']);
    final speed = _asInt(sheet['speed']);
    return Card(
      margin: const EdgeInsets.all(16),
      color: colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '生命值 $currentHp/$maxHp',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  key: const Key('campaign-actor-avatar-picker'),
                  tooltip: '更换头像',
                  icon: const Icon(Icons.add_a_photo_outlined),
                  onPressed: actor.status == 'archived'
                      ? null
                      : () => _pickAvatar(actor, sheet),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (armorClass > 0) Chip(label: Text('AC $armorClass')),
                if (speed > 0) Chip(label: Text('速度 $speed')),
                Chip(label: Text('版本 ${actor.revision}')),
                if (actor.status == 'archived')
                  Chip(
                    label: Text(
                      '已归档',
                      style: TextStyle(color: colorScheme.error),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHpSection(
    BuildContext context,
    CampaignActor actor,
    Map<String, Object?> sheet,
  ) {
    final currentHp = _asInt(sheet['currentHp']);
    final maxHp = _asInt(sheet['maxHp']);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('生命值', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                tooltip: '受到 1 点伤害',
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: actor.status == 'archived'
                    ? null
                    : () => _updateHp(actor, sheet, currentHp - 1),
              ),
              Text('当前 HP $currentHp/$maxHp'),
              IconButton(
                tooltip: '恢复 1 点 HP',
                icon: const Icon(Icons.add_circle_outline),
                onPressed: actor.status == 'archived'
                    ? null
                    : () => _updateHp(actor, sheet, currentHp + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRuntimeSection(
    BuildContext context,
    Map<String, Object?> sheet,
  ) {
    final data = _asMap(sheet['data']);
    final runtime = _asMap(data['runtime']);
    final conditions = (runtime['conditions'] as List<Object?>? ?? const [])
        .map((condition) => condition.toString())
        .where((condition) => condition.isNotEmpty)
        .toList(growable: false);
    final resources = _asMap(runtime['classResourcesUsed']);
    final temporaryHp = _asInt(runtime['temporaryHp']);
    return _SheetSection(
      title: '运行时状态',
      icon: Icons.monitor_heart_outlined,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          Chip(label: Text('临时 HP $temporaryHp')),
          if (runtime['inspiration'] == true) const Chip(label: Text('有灵感')),
          for (final condition in conditions)
            Chip(
              avatar: const Icon(Icons.warning_amber_outlined, size: 18),
              label: Text(condition),
            ),
          for (final resource in resources.entries)
            Chip(label: Text('${resource.key} 已用 ${resource.value}')),
          if (conditions.isEmpty && resources.isEmpty && temporaryHp == 0)
            Text(
              '当前没有额外状态',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
        ],
      ),
    );
  }

  Widget _buildRuleLedgerSection(
    BuildContext context,
    Map<String, Object?> sheet,
  ) {
    final data = _asMap(sheet['data']);
    final grants = (data['resolvedGrants'] as List<Object?>? ?? const [])
        .whereType<Map>()
        .map((grant) => Map<String, Object?>.from(grant))
        .toList(growable: false);
    return _SheetSection(
      title: '规则账本',
      icon: Icons.account_tree_outlined,
      child: grants.isEmpty
          ? Text(
              '该 Actor 还没有规则授予快照',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            )
          : Column(
              children: [
                for (final grant in grants)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.auto_awesome_outlined),
                    title: Text(
                      grant['label']?.toString() ??
                          grant['id']?.toString() ??
                          '未命名授予',
                    ),
                    subtitle: Text(_grantSource(grant)),
                  ),
              ],
            ),
    );
  }

  Widget _buildAuditSection(BuildContext context, CampaignActor actor) {
    final loading = widget.controller.isLoadingAudits(actor.id);
    final error = widget.controller.auditErrorFor(actor.id);
    final audits = widget.controller.auditsFor(actor.id).reversed.toList();
    return _SheetSection(
      title: '编辑历史',
      icon: Icons.history_outlined,
      trailing: IconButton(
        tooltip: '刷新编辑历史',
        onPressed: loading
            ? null
            : () => widget.controller.loadActorAudits(actor.id),
        icon: const Icon(Icons.refresh),
      ),
      child: loading && audits.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            )
          : audits.isEmpty
          ? Text(
              '暂无编辑记录',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            )
          : Column(
              children: [
                for (final audit in audits)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.manage_history_outlined),
                    title: Text(
                      '版本 ${audit.baseRevision} → ${audit.resultRevision}',
                    ),
                    subtitle: Text(
                      '${audit.changedPaths.join(', ')}\n操作人 ${audit.actorUserId}',
                    ),
                    isThreeLine: true,
                  ),
              ],
            ),
    );
  }

  String _grantSource(Map<String, Object?> grant) {
    final parts = <String>[
      if (grant['kind'] != null) grant['kind'].toString(),
      if (grant['entryId'] != null) '来源 ${grant['entryId']}',
      if (grant['sourceLevel'] != null) '等级 ${grant['sourceLevel']}',
    ];
    return parts.isEmpty ? '无来源信息' : parts.join(' · ');
  }

  Map<String, Object?> _asMap(Object? value) => value is Map
      ? Map<String, Object?>.from(value)
      : const <String, Object?>{};

  Widget _buildBuildFields(
    BuildContext context,
    CampaignActor actor,
    Map<String, Object?> sheet,
  ) {
    final abilities = sheet['abilities'];
    final armorClass = _asInt(sheet['armorClass']);
    final speed = _asInt(sheet['speed']);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('构建字段', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (abilities is Map) ...[
            Text('属性', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final entry in abilities.entries)
                  Chip(label: Text('${entry.key} ${entry.value}')),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.shield_outlined),
                  label: Text('AC $armorClass'),
                  onPressed: actor.status == 'archived'
                      ? null
                      : () => _editNumericField(
                          actor,
                          sheet,
                          'armorClass',
                          'AC',
                          armorClass,
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.directions_run),
                  label: Text('速度 $speed'),
                  onPressed: actor.status == 'archived'
                      ? null
                      : () => _editNumericField(
                          actor,
                          sheet,
                          'speed',
                          '速度',
                          speed,
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection(
    BuildContext context,
    CampaignActor actor,
    Map<String, Object?> sheet,
  ) {
    final notes = sheet['notes']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('备注', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: TextEditingController(text: notes)
              ..selection = TextSelection.fromPosition(
                TextPosition(offset: notes.length),
              ),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'DM 备注，仅战役主持人可见',
            ),
            maxLines: 4,
            onSubmitted: (value) => _updateField(actor, sheet, 'notes', value),
          ),
        ],
      ),
    );
  }

  Future<void> _updateHp(
    CampaignActor actor,
    Map<String, Object?> sheet,
    int newHp,
  ) async {
    final updated = Map<String, Object?>.from(sheet);
    updated['currentHp'] = newHp;
    await widget.controller.updateActor(actor, updated);
  }

  Future<void> _pickAvatar(
    CampaignActor actor,
    Map<String, Object?> sheet,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      withData: true,
    );
    final file = result?.files.singleOrNull;
    final bytes = file?.bytes;
    if (bytes == null || bytes.isEmpty || !mounted) return;
    if (bytes.length > 2 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('头像图片不能超过 2 MB')),
      );
      return;
    }
    final extension = (file?.extension ?? 'png').toLowerCase();
    final mimeType = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      _ => 'image/png',
    };
    final updated = Map<String, Object?>.from(sheet);
    updated['avatarUrl'] = 'data:$mimeType;base64,${base64Encode(bytes)}';
    await widget.controller.updateActor(actor, updated);
  }

  Future<void> _updateField(
    CampaignActor actor,
    Map<String, Object?> sheet,
    String key,
    Object? value,
  ) async {
    final updated = Map<String, Object?>.from(sheet);
    updated[key] = value;
    await widget.controller.updateActor(actor, updated);
  }

  Future<void> _editNumericField(
    CampaignActor actor,
    Map<String, Object?> sheet,
    String key,
    String label,
    int current,
  ) async {
    final controller = TextEditingController(text: '$current');
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('编辑$label'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text);
              Navigator.of(context).pop(parsed);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (value == null) return;
    await _updateField(actor, sheet, key, value);
  }

  Future<void> _confirmArchive(CampaignActor actor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('归档角色'),
        content: Text('确认归档 ${actor.sheet['name'] ?? '此角色'}？归档后可在筛选中恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('归档'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final success = await widget.controller.archiveActor(actor);
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.controller.error ?? '归档失败')),
      );
    }
  }

  int _asInt(Object? value) {
    if (value is num) return value.toInt();
    return 0;
  }
}

class _SheetSection extends StatelessWidget {
  const _SheetSection({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _ActorConflictDialog extends StatelessWidget {
  const _ActorConflictDialog({
    required this.conflict,
    required this.onReload,
    required this.onKeepLocal,
  });

  final CampaignConflictException conflict;
  final VoidCallback onReload;
  final VoidCallback onKeepLocal;

  @override
  Widget build(BuildContext context) {
    final current = conflict.current;
    final sheet = current['sheet'] is Map
        ? Map<String, Object?>.from(current['sheet'] as Map)
        : <String, Object?>{};
    final currentHp = _asInt(sheet['currentHp']);
    final maxHp = _asInt(sheet['maxHp']);
    final name = sheet['name']?.toString() ?? '(未命名)';
    final revision = current['revision'];
    return AlertDialog(
      key: const Key('actor-conflict-dialog'),
      title: const Text('版本冲突'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$name 已被其他主持人修改。'),
            const SizedBox(height: 12),
            Text('服务器最新版本：'),
            const SizedBox(height: 4),
            Text('当前 HP $currentHp/$maxHp'),
            if (revision is num) ...[
              const SizedBox(height: 4),
              Text('版本号 ${revision.toInt()}'),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: onKeepLocal, child: const Text('保留本地')),
        FilledButton(onPressed: onReload, child: const Text('重新加载')),
      ],
    );
  }

  int _asInt(Object? value) {
    if (value is num) return value.toInt();
    return 0;
  }
}
