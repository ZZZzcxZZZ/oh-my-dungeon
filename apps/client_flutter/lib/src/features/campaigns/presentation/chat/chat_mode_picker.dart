import 'package:flutter/material.dart';

import 'chat_helpers.dart';

/// 聊天输入区“说/做”模式切换。
///
/// Plan 2026-07-23 Wave 1 Task 1.2: 用户反馈应当做出滑块切换动画，而不是
/// 两个拼在一起的按钮。改为 `Stack` + `AnimatedAlign` 实现 thumb 在左右
/// 两个半区之间 240ms 滑动；前景按钮显示「说」「做」文字标签 + 图标，而
/// 非仅图标。
enum ChatMode { say, act }

class ChatModePicker extends StatelessWidget {
  const ChatModePicker({
    required this.mode,
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  final ChatMode mode;
  final bool enabled;
  final ValueChanged<ChatMode> onChanged;

  static const _thumbKey = Key('chat-mode-thumb');

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSay = mode == ChatMode.say;
    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // thumb 宽度为容器的一半减去 padding 间距
            final thumbWidth = (constraints.maxWidth / 2) - 2;
            return SizedBox(
              height: 36,
              child: Stack(
                children: [
                  // 底层 thumb：通过 AnimatedAlign 在左右半区滑动
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeInOutCubic,
                    alignment: isSay
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    child: Container(
                      key: _thumbKey,
                      width: thumbWidth,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  // 前景：两个透明按钮，各占一半
                  Row(
                    children: [
                      Expanded(
                        child: ChatModeHalf(
                          key: const Key('chat-mode-say'),
                          selected: isSay,
                          enabled: enabled,
                          icon: Icons.chat_bubble_outline,
                          label: chatText('say'),
                          onTap: () => onChanged(ChatMode.say),
                        ),
                      ),
                      Expanded(
                        child: ChatModeHalf(
                          key: const Key('chat-mode-action'),
                          selected: !isSay,
                          enabled: enabled,
                          icon: Icons.directions_run_outlined,
                          label: chatText('act'),
                          onTap: () => onChanged(ChatMode.act),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class ChatModeHalf extends StatelessWidget {
  const ChatModeHalf({
    super.key,
    required this.selected,
    required this.enabled,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final bool enabled;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = selected
        ? colorScheme.onSecondaryContainer
        : colorScheme.onSurfaceVariant;
    return Semantics(
      label: label,
      button: true,
      enabled: enabled,
      selected: selected,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: foreground),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: foreground,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
