import 'package:flutter/material.dart';

enum ChatMode { say, act }

/// A single in-field mode button. The visible icon represents the current
/// message format; tapping it switches to the other format.
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
    final colors = Theme.of(context).colorScheme;
    final isSay = mode == ChatMode.say;
    final semanticsLabel = isSay ? '当前为说话，点击切换为动作' : '当前为动作，点击切换为说话';

    return Semantics(
      label: semanticsLabel,
      button: true,
      enabled: enabled,
      child: Tooltip(
        message: semanticsLabel,
        excludeFromSemantics: true,
        // 48dp touch target with a 40dp visual circle (Material minimum).
        child: InkResponse(
          key: const Key('chat-mode-toggle'),
          radius: 24,
          containedInkWell: false,
          onTap: enabled
              ? () => onChanged(isSay ? ChatMode.act : ChatMode.say)
              : null,
          child: SizedBox.square(
            dimension: 48,
            child: Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    child: Icon(
                      isSay
                          ? Icons.chat_bubble_outline
                          : Icons.directions_run_outlined,
                      key: ValueKey(mode),
                      size: 19,
                      color: colors.onSecondaryContainer,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
