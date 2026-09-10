---
name: OhMyDungeon
description: 离线优先 D&D 跑团辅助客户端的 Material 3 设计系统。颜色随用户偏好 seed 动态派生。
colors:
  # 默认 seed（Material 紫 #6750A4, tonalSpot, 亮色）基线角色；实际值由
  # ColorScheme.fromSeed(seed, brightness, contrastLevel, variant) 派生，用户可选
  # 6 个预设 seed 或自定义 hex。以下为契约角色，非固定字面值。
  seed-default: "#6750A4"
  primary: "{colors.seed-default}"
  on-primary: "#FFFFFF"
  secondary: "#625B71"  # 保留角色（当前仅经 secondary-container 使用）
  secondary-container: "#E8DEF8"
  on-secondary-container: "#4A4458"
  tertiary: "#7D5260"
  error: "#BA1A1A"
  on-error: "#FFFFFF"
  error-container: "#FFDAD6"
  on-error-container: "#93000A"
  surface: "#FDF7FF"
  on-surface: "#1D1B20"
  surface-container-low: "#F8F2FA"
  surface-container-high: "#ECE6EE"
  surface-container-highest: "#E6E0E9"
  on-surface-variant: "#49454E"
  outline: "#79747E"
  outline-variant: "#CAC4D0"
  inverse-surface: "#322F35"
  on-inverse-surface: "#F5EFF7"
typography:
  # 全部层级使用 NotoSansSC（Variable），字号为 M3 默认；随用户字体缩放偏好变化。
  display-large: { fontFamily: NotoSansSC, fontSize: 57px, fontWeight: 400, lineHeight: 64px, letterSpacing: -0.25px }
  display-small: { fontFamily: NotoSansSC, fontSize: 36px, fontWeight: 400, lineHeight: 44px }
  headline-large: { fontFamily: NotoSansSC, fontSize: 32px, fontWeight: 400, lineHeight: 40px }
  headline-small: { fontFamily: NotoSansSC, fontSize: 24px, fontWeight: 400, lineHeight: 32px }
  title-large: { fontFamily: NotoSansSC, fontSize: 22px, fontWeight: 400, lineHeight: 28px }
  title-medium: { fontFamily: NotoSansSC, fontSize: 16px, fontWeight: 500, lineHeight: 24px, letterSpacing: 0.15px }
  title-small: { fontFamily: NotoSansSC, fontSize: 14px, fontWeight: 500, lineHeight: 20px, letterSpacing: 0.1px }
  body-large: { fontFamily: NotoSansSC, fontSize: 16px, fontWeight: 400, lineHeight: 24px, letterSpacing: 0.5px }
  body-medium: { fontFamily: NotoSansSC, fontSize: 14px, fontWeight: 400, lineHeight: 20px, letterSpacing: 0.25px }
  body-small: { fontFamily: NotoSansSC, fontSize: 12px, fontWeight: 400, lineHeight: 16px, letterSpacing: 0.4px }
  label-large: { fontFamily: NotoSansSC, fontSize: 14px, fontWeight: 500, lineHeight: 20px, letterSpacing: 0.1px }
  label-medium: { fontFamily: NotoSansSC, fontSize: 12px, fontWeight: 500, lineHeight: 16px, letterSpacing: 0.5px }
  label-small: { fontFamily: NotoSansSC, fontSize: 11px, fontWeight: 500, lineHeight: 16px, letterSpacing: 0.5px }
  mono-code: { fontFamily: monospace, fontSize: 13px, fontWeight: 400 }  # JSON 预览（骰式用 title-medium + mono-family）
  narrator: { fontFamily: NotoSansSC, fontSize: 14px, fontWeight: 500 }  # 聊天旁白（斜体）
  system-message: { fontFamily: NotoSansSC, fontSize: 14px, fontWeight: 700 }  # 聊天系统消息
  dice-notation: { fontFamily: NotoSansSC, fontSize: 16px, fontWeight: 700 }  # 掷骰表达式预览
  invite-code: { fontFamily: NotoSansSC, fontSize: 24px, fontWeight: 700, letterSpacing: 2px }  # 邀请码展示
  invite-code-compact: { fontFamily: NotoSansSC, fontSize: 16px, fontWeight: 700, letterSpacing: 1px }  # 邀请码行内
  avatar-initials: { fontFamily: NotoSansSC, fontSize: 14px, fontWeight: 600 }  # 头像首字母（FittedBox 缩放）
  quote: { fontFamily: NotoSansSC, fontSize: 14px, fontWeight: 400 }  # 引用块（斜体）
rounded:
  sm: 8px      # 组件（卡片/按钮/输入框/chip）
  md: 16px     # 对话框 / 底部弹层
  pill: 24px   # 聊天气泡（唯一有意例外）
spacing:
  xs: 4px
  sm: 8px
  md: 12px
  lg: 16px
  xl: 24px
  xxl: 32px
  xxxl: 48px
