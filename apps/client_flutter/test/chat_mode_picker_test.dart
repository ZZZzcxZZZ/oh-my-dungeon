import 'package:dnd_table_client/src/features/campaigns/presentation/chat/chat_mode_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget harness(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  group('ChatModePicker 单按钮切换', () {
    testWidgets('说话模式暴露当前状态和下一动作', (tester) async {
      await tester.pumpWidget(
        harness(
          ChatModePicker(mode: ChatMode.say, enabled: true, onChanged: (_) {}),
        ),
      );

      expect(find.bySemanticsLabel('当前为说话，点击切换为动作'), findsOneWidget);
    });

    testWidgets('根据模式切换图标', (tester) async {
      await tester.pumpWidget(
        harness(
          ChatModePicker(mode: ChatMode.say, enabled: true, onChanged: (_) {}),
        ),
      );

      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);

      await tester.pumpWidget(
        harness(
          ChatModePicker(mode: ChatMode.act, enabled: true, onChanged: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.directions_run_outlined), findsOneWidget);
    });

    testWidgets('点击按钮切换到另一模式', (tester) async {
      ChatMode? captured;
      await tester.pumpWidget(
        harness(
          ChatModePicker(
            mode: ChatMode.say,
            enabled: true,
            onChanged: (m) => captured = m,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('chat-mode-toggle')));
      await tester.pump();

      expect(captured, ChatMode.act);
    });

    testWidgets('disabled 时不响应点击', (tester) async {
      ChatMode? captured;
      await tester.pumpWidget(
        harness(
          ChatModePicker(
            mode: ChatMode.say,
            enabled: false,
            onChanged: (m) => captured = m,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const Key('chat-mode-toggle')),
        warnIfMissed: false,
      );
      await tester.pump();

      expect(captured, isNull);
    });
  });
}
