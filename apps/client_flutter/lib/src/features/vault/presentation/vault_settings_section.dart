import 'package:flutter/material.dart';

import '../../../core/sync/sync_models.dart';
import '../domain/vault_models.dart';
import 'vault_sync_controller.dart';

/// 设置页中的「个人同步」卡片。
///
/// 未登录（[SyncPhase.offline]）时显示提示，不禁用本地功能；登录后显示
/// pending 数量、立即同步、后台同步开关、错误详情和设备列表。错误信息只
/// 显示简短文本，使用 [SelectableText] 以便复制，不包含 token 或实体全文。
class VaultSettingsSection extends StatefulWidget {
  const VaultSettingsSection({required this.actions, super.key});

  final VaultSyncActions actions;

  @override
  State<VaultSettingsSection> createState() => _VaultSettingsSectionState();
}

class _VaultSettingsSectionState extends State<VaultSettingsSection> {
  @override
  void initState() {
    super.initState();
    widget.actions.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.actions.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final actions = widget.actions;
    final theme = Theme.of(context);

    // 未登录或未配置服务器：同步是可选能力，不禁用本地角色与资料。
    if (actions.phase == SyncPhase.offline) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('个人同步', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                '登录后可跨设备同步角色、收藏和笔记。本地角色不会丢失。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('个人同步', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _buildStatusRow(context, actions),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton(
                  onPressed: actions.paused ? null : () => actions.syncNow(),
                  child: const Text('立即同步'),
                ),
                const SizedBox(width: 12),
                Switch(
                  value: !actions.paused,
                  onChanged: (v) => actions.setPaused(!v),
                ),
                const SizedBox(width: 8),
                Text('后台同步', style: theme.textTheme.bodyMedium),
              ],
            ),
            if (actions.lastError != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  actions.lastError!,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onErrorContainer),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text('设备', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final device in actions.devices)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(device.name),
                subtitle: Text('${device.platform} · ${device.lastSeenAt}'),
                trailing: device.isCurrent
                    ? Text(
                        '当前设备',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: '撤销设备',
                        onPressed: () => _confirmRevoke(device),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(BuildContext context, VaultSyncActions actions) {
    final theme = Theme.of(context);
    final phaseText = switch (actions.phase) {
      SyncPhase.offline => '离线',
      SyncPhase.idle => '已同步',
      SyncPhase.syncing => '同步中…',
      SyncPhase.conflict => '存在冲突',
      SyncPhase.error => '同步失败',
    };
    return Row(
      children: [
        Text(phaseText, style: theme.textTheme.bodyMedium),
        const SizedBox(width: 16),
        if (actions.pendingCount > 0)
          Text(
            '${actions.pendingCount} 项等待同步',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }

  Future<void> _confirmRevoke(VaultDeviceView device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('撤销设备'),
        content: Text('确定撤销 ${device.name} 的同步权限？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('撤销'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.actions.revokeDevice(device.deviceId);
    }
  }
}
