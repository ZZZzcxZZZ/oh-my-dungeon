import 'package:flutter/material.dart';

import '../../domain/campaign_actor.dart';
import 'campaign_avatar.dart';

/// 战役角色快捷摘要，用于点击头像后弹出。
///
/// 主持人（owner/dm）看到精确 HP，其他玩家只看到健康分级词，遵循战役工作区
/// 设计的 viewer-aware 投影。
class CampaignActorQuickSheet extends StatelessWidget {
  const CampaignActorQuickSheet({
    required this.actor,
    required this.isManager,
    this.onOpenSheet,
    super.key,
  });

  final CampaignActor actor;
  final bool isManager;
  final VoidCallback? onOpenSheet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sheet = actor.sheet;
    final rawName = sheet['name']?.toString().trim();
    final name = (rawName == null || rawName.isEmpty) ? '未命名角色' : rawName;
    final currentHp = _toInt(sheet['currentHp']);
    final maxHp = _toInt(sheet['maxHp']);
    final ac = sheet['armorClass']?.toString();
    final health = _healthGrade(currentHp, maxHp);
    final avatarUrl = sheet['avatarUrl'] as String?;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CampaignAvatar(
                initials: name,
                imageUrl: avatarUrl,
                health: health,
                size: 56,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: theme.textTheme.titleLarge),
                    Text(
                      _actorTypeLabel(actor.actorType),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _Stat(
                label: '生命',
                value: isManager
                    ? '$currentHp/$maxHp'
                    : _healthWord(health),
              ),
              const SizedBox(width: 24),
              if (ac != null && ac.isNotEmpty) _Stat(label: 'AC', value: ac),
            ],
          ),
          if (onOpenSheet != null) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onOpenSheet,
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('打开角色卡'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  int _toInt(Object? v) {
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  CampaignAvatarHealth _healthGrade(int current, int max) {
    if (max <= 0) return CampaignAvatarHealth.unknown;
    if (current <= 0) return CampaignAvatarHealth.down;
    final ratio = current / max;
    if (ratio > 0.5) return CampaignAvatarHealth.healthy;
    if (ratio > 0.25) return CampaignAvatarHealth.injured;
    return CampaignAvatarHealth.critical;
  }

  String _healthWord(CampaignAvatarHealth h) => switch (h) {
        CampaignAvatarHealth.healthy => '健康',
        CampaignAvatarHealth.injured => '受伤',
        CampaignAvatarHealth.critical => '危险',
        CampaignAvatarHealth.down => '倒地',
        CampaignAvatarHealth.unknown => '未知',
      };

  String _actorTypeLabel(String t) => switch (t) {
        'player' => '玩家角色',
        'npc' => 'NPC',
        'monster' => '怪物',
        'companion' => '同伴',
        _ => t,
      };
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelSmall),
        Text(value, style: theme.textTheme.titleMedium),
      ],
    );
  }
}
