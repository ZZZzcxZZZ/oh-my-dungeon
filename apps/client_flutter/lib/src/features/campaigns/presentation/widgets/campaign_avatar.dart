import 'dart:math' as math;

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
    this.healthFraction,
    this.imageUrl,
    this.initials = '',
    this.size = 40,
    this.tapTargetSize,
    this.onTap,
    super.key,
  });

  final CampaignAvatarHealth health;
  final double? healthFraction;
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

  static double? fractionFromHp(num? current, num? max) =>
      campaignHealthFractionFromHp(current, max);

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
    final ringFraction =
        healthFraction?.clamp(0, 1).toDouble() ?? _fallbackFraction(health);
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
                    painter: CampaignHealthRingPainter(
                      color: _ringColor(theme.colorScheme, health),
                      trackColor: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.72,
                      ),
                      strokeWidth: ringWidth,
                      fraction: ringFraction,
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
      CampaignAvatarHealth.critical ||
      CampaignAvatarHealth.down => colors.error,
      CampaignAvatarHealth.unknown => colors.outline,
    };
  }

  double? _fallbackFraction(CampaignAvatarHealth health) => switch (health) {
    CampaignAvatarHealth.healthy => 0.75,
    CampaignAvatarHealth.injured => 0.5,
    CampaignAvatarHealth.critical => 0.25,
    CampaignAvatarHealth.down => 0,
    CampaignAvatarHealth.unknown => null,
  };
}

class CampaignHealthRingPainter extends CustomPainter {
  const CampaignHealthRingPainter({
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
    required this.fraction,
  });

  final Color color;
  final Color trackColor;
  final double strokeWidth;
  final double? fraction;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    final radius = (canvasSize.shortestSide - strokeWidth) / 2;
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    canvas.drawCircle(center, radius, trackPaint);

    final progress = fraction;
    if (progress == null || progress <= 0) return;
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    if (progress >= 1) {
      canvas.drawCircle(center, radius, progressPaint);
      return;
    }
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CampaignHealthRingPainter oldDelegate) =>
      color != oldDelegate.color ||
      trackColor != oldDelegate.trackColor ||
      strokeWidth != oldDelegate.strokeWidth ||
      fraction != oldDelegate.fraction;
}