components:
  button-primary: { backgroundColor: "{colors.primary}", textColor: "{colors.on-primary}", rounded: "{rounded.sm}" }
  button-elevated: { backgroundColor: "{colors.surface-container-high}", textColor: "{colors.on-surface}", rounded: "{rounded.sm}" }
  button-text: { textColor: "{colors.primary}", rounded: "{rounded.sm}" }
  button-outlined: { textColor: "{colors.primary}", rounded: "{rounded.sm}" }
  button-tonal: { backgroundColor: "{colors.secondary-container}", textColor: "{colors.on-secondary-container}", rounded: "{rounded.sm}" }
  chip: { backgroundColor: "{colors.surface-container-high}", textColor: "{colors.on-surface}", rounded: "{rounded.sm}" }
  chip-selected: { backgroundColor: "{colors.secondary-container}", textColor: "{colors.on-secondary-container}", rounded: "{rounded.sm}" }
  card: { backgroundColor: "{colors.surface-container-low}", textColor: "{colors.on-surface}", rounded: "{rounded.sm}", padding: "{spacing.lg}" }
  input-field: { backgroundColor: "{colors.surface-container-high}", textColor: "{colors.on-surface}", rounded: "{rounded.sm}" }
  dialog: { backgroundColor: "{colors.surface-container-high}", rounded: "{rounded.md}" }
  bottom-sheet: { backgroundColor: "{colors.surface-container-high}", rounded: "{rounded.md}" }
  snackbar: { backgroundColor: "{colors.inverse-surface}", textColor: "{colors.on-inverse-surface}", rounded: "{rounded.sm}" }
  search-bar: { backgroundColor: "{colors.surface-container-high}", textColor: "{colors.on-surface}", rounded: "{rounded.sm}" }
  nav-indicator: { backgroundColor: "{colors.secondary-container}" }
  nav-icon-selected: { textColor: "{colors.on-secondary-container}" }
  nav-icon-unselected: { textColor: "{colors.on-surface-variant}" }
  page: { backgroundColor: "{colors.surface}" }
  text-secondary: { textColor: "{colors.on-surface-variant}" }
  badge-status: { backgroundColor: "{colors.error}", textColor: "{colors.on-error}", rounded: "{rounded.sm}" }
  callout-error: { backgroundColor: "{colors.error-container}", textColor: "{colors.on-error-container}", rounded: "{rounded.sm}" }
  avatar-ring-injured: { textColor: "{colors.tertiary}" }
  divider: { backgroundColor: "{colors.outline-variant}" }
  icon-muted: { textColor: "{colors.outline}" }
  composer-pill: { backgroundColor: "{colors.surface-container-highest}", rounded: "{rounded.pill}" }
---

## Overview

OhMyDungeon 是离线优先的 D&D 跑团辅助工具，界面语言是"安静的工具台"：以 Material 3 动态色
（用户可选 6 个预设 seed 或自定义色）为唯一色彩来源，8dp 圆角、零投影的扁平层级、NotoSansSC
中文排版。整体气质克制、信息密度中高，让位于规则文本与角色数据本身。

## Colors

所有颜色由 `ColorScheme.fromSeed` 派生，**禁止硬编码字面颜色**（唯一例外：seed 选择器中的预设
色）。文字必须使用与背景匹配的 `on-*` 角色。`outline` 仅用于描边与图标，不得作为正文文字色。
`secondary` 为保留角色，当前仅经 secondaryContainer 参与组件；`tertiary` 用于头像生命环"受伤"档。

## Typography

统一 NotoSansSC（Variable），层级即 M3 默认 textTheme，随用户字体缩放偏好缩放。正文 14–16px；
标题 22–32px；元数据用 label 系列。代码/骰式用 `mono-code` 13px。不要用固定字号覆盖字体缩放。

## Layout

8px 刻度 + 4px 半步（xs 4 / sm 8 / md 12 / lg 16 / xl 24 / xxl 32 / xxxl 48）。列表底部为 FAB
让位时用 96px 单一常量。区块垂直节奏 24px；卡片内边距 16–24px。

## Elevation & Depth

**扁平化**：所有表面 `elevation: 0`、`surfaceTint: transparent`（含对话框）。层级用色调层
（surfaceContainerLow → High）与 1px outlineVariant 描边表达。唯一浮动元素为 SnackBar。

## Shapes

组件统一 8dp（卡片/按钮/输入框/chip）；对话框与底部弹层 16dp；聊天气泡胶囊 24dp 为唯一例外。
不得混用其他圆角值。

## Components

按钮五态（filled/elevated/text/outlined/tonal）如 token 定义，破坏性操作统一 error 角色。
Chip 选中态必须使用 onSecondaryContainer。输入框一律走 `inputDecorationTheme`（8dp 填充式），
不覆写 border。对话框内容宽度取 token（440/560/760）。所有纯图标控件必须带 Tooltip。

## Do's and Don'ts

- Do 只用 colorScheme 角色取色，文字配 on-* 角色
- Do 保持 4/8px 间距韵律与 8/16dp 圆角契约
- Do 为纯图标控件提供 Tooltip，触达尺寸 ≥ 48dp
- Don't 硬编码颜色、字号或间距
- Don't 覆写 `border: OutlineInputBorder()`（丢失主题 8dp 与聚焦态）
- Don't 在彩色底上使用默认 onSurface 文字
- Don't 引入非零 elevation（对话框、SearchBar 均需显式 0）