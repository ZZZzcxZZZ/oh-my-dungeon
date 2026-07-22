import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:dnd_table_client/src/features/content/presentation/content_library_controller.dart';
import 'package:dnd_table_client/src/features/content/presentation/content_library_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/content_test_support.dart';

Widget buildContentTestApp({required List<ContentEntry> entries}) {
  final repository = MemoryContentRepository(initialEntries: entries);
  return MaterialApp(
    home: ContentLibraryPage(
      controller: ContentLibraryController(repository: repository),
      onImportRequested: () {},
    ),
  );
}

List<ContentEntry> _spellEntries() => [
  ContentEntry.fromJson({
    'id': 'example:spell/fireball',
    'type': 'spell',
    'slug': 'fireball',
    'name': '火球术',
    'body': <Map<String, Object?>>[],
    'structured': {
      'level': 3,
      'school': '塑能',
      'classes': ['术士', '法师'],
    },
    'revision': 1,
  }),
  ContentEntry.fromJson({
    'id': 'example:spell/fire-bolt',
    'type': 'spell',
    'slug': 'fire-bolt',
    'name': '火焰箭',
    'body': <Map<String, Object?>>[],
    'structured': {
      'level': 0,
      'school': '塑能',
      'classes': ['术士', '法师'],
    },
    'revision': 1,
  }),
  ContentEntry.fromJson({
    'id': 'example:spell/fly',
    'type': 'spell',
    'slug': 'fly',
    'name': '飞行术',
    'body': <Map<String, Object?>>[],
    'structured': {
      'level': 3,
      'school': '变化',
      'classes': ['术士', '法师'],
    },
    'revision': 1,
  }),
];

void main() {
  group('compact filter system', () {
    testWidgets(
      'mobile first screen shows SearchBar and filter button, no large dropdowns',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          buildContentTestApp(entries: [testFighterEntry()]),
        );
        await tester.pumpAndSettle();

        expect(find.byType(SearchBar), findsOneWidget);
        expect(find.byKey(const Key('content-filter-button')), findsOneWidget);
        // 不显示巨大的下拉框.
        expect(find.byType(DropdownMenu), findsNothing);
      },
    );

    testWidgets(
      'tapping filter button opens bottom sheet with type options',
      (tester) async {
        await tester.pumpWidget(buildContentTestApp(entries: _spellEntries()));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('content-filter-button')));
        await tester.pumpAndSettle();

        expect(find.byType(BottomSheet), findsOneWidget);
        // 类型选项可见.
        expect(find.text('法术'), findsWidgets);
      },
    );

    testWidgets(
      'selecting spell type exposes level school and class facets in bottom sheet',
      (tester) async {
        await tester.pumpWidget(buildContentTestApp(entries: _spellEntries()));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('content-filter-button')));
        await tester.pumpAndSettle();

        // 选择法术类型.
        await tester.tap(find.text('法术').last);
        await tester.pumpAndSettle();

        // 法术的结构化 facet 可见.
        expect(find.text('环位'), findsOneWidget);
        expect(find.text('学派'), findsOneWidget);
        expect(find.text('职业'), findsOneWidget);
      },
    );

    testWidgets(
      'selecting a spell level facet shows FilterChip and filters results',
      (tester) async {
        await tester.pumpWidget(buildContentTestApp(entries: _spellEntries()));
        await tester.pumpAndSettle();

        // 打开筛选面板.
        await tester.tap(find.byKey(const Key('content-filter-button')));
        await tester.pumpAndSettle();

        // 选择法术类型.
        await tester.tap(find.text('法术').last);
        await tester.pumpAndSettle();

        // 选择 3 环.
        await tester.tap(find.text('3环').last);
        await tester.pumpAndSettle();

        // 关闭面板.
        await tester.tap(find.byKey(const Key('content-filter-apply')));
        await tester.pumpAndSettle();

        // 结果被过滤: 只剩 3 环法术.
        expect(find.text('火球术'), findsOneWidget);
        expect(find.text('飞行术'), findsOneWidget);
        expect(find.text('火焰箭'), findsNothing);

        // 已启用的 FilterChip 显示在搜索栏下方.
        expect(
          find.descendant(
            of: find.byType(FilterChip),
            matching: find.textContaining('3环'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('clear button in bottom sheet clears all filters',
        (tester) async {
      await tester.pumpWidget(buildContentTestApp(entries: _spellEntries()));
      await tester.pumpAndSettle();

      // 设置筛选.
      await tester.tap(find.byKey(const Key('content-filter-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('法术').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('3环').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('content-filter-apply')));
      await tester.pumpAndSettle();

      // 确认有筛选.
      expect(find.text('火焰箭'), findsNothing);

      // 打开面板并清除.
      await tester.tap(find.byKey(const Key('content-filter-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('content-filter-clear')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('content-filter-apply')));
      await tester.pumpAndSettle();

      // 所有法术都可见.
      expect(find.text('火球术'), findsOneWidget);
      expect(find.text('火焰箭'), findsOneWidget);
      expect(find.text('飞行术'), findsOneWidget);
    });

    testWidgets(
      'tapping a FilterChip label removes that filter',
      (tester) async {
        await tester.pumpWidget(buildContentTestApp(entries: _spellEntries()));
        await tester.pumpAndSettle();

        // 设置类型筛选.
        await tester.tap(find.byKey(const Key('content-filter-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('法术').last);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('content-filter-apply')));
        await tester.pumpAndSettle();

        // 类型 FilterChip 可见.
        final typeChip = find.descendant(
          of: find.byType(FilterChip),
          matching: find.textContaining('法术'),
        );
        expect(typeChip, findsOneWidget);

        // 点击 FilterChip 移除类型筛选.
        await tester.tap(typeChip);
        await tester.pumpAndSettle();

        // 类型筛选被移除, 战士也可见 (如果有).
        // 这里只验证 FilterChip 消失.
        expect(typeChip, findsNothing);
      },
    );
  });
}
