import 'package:flutter/material.dart';

import '../../domain/declared_levels.dart';

/// 等级滑杆的轨道：把**已声明区间**与**未声明区间**画成两种颜色（契约 §3.12）。
///
/// Material 的 `SliderThemeData` 只有"滑块左侧 / 右侧"两种轨道色，无法表达
/// "哪一段等级被职业声明过"。因此这里做成自定义 [SliderTrackShape]：
///
/// 1. 先用 `inactiveTrackColor`（主题的 `outlineVariant`，§3.12 指定的未声明色）
///    画满整条轨道；
/// 2. 再把**已声明区间**覆盖成 `activeTrackColor`（主题色）。
///
/// 两个颜色都从 `SliderTheme` 读，颜色角色仍由主题决定，代码里不写死颜色值。
/// 完全没有声明（[DeclaredLevels.isEmpty]）时整条轨道都是未声明色。
///
/// 区间 → 轨道比例的换算只有一处实现：[declaredRangeFraction]。
class DeclaredLevelTrackShape extends SliderTrackShape
    with BaseSliderTrackShape {
  const DeclaredLevelTrackShape({
    required this.levels,
    required this.min,
    required this.max,
  });

  /// 职业声明范围。
  final DeclaredLevels levels;

  /// 滑杆取值下限（通常是 1 级）。
  final double min;

  /// 滑杆取值上限（通常是 [kMaxCharacterLevel]）。
  final double max;

  /// 已声明区间在轨道上的比例 `(起点, 终点)`，均为 `0..1`。
  ///
  /// 等级 `L` 的位置比例 = `(L - min) / (max - min)`，区间取
  /// `[levels.min, levels.max]` 两个端点并夹到 `0..1`。
  /// 完全没有声明（`max == null`）或区间退化（`end <= start`）时返回 `null`，
  /// 调用方据此只画未声明色。
  static (double, double)? declaredRangeFraction({
    required DeclaredLevels levels,
    required double min,
    required double max,
  }) {
    final maximum = levels.max;
    if (maximum == null || max <= min) return null;
    double ratio(int level) => ((level - min) / (max - min)).clamp(0.0, 1.0);
    final start = ratio(levels.min);
    final end = ratio(maximum);
    if (end <= start) return null;
    return (start, end);
  }

  @override
  bool get isRounded => true;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
    required TextDirection textDirection,
  }) {
    // 与默认轨道形状同一语义：厚度 <= 0 时轨道没有可画的东西。
    //
    // `trackHeight` 为 null **不在这里兜底**：`getPreferredRect` 内部用的是
    // `sliderTheme.trackHeight!`（SDK 的非空断言）+ `assert(...)`，缺省主题由
    // `SliderTheme.of` 补齐，因此 null 只可能来自自定义主题写错——那种情况按
    // 契约**大声失败**（SDK 断言），不在这里静默画一条空轨道。
    // 本 guard 只对"非 null 且 <= 0"生效。
    final trackHeight = sliderTheme.trackHeight;
    if (trackHeight != null && trackHeight <= 0) return;
    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    // 与默认轨道形状同类：这四个颜色由 `SliderThemeData` 的契约保证非空
    // （`SliderTheme.of` 会补上默认值）。主题不合法时用 `!` **大声失败**，
    // 不静默画一条空轨道。
    assert(sliderTheme.activeTrackColor != null);
    assert(sliderTheme.inactiveTrackColor != null);
    final undeclaredColor = isEnabled
        ? sliderTheme.inactiveTrackColor!
        : sliderTheme.disabledInactiveTrackColor!;
    final declaredColor = isEnabled
        ? sliderTheme.activeTrackColor!
        : sliderTheme.disabledActiveTrackColor!;

    final paint = Paint()..style = PaintingStyle.fill;
    final radius = Radius.circular(trackRect.height / 2);
    paint.color = undeclaredColor;
    context.canvas.drawRRect(RRect.fromRectAndRadius(trackRect, radius), paint);

    final fraction = declaredRangeFraction(levels: levels, min: min, max: max);
    if (fraction == null) return;
    final declaredRect = Rect.fromLTRB(
      trackRect.left + trackRect.width * fraction.$1,
      trackRect.top,
      trackRect.left + trackRect.width * fraction.$2,
      trackRect.bottom,
    );
    paint.color = declaredColor;
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(declaredRect, radius),
      paint,
    );
  }
}
