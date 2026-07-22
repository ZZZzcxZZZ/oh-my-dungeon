import 'package:flutter/material.dart';

import '../../../../core/presentation/avatar_image_provider.dart';
import '../../domain/campaign_health.dart';

/// 战役角色头像的健康分级，对应生命环颜色。
///
/// 服务端按 viewer 投影：自己与 owner/dm 可得精确 HP 比例，其他玩家只拿到
/// 分级。0 HP 一律归为 [down]。
enum CampaignAvatarHealth { healthy, injured, critical, down, unknown }

/// 统一的角色/账号头像，外圈生命环按 [health] 着色。
///
/// [size] 控制头像视觉尺寸，[tapTargetSize] 可提供更大的 Material 触控区域。
class CampaignAvatar extends StatelessWidget {
  const CampaignAvatar({
    this.health = CampaignAvatarHealth.unknown,
    this.imageUrl,
    this.initials = '',
    this.size = 40,
    this.tapTargetSize,
    this.onTap,
    super.key,
  });

  final CampaignAvatarHealth health;
  final String? imageUrl;
  final String initials;
  final double size;
  final double? tapTargetSize;
  final VoidCallback? onTap;

  static CampaignAvatarHealth healthFromHp(num? current, num? max) {
    return switch (campaignHealthStateFromHp(current, max)) {
      'healthy' => CampaignAvatarHealth.healthy,
      'injured' => CampaignAvatarHealth.injured,
      'critical' => CampaignAvatarHealth.critical,
      'down' => CampaignAvatarHealth.down,
      _ => CampaignAvatarHealth.unknown,
    };
  }

  static CampaignAvatarHealth healthFromState(String? state) {
    return switch (state) {
      'healthy' => CampaignAvatarHealth.healthy,
      'injured' => CampaignAvatarHealth.injured,
      'critical' => CampaignAvatarHealth.critical,
      'down' => CampaignAvatarHealth.down,
      _ => CampaignAvatarHealth.unknown,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final image = avatarImageProvider(imageUrl);
    final label = initials.isNotEmpty
        ? initials.characters.first.toUpperCase()
        : '';
    final ringWidth = size * 0.09;
    final targetSize = tapTargetSize == null
        ? size
        : tapTargetSize!.clamp(size, double.infinity).toDouble();

    return Semantics(
      label: '$label，${_healthLabel(health)}',
      button: onTap != null,
      container: true,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox.square(
          key: const Key('campaign-avatar-target'),
          dimension: targetSize,
          child: Center(
            child: SizedBox.square(
              key: const Key('campaign-avatar-visual'),
              dimension: size,
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.none,
                children: [
                  CustomPaint(
                    key: Key('campaign-avatar-ring-${health.name}'),
                    painter: _HealthRingPainter(
                      color: _ringColor(theme.colorScheme, health),
                      strokeWidth: ringWidth,
                      hollow: health == CampaignAvatarHealth.down,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(ringWidth + 2),
                      child: CircleAvatar(
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        backgroundImage: image,
                        child: image != null
                            ? null
                            : Text(
                                label,
                                style: TextStyle(
                                  fontSize: size * 0.32,
                                  fontWeight: FontWeight.w600,
                                ),
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
          ),
        ),
      ),
    );
  }

  String _healthLabel(CampaignAvatarHealth health) {
    return switch (health) {
      CampaignAvatarHealth.healthy => '健康',
      CampaignAvatarHealth.injured => '受伤',
      CampaignAvatarHealth.critical => '濒危',
      CampaignAvatarHealth.down => '倒地',
      CampaignAvatarHealth.unknown => '生命值未知',
    };
  }

  Color _ringColor(ColorScheme colors, CampaignAvatarHealth health) {
    return switch (health) {
      CampaignAvatarHealth.healthy => colors.primary,
      CampaignAvatarHealth.injured => colors.tertiary,
      CampaignAvatarHealth.critical || CampaignAvatarHealth.down =>
        colors.error,
      CampaignAvatarHealth.unknown => colors.outline,
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
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _HealthRingPainter oldDelegate) =>
      color != oldDelegate.color ||
      strokeWidth != oldDelegate.strokeWidth ||
      hollow != oldDelegate.hollow;
}
