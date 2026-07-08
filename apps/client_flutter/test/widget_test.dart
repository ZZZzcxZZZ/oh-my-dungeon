import 'package:dnd_table_client/src/app/dnd_table_app.dart';
import 'package:dnd_table_client/src/features/server_profiles/data/server_profile_store.dart';
import 'package:dnd_table_client/src/features/server_profiles/domain/server_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const profile = ServerProfile(
    id: 'localhost',
    name: 'Local Table',
    baseUrl: 'http://localhost:3000',
    apiBaseUrl: 'http://localhost:3000/api',
    websocketUrl: 'ws://localhost:3000/ws',
    lastKnownVersion: '0.1.0',
  );

  testWidgets('shows the server profile empty state', (tester) async {
    await tester.pumpWidget(
      DndTableApp(serverProfileStore: InMemoryServerProfileStore()),
    );
    await tester.pumpAndSettle();

    expect(find.text('连接你的跑团服务器'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '添加服务器'), findsOneWidget);
  });

  testWidgets('switches client mode from settings', (tester) async {
    await tester.pumpWidget(
      DndTableApp(serverProfileStore: InMemoryServerProfileStore()),
    );
    await tester.pumpAndSettle();

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

  testWidgets('marks a saved server profile as default', (tester) async {
    final store = InMemoryServerProfileStore();
    await store.saveProfile(profile);

    await tester.pumpWidget(DndTableApp(serverProfileStore: store));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('服务器操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设为默认'));
    await tester.pumpAndSettle();

    expect(find.text('默认'), findsOneWidget);
  });

  testWidgets('edits a saved server profile name', (tester) async {
    final store = InMemoryServerProfileStore();
    await store.saveProfile(profile);

    await tester.pumpWidget(DndTableApp(serverProfileStore: store));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('服务器操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑名称'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Main Campaign');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('Main Campaign'), findsOneWidget);
    expect(find.text('Local Table'), findsNothing);
  });

  testWidgets('deletes a saved server profile', (tester) async {
    final store = InMemoryServerProfileStore();
    await store.saveProfile(profile);

    await tester.pumpWidget(DndTableApp(serverProfileStore: store));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('服务器操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认删除'));
    await tester.pumpAndSettle();

    expect(find.text('Local Table'), findsNothing);
    expect(find.text('连接你的跑团服务器'), findsOneWidget);
  });

  testWidgets('opens a saved server profile home page', (tester) async {
    final store = InMemoryServerProfileStore();
    await store.saveProfile(profile);

    await tester.pumpWidget(DndTableApp(serverProfileStore: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Local Table'));
    await tester.pumpAndSettle();

    expect(find.text('Local Table'), findsAtLeastNWidgets(1));
    expect(find.text('http://localhost:3000'), findsOneWidget);
    expect(find.text('当前模式：Player'), findsOneWidget);
    expect(find.text('房间与登录入口'), findsOneWidget);
  });
}
