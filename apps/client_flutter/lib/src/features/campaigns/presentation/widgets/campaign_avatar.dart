import 'package:flutter/material.dart';

import '../../../../core/presentation/avatar_image_provider.dart';

/// 战役角色头像的健康分级，对应生命环颜色。
///
/// 服务端按 viewer 投影：自己与 owner/dm 可得精确 HP 比例，其他玩家只拿到
/// 分级。0 HP 一律归为 [down]。
enum CampaignAvatarHealth { healthy, injured, critical, down, unknown }

/// 统一的角色/账号头像，外圈生命环按 [health] 着色。
///
/// 设计参考战役工作区重构设计：名字旁不再重复 HP 数字，状态由圆环颜色和
/// 倒地角标传达。无 [imageUrl] 时显示 [initials] 首字母。
class CampaignAvatar extends StatelessWidget {
  const CampaignAvatar({
    this.health = CampaignAvatarHealth.unknown,
    this.imageUrl,
    this.initials = '',
    this.size = 40,
    this.onTap,
    super.key,
  });

  final CampaignAvatarHealth health;
  final String? imageUrl;
  final String initials;
  final double size;
  final VoidCallback? onTap;

  /// 按 HP 比例计算健康分级：>50% 健康、>25% 受伤、>0 危险、0 倒地、
  /// 无 maxHp 未知。供 viewer-aware 投影后的客户端渲染复用。
  static CampaignAvatarHealth healthFromHp(num? current, num? max) {
    final m = max ?? 0;
    if (m <= 0) return CampaignAvatarHealth.unknown;
    final c = current ?? 0;
    if (c <= 0) return CampaignAvatarHealth.down;
    final ratio = c / m;
    if (ratio > 0.5) return CampaignAvatarHealth.healthy;
    if (ratio > 0.25) return CampaignAvatarHealth.injured;
    return CampaignAvatarHealth.critical;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final image = avatarImageProvider(imageUrl);
    final label = initials.isNotEmpty
        ? initials.characters.first.toUpperCase()
        : '';
    final ringWidth = size * 0.09;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            CustomPaint(
              painter: _HealthRingPainter(
                color: _ringColor(health),
                strokeWidth: ringWidth,
                hollow: health == CampaignAvatarHealth.down,
              ),
              child: CircleAvatar(
                radius: (size / 2) - ringWidth - 1,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                backgroundImage: image,
                child: image != null
                    ? null
                    : Text(
                        label,
                        style: TextStyle(
                          fontSize: size * 0.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            if (health == CampaignAvatarHealth.down)
              Positioned(
                right: -2,
                top: -2,
                child: Tooltip(
                  message: '倒地',
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      size: size * 0.28,
                      color: theme.colorScheme.onError,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _ringColor(CampaignAvatarHealth h) {
    return switch (h) {
      CampaignAvatarHealth.healthy => const Color(0xFF1D9E75),
      CampaignAvatarHealth.injured => const Color(0xFFEF9F27),
      CampaignAvatarHealth.critical => const Color(0xFFD85A30),
      CampaignAvatarHealth.down => const Color(0xFFB00020),
      CampaignAvatarHealth.unknown => const Color(0xFF888780),
    };
  }
}

class _HealthRingPainter extends CustomPainter {
  const _HealthRingPainter({
    required this.color,
    required this.strokeWidth,
    required this.hollow,
  });

  final Color color;
  final double strokeWidth;
  final bool hollow;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final radius = (canvasSize.shortestSide - strokeWidth) / 2;
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    if (hollow) {
      // 倒地：空心虚线环，避免与实心状态混淆。
      paint.style = PaintingStyle.stroke;
      canvas.drawCircle(center, radius, paint);
    } else {
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HealthRingPainter oldDelegate) =>
      color != oldDelegate.color ||
      strokeWidth != oldDelegate.strokeWidth ||
      hollow != oldDelegate.hollow;
}
