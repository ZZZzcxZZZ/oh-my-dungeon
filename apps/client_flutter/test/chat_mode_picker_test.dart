import 'package:dnd_table_client/src/features/campaigns/presentation/chat/chat_mode_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plan 2026-07-23 Wave 1 Task 1.2: 说/做切换滑块动画
///
/// 用户反馈：说/做切换应当做出滑块切换动画而不是两个拼在一起的按钮。
/// 改造目标：用 AnimatedAlign 实现 thumb 滑动；显示「说」「做」文字标签
/// 而非仅图标。
void main() {
  Widget harness(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

  group('ChatModePicker 滑块动画', () {
    testWidgets('显示「说」和「做」文字标签', (tester) async {
      await tester.pumpWidget(harness(
        ChatModePicker(
          mode: ChatMode.say,
          enabled: true,
          onChanged: (_) {},
        ),
      ));

      expect(find.text('说'), findsOneWidget);
      expect(find.text('做'), findsOneWidget);
    });

    testWidgets('say 模式 thumb 居左，act 模式 thumb 居右', (tester) async {
      await tester.pumpWidget(harness(
        ChatModePicker(
          mode: ChatMode.say,
          enabled: true,
          onChanged: (_) {},
        ),
      ));

      // 初始 say 模式，thumb（key=chat-mode-thumb）应在左侧
      final thumbSay = tester.getCenter(find.byKey(const Key('chat-mode-thumb')));
      final pickerCenter =
          tester.getCenter(find.byType(ChatModePicker));
      expect(thumbSay.dx, lessThan(pickerCenter.dx),
          reason: 'say 模式 thumb 应居左');

      // 切换到 act 模式
      await tester.pumpWidget(harness(
        ChatModePicker(
          mode: ChatMode.act,
          enabled: true,
          onChanged: (_) {},
        ),
      ));
      // pump 完成动画
      await tester.pumpAndSettle();

      final thumbAct = tester.getCenter(find.byKey(const Key('chat-mode-thumb')));
      expect(thumbAct.dx, greaterThan(pickerCenter.dx),
          reason: 'act 模式 thumb 应居右');
    });

    testWidgets('点击「做」触发 onChanged 回调', (tester) async {
      ChatMode? captured;
      await tester.pumpWidget(harness(
        ChatModePicker(
          mode: ChatMode.say,
          enabled: true,
          onChanged: (m) => captured = m,
        ),
      ));

      // 找到 act 按钮（key=chat-mode-action）并点击
      await tester.tap(find.byKey(const Key('chat-mode-action')));
      await tester.pump();

      expect(captured, ChatMode.act);
    });

    testWidgets('disabled 时不响应点击', (tester) async {
      ChatMode? captured;
      await tester.pumpWidget(harness(
        ChatModePicker(
          mode: ChatMode.say,
          enabled: false,
          onChanged: (m) => captured = m,
        ),
      ));

      await tester.tap(find.byKey(const Key('chat-mode-action')), warnIfMissed: false);
      await tester.pump();

      expect(captured, isNull);
    });
  });
}
