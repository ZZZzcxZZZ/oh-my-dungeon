import 'package:flutter/material.dart';

import '../domain/encounter.dart';
import 'encounter_controller.dart';

/// DM 控场面板: 把旧桌面页的遭遇控场迁移到底部 sheet, 让 DM 在战役进行中
/// 快速管理参与者 HP、推进回合、结束遭遇。
///
/// 设计原则:
/// - 卡片式参与者列表, 当前回合高亮.
/// - HP 控件 (-/+ 按钮) 直接调用 controller.adjustParticipantHp.
/// - 推进回合 / 结束遭遇 放在底部操作条.
/// - 无活跃遭遇时显示空态, 提供"新建遭遇"入口.
class EncounterPanelPage extends StatelessWidget {
  const EncounterPanelPage({
    required this.controller,
    this.campaignId,
    this.onCreateEncounter,
    super.key,
  });

  final EncounterController controller;
  final String? campaignId;
  final Future<void> Function()? onCreateEncounter;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final encounter = controller.activeEncounter;
        if (encounter == null) {
          return _EncounterEmptyState(onCreate: onCreateEncounter);
        }
        return _EncounterActiveView(
          encounter: encounter,
          controller: controller,
        );
      },
    );
  }
}

class _EncounterEmptyState extends StatelessWidget {
  const _EncounterEmptyState({this.onCreate});

  final Future<void> Function()? onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shield_moon_outlined,
              size: 56,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              '当前没有进行中的遭遇',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('encounter-create-button'),
              icon: const Icon(Icons.add),
              label: const Text('新建遭遇'),
              onPressed: onCreate == null
                  ? null
                  : () {
                      onCreate!();
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class _EncounterActiveView extends StatelessWidget {
  const _EncounterActiveView({
    required this.encounter,
    required this.controller,
  });

  final Encounter encounter;
  final EncounterController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sortedParticipants = [...encounter.participants]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final currentId = encounter.currentTurnParticipantId;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  encounter.name,
                  style: theme.textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '第 ${encounter.round} 轮',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: sortedParticipants.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final participant = sortedParticipants[index];
              final isCurrent = participant.id == currentId;
              return _ParticipantCard(
                participant: participant,
                isCurrentTurn: isCurrent,
                onDamage: () => controller.adjustParticipantHp(
                  encounterId: encounter.id,
                  participantId: participant.id,
                  delta: -1,
                ),
                onHeal: () => controller.adjustParticipantHp(
                  encounterId: encounter.id,
                  participantId: participant.id,
                  delta: 1,
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: const Key('encounter-advance-turn-button'),
                  icon: const Icon(Icons.skip_next),
                  label: const Text('推进回合'),
                  onPressed: () => controller.advanceTurn(),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                key: const Key('encounter-end-button'),
                onPressed: () => controller.endEncounter(),
                child: const Text('结束遭遇'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ParticipantCard extends StatelessWidget {
  const _ParticipantCard({
    required this.participant,
    required this.isCurrentTurn,
    required this.onDamage,
    required this.onHeal,
  });

  final EncounterParticipant participant;
  final bool isCurrentTurn;
  final Future<void> Function() onDamage;
  final Future<void> Function() onHeal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      shape: RoundedRectangleBorder(
        side: isCurrentTurn
            ? BorderSide(color: colorScheme.primary, width: 2)
            : BorderSide(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      color: isCurrentTurn
          ? colorScheme.secondaryContainer
          : colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Text(
                participant.participantType == 'player' ? 'P' : 'N',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          participant.displayName,
                          style: theme.textTheme.titleSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrentTurn) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.play_arrow,
                          size: 14,
                          color: colorScheme.primary,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    children: [
                      Text(
                        '先攻 ${participant.initiative}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        'AC ${participant.armorClass}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${participant.hpCurrent}/${participant.hpMax}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: participant.hpCurrent <= 0
                        ? colorScheme.error
                        : colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'HP',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            IconButton(
              key: const ValueKey('encounter-damage-button'),
              tooltip: '受到 1 点伤害',
              icon: const Icon(Icons.remove_circle_outline),
              color: colorScheme.error,
              onPressed: () => onDamage(),
            ),
            IconButton(
              key: const ValueKey('encounter-heal-button'),
              tooltip: '恢复 1 点 HP',
              icon: const Icon(Icons.add_circle_outline),
              color: colorScheme.primary,
              onPressed: () => onHeal(),
            ),
          ],
        ),
      ),
    );
  }
}
