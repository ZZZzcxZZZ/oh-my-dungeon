import 'package:flutter/material.dart';

import '../../../../core/presentation/avatar_image_provider.dart';
import 'chat_helpers.dart';

/// 聊天消息和成员列表中显示的角色头像。支持 data URI 与网络图片，
/// 可选外圈生命环（按 [healthState] 着色）。
class ChatAvatar extends StatelessWidget {
  const ChatAvatar({
    required this.name,
    required this.avatarUrl,
    this.size = 40,
    this.healthState,
    this.onTap,
    super.key,
  });

  final String name;
  final String? avatarUrl;
  final double size;
  final String? healthState;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();
    final image = avatarImageProvider(url);
    final color = healthRingColor(context, healthState);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CircleAvatar(
              backgroundImage: image,
              child: image == null ? Text(avatarText(name)) : null,
            ),
            if (color != null)
              IgnorePointer(
                child: DecoratedBox(
                  key: Key('campaign-avatar-ring-$healthState'),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 3),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Color? healthRingColor(BuildContext context, String? state) {
  final colors = Theme.of(context).colorScheme;
  return switch (state) {
    'healthy' => colors.primary,
    'injured' => colors.tertiary,
    'critical' || 'down' => colors.error,
    _ => null,
  };
}
