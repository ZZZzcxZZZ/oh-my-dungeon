import 'package:flutter/material.dart';

/// 语义排版 token（DESIGN.md typography 的代码落地）。
///
/// 这些样式在 M3 textTheme 之外补充领域语义（代码/骰式、旁白、系统消息、
/// 掷骰预览、邀请码、头像首字母）。统一入口后，全局改版只改这里；
/// 颜色不在此定义——由调用方按 on-* 角色叠加。
abstract final class AppTextStyles {
  /// 等宽字体族：JSON 预览与骰式表达式使用。
  static const String monoFamily = 'monospace';

  /// JSON 预览：等宽 13px（DESIGN.md `mono-code`）。
  static TextStyle monoCode(TextTheme theme) => TextStyle(
        fontFamily: monoFamily,
        fontSize: 13,
        fontWeight: FontWeight.w400,
      );

  /// 聊天旁白（居中叙述，w500 斜体）。
  static TextStyle narrator(TextTheme theme) => theme.bodyMedium!.copyWith(
        fontWeight: FontWeight.w500,
        fontStyle: FontStyle.italic,
      );

  /// 聊天系统消息（加粗强调）。
  static TextStyle systemMessage(TextTheme theme) =>
      theme.bodyMedium!.copyWith(fontWeight: FontWeight.bold);

  /// 掷骰表达式预览（加粗）。
  static TextStyle diceNotation(TextTheme theme) =>
      theme.titleMedium!.copyWith(fontWeight: FontWeight.bold);

  /// 邀请码大号展示（24px 加粗 + 宽字距）。
  static TextStyle inviteCode(TextTheme theme) => theme.titleMedium!.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        letterSpacing: 2,
      );

  /// 邀请码紧凑行（加粗 + 字距 1）。
  static TextStyle inviteCodeCompact(TextTheme theme) =>
      theme.titleMedium!.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1);

  /// 头像首字母（w600；随头像尺寸缩放由调用方用 FittedBox 处理）。
  static TextStyle avatarInitials(TextTheme theme) =>
      theme.labelLarge!.copyWith(fontWeight: FontWeight.w600);

  /// 引用块（斜体，语义性变体）。
  static TextStyle quote(TextTheme theme) =>
      theme.bodyMedium!.copyWith(fontStyle: FontStyle.italic);
}
