import 'package:dnd_table_client/src/app/dnd_table_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the server profile empty state', (tester) async {
    await tester.pumpWidget(const DndTableApp());

    expect(find.text('连接你的跑团服务器'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '添加服务器'), findsOneWidget);
  });

  testWidgets('switches client mode from settings', (tester) async {
    await tester.pumpWidget(const DndTableApp());

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();

    expect(find.text('客户端模式'), findsOneWidget);
    expect(find.text('Player'), findsOneWidget);
    expect(find.text('DM'), findsOneWidget);

    await tester.tap(find.text('DM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();

    expect(find.text('当前模式：DM'), findsOneWidget);
  });
}
