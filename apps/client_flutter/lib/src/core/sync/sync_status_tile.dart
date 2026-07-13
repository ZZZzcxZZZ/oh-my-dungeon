import 'package:flutter/material.dart';

import 'sync_models.dart';
import 'sync_status_controller.dart';

/// 设置页中的同步状态条目。
///
/// 根据 [SyncStatusController.phase] 显示离线、空闲、同步中、冲突或错误；
/// 未登录时副标题固定为"仅保存在此设备"。
class SyncStatusTile extends StatelessWidget {
  const SyncStatusTile({
    required this.controller,
    required this.isLoggedIn,
    super.key,
  });

  final SyncStatusController controller;
  final bool isLoggedIn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final phase = controller.phase;
    final pending = controller.pendingCount;

    IconData icon;
    String title;
    String? subtitle;
    Color? iconColor;

    if (!isLoggedIn) {
      icon = Icons.cloud_off_outlined;
      title = '离线';
      subtitle = '仅保存在此设备';
    } else {
      switch (phase) {
        case SyncPhase.offline:
          icon = Icons.cloud_off_outlined;
          title = '离线';
          subtitle = '等待网络恢复';
          iconColor = theme.colorScheme.onSurfaceVariant;
        case SyncPhase.idle:
          icon = Icons.cloud_done_outlined;
          title = '已同步';
          subtitle = pending > 0 ? '$pending 项待同步' : '所有数据已是最新';
          iconColor = theme.colorScheme.onSurfaceVariant;
        case SyncPhase.syncing:
          icon = Icons.sync;
          title = '同步中';
          subtitle = pending > 0 ? '正在同步 $pending 项…' : '正在同步…';
          iconColor = theme.colorScheme.primary;
        case SyncPhase.conflict:
          icon = Icons.warning_amber_outlined;
          title = '存在冲突';
          subtitle = '部分数据需要手动解决';
          iconColor = theme.colorScheme.error;
        case SyncPhase.error:
          icon = Icons.error_outline;
          title = '同步出错';
          subtitle = controller.lastError ?? '同步失败，将稍后重试';
          iconColor = theme.colorScheme.error;
      }
    }

    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      subtitle: Text(subtitle),
      dense: true,
    );
  }
}
