import 'dart:convert';

import 'package:flutter/material.dart';

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
    final image = _avatarImage(url);
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

  ImageProvider<Object>? _avatarImage(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('data:image/')) {
      final separator = url.indexOf(',');
      if (separator < 0) return null;
      try {
        return MemoryImage(base64Decode(url.substring(separator + 1)));
      } on FormatException {
        return null;
      }
    }
    return NetworkImage(url);
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
