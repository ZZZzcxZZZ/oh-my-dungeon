import 'package:flutter/material.dart';

import 'chat_helpers.dart';

/// 聊天输入区“说/做”模式切换。可见界面保持图标化，文字通过 Tooltip 和
/// Semantics 提供。
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

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Row(
          children: [
            Expanded(
              child: ChatModeHalf(
                key: const Key('chat-mode-say'),
                selected: mode == ChatMode.say,
                enabled: enabled,
                icon: Icons.chat_bubble_outline,
                label: chatText('say'),
                onTap: () => onChanged(ChatMode.say),
              ),
            ),
            Expanded(
              child: ChatModeHalf(
                key: const Key('chat-mode-action'),
                selected: mode == ChatMode.act,
                enabled: enabled,
                icon: Icons.directions_run_outlined,
                label: chatText('act'),
                onTap: () => onChanged(ChatMode.act),
              ),
            ),
          ],
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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? colorScheme.secondaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: foreground),
          ),
        ),
      ),
    );
  }
}
