import 'package:dnd_table_client/src/app/dnd_table_app.dart';
import 'package:dnd_table_client/src/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('opens the local shell without a server profile', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    await tester.pumpWidget(
      DndTableApp(database: database, bundledContentLoader: () async => '{}'),
    );
    await tester.pumpAndSettle();

    expect(find.text('首页'), findsNothing);
    expect(find.text('战役'), findsWidgets);
    expect(find.text('角色'), findsWidgets);
    expect(find.text('资料库'), findsWidgets);
    expect(find.text('设置'), findsWidgets);
    // 离线优先：不再显示"连接你的跑团服务器"入口，直接进入主壳。
    expect(find.text('连接你的跑团服务器'), findsNothing);
    await database.close();
  });

  testWidgets('shows offline prompts on campaigns tab without a server', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    await tester.pumpWidget(
      DndTableApp(database: database, bundledContentLoader: () async => '{}'),
    );
    await tester.pumpAndSettle();

    // 战役是默认入口；离线时直接说明需要连接服务器。
    expect(find.text('未连接服务器'), findsWidgets);
    await database.close();
  });

  testWidgets('settings tab shows manage server entry in offline mode', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    await tester.pumpWidget(
      DndTableApp(database: database, bundledContentLoader: () async => '{}'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();

    expect(find.text('尚未连接服务器'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '管理服务器'), findsOneWidget);
    await database.close();
  });
}
