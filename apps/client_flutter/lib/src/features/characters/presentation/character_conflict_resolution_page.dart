import 'dart:convert';

import 'package:flutter/material.dart';

import '../../campaigns/presentation/actors/campaign_actor_controller.dart';
import '../data/local/character_sync_conflict_repository.dart';
import '../domain/character.dart';
import 'character_conflict_banner_controller.dart';
import 'character_controller.dart';

/// 角色 vs 战役 Actor 同步冲突解决页。
///
/// 列出所有未解决冲突，每个冲突显示本地 vs 远端 sheet 的关键差异，并提供：
/// - 用本地覆盖：调 actorController.publishCharacter 重发本地角色
/// - 用远端覆盖：调 actorController.pullUntilCurrent 后 markResolved
/// - 稍后处理：关闭页面，冲突保留
class CharacterConflictResolutionPage extends StatelessWidget {
  const CharacterConflictResolutionPage({
    required this.controller,
    required this.characterController,
    this.actorController,
    super.key,
  });

  final CharacterConflictBannerController controller;
  final CharacterController characterController;
  final CampaignActorController? actorController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final conflicts = controller.conflicts;
        return Scaffold(
          appBar: AppBar(
            title: const Text('同步冲突'),
            actions: [
              IconButton(
                tooltip: '全部用远端覆盖',
                icon: const Icon(Icons.cloud_download),
                onPressed: conflicts.isEmpty
                    ? null
                    : () => _resolveAllWithRemote(context),
              ),
            ],
          ),
          body: conflicts.isEmpty
              ? const _EmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: conflicts.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final conflict = conflicts[index];
                    return _ConflictCard(
                      conflict: conflict,
                      characterName: _characterName(conflict.characterId),
                      onUseLocal: () => _useLocal(context, conflict),
                      onUseRemote: () => _useRemote(context, conflict),
                    );
                  },
                ),
        );
      },
    );
  }

  String _characterName(String characterId) {
    final character = characterController.characters
        .cast<CharacterSheet?>()
        .firstWhere(
          (c) => c?.id == characterId,
          orElse: () => null,
        );
    return character?.name ?? '已删除的角色';
  }

  Future<void> _useLocal(
    BuildContext context,
    CharacterSyncConflict conflict,
  ) async {
    final actor = actorController;
    if (actor == null) {
      _showSnack(context, '未连接到战役，无法覆盖');
      return;
    }
    final character = characterController.characters
        .cast<CharacterSheet?>()
        .firstWhere(
          (c) => c?.id == conflict.characterId,
          orElse: () => null,
        );
    if (character == null) {
      _showSnack(context, '本地角色已被删除');
      return;
    }
    final success = await actor.publishCharacter(
      character,
      baseRevisionOverride: _extractRevision(conflict.remoteValueJson),
    );
    if (success) {
      await controller.markResolved(conflict.id);
      if (context.mounted) _showSnack(context, '已用本地版本覆盖');
    } else {
      if (context.mounted) {
        _showSnack(context, actor.error ?? '覆盖失败');
      }
    }
  }

  Future<void> _useRemote(
    BuildContext context,
    CharacterSyncConflict conflict,
  ) async {
    final actor = actorController;
    if (actor == null) {
      _showSnack(context, '未连接到战役，无法拉取');
      return;
    }
    await actor.pullUntilCurrent();
    await controller.markResolved(conflict.id);
    if (context.mounted) _showSnack(context, '已用远端版本覆盖');
  }

  Future<void> _resolveAllWithRemote(BuildContext context) async {
    final actor = actorController;
    if (actor == null) {
      _showSnack(context, '未连接到战役，无法拉取');
      return;
    }
    await actor.pullUntilCurrent();
    final conflicts = List<CharacterSyncConflict>.from(controller.conflicts);
    for (final conflict in conflicts) {
      await controller.markResolved(conflict.id);
    }
    if (context.mounted) _showSnack(context, '已用远端版本解决全部冲突');
  }

  int? _extractRevision(String remoteJson) {
    try {
      final decoded = jsonDecode(remoteJson);
      if (decoded is Map<String, Object?>) {
        final revision = decoded['revision'];
        if (revision is num) return revision.toInt();
      }
    } catch (_) {}
    return null;
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text('没有未解决的同步冲突', style: theme.textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

class _ConflictCard extends StatelessWidget {
  const _ConflictCard({
    required this.conflict,
    required this.characterName,
    required this.onUseLocal,
    required this.onUseRemote,
  });

  final CharacterSyncConflict conflict;
  final String characterName;
  final VoidCallback onUseLocal;
  final VoidCallback onUseRemote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localSheet = _decodeSheet(conflict.localValueJson);
    final remoteSheet = _decodeSheet(conflict.remoteValueJson);
    return Card(
      key: ValueKey('conflict-card-${conflict.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sync_problem, color: theme.colorScheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    characterName,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '字段：${conflict.fieldPath}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            _SheetComparison(
              label: '本地版本',
              sheet: localSheet,
              color: theme.colorScheme.primaryContainer,
              onColor: theme.colorScheme.onPrimaryContainer,
            ),
            const SizedBox(height: 8),
            _SheetComparison(
              label: '服务器版本',
              sheet: remoteSheet,
              color: theme.colorScheme.secondaryContainer,
              onColor: theme.colorScheme.onSecondaryContainer,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  key: ValueKey('use-remote-${conflict.id}'),
                  onPressed: onUseRemote,
                  child: const Text('用远端覆盖'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: ValueKey('use-local-${conflict.id}'),
                  onPressed: onUseLocal,
                  child: const Text('用本地覆盖'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Map<String, Object?> _decodeSheet(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map<String, Object?>) return decoded;
    } catch (_) {}
    return const {};
  }
}

class _SheetComparison extends StatelessWidget {
  const _SheetComparison({
    required this.label,
    required this.sheet,
    required this.color,
    required this.onColor,
  });

  final String label;
  final Map<String, Object?> sheet;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = sheet['name']?.toString() ?? '未命名';
    final currentHp = _asInt(sheet['currentHp']);
    final maxHp = _asInt(sheet['maxHp']);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: onColor),
          ),
          const SizedBox(height: 4),
          Text(name, style: theme.textTheme.titleSmall?.copyWith(color: onColor)),
          if (maxHp > 0) ...[
            const SizedBox(height: 4),
            Text(
              'HP $currentHp/$maxHp',
              style: theme.textTheme.bodyMedium?.copyWith(color: onColor),
            ),
          ],
        ],
      ),
    );
  }

  int _asInt(Object? value) {
    if (value is num) return value.toInt();
    return 0;
  }
}
