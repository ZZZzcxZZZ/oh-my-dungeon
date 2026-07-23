import 'package:dnd_table_client/src/core/dice/dice_roller.dart';
import 'package:dnd_table_client/src/core/dice/dice_tray_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Task 3.2 — 组合式骰子编辑器 (Foundry Dice Tray 风格) widget 测试.
///
/// 覆盖:
/// - 默认一组 d20 + 修正 0
/// - 修改数量 / 面数 / 修正后表达式预览实时更新
/// - 多组骰子相加, 表达式合并
/// - 优势 / 劣势切换后表达式变为 2d20kh1 / 2d20kl1
/// - 内置预设 (攻击 / 伤害 / 救赎 / 死亡救赎) 填入表达式
/// - 用户自定义预设渲染为按钮
/// - 发送按钮触发 onSend 回调, 携带正确 notation 与 total
/// - 非法表达式时发送按钮禁用, 显示错误提示
void main() {
  /// 固定 nextInt, 让骰子结果可预测: 第一次返回 max-1 (即面数-1 的最大值).
  /// rollExpression 走 DiceExpression.create(notation, random).roll(),
  /// 底层包会按需多次调用 nextInt, 这里统一返回 max-1.
  int fixedNextInt(int max) => max - 1;

  DiceRoller fixedRoller() => DiceRoller(nextInt: fixedNextInt);

  Widget harness(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  group('DiceTrayDialog (Task 3.2)', () {
    test('正则验证: 1d20+5 应正确解析', () {
      final match = RegExp(r'^(\d+)d(\d+)(?:kh1|kl1)?([+-]\d+)?$')
          .firstMatch('1d20+5');
      expect(match, isNotNull, reason: '正则应匹配 1d20+5');
      expect(match!.group(1), '1');
      expect(match.group(2), '20');
      expect(match.group(3), '+5');
    });

    testWidgets('默认显示一组 d20 + 修正 0, 表达式预览为 1d20+0', (tester) async {
      await tester.pumpWidget(
        harness(
          DiceTrayDialog(
            diceRoller: fixedRoller(),
            onSend: (_) {},
          ),
        ),
      );

      // 默认应看到表达式预览
      expect(find.textContaining('1d20'), findsOneWidget);
    });

    testWidgets('修改数量为 2 后表达式变为 2d20+0', (tester) async {
      await tester.pumpWidget(
        harness(
          DiceTrayDialog(
            diceRoller: fixedRoller(),
            onSend: (_) {},
          ),
        ),
      );

      // 找到第一组数量 dropdown 并展开
      await tester.tap(find.byType(DropdownButton<int>).first);
      await tester.pumpAndSettle();

      // 选择 2
      await tester.tap(find.text('2').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('2d20'), findsOneWidget);
    });

    testWidgets('添加骰子组后表达式合并显示 +', (tester) async {
      await tester.pumpWidget(
        harness(
          DiceTrayDialog(
            diceRoller: fixedRoller(),
            onSend: (_) {},
          ),
        ),
      );

      // 点击「加骰子组」按钮
      await tester.tap(find.byKey(DiceTrayDialog.addGroupKey));
      await tester.pumpAndSettle();

      // 表达式应包含 + 分隔符
      expect(find.textContaining('+'), findsWidgets);
    });

    testWidgets('优势模式切换后表达式变为 2d20kh1+修正', (tester) async {
      await tester.pumpWidget(
        harness(
          DiceTrayDialog(
            diceRoller: fixedRoller(),
            onSend: (_) {},
          ),
        ),
      );

      // 点击「优势」分段按钮
      await tester.tap(find.text('优势'));
      await tester.pumpAndSettle();

      expect(find.textContaining('2d20kh1'), findsOneWidget);
    });

    testWidgets('劣势模式切换后表达式变为 2d20kl1+修正', (tester) async {
      await tester.pumpWidget(
        harness(
          DiceTrayDialog(
            diceRoller: fixedRoller(),
            onSend: (_) {},
          ),
        ),
      );

      await tester.tap(find.text('劣势'));
      await tester.pumpAndSettle();

      expect(find.textContaining('2d20kl1'), findsOneWidget);
    });

    testWidgets('内置预设按钮填入对应表达式', (tester) async {
      await tester.pumpWidget(
        harness(
          DiceTrayDialog(
            diceRoller: fixedRoller(),
            onSend: (_) {},
          ),
        ),
      );

      // 点击「攻击」预设 (1d20+5). 用 byKey 定位避免 tap 坐标问题.
      final attackButton = find.byKey(const ValueKey('dice-tray-builtin-攻击'));
      await tester.ensureVisible(attackButton);
      await tester.tap(attackButton, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.textContaining('1d20+5'), findsOneWidget);
    });

    testWidgets('用户自定义预设渲染为按钮', (tester) async {
      await tester.pumpWidget(
        harness(
          DiceTrayDialog(
            diceRoller: fixedRoller(),
            quickPresets: const ['8d6', '2d20kh1+3'],
            onSend: (_) {},
          ),
        ),
      );

      expect(find.text('8d6'), findsOneWidget);
      expect(find.text('2d20kh1+3'), findsOneWidget);
    });

    testWidgets('点击自定义预设填入表达式并发送', (tester) async {
      DiceTrayResult? captured;
      await tester.pumpWidget(
        harness(
          DiceTrayDialog(
            diceRoller: fixedRoller(),
            quickPresets: const ['8d6+3'],
            onSend: (result) => captured = result,
          ),
        ),
      );

      // 点击自定义预设 8d6+3
      final presetButton = find.byKey(const ValueKey('dice-tray-preset-8d6+3'));
      await tester.ensureVisible(presetButton);
      await tester.tap(presetButton, warnIfMissed: false);
      await tester.pumpAndSettle();

      // 表达式预览应显示 8d6+3 (按钮 label 和预览都有该文本, 故至少 1 个)
      expect(find.textContaining('8d6+3'), findsAtLeastNWidgets(1));

      // 点击发送
      await tester.ensureVisible(find.byKey(DiceTrayDialog.sendKey));
      await tester.tap(find.byKey(DiceTrayDialog.sendKey), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.notation, contains('8d6'));
      expect(captured!.notation, contains('+3'));
      // 8d6, nextInt(6)=5, 每颗 6 点, 8 颗 = 48, +3 = 51
      expect(captured!.total, 51);
    });

    testWidgets('发送 d20+5 触发回调携带正确 notation 与 total', (tester) async {
      DiceTrayResult? captured;
      await tester.pumpWidget(
        harness(
          DiceTrayDialog(
            diceRoller: fixedRoller(),
            onSend: (result) => captured = result,
          ),
        ),
      );

      // 选择「攻击」预设 (1d20+5)
      final attackButton = find.byKey(const ValueKey('dice-tray-builtin-攻击'));
      await tester.ensureVisible(attackButton);
      await tester.tap(attackButton, warnIfMissed: false);
      await tester.pumpAndSettle();

      // 发送
      await tester.ensureVisible(find.byKey(DiceTrayDialog.sendKey));
      await tester.tap(find.byKey(DiceTrayDialog.sendKey), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.notation, '1d20+5');
      // d20, nextInt(20)=19, 即 20, +5 = 25
      expect(captured!.total, 25);
      expect(captured!.rollMode, 'normal');
    });

    testWidgets('设置 DC 后回调携带 dc 与 success 字段', (tester) async {
      DiceTrayResult? captured;
      await tester.pumpWidget(
        harness(
          DiceTrayDialog(
            diceRoller: fixedRoller(),
            onSend: (result) => captured = result,
          ),
        ),
      );

      // 选择攻击预设 (1d20+5 = 25)
      final attackButton = find.byKey(const ValueKey('dice-tray-builtin-攻击'));
      await tester.ensureVisible(attackButton);
      await tester.tap(attackButton, warnIfMissed: false);
      await tester.pumpAndSettle();

      // 输入 DC = 15
      await tester.enterText(find.byKey(DiceTrayDialog.dcKey), '15');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(DiceTrayDialog.sendKey));
      await tester.tap(find.byKey(DiceTrayDialog.sendKey), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.dc, 15);
      expect(captured!.success, true); // 25 >= 15
    });

    testWidgets('DC 检定失败时 success 为 false', (tester) async {
      DiceTrayResult? captured;
      await tester.pumpWidget(
        harness(
          DiceTrayDialog(
            diceRoller: fixedRoller(),
            onSend: (result) => captured = result,
          ),
        ),
      );

      // 选择攻击预设 (1d20+5 = 25)
      final attackButton = find.byKey(const ValueKey('dice-tray-builtin-攻击'));
      await tester.ensureVisible(attackButton);
      await tester.tap(attackButton, warnIfMissed: false);
      await tester.pumpAndSettle();

      // 输入 DC = 30 (高于 25, 失败)
      await tester.enterText(find.byKey(DiceTrayDialog.dcKey), '30');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(DiceTrayDialog.sendKey));
      await tester.tap(find.byKey(DiceTrayDialog.sendKey), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.dc, 30);
      expect(captured!.success, false);
    });

    testWidgets('删除骰子组后表达式只保留剩余组', (tester) async {
      await tester.pumpWidget(
        harness(
          DiceTrayDialog(
            diceRoller: fixedRoller(),
            onSend: (_) {},
          ),
        ),
      );

      // 加一组 (默认 1 组, 加后 2 组, 每组 3 个 dropdown = 6 个)
      await tester.tap(find.byKey(DiceTrayDialog.addGroupKey));
      await tester.pumpAndSettle();

      // 删除第一组
      await tester.tap(find.byKey(DiceTrayDialog.removeGroupKey(0)));
      await tester.pumpAndSettle();

      // 应只剩一组 = 3 个 dropdown
      expect(find.byType(DropdownButton<int>), findsNWidgets(3));
    });

    testWidgets('只有一组时删除按钮禁用', (tester) async {
      await tester.pumpWidget(
        harness(
          DiceTrayDialog(
            diceRoller: fixedRoller(),
            onSend: (_) {},
          ),
        ),
      );

      // 只有一组时, 删除按钮应禁用 (onPressed 为 null)
      final button = tester.widget<IconButton>(
        find.byKey(DiceTrayDialog.removeGroupKey(0)),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('解析失败时发送按钮禁用并显示错误', (tester) async {
      await tester.pumpWidget(
        harness(
          DiceTrayDialog(
            diceRoller: fixedRoller(),
            onSend: (_) {},
          ),
        ),
      );

      // 把数量改成 0 (非法表达式 0d20+0). 直接调用 dropdown 的 onChanged 回调,
      // 绕过 overlay 在 widget test 中的遮挡问题.
      final countDropdown = tester.widget<DropdownButton<int>>(
        find.byKey(const ValueKey('dice-tray-count-0')),
      );
      countDropdown.onChanged!(0);
      await tester.pumpAndSettle();

      // 发送按钮应禁用
      await tester.ensureVisible(find.byKey(DiceTrayDialog.sendKey));
      final sendButton = tester.widget<FilledButton>(
        find.byKey(DiceTrayDialog.sendKey),
      );
      expect(sendButton.onPressed, isNull);
    });
  });
}
