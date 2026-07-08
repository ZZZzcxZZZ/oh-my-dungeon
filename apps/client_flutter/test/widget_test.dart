import 'package:dnd_table_client/src/app/dnd_table_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the server profile empty state', (tester) async {
    await tester.pumpWidget(const DndTableApp());

    expect(find.text('连接你的跑团服务器'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '添加服务器'), findsOneWidget);
  });
}
